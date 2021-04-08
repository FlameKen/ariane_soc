// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Xilinx Peripehrals
module ariane_peripherals #(
    parameter NB_SLAVE = 3,   
    parameter int AxiAddrWidth = -1,
    parameter int AxiDataWidth = -1,
    parameter int AxiIdWidth   = -1,
    parameter int AxiUserWidth = 1,
    parameter bit InclUART     = 1,
    parameter bit InclSPI      = 0,
    parameter bit InclEthernet = 0,
    parameter LOG_N_INIT = $clog2(ariane_soc::NB_PERIPHERALS),
    parameter bit InclGPIO     = 0
) (
    input  logic               clk_i           , // Clock
    input  logic               rst_ni          , // Asynchronous reset active low
    input  logic               srst_ni         ,
    AXI_BUS.in                 plic            ,
    AXI_BUS.in                 aes             , 
    AXI_BUS.in                 aes2            ,
    AXI_BUS.in                 mop            ,
    AXI_BUS.in                 debug2          ,
    AXI_BUS.in                 test            , 
    AXI_BUS.in                 sha256          , 
    AXI_BUS.in                 acct            , 
    AXI_BUS.in                 pkt             , 
    AXI_BUS.in                 reglk           , 
    AXI_BUS.in                 uart            ,
    AXI_BUS.in                 spi             ,
    AXI_BUS.in                 ethernet        ,
    
    AXI_BUS.in                 dma             , 
    output ariane_axi::req_t   dma_axi_req_o   ,
    input  ariane_axi::resp_t  dma_axi_resp_i  ,
    
    output logic [31:0]        jtag_key       , 
    output logic [NB_SLAVE-1:0][4*ariane_soc::NB_PERIPHERALS-1 :0]   access_ctrl_reg, 
    output logic [1:0]         irq_o           ,
    // UART
    input  logic               rx_i            ,
    output logic               tx_o            ,
    // Ethernet
    input  wire                eth_txck        ,
    input  wire                eth_rxck        ,
    input  wire                eth_rxctl       ,
    input  wire [3:0]          eth_rxd         ,
    output wire                eth_rst_n       ,
    output wire                eth_tx_en       ,
    output wire [3:0]          eth_txd         ,
    inout  wire                phy_mdio        ,
    output logic               eth_mdc         ,
    // MDIO Interface
    inout                      mdio            ,
    output                     mdc             ,
    // SPI
    output logic               spi_clk_o       ,
    output logic               spi_mosi        ,
    input  logic               spi_miso        ,
    input  logic [191:0]       testCycle       ,
    output logic [LOG_N_INIT-1:0]              MoP_request     ,
    output logic [LOG_N_INIT-1:0]              MoP_receive     ,
    output logic  [ariane_soc::NB_PERIPHERALS-1 :0]  redirection_idle,
    output logic [ariane_soc::NB_PERIPHERALS-1 :0]  valid_i,
    input logic [ariane_soc::NB_PERIPHERALS-1 :0]  valid_o,
    output logic               spi_ss
);
logic   [7:0] TEST_SIGNAL;
logic   [ariane_soc::NB_PERIPHERALS-1 :0] [LOG_N_INIT-1:0]          request;
logic   [ariane_soc::NB_PERIPHERALS-1 :0] [LOG_N_INIT-1:0]          receive;
logic   [LOG_N_INIT-1:0]                                            request_2[ariane_soc::NB_PERIPHERALS-1 :0];
logic   [LOG_N_INIT-1:0]                                            receive_2[ariane_soc::NB_PERIPHERALS-1 :0];
logic   [8*ariane_soc::NB_PERIPHERALS-1 :0]                         reglk_ctrl; // Access control values
logic   [ariane_soc::NB_PERIPHERALS-1 :0]                           load_ctrl; // Access control values
logic   [31:0]                                                      instrut_value;
logic   [1:0]                                                       change;
logic   [ariane_soc::NB_PERIPHERALS-1 :0]                           idle;
logic                                                               MoP_override;
logic   [ariane_soc::NB_PERIPHERALS-1 :0]                           override_in;
logic   [ariane_soc::NB_PERIPHERALS-1 :0]                           override_out;
logic   [ariane_soc::NB_PERIPHERALS-1 :0] [32:0]                    re_data_out;
logic   [ariane_soc::NB_PERIPHERALS-1 :0] [32:0]                    re_data_in;
assign redirection_idle = idle;

genvar i;
generate
    for(i = 0 ; i < ariane_soc::NB_PERIPHERALS; i++)begin
        if(i != 5 && i != 14 && i != 15 )begin
            assign request[i] = 0;
            assign receive[i] = 0;
            // assign redirect_o[i] = 0;
        end
    end
    for(i = 0 ; i < ariane_soc::NB_PERIPHERALS; i++)begin
            assign request_2[i] = request[i];
            assign receive_2[i] = receive[i];
            // assign redirect_o[i] = 0;
    end
assign MoP_request = request_2.sum();
assign MoP_receive = receive_2.sum();
    

endgenerate

    // ---------------
    // 1. PLIC
    // ---------------
    logic [ariane_soc::NumSources-1:0] irq_sources;

    REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) reg_bus (clk_i);

    logic         plic_penable;
    logic         plic_pwrite;
    logic [31:0]  plic_paddr;
    logic         plic_psel;
    logic [31:0]  plic_pwdata;
    logic [31:0]  plic_prdata;
    logic         plic_pready;
    logic         plic_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth  ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_ID_WIDTH      ( AxiIdWidth    ),
        .AXI4_USER_WIDTH    ( AxiUserWidth  ),
        .BUFF_DEPTH_SLAVE   ( 2             ),
        .APB_ADDR_WIDTH     ( 32            )
    ) i_axi2apb_64_32_plic (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( plic.aw_id     ),
        .AWADDR_i  ( plic.aw_addr   ),
        .AWLEN_i   ( plic.aw_len    ),
        .AWSIZE_i  ( plic.aw_size   ),
        .AWBURST_i ( plic.aw_burst  ),
        .AWLOCK_i  ( plic.aw_lock   ),
        .AWCACHE_i ( plic.aw_cache  ),
        .AWPROT_i  ( plic.aw_prot   ),
        .AWREGION_i( plic.aw_region ),
        .AWUSER_i  ( plic.aw_user   ),
        .AWQOS_i   ( plic.aw_qos    ),
        .AWVALID_i ( plic.aw_valid  ),
        .AWREADY_o ( plic.aw_ready  ),
        .WDATA_i   ( plic.w_data    ),
        .WSTRB_i   ( plic.w_strb    ),
        .WLAST_i   ( plic.w_last    ),
        .WUSER_i   ( plic.w_user    ),
        .WVALID_i  ( plic.w_valid   ),
        .WREADY_o  ( plic.w_ready   ),
        .BID_o     ( plic.b_id      ),
        .BRESP_o   ( plic.b_resp    ),
        .BVALID_o  ( plic.b_valid   ),
        .BUSER_o   ( plic.b_user    ),
        .BREADY_i  ( plic.b_ready   ),
        .ARID_i    ( plic.ar_id     ),
        .ARADDR_i  ( plic.ar_addr   ),
        .ARLEN_i   ( plic.ar_len    ),
        .ARSIZE_i  ( plic.ar_size   ),
        .ARBURST_i ( plic.ar_burst  ),
        .ARLOCK_i  ( plic.ar_lock   ),
        .ARCACHE_i ( plic.ar_cache  ),
        .ARPROT_i  ( plic.ar_prot   ),
        .ARREGION_i( plic.ar_region ),
        .ARUSER_i  ( plic.ar_user   ),
        .ARQOS_i   ( plic.ar_qos    ),
        .ARVALID_i ( plic.ar_valid  ),
        .ARREADY_o ( plic.ar_ready  ),
        .RID_o     ( plic.r_id      ),
        .RDATA_o   ( plic.r_data    ),
        .RRESP_o   ( plic.r_resp    ),
        .RLAST_o   ( plic.r_last    ),
        .RUSER_o   ( plic.r_user    ),
        .RVALID_o  ( plic.r_valid   ),
        .RREADY_i  ( plic.r_ready   ),
        .PENABLE   ( plic_penable   ),
        .PWRITE    ( plic_pwrite    ),
        .PADDR     ( plic_paddr     ),
        .PSEL      ( plic_psel      ),
        .PWDATA    ( plic_pwdata    ),
        .PRDATA    ( plic_prdata    ),
        .PREADY    ( plic_pready    ),
        .PSLVERR   ( plic_pslverr   )
    );

    apb_to_reg i_apb_to_reg (
        .clk_i     ( clk_i        ),
        .rst_ni    ( rst_ni       ),
        .penable_i ( plic_penable ),
        .pwrite_i  ( plic_pwrite  ),
        .paddr_i   ( plic_paddr   ),
        .psel_i    ( plic_psel    ),
        .pwdata_i  ( plic_pwdata  ),
        .prdata_o  ( plic_prdata  ),
        .pready_o  ( plic_pready  ),
        .pslverr_o ( plic_pslverr ),
        .reg_o     ( reg_bus      )
    );

    plic #(
        .ID_BITWIDTH        ( ariane_soc::PLICIdWidth       ),
        .PARAMETER_BITWIDTH ( ariane_soc::ParameterBitwidth ),
        .NUM_TARGETS        ( ariane_soc::NumTargets        ),
        .NUM_SOURCES        ( ariane_soc::NumSources        )
    ) i_plic (
        .clk_i              ( clk_i                  ),
        .rst_ni             ( rst_ni                 ),
        .irq_sources_i      ( irq_sources            ),
        .eip_targets_o      ( irq_o                  ),
        .external_bus_io    ( reg_bus                )
    );
    

///////////////////////////////////////////////////////////////////////////////////////
    // ---------------
    //  test.
    // It is the peripheral key table. It reads data from fuse mem and gives that data
    // and the corresponding target address for that data to the processor
    // ---------------

    REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) reg_bus_test (clk_i);
    
    logic         test_penable;
    logic         test_pwrite;
    logic [31:0]  test_paddr;
    logic         test_psel;
    logic [31:0]  test_pwdata;
    logic [31:0]  test_prdata;
    logic         test_pready;
    logic         test_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth  ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_ID_WIDTH      ( AxiIdWidth    ),
        .AXI4_USER_WIDTH    ( AxiUserWidth  ),
        .BUFF_DEPTH_SLAVE   ( 2             ),
        .APB_ADDR_WIDTH     ( 32            )
    ) i_axi2apb_64_32_test (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( test.aw_id     ),
        .AWADDR_i  ( test.aw_addr   ),
        .AWLEN_i   ( test.aw_len    ),
        .AWSIZE_i  ( test.aw_size   ),
        .AWBURST_i ( test.aw_burst  ),
        .AWLOCK_i  ( test.aw_lock   ),
        .AWCACHE_i ( test.aw_cache  ),
        .AWPROT_i  ( test.aw_prot   ),
        .AWREGION_i( test.aw_region ),
        .AWUSER_i  ( test.aw_user   ),
        .AWQOS_i   ( test.aw_qos    ),
        .AWVALID_i ( test.aw_valid  ),
        .AWREADY_o ( test.aw_ready  ),
        .WDATA_i   ( test.w_data    ),
        .WSTRB_i   ( test.w_strb    ),
        .WLAST_i   ( test.w_last    ),
        .WUSER_i   ( test.w_user    ),
        .WVALID_i  ( test.w_valid   ),
        .WREADY_o  ( test.w_ready   ),
        .BID_o     ( test.b_id      ),
        .BRESP_o   ( test.b_resp    ),
        .BVALID_o  ( test.b_valid   ),
        .BUSER_o   ( test.b_user    ),
        .BREADY_i  ( test.b_ready   ),
        .ARID_i    ( test.ar_id     ),
        .ARADDR_i  ( test.ar_addr   ),
        .ARLEN_i   ( test.ar_len    ),
        .ARSIZE_i  ( test.ar_size   ),
        .ARBURST_i ( test.ar_burst  ),
        .ARLOCK_i  ( test.ar_lock   ),
        .ARCACHE_i ( test.ar_cache  ),
        .ARPROT_i  ( test.ar_prot   ),
        .ARREGION_i( test.ar_region ),
        .ARUSER_i  ( test.ar_user   ),
        .ARQOS_i   ( test.ar_qos    ),
        .ARVALID_i ( test.ar_valid  ),
        .ARREADY_o ( test.ar_ready  ),
        .RID_o     ( test.r_id      ),
        .RDATA_o   ( test.r_data    ),
        .RRESP_o   ( test.r_resp    ),
        .RLAST_o   ( test.r_last    ),
        .RUSER_o   ( test.r_user    ),
        .RVALID_o  ( test.r_valid   ),
        .RREADY_i  ( test.r_ready   ),
        .PENABLE   ( test_penable   ),
        .PWRITE    ( test_pwrite    ),
        .PADDR     ( test_paddr     ),
        .PSEL      ( test_psel      ),
        .PWDATA    ( test_pwdata    ),
        .PRDATA    ( test_prdata    ),
        .PREADY    ( test_pready    ),
        .PSLVERR   ( test_pslverr   )
    );

    apb_to_reg i_apb_to_reg_test (
        .clk_i     ( clk_i        ),
        .rst_ni    ( rst_ni       ),
        .penable_i ( test_penable ),
        .pwrite_i  ( test_pwrite  ),
        .paddr_i   ( test_paddr   ),
        .psel_i    ( test_psel    ),
        .pwdata_i  ( test_pwdata  ),
        .prdata_o  ( test_prdata  ),
        .pready_o  ( test_pready  ),
        .pslverr_o ( test_pslverr ),
        .reg_o     ( reg_bus_test )
    );

    test_wrapper #(
        .LOG_N_INIT(LOG_N_INIT)
    ) i_test_wrapper (
        .clk_i              ( clk_i             ),
        .rst_ni             ( rst_ni            ),
        .reglk_ctrl_o       ( TEST_SIGNAL ),
        .request            (request[ariane_soc::TEST]),
        .receive            (receive[ariane_soc::TEST]),
        .valid_i            (valid_o[ariane_soc::TEST]),
        .valid_o            (valid_i[ariane_soc::TEST]),
        .external_bus_io    ( reg_bus_test       )
    );

///////////////////////////////////////////////////////////////////////////////////////
    // ---------------
    // Access control peripheral
    // ---------------

    REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) reg_bus_acct (clk_i);
    
    logic         acct_penable;
    logic         acct_pwrite;
    logic [31:0]  acct_paddr;
    logic         acct_psel;
    logic [31:0]  acct_pwdata;
    logic [31:0]  acct_prdata;
    logic         acct_pready;
    logic         acct_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth  ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_ID_WIDTH      ( AxiIdWidth    ),
        .AXI4_USER_WIDTH    ( AxiUserWidth  ),
        .BUFF_DEPTH_SLAVE   ( 2             ),
        .APB_ADDR_WIDTH     ( 32            )
    ) i_axi2apb_64_32_acct (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( acct.aw_id     ),
        .AWADDR_i  ( acct.aw_addr   ),
        .AWLEN_i   ( acct.aw_len    ),
        .AWSIZE_i  ( acct.aw_size   ),
        .AWBURST_i ( acct.aw_burst  ),
        .AWLOCK_i  ( acct.aw_lock   ),
        .AWCACHE_i ( acct.aw_cache  ),
        .AWPROT_i  ( acct.aw_prot   ),
        .AWREGION_i( acct.aw_region ),
        .AWUSER_i  ( acct.aw_user   ),
        .AWQOS_i   ( acct.aw_qos    ),
        .AWVALID_i ( acct.aw_valid  ),
        .AWREADY_o ( acct.aw_ready  ),
        .WDATA_i   ( acct.w_data    ),
        .WSTRB_i   ( acct.w_strb    ),
        .WLAST_i   ( acct.w_last    ),
        .WUSER_i   ( acct.w_user    ),
        .WVALID_i  ( acct.w_valid   ),
        .WREADY_o  ( acct.w_ready   ),
        .BID_o     ( acct.b_id      ),
        .BRESP_o   ( acct.b_resp    ),
        .BVALID_o  ( acct.b_valid   ),
        .BUSER_o   ( acct.b_user    ),
        .BREADY_i  ( acct.b_ready   ),
        .ARID_i    ( acct.ar_id     ),
        .ARADDR_i  ( acct.ar_addr   ),
        .ARLEN_i   ( acct.ar_len    ),
        .ARSIZE_i  ( acct.ar_size   ),
        .ARBURST_i ( acct.ar_burst  ),
        .ARLOCK_i  ( acct.ar_lock   ),
        .ARCACHE_i ( acct.ar_cache  ),
        .ARPROT_i  ( acct.ar_prot   ),
        .ARREGION_i( acct.ar_region ),
        .ARUSER_i  ( acct.ar_user   ),
        .ARQOS_i   ( acct.ar_qos    ),
        .ARVALID_i ( acct.ar_valid  ),
        .ARREADY_o ( acct.ar_ready  ),
        .RID_o     ( acct.r_id      ),
        .RDATA_o   ( acct.r_data    ),
        .RRESP_o   ( acct.r_resp    ),
        .RLAST_o   ( acct.r_last    ),
        .RUSER_o   ( acct.r_user    ),
        .RVALID_o  ( acct.r_valid   ),
        .RREADY_i  ( acct.r_ready   ),
        .PENABLE   ( acct_penable   ),
        .PWRITE    ( acct_pwrite    ),
        .PADDR     ( acct_paddr     ),
        .PSEL      ( acct_psel      ),
        .PWDATA    ( acct_pwdata    ),
        .PRDATA    ( acct_prdata    ),
        .PREADY    ( acct_pready    ),
        .PSLVERR   ( acct_pslverr   )
    );

    apb_to_reg i_apb_to_reg_acct (
        .clk_i     ( clk_i        ),
        .rst_ni    ( rst_ni       ),
        .penable_i ( acct_penable ),
        .pwrite_i  ( acct_pwrite  ),
        .paddr_i   ( acct_paddr   ),
        .psel_i    ( acct_psel    ),
        .pwdata_i  ( acct_pwdata  ),
        .prdata_o  ( acct_prdata  ),
        .pready_o  ( acct_pready  ),
        .pslverr_o ( acct_pslverr ),
        .reg_o     ( reg_bus_acct )
    );
    
    acct_wrapper #(
        .NB_SLAVE(NB_SLAVE)
    ) i_acct_wrapper (
        .clk_i              ( clk_i                  ),
        .rst_ni             ( rst_ni                 ),
        .reglk_ctrl_i       ( reglk_ctrl[((8*ariane_soc::AcCt)+8-1):((8*ariane_soc::AcCt))] ),
        .acc_ctrl_o         ( access_ctrl_reg        ),
        .external_bus_io    ( reg_bus_acct           )
    );


///////////////////////////////////////////////////////////////////////////////////////

    // ---------------
    // FUSE Mem 
    // ---------------
    logic                         fuse_req;
    logic [31:0]                  fuse_addr;
    logic [31:0]                  fuse_rdata;

    parameter  FUSE_MEM_SIZE = 34; // change this size when ever no of entries in FUSE mem is changed

    fuse_mem # (
        .MEM_SIZE(FUSE_MEM_SIZE)
    ) i_fuse_mem        (
        .clk_i          ( clk_i      ),
        .jtag_key_o     ( jtag_key   ),
        .req_i          ( fuse_req   ),
        .addr_i         ( fuse_addr  ),
        .rdata_o        ( fuse_rdata ) 
    );
    

///////////////////////////////////////////////////////////////////////////////////////
    // ---------------
    //  pkt.
    // It is the peripheral key table. It reads data from fuse mem and gives that data
    // and the corresponding target address for that data to the processor
    // ---------------

    REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) reg_bus_pkt (clk_i);
    
    logic         pkt_penable;
    logic         pkt_pwrite;
    logic [31:0]  pkt_paddr;
    logic         pkt_psel;
    logic [31:0]  pkt_pwdata;
    logic [31:0]  pkt_prdata;
    logic         pkt_pready;
    logic         pkt_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth  ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_ID_WIDTH      ( AxiIdWidth    ),
        .AXI4_USER_WIDTH    ( AxiUserWidth  ),
        .BUFF_DEPTH_SLAVE   ( 2             ),
        .APB_ADDR_WIDTH     ( 32            )
    ) i_axi2apb_64_32_pkt (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( pkt.aw_id     ),
        .AWADDR_i  ( pkt.aw_addr   ),
        .AWLEN_i   ( pkt.aw_len    ),
        .AWSIZE_i  ( pkt.aw_size   ),
        .AWBURST_i ( pkt.aw_burst  ),
        .AWLOCK_i  ( pkt.aw_lock   ),
        .AWCACHE_i ( pkt.aw_cache  ),
        .AWPROT_i  ( pkt.aw_prot   ),
        .AWREGION_i( pkt.aw_region ),
        .AWUSER_i  ( pkt.aw_user   ),
        .AWQOS_i   ( pkt.aw_qos    ),
        .AWVALID_i ( pkt.aw_valid  ),
        .AWREADY_o ( pkt.aw_ready  ),
        .WDATA_i   ( pkt.w_data    ),
        .WSTRB_i   ( pkt.w_strb    ),
        .WLAST_i   ( pkt.w_last    ),
        .WUSER_i   ( pkt.w_user    ),
        .WVALID_i  ( pkt.w_valid   ),
        .WREADY_o  ( pkt.w_ready   ),
        .BID_o     ( pkt.b_id      ),
        .BRESP_o   ( pkt.b_resp    ),
        .BVALID_o  ( pkt.b_valid   ),
        .BUSER_o   ( pkt.b_user    ),
        .BREADY_i  ( pkt.b_ready   ),
        .ARID_i    ( pkt.ar_id     ),
        .ARADDR_i  ( pkt.ar_addr   ),
        .ARLEN_i   ( pkt.ar_len    ),
        .ARSIZE_i  ( pkt.ar_size   ),
        .ARBURST_i ( pkt.ar_burst  ),
        .ARLOCK_i  ( pkt.ar_lock   ),
        .ARCACHE_i ( pkt.ar_cache  ),
        .ARPROT_i  ( pkt.ar_prot   ),
        .ARREGION_i( pkt.ar_region ),
        .ARUSER_i  ( pkt.ar_user   ),
        .ARQOS_i   ( pkt.ar_qos    ),
        .ARVALID_i ( pkt.ar_valid  ),
        .ARREADY_o ( pkt.ar_ready  ),
        .RID_o     ( pkt.r_id      ),
        .RDATA_o   ( pkt.r_data    ),
        .RRESP_o   ( pkt.r_resp    ),
        .RLAST_o   ( pkt.r_last    ),
        .RUSER_o   ( pkt.r_user    ),
        .RVALID_o  ( pkt.r_valid   ),
        .RREADY_i  ( pkt.r_ready   ),
        .PENABLE   ( pkt_penable   ),
        .PWRITE    ( pkt_pwrite    ),
        .PADDR     ( pkt_paddr     ),
        .PSEL      ( pkt_psel      ),
        .PWDATA    ( pkt_pwdata    ),
        .PRDATA    ( pkt_prdata    ),
        .PREADY    ( pkt_pready    ),
        .PSLVERR   ( pkt_pslverr   )
    );

    apb_to_reg i_apb_to_reg_pkt (
        .clk_i     ( clk_i        ),
        .rst_ni    ( rst_ni       ),
        .penable_i ( pkt_penable ),
        .pwrite_i  ( pkt_pwrite  ),
        .paddr_i   ( pkt_paddr   ),
        .psel_i    ( pkt_psel    ),
        .pwdata_i  ( pkt_pwdata  ),
        .prdata_o  ( pkt_prdata  ),
        .pready_o  ( pkt_pready  ),
        .pslverr_o ( pkt_pslverr ),
        .reg_o     ( reg_bus_pkt )
    );

    pkt_wrapper #(
    ) i_pkt_wrapper (
        .clk_i              ( clk_i             ),
        .rst_ni             ( rst_ni            ),
        .fuse_req_o         ( fuse_req          ),
        .fuse_addr_o        ( fuse_addr         ),
        .fuse_rdata_i       ( fuse_rdata        ), 
        .external_bus_io    ( reg_bus_pkt       )
    );



///////////////////////////////////////////////////////////////////////////////////////
    // ---------------
    // Register lock peripheral
    // ---------------

    REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) reg_bus_reglk (clk_i);
    
    logic         reglk_penable;
    logic         reglk_pwrite;
    logic [31:0]  reglk_paddr;
    logic         reglk_psel;
    logic [31:0]  reglk_pwdata;
    logic [31:0]  reglk_prdata;
    logic         reglk_pready;
    logic         reglk_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth  ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_ID_WIDTH      ( AxiIdWidth    ),
        .AXI4_USER_WIDTH    ( AxiUserWidth  ),
        .BUFF_DEPTH_SLAVE   ( 2             ),
        .APB_ADDR_WIDTH     ( 32            )
    ) i_axi2apb_64_32_reglk (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( reglk.aw_id     ),
        .AWADDR_i  ( reglk.aw_addr   ),
        .AWLEN_i   ( reglk.aw_len    ),
        .AWSIZE_i  ( reglk.aw_size   ),
        .AWBURST_i ( reglk.aw_burst  ),
        .AWLOCK_i  ( reglk.aw_lock   ),
        .AWCACHE_i ( reglk.aw_cache  ),
        .AWPROT_i  ( reglk.aw_prot   ),
        .AWREGION_i( reglk.aw_region ),
        .AWUSER_i  ( reglk.aw_user   ),
        .AWQOS_i   ( reglk.aw_qos    ),
        .AWVALID_i ( reglk.aw_valid  ),
        .AWREADY_o ( reglk.aw_ready  ),
        .WDATA_i   ( reglk.w_data    ),
        .WSTRB_i   ( reglk.w_strb    ),
        .WLAST_i   ( reglk.w_last    ),
        .WUSER_i   ( reglk.w_user    ),
        .WVALID_i  ( reglk.w_valid   ),
        .WREADY_o  ( reglk.w_ready   ),
        .BID_o     ( reglk.b_id      ),
        .BRESP_o   ( reglk.b_resp    ),
        .BVALID_o  ( reglk.b_valid   ),
        .BUSER_o   ( reglk.b_user    ),
        .BREADY_i  ( reglk.b_ready   ),
        .ARID_i    ( reglk.ar_id     ),
        .ARADDR_i  ( reglk.ar_addr   ),
        .ARLEN_i   ( reglk.ar_len    ),
        .ARSIZE_i  ( reglk.ar_size   ),
        .ARBURST_i ( reglk.ar_burst  ),
        .ARLOCK_i  ( reglk.ar_lock   ),
        .ARCACHE_i ( reglk.ar_cache  ),
        .ARPROT_i  ( reglk.ar_prot   ),
        .ARREGION_i( reglk.ar_region ),
        .ARUSER_i  ( reglk.ar_user   ),
        .ARQOS_i   ( reglk.ar_qos    ),
        .ARVALID_i ( reglk.ar_valid  ),
        .ARREADY_o ( reglk.ar_ready  ),
        .RID_o     ( reglk.r_id      ),
        .RDATA_o   ( reglk.r_data    ),
        .RRESP_o   ( reglk.r_resp    ),
        .RLAST_o   ( reglk.r_last    ),
        .RUSER_o   ( reglk.r_user    ),
        .RVALID_o  ( reglk.r_valid   ),
        .RREADY_i  ( reglk.r_ready   ),
        .PENABLE   ( reglk_penable   ),
        .PWRITE    ( reglk_pwrite    ),
        .PADDR     ( reglk_paddr     ),
        .PSEL      ( reglk_psel      ),
        .PWDATA    ( reglk_pwdata    ),
        .PRDATA    ( reglk_prdata    ),
        .PREADY    ( reglk_pready    ),
        .PSLVERR   ( reglk_pslverr   )
    );

    apb_to_reg i_apb_to_reg_reglk (
        .clk_i     ( clk_i        ),
        .rst_ni    ( rst_ni       ),
        .penable_i ( reglk_penable ),
        .pwrite_i  ( reglk_pwrite  ),
        .paddr_i   ( reglk_paddr   ),
        .psel_i    ( reglk_psel    ),
        .pwdata_i  ( reglk_pwdata  ),
        .prdata_o  ( reglk_prdata  ),
        .pready_o  ( reglk_pready  ),
        .pslverr_o ( reglk_pslverr ),
        .reg_o     ( reg_bus_reglk )
    );
   

 
    reglk_wrapper #(
        .NB_SLAVE(NB_SLAVE)
    ) i_reglk_wrapper (
        .clk_i              ( clk_i                  ),
        .rst_ni             ( rst_ni && srst_ni      ),
        .reglk_ctrl_o       ( reglk_ctrl             ),
        .external_bus_io    ( reg_bus_reglk          )
    );

    
///////////////////////////////////////////////////////////////////////////////////////

    // ---------------
    // 4. AES
    // ---------------

    REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) reg_bus_aes (clk_i);

    MOP_BUS mop_bus_aes();

    logic [191:0] aes_key_in;
    logic         aes_penable;
    logic         aes_pwrite;
    logic [31:0]  aes_paddr;
    logic         aes_psel;
    logic [31:0]  aes_pwdata;
    logic [31:0]  aes_prdata;
    logic         aes_pready;
    logic         aes_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth  ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_ID_WIDTH      ( AxiIdWidth    ),
        .AXI4_USER_WIDTH    ( AxiUserWidth  ),
        .BUFF_DEPTH_SLAVE   ( 2             ),
        .APB_ADDR_WIDTH     ( 32            )
    ) i_axi2apb_64_32_aes (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( aes.aw_id     ),
        .AWADDR_i  ( aes.aw_addr   ),
        .AWLEN_i   ( aes.aw_len    ),
        .AWSIZE_i  ( aes.aw_size   ),
        .AWBURST_i ( aes.aw_burst  ),
        .AWLOCK_i  ( aes.aw_lock   ),
        .AWCACHE_i ( aes.aw_cache  ),
        .AWPROT_i  ( aes.aw_prot   ),
        .AWREGION_i( aes.aw_region ),
        .AWUSER_i  ( aes.aw_user   ),
        .AWQOS_i   ( aes.aw_qos    ),
        .AWVALID_i ( aes.aw_valid  ),
        .AWREADY_o ( aes.aw_ready  ),
        .WDATA_i   ( aes.w_data    ),
        .WSTRB_i   ( aes.w_strb    ),
        .WLAST_i   ( aes.w_last    ),
        .WUSER_i   ( aes.w_user    ),
        .WVALID_i  ( aes.w_valid   ),
        .WREADY_o  ( aes.w_ready   ),
        .BID_o     ( aes.b_id      ),
        .BRESP_o   ( aes.b_resp    ),
        .BVALID_o  ( aes.b_valid   ),
        .BUSER_o   ( aes.b_user    ),
        .BREADY_i  ( aes.b_ready   ),
        .ARID_i    ( aes.ar_id     ),
        .ARADDR_i  ( aes.ar_addr   ),
        .ARLEN_i   ( aes.ar_len    ),
        .ARSIZE_i  ( aes.ar_size   ),
        .ARBURST_i ( aes.ar_burst  ),
        .ARLOCK_i  ( aes.ar_lock   ),
        .ARCACHE_i ( aes.ar_cache  ),
        .ARPROT_i  ( aes.ar_prot   ),
        .ARREGION_i( aes.ar_region ),
        .ARUSER_i  ( aes.ar_user   ),
        .ARQOS_i   ( aes.ar_qos    ),
        .ARVALID_i ( aes.ar_valid  ),
        .ARREADY_o ( aes.ar_ready  ),
        .RID_o     ( aes.r_id      ),
        .RDATA_o   ( aes.r_data    ),
        .RRESP_o   ( aes.r_resp    ),
        .RLAST_o   ( aes.r_last    ),
        .RUSER_o   ( aes.r_user    ),
        .RVALID_o  ( aes.r_valid   ),
        .RREADY_i  ( aes.r_ready   ),
        .PENABLE   ( aes_penable   ),
        .PWRITE    ( aes_pwrite    ),
        .PADDR     ( aes_paddr     ),
        .PSEL      ( aes_psel      ),
        .PWDATA    ( aes_pwdata    ),
        .PRDATA    ( aes_prdata    ),
        .PREADY    ( aes_pready    ),
        .PSLVERR   ( aes_pslverr   )
    );

    apb_to_reg i_apb_to_reg_aes (
        .clk_i     ( clk_i        ),
        .rst_ni    ( rst_ni       ),
        .penable_i ( aes_penable ),
        .pwrite_i  ( aes_pwrite  ),
        .paddr_i   ( aes_paddr   ),
        .psel_i    ( aes_psel    ),
        .pwdata_i  ( aes_pwdata  ),
        .prdata_o  ( aes_prdata  ),
        .pready_o  ( aes_pready  ),
        .pslverr_o ( aes_pslverr ),
        .reg_o     ( reg_bus_aes )
    );
    str_to_mop i_str_to_mop_aes(
        .request            (request[ariane_soc::AES]),
        .receive            (receive[ariane_soc::AES]),
        .valid_i            (valid_o[ariane_soc::AES]),
        .valid_o            (valid_i[ariane_soc::AES]),
        .idle_IP            (idle[ariane_soc::AES]),
        .instrut_value      (instrut_value),
        .load_ctrl          ( load_ctrl),
        .MoP_override       ( MoP_override),
        .change             ( change),
        .override_in        ( override_out[ariane_soc::AES2]),
        .override_out       ( override_out[ariane_soc::AES]),
        .re_data_in    ( re_data_out[ariane_soc::AES2]),
        .re_data_out   ( re_data_out[ariane_soc::AES]),
        .mop_o              ( mop_bus_aes)
    );
    aes_wrapper #(
        .LOG_N_INIT(LOG_N_INIT)
    ) i_aes_wrapper (
        .clk_i              ( clk_i                  ),
        .rst_ni             ( rst_ni                 ),
        .key_in             ( aes_key_in             ),
        .reglk_ctrl_i       ( reglk_ctrl[8*ariane_soc::AES+8-1:8*ariane_soc::AES] ),
        .testCycle          (testCycle),
        .mop_bus_io         ( mop_bus_aes),
        .external_bus_io    ( reg_bus_aes            )
    );
    // ---------------
    // 4. AES2
    // ---------------

    REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) reg_bus_aes2 (clk_i);
    
    MOP_BUS mop_bus_aes2();

    logic         aes2_penable;
    logic         aes2_pwrite;
    logic [31:0]  aes2_paddr;
    logic         aes2_psel;
    logic [31:0]  aes2_pwdata;
    logic [31:0]  aes2_prdata;
    logic         aes2_pready;
    logic         aes2_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth  ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_ID_WIDTH      ( AxiIdWidth    ),
        .AXI4_USER_WIDTH    ( AxiUserWidth  ),
        .BUFF_DEPTH_SLAVE   ( 2             ),
        .APB_ADDR_WIDTH     ( 32            )
    ) i_axi2apb_64_32_aes2 (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( aes2.aw_id     ),
        .AWADDR_i  ( aes2.aw_addr   ),
        .AWLEN_i   ( aes2.aw_len    ),
        .AWSIZE_i  ( aes2.aw_size   ),
        .AWBURST_i ( aes2.aw_burst  ),
        .AWLOCK_i  ( aes2.aw_lock   ),
        .AWCACHE_i ( aes2.aw_cache  ),
        .AWPROT_i  ( aes2.aw_prot   ),
        .AWREGION_i( aes2.aw_region ),
        .AWUSER_i  ( aes2.aw_user   ),
        .AWQOS_i   ( aes2.aw_qos    ),
        .AWVALID_i ( aes2.aw_valid  ),
        .AWREADY_o ( aes2.aw_ready  ),
        .WDATA_i   ( aes2.w_data    ),
        .WSTRB_i   ( aes2.w_strb    ),
        .WLAST_i   ( aes2.w_last    ),
        .WUSER_i   ( aes2.w_user    ),
        .WVALID_i  ( aes2.w_valid   ),
        .WREADY_o  ( aes2.w_ready   ),
        .BID_o     ( aes2.b_id      ),
        .BRESP_o   ( aes2.b_resp    ),
        .BVALID_o  ( aes2.b_valid   ),
        .BUSER_o   ( aes2.b_user    ),
        .BREADY_i  ( aes2.b_ready   ),
        .ARID_i    ( aes2.ar_id     ),
        .ARADDR_i  ( aes2.ar_addr   ),
        .ARLEN_i   ( aes2.ar_len    ),
        .ARSIZE_i  ( aes2.ar_size   ),
        .ARBURST_i ( aes2.ar_burst  ),
        .ARLOCK_i  ( aes2.ar_lock   ),
        .ARCACHE_i ( aes2.ar_cache  ),
        .ARPROT_i  ( aes2.ar_prot   ),
        .ARREGION_i( aes2.ar_region ),
        .ARUSER_i  ( aes2.ar_user   ),
        .ARQOS_i   ( aes2.ar_qos    ),
        .ARVALID_i ( aes2.ar_valid  ),
        .ARREADY_o ( aes2.ar_ready  ),
        .RID_o     ( aes2.r_id      ),
        .RDATA_o   ( aes2.r_data    ),
        .RRESP_o   ( aes2.r_resp    ),
        .RLAST_o   ( aes2.r_last    ),
        .RUSER_o   ( aes2.r_user    ),
        .RVALID_o  ( aes2.r_valid   ),
        .RREADY_i  ( aes2.r_ready   ),
        .PENABLE   ( aes2_penable   ),
        .PWRITE    ( aes2_pwrite    ),
        .PADDR     ( aes2_paddr     ),
        .PSEL      ( aes2_psel      ),
        .PWDATA    ( aes2_pwdata    ),
        .PRDATA    ( aes2_prdata    ),
        .PREADY    ( aes2_pready    ),
        .PSLVERR   ( aes2_pslverr   )
    );

    apb_to_reg i_apb_to_reg_aes2 (
        .clk_i     ( clk_i        ),
        .rst_ni    ( rst_ni       ),
        .penable_i ( aes2_penable ),
        .pwrite_i  ( aes2_pwrite  ),
        .paddr_i   ( aes2_paddr   ),
        .psel_i    ( aes2_psel    ),
        .pwdata_i  ( aes2_pwdata  ),
        .prdata_o  ( aes2_prdata  ),
        .pready_o  ( aes2_pready  ),
        .pslverr_o ( aes2_pslverr ),
        .reg_o     ( reg_bus_aes2 )
    );
    str_to_mop i_str_to_mop_aes2(
        .request            (request[ariane_soc::AES2]),
        .receive            (receive[ariane_soc::AES2]),
        .valid_i            (valid_o[ariane_soc::AES2]),
        .valid_o            (valid_i[ariane_soc::AES2]),
        .instrut_value      (instrut_value),
        .idle_IP            (idle[ariane_soc::AES2]),
        .MoP_override       ( MoP_override),
        .load_ctrl          ( load_ctrl),
        .change             ( change),
        .override_in        ( override_out[ariane_soc::AES]),
        .override_out       ( override_out[ariane_soc::AES2]),
        .re_data_in         ( re_data_out[ariane_soc::AES]),
        .re_data_out        ( re_data_out[ariane_soc::AES2]),
        .mop_o              ( mop_bus_aes2)
    );
    aes2_wrapper #(
        .LOG_N_INIT(LOG_N_INIT)
    ) i_aes2_wrapper (
        .clk_i              ( clk_i                  ),
        .rst_ni             ( rst_ni                 ),
        .reglk_ctrl_i       ( reglk_ctrl[8*ariane_soc::AES2+8-1:8*ariane_soc::AES2] ),
        .mop_bus_io         ( mop_bus_aes2),
        .external_bus_io    ( reg_bus_aes2            )
    );
///////////////////////////////////////////////////////////////////////////////////////

    // ---------------
    // 4. SHA256
    // ---------------

    REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) reg_bus_sha256 (clk_i);
    
    logic         sha256_penable;
    logic         sha256_pwrite;
    logic [31:0]  sha256_paddr;
    logic         sha256_psel;
    logic [31:0]  sha256_pwdata;
    logic [31:0]  sha256_prdata;
    logic         sha256_pready;
    logic         sha256_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth  ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_ID_WIDTH      ( AxiIdWidth    ),
        .AXI4_USER_WIDTH    ( AxiUserWidth  ),
        .BUFF_DEPTH_SLAVE   ( 2             ),
        .APB_ADDR_WIDTH     ( 32            )
    ) i_axi2apb_64_32_sha256 (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( sha256.aw_id     ),
        .AWADDR_i  ( sha256.aw_addr   ),
        .AWLEN_i   ( sha256.aw_len    ),
        .AWSIZE_i  ( sha256.aw_size   ),
        .AWBURST_i ( sha256.aw_burst  ),
        .AWLOCK_i  ( sha256.aw_lock   ),
        .AWCACHE_i ( sha256.aw_cache  ),
        .AWPROT_i  ( sha256.aw_prot   ),
        .AWREGION_i( sha256.aw_region ),
        .AWUSER_i  ( sha256.aw_user   ),
        .AWQOS_i   ( sha256.aw_qos    ),
        .AWVALID_i ( sha256.aw_valid  ),
        .AWREADY_o ( sha256.aw_ready  ),
        .WDATA_i   ( sha256.w_data    ),
        .WSTRB_i   ( sha256.w_strb    ),
        .WLAST_i   ( sha256.w_last    ),
        .WUSER_i   ( sha256.w_user    ),
        .WVALID_i  ( sha256.w_valid   ),
        .WREADY_o  ( sha256.w_ready   ),
        .BID_o     ( sha256.b_id      ),
        .BRESP_o   ( sha256.b_resp    ),
        .BVALID_o  ( sha256.b_valid   ),
        .BUSER_o   ( sha256.b_user    ),
        .BREADY_i  ( sha256.b_ready   ),
        .ARID_i    ( sha256.ar_id     ),
        .ARADDR_i  ( sha256.ar_addr   ),
        .ARLEN_i   ( sha256.ar_len    ),
        .ARSIZE_i  ( sha256.ar_size   ),
        .ARBURST_i ( sha256.ar_burst  ),
        .ARLOCK_i  ( sha256.ar_lock   ),
        .ARCACHE_i ( sha256.ar_cache  ),
        .ARPROT_i  ( sha256.ar_prot   ),
        .ARREGION_i( sha256.ar_region ),
        .ARUSER_i  ( sha256.ar_user   ),
        .ARQOS_i   ( sha256.ar_qos    ),
        .ARVALID_i ( sha256.ar_valid  ),
        .ARREADY_o ( sha256.ar_ready  ),
        .RID_o     ( sha256.r_id      ),
        .RDATA_o   ( sha256.r_data    ),
        .RRESP_o   ( sha256.r_resp    ),
        .RLAST_o   ( sha256.r_last    ),
        .RUSER_o   ( sha256.r_user    ),
        .RVALID_o  ( sha256.r_valid   ),
        .RREADY_i  ( sha256.r_ready   ),
        .PENABLE   ( sha256_penable   ),
        .PWRITE    ( sha256_pwrite    ),
        .PADDR     ( sha256_paddr     ),
        .PSEL      ( sha256_psel      ),
        .PWDATA    ( sha256_pwdata    ),
        .PRDATA    ( sha256_prdata    ),
        .PREADY    ( sha256_pready    ),
        .PSLVERR   ( sha256_pslverr   )
    );

    apb_to_reg i_apb_to_reg_sha256 (
        .clk_i     ( clk_i        ),
        .rst_ni    ( rst_ni       ),
        .penable_i ( sha256_penable ),
        .pwrite_i  ( sha256_pwrite  ),
        .paddr_i   ( sha256_paddr   ),
        .psel_i    ( sha256_psel    ),
        .pwdata_i  ( sha256_pwdata  ),
        .prdata_o  ( sha256_prdata  ),
        .pready_o  ( sha256_pready  ),
        .pslverr_o ( sha256_pslverr ),
        .reg_o     ( reg_bus_sha256 )
    );

    sha256_wrapper #(
    ) i_sha256_wrapper (
        .clk_i              ( clk_i                  ),
        .rst_ni             ( rst_ni                 ),
        .reglk_ctrl_i       ( reglk_ctrl[8*ariane_soc::SHA256+8-1:8*ariane_soc::SHA256] ),
        .external_bus_io    ( reg_bus_sha256         )
    );


///////////////////////////////////////////////////////////////////////////////////////

    // ---------------
    // 5. DMA
    // ---------------

    REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) reg_bus_dma (clk_i);
    
    //logic [191:0] sha256_key_in;
    logic         dma_penable;
    logic         dma_pwrite;
    logic [31:0]  dma_paddr;
    logic         dma_psel;
    logic [31:0]  dma_pwdata;
    logic [31:0]  dma_prdata;
    logic         dma_pready;
    logic         dma_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth  ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_ID_WIDTH      ( AxiIdWidth    ),
        .AXI4_USER_WIDTH    ( AxiUserWidth  ),
        .BUFF_DEPTH_SLAVE   ( 2             ),
        .APB_ADDR_WIDTH     ( 32            )
    ) i_axi2apb_64_32_dma (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( dma.aw_id     ),
        .AWADDR_i  ( dma.aw_addr   ),
        .AWLEN_i   ( dma.aw_len    ),
        .AWSIZE_i  ( dma.aw_size   ),
        .AWBURST_i ( dma.aw_burst  ),
        .AWLOCK_i  ( dma.aw_lock   ),
        .AWCACHE_i ( dma.aw_cache  ),
        .AWPROT_i  ( dma.aw_prot   ),
        .AWREGION_i( dma.aw_region ),
        .AWUSER_i  ( dma.aw_user   ),
        .AWQOS_i   ( dma.aw_qos    ),
        .AWVALID_i ( dma.aw_valid  ),
        .AWREADY_o ( dma.aw_ready  ),
        .WDATA_i   ( dma.w_data    ),
        .WSTRB_i   ( dma.w_strb    ),
        .WLAST_i   ( dma.w_last    ),
        .WUSER_i   ( dma.w_user    ),
        .WVALID_i  ( dma.w_valid   ),
        .WREADY_o  ( dma.w_ready   ),
        .BID_o     ( dma.b_id      ),
        .BRESP_o   ( dma.b_resp    ),
        .BVALID_o  ( dma.b_valid   ),
        .BUSER_o   ( dma.b_user    ),
        .BREADY_i  ( dma.b_ready   ),
        .ARID_i    ( dma.ar_id     ),
        .ARADDR_i  ( dma.ar_addr   ),
        .ARLEN_i   ( dma.ar_len    ),
        .ARSIZE_i  ( dma.ar_size   ),
        .ARBURST_i ( dma.ar_burst  ),
        .ARLOCK_i  ( dma.ar_lock   ),
        .ARCACHE_i ( dma.ar_cache  ),
        .ARPROT_i  ( dma.ar_prot   ),
        .ARREGION_i( dma.ar_region ),
        .ARUSER_i  ( dma.ar_user   ),
        .ARQOS_i   ( dma.ar_qos    ),
        .ARVALID_i ( dma.ar_valid  ),
        .ARREADY_o ( dma.ar_ready  ),
        .RID_o     ( dma.r_id      ),
        .RDATA_o   ( dma.r_data    ),
        .RRESP_o   ( dma.r_resp    ),
        .RLAST_o   ( dma.r_last    ),
        .RUSER_o   ( dma.r_user    ),
        .RVALID_o  ( dma.r_valid   ),
        .RREADY_i  ( dma.r_ready   ),
        .PENABLE   ( dma_penable   ),
        .PWRITE    ( dma_pwrite    ),
        .PADDR     ( dma_paddr     ),
        .PSEL      ( dma_psel      ),
        .PWDATA    ( dma_pwdata    ),
        .PRDATA    ( dma_prdata    ),
        .PREADY    ( dma_pready    ),
        .PSLVERR   ( dma_pslverr   )
    );

    apb_to_reg i_apb_to_reg_dma (
        .clk_i     ( clk_i        ),
        .rst_ni    ( rst_ni       ),
        .penable_i ( dma_penable ),
        .pwrite_i  ( dma_pwrite  ),
        .paddr_i   ( dma_paddr   ),
        .psel_i    ( dma_psel    ),
        .pwdata_i  ( dma_pwdata  ),
        .prdata_o  ( dma_prdata  ),
        .pready_o  ( dma_pready  ),
        .pslverr_o ( dma_pslverr ),
        .reg_o     ( reg_bus_dma )
    );

    dma_wrapper #(
    ) u_dma_wrapper (
        .clk_i              ( clk_i       ),
        .rst_ni             ( rst_ni      ),
        .external_bus_io    ( reg_bus_dma ), 
        
        .axi_req_o          ( dma_axi_req_o  ),
        .axi_resp_i         ( dma_axi_resp_i )  
    );

///////////////////////////////////////////////////////////////////////////////////////
    // ---------------
    // 2. UART
    // ---------------
    logic         uart_penable;
    logic         uart_pwrite;
    logic [31:0]  uart_paddr;
    logic         uart_psel;
    logic [31:0]  uart_pwdata;
    logic [31:0]  uart_prdata;
    logic         uart_pready;
    logic         uart_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth ),
        .AXI4_ID_WIDTH      ( AxiIdWidth   ),
        .AXI4_USER_WIDTH    ( AxiUserWidth ),
        .BUFF_DEPTH_SLAVE   ( 2            ),
        .APB_ADDR_WIDTH     ( 32           )
    ) i_axi2apb_64_32_uart (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( uart.aw_id     ),
        .AWADDR_i  ( uart.aw_addr   ),
        .AWLEN_i   ( uart.aw_len    ),
        .AWSIZE_i  ( uart.aw_size   ),
        .AWBURST_i ( uart.aw_burst  ),
        .AWLOCK_i  ( uart.aw_lock   ),
        .AWCACHE_i ( uart.aw_cache  ),
        .AWPROT_i  ( uart.aw_prot   ),
        .AWREGION_i( uart.aw_region ),
        .AWUSER_i  ( uart.aw_user   ),
        .AWQOS_i   ( uart.aw_qos    ),
        .AWVALID_i ( uart.aw_valid  ),
        .AWREADY_o ( uart.aw_ready  ),
        .WDATA_i   ( uart.w_data    ),
        .WSTRB_i   ( uart.w_strb    ),
        .WLAST_i   ( uart.w_last    ),
        .WUSER_i   ( uart.w_user    ),
        .WVALID_i  ( uart.w_valid   ),
        .WREADY_o  ( uart.w_ready   ),
        .BID_o     ( uart.b_id      ),
        .BRESP_o   ( uart.b_resp    ),
        .BVALID_o  ( uart.b_valid   ),
        .BUSER_o   ( uart.b_user    ),
        .BREADY_i  ( uart.b_ready   ),
        .ARID_i    ( uart.ar_id     ),
        .ARADDR_i  ( uart.ar_addr   ),
        .ARLEN_i   ( uart.ar_len    ),
        .ARSIZE_i  ( uart.ar_size   ),
        .ARBURST_i ( uart.ar_burst  ),
        .ARLOCK_i  ( uart.ar_lock   ),
        .ARCACHE_i ( uart.ar_cache  ),
        .ARPROT_i  ( uart.ar_prot   ),
        .ARREGION_i( uart.ar_region ),
        .ARUSER_i  ( uart.ar_user   ),
        .ARQOS_i   ( uart.ar_qos    ),
        .ARVALID_i ( uart.ar_valid  ),
        .ARREADY_o ( uart.ar_ready  ),
        .RID_o     ( uart.r_id      ),
        .RDATA_o   ( uart.r_data    ),
        .RRESP_o   ( uart.r_resp    ),
        .RLAST_o   ( uart.r_last    ),
        .RUSER_o   ( uart.r_user    ),
        .RVALID_o  ( uart.r_valid   ),
        .RREADY_i  ( uart.r_ready   ),
        .PENABLE   ( uart_penable   ),
        .PWRITE    ( uart_pwrite    ),
        .PADDR     ( uart_paddr     ),
        .PSEL      ( uart_psel      ),
        .PWDATA    ( uart_pwdata    ),
        .PRDATA    ( uart_prdata    ),
        .PREADY    ( uart_pready    ),
        .PSLVERR   ( uart_pslverr   )
    );

    if (InclUART) begin : gen_uart
        apb_uart i_apb_uart (
            .CLK     ( clk_i           ),
            .RSTN    ( rst_ni          ),
            .PSEL    ( uart_psel       ),
            .PENABLE ( uart_penable    ),
            .PWRITE  ( uart_pwrite     ),
            .PADDR   ( uart_paddr[4:2] ),
            .PWDATA  ( uart_pwdata     ),
            .PRDATA  ( uart_prdata     ),
            .PREADY  ( uart_pready     ),
            .PSLVERR ( uart_pslverr    ),
            .INT     ( irq_sources[2]  ),
            .OUT1N   (                 ), // keep open
            .OUT2N   (                 ), // keep open
            .RTSN    (                 ), // no flow control
            .DTRN    (                 ), // no flow control
            .CTSN    ( 1'b0            ),
            .DSRN    ( 1'b0            ),
            .DCDN    ( 1'b0            ),
            .RIN     ( 1'b0            ),
            .SIN     ( rx_i            ),
            .SOUT    ( tx_o            )
        );
    end else begin
        /* pragma translate_off */
        `ifndef VERILATOR
        mock_uart i_mock_uart (
            .clk_i     ( clk_i        ),
            .rst_ni    ( rst_ni       ),
            .penable_i ( uart_penable ),
            .pwrite_i  ( uart_pwrite  ),
            .paddr_i   ( uart_paddr   ),
            .psel_i    ( uart_psel    ),
            .pwdata_i  ( uart_pwdata  ),
            .prdata_o  ( uart_prdata  ),
            .pready_o  ( uart_pready  ),
            .pslverr_o ( uart_pslverr )
        );
        `endif
        /* pragma translate_on */
    end

    // ---------------
    // 3. SPI
    // ---------------
    if (InclSPI) begin : gen_spi
        logic [31:0] s_axi_spi_awaddr;
        logic [7:0]  s_axi_spi_awlen;
        logic [2:0]  s_axi_spi_awsize;
        logic [1:0]  s_axi_spi_awburst;
        logic [0:0]  s_axi_spi_awlock;
        logic [3:0]  s_axi_spi_awcache;
        logic [2:0]  s_axi_spi_awprot;
        logic [3:0]  s_axi_spi_awregion;
        logic [3:0]  s_axi_spi_awqos;
        logic        s_axi_spi_awvalid;
        logic        s_axi_spi_awready;
        logic [31:0] s_axi_spi_wdata;
        logic [3:0]  s_axi_spi_wstrb;
        logic        s_axi_spi_wlast;
        logic        s_axi_spi_wvalid;
        logic        s_axi_spi_wready;
        logic [1:0]  s_axi_spi_bresp;
        logic        s_axi_spi_bvalid;
        logic        s_axi_spi_bready;
        logic [31:0] s_axi_spi_araddr;
        logic [7:0]  s_axi_spi_arlen;
        logic [2:0]  s_axi_spi_arsize;
        logic [1:0]  s_axi_spi_arburst;
        logic [0:0]  s_axi_spi_arlock;
        logic [3:0]  s_axi_spi_arcache;
        logic [2:0]  s_axi_spi_arprot;
        logic [3:0]  s_axi_spi_arregion;
        logic [3:0]  s_axi_spi_arqos;
        logic        s_axi_spi_arvalid;
        logic        s_axi_spi_arready;
        logic [31:0] s_axi_spi_rdata;
        logic [1:0]  s_axi_spi_rresp;
        logic        s_axi_spi_rlast;
        logic        s_axi_spi_rvalid;
        logic        s_axi_spi_rready;

        xlnx_axi_clock_converter i_xlnx_axi_clock_converter_spi (
            .s_axi_aclk     ( clk_i              ),
            .s_axi_aresetn  ( rst_ni             ),

            .s_axi_awid     ( spi.aw_id          ),
            .s_axi_awaddr   ( spi.aw_addr[31:0]  ),
            .s_axi_awlen    ( spi.aw_len         ),
            .s_axi_awsize   ( spi.aw_size        ),
            .s_axi_awburst  ( spi.aw_burst       ),
            .s_axi_awlock   ( spi.aw_lock        ),
            .s_axi_awcache  ( spi.aw_cache       ),
            .s_axi_awprot   ( spi.aw_prot        ),
            .s_axi_awregion ( spi.aw_region      ),
            .s_axi_awqos    ( spi.aw_qos         ),
            .s_axi_awvalid  ( spi.aw_valid       ),
            .s_axi_awready  ( spi.aw_ready       ),
            .s_axi_wdata    ( spi.w_data         ),
            .s_axi_wstrb    ( spi.w_strb         ),
            .s_axi_wlast    ( spi.w_last         ),
            .s_axi_wvalid   ( spi.w_valid        ),
            .s_axi_wready   ( spi.w_ready        ),
            .s_axi_bid      ( spi.b_id           ),
            .s_axi_bresp    ( spi.b_resp         ),
            .s_axi_bvalid   ( spi.b_valid        ),
            .s_axi_bready   ( spi.b_ready        ),
            .s_axi_arid     ( spi.ar_id          ),
            .s_axi_araddr   ( spi.ar_addr[31:0]  ),
            .s_axi_arlen    ( spi.ar_len         ),
            .s_axi_arsize   ( spi.ar_size        ),
            .s_axi_arburst  ( spi.ar_burst       ),
            .s_axi_arlock   ( spi.ar_lock        ),
            .s_axi_arcache  ( spi.ar_cache       ),
            .s_axi_arprot   ( spi.ar_prot        ),
            .s_axi_arregion ( spi.ar_region      ),
            .s_axi_arqos    ( spi.ar_qos         ),
            .s_axi_arvalid  ( spi.ar_valid       ),
            .s_axi_arready  ( spi.ar_ready       ),
            .s_axi_rid      ( spi.r_id           ),
            .s_axi_rdata    ( spi.r_data         ),
            .s_axi_rresp    ( spi.r_resp         ),
            .s_axi_rlast    ( spi.r_last         ),
            .s_axi_rvalid   ( spi.r_valid        ),
            .s_axi_rready   ( spi.r_ready        ),

            .m_axi_awaddr   ( s_axi_spi_awaddr   ),
            .m_axi_awlen    ( s_axi_spi_awlen    ),
            .m_axi_awsize   ( s_axi_spi_awsize   ),
            .m_axi_awburst  ( s_axi_spi_awburst  ),
            .m_axi_awlock   ( s_axi_spi_awlock   ),
            .m_axi_awcache  ( s_axi_spi_awcache  ),
            .m_axi_awprot   ( s_axi_spi_awprot   ),
            .m_axi_awregion ( s_axi_spi_awregion ),
            .m_axi_awqos    ( s_axi_spi_awqos    ),
            .m_axi_awvalid  ( s_axi_spi_awvalid  ),
            .m_axi_awready  ( s_axi_spi_awready  ),
            .m_axi_wdata    ( s_axi_spi_wdata    ),
            .m_axi_wstrb    ( s_axi_spi_wstrb    ),
            .m_axi_wlast    ( s_axi_spi_wlast    ),
            .m_axi_wvalid   ( s_axi_spi_wvalid   ),
            .m_axi_wready   ( s_axi_spi_wready   ),
            .m_axi_bresp    ( s_axi_spi_bresp    ),
            .m_axi_bvalid   ( s_axi_spi_bvalid   ),
            .m_axi_bready   ( s_axi_spi_bready   ),
            .m_axi_araddr   ( s_axi_spi_araddr   ),
            .m_axi_arlen    ( s_axi_spi_arlen    ),
            .m_axi_arsize   ( s_axi_spi_arsize   ),
            .m_axi_arburst  ( s_axi_spi_arburst  ),
            .m_axi_arlock   ( s_axi_spi_arlock   ),
            .m_axi_arcache  ( s_axi_spi_arcache  ),
            .m_axi_arprot   ( s_axi_spi_arprot   ),
            .m_axi_arregion ( s_axi_spi_arregion ),
            .m_axi_arqos    ( s_axi_spi_arqos    ),
            .m_axi_arvalid  ( s_axi_spi_arvalid  ),
            .m_axi_arready  ( s_axi_spi_arready  ),
            .m_axi_rdata    ( s_axi_spi_rdata    ),
            .m_axi_rresp    ( s_axi_spi_rresp    ),
            .m_axi_rlast    ( s_axi_spi_rlast    ),
            .m_axi_rvalid   ( s_axi_spi_rvalid   ),
            .m_axi_rready   ( s_axi_spi_rready   )
        );

        xlnx_axi_quad_spi i_xlnx_axi_quad_spi (
            .ext_spi_clk    ( clk_i                  ),
            .s_axi4_aclk    ( clk_i                  ),
            .s_axi4_aresetn ( rst_ni                 ),
            .s_axi4_awaddr  ( s_axi_spi_awaddr[23:0] ),
            .s_axi4_awlen   ( s_axi_spi_awlen        ),
            .s_axi4_awsize  ( s_axi_spi_awsize       ),
            .s_axi4_awburst ( s_axi_spi_awburst      ),
            .s_axi4_awlock  ( s_axi_spi_awlock       ),
            .s_axi4_awcache ( s_axi_spi_awcache      ),
            .s_axi4_awprot  ( s_axi_spi_awprot       ),
            .s_axi4_awvalid ( s_axi_spi_awvalid      ),
            .s_axi4_awready ( s_axi_spi_awready      ),
            .s_axi4_wdata   ( s_axi_spi_wdata        ),
            .s_axi4_wstrb   ( s_axi_spi_wstrb        ),
            .s_axi4_wlast   ( s_axi_spi_wlast        ),
            .s_axi4_wvalid  ( s_axi_spi_wvalid       ),
            .s_axi4_wready  ( s_axi_spi_wready       ),
            .s_axi4_bresp   ( s_axi_spi_bresp        ),
            .s_axi4_bvalid  ( s_axi_spi_bvalid       ),
            .s_axi4_bready  ( s_axi_spi_bready       ),
            .s_axi4_araddr  ( s_axi_spi_araddr[23:0] ),
            .s_axi4_arlen   ( s_axi_spi_arlen        ),
            .s_axi4_arsize  ( s_axi_spi_arsize       ),
            .s_axi4_arburst ( s_axi_spi_arburst      ),
            .s_axi4_arlock  ( s_axi_spi_arlock       ),
            .s_axi4_arcache ( s_axi_spi_arcache      ),
            .s_axi4_arprot  ( s_axi_spi_arprot       ),
            .s_axi4_arvalid ( s_axi_spi_arvalid      ),
            .s_axi4_arready ( s_axi_spi_arready      ),
            .s_axi4_rdata   ( s_axi_spi_rdata        ),
            .s_axi4_rresp   ( s_axi_spi_rresp        ),
            .s_axi4_rlast   ( s_axi_spi_rlast        ),
            .s_axi4_rvalid  ( s_axi_spi_rvalid       ),
            .s_axi4_rready  ( s_axi_spi_rready       ),

            .io0_i          ( '0                     ),
            .io0_o          ( spi_mosi               ),
            .io0_t          ( '0                     ),
            .io1_i          ( spi_miso               ),
            .io1_o          (                        ),
            .io1_t          ( '0                     ),
            .ss_i           ( '0                     ),
            .ss_o           ( spi_ss                 ),
            .ss_t           ( '0                     ),
            .sck_o          ( spi_clk_o              ),
            .sck_i          ( '0                     ),
            .sck_t          (                        ),
            .ip2intc_irpt   ( irq_sources[1]         )
            // .ip2intc_irpt   ( irq_sources[1]         )
        );
        // assign irq_sources [1] = 1'b0;
    end else begin
        assign spi_clk_o = 1'b0;
        assign spi_mosi = 1'b0;
        assign spi_ss = 1'b0;

        assign irq_sources [1] = 1'b0;
        assign spi.aw_ready = 1'b1;
        assign spi.ar_ready = 1'b1;
        assign spi.w_ready = 1'b1;

        assign spi.b_valid = spi.aw_valid;
        assign spi.b_id = spi.aw_id;
        assign spi.b_resp = axi_pkg::RESP_SLVERR;
        assign spi.b_user = '0;

        assign spi.r_valid = spi.ar_valid;
        assign spi.r_resp = axi_pkg::RESP_SLVERR;
        assign spi.r_data = 'hdeadbeef;
        assign spi.r_last = 1'b1;
    end


    // ---------------
    // 4. Ethernet
    // ---------------
    if (InclEthernet) begin : gen_ethernet
        wire         mdio_i, mdio_o, mdio_t;
        logic [3:0]  s_axi_eth_awid;
        logic [31:0] s_axi_eth_awaddr;
        logic [7:0]  s_axi_eth_awlen;
        logic [2:0]  s_axi_eth_awsize;
        logic [1:0]  s_axi_eth_awburst;
        logic [3:0]  s_axi_eth_awcache;
        logic        s_axi_eth_awvalid;
        logic        s_axi_eth_awready;
        logic [31:0] s_axi_eth_wdata;
        logic [3:0]  s_axi_eth_wstrb;
        logic        s_axi_eth_wlast;
        logic        s_axi_eth_wvalid;
        logic        s_axi_eth_wready;
        logic [3:0]  s_axi_eth_bid;
        logic [1:0]  s_axi_eth_bresp;
        logic        s_axi_eth_bvalid;
        logic        s_axi_eth_bready;
        logic [3:0]  s_axi_eth_arid;
        logic [31:0] s_axi_eth_araddr;
        logic [7:0]  s_axi_eth_arlen;
        logic [2:0]  s_axi_eth_arsize;
        logic [1:0]  s_axi_eth_arburst;
        logic [3:0]  s_axi_eth_arcache;
        logic        s_axi_eth_arvalid;
        logic        s_axi_eth_arready;
        logic [3:0]  s_axi_eth_rid;
        logic [31:0] s_axi_eth_rdata;
        logic [1:0]  s_axi_eth_rresp;
        logic        s_axi_eth_rlast;
        logic        s_axi_eth_rvalid;

        assign s_axi_eth_awid = '0;
        assign s_axi_eth_arid = '0;

        // system-bus is 64-bit, convert down to 32 bit
        xlnx_axi_clock_converter i_xlnx_axi_clock_converter_ethernet (
            .s_axi_aclk     ( clk_i                  ),
            .s_axi_aresetn  ( rst_ni                 ),
            .s_axi_awid     ( ethernet.aw_id         ),
            .s_axi_awaddr   ( ethernet.aw_addr[31:0] ),
            .s_axi_awlen    ( ethernet.aw_len        ),
            .s_axi_awsize   ( ethernet.aw_size       ),
            .s_axi_awburst  ( ethernet.aw_burst      ),
            .s_axi_awlock   ( ethernet.aw_lock       ),
            .s_axi_awcache  ( ethernet.aw_cache      ),
            .s_axi_awprot   ( ethernet.aw_prot       ),
            .s_axi_awregion ( ethernet.aw_region     ),
            .s_axi_awqos    ( ethernet.aw_qos        ),
            .s_axi_awvalid  ( ethernet.aw_valid      ),
            .s_axi_awready  ( ethernet.aw_ready      ),
            .s_axi_wdata    ( ethernet.w_data        ),
            .s_axi_wstrb    ( ethernet.w_strb        ),
            .s_axi_wlast    ( ethernet.w_last        ),
            .s_axi_wvalid   ( ethernet.w_valid       ),
            .s_axi_wready   ( ethernet.w_ready       ),
            .s_axi_bid      ( ethernet.b_id          ),
            .s_axi_bresp    ( ethernet.b_resp        ),
            .s_axi_bvalid   ( ethernet.b_valid       ),
            .s_axi_bready   ( ethernet.b_ready       ),
            .s_axi_arid     ( ethernet.ar_id         ),
            .s_axi_araddr   ( ethernet.ar_addr[31:0] ),
            .s_axi_arlen    ( ethernet.ar_len        ),
            .s_axi_arsize   ( ethernet.ar_size       ),
            .s_axi_arburst  ( ethernet.ar_burst      ),
            .s_axi_arlock   ( ethernet.ar_lock       ),
            .s_axi_arcache  ( ethernet.ar_cache      ),
            .s_axi_arprot   ( ethernet.ar_prot       ),
            .s_axi_arregion ( ethernet.ar_region     ),
            .s_axi_arqos    ( ethernet.ar_qos        ),
            .s_axi_arvalid  ( ethernet.ar_valid      ),
            .s_axi_arready  ( ethernet.ar_ready      ),
            .s_axi_rid      ( ethernet.r_id          ),
            .s_axi_rdata    ( ethernet.r_data        ),
            .s_axi_rresp    ( ethernet.r_resp        ),
            .s_axi_rlast    ( ethernet.r_last        ),
            .s_axi_rvalid   ( ethernet.r_valid       ),
            .s_axi_rready   ( ethernet.r_ready       ),

            .m_axi_awaddr   ( s_axi_eth_awaddr  ),
            .m_axi_awlen    ( s_axi_eth_awlen   ),
            .m_axi_awsize   ( s_axi_eth_awsize  ),
            .m_axi_awburst  ( s_axi_eth_awburst ),
            .m_axi_awlock   (                   ),
            .m_axi_awcache  ( s_axi_eth_awcache ),
            .m_axi_awprot   (                   ),
            .m_axi_awregion (                   ),
            .m_axi_awqos    (                   ),
            .m_axi_awvalid  ( s_axi_eth_awvalid ),
            .m_axi_awready  ( s_axi_eth_awready ),
            .m_axi_wdata    ( s_axi_eth_wdata   ),
            .m_axi_wstrb    ( s_axi_eth_wstrb   ),
            .m_axi_wlast    ( s_axi_eth_wlast   ),
            .m_axi_wvalid   ( s_axi_eth_wvalid  ),
            .m_axi_wready   ( s_axi_eth_wready  ),
            .m_axi_bresp    ( s_axi_eth_bresp   ),
            .m_axi_bvalid   ( s_axi_eth_bvalid  ),
            .m_axi_bready   ( s_axi_eth_bready  ),
            .m_axi_araddr   ( s_axi_eth_araddr  ),
            .m_axi_arlen    ( s_axi_eth_arlen   ),
            .m_axi_arsize   ( s_axi_eth_arsize  ),
            .m_axi_arburst  ( s_axi_eth_arburst ),
            .m_axi_arlock   (                   ),
            .m_axi_arcache  ( s_axi_eth_arcache ),
            .m_axi_arprot   (                   ),
            .m_axi_arregion (                   ),
            .m_axi_arqos    (                   ),
            .m_axi_arvalid  ( s_axi_eth_arvalid ),
            .m_axi_arready  ( s_axi_eth_arready ),
            .m_axi_rdata    ( s_axi_eth_rdata   ),
            .m_axi_rresp    ( s_axi_eth_rresp   ),
            .m_axi_rlast    ( s_axi_eth_rlast   ),
            .m_axi_rvalid   ( s_axi_eth_rvalid  ),
            .m_axi_rready   ( m_axi_rready      )
        );

        xlnx_axi_ethernetlite i_xlnx_axi_ethernetlite (
            .s_axi_aclk    ( clk_i                   ),
            .s_axi_aresetn ( rst_ni                  ),
            .ip2intc_irpt  ( irq_sources[0]          ),
            .s_axi_awid    ( s_axi_eth_awid          ),
            .s_axi_awaddr  ( s_axi_eth_awaddr[12:0]  ),
            .s_axi_awlen   ( s_axi_eth_awlen         ),
            .s_axi_awsize  ( s_axi_eth_awsize        ),
            .s_axi_awburst ( s_axi_eth_awburst       ),
            .s_axi_awcache ( s_axi_eth_awcache       ),
            .s_axi_awvalid ( s_axi_eth_awvalid       ),
            .s_axi_awready ( s_axi_eth_awready       ),
            .s_axi_wdata   ( s_axi_eth_wdata         ),
            .s_axi_wstrb   ( s_axi_eth_wstrb         ),
            .s_axi_wlast   ( s_axi_eth_wlast         ),
            .s_axi_wvalid  ( s_axi_eth_wvalid        ),
            .s_axi_wready  ( s_axi_eth_wready        ),
            .s_axi_bid     ( s_axi_eth_bid           ),
            .s_axi_bresp   ( s_axi_eth_bresp         ),
            .s_axi_bvalid  ( s_axi_eth_bvalid        ),
            .s_axi_bready  ( s_axi_eth_bready        ),
            .s_axi_arid    ( s_axi_eth_arid          ),
            .s_axi_araddr  ( s_axi_eth_araddr[12:0]  ),
            .s_axi_arlen   ( s_axi_eth_arlen         ),
            .s_axi_arsize  ( s_axi_eth_arsize        ),
            .s_axi_arburst ( s_axi_eth_arburst       ),
            .s_axi_arcache ( s_axi_eth_arcache       ),
            .s_axi_arvalid ( s_axi_eth_arvalid       ),
            .s_axi_arready ( s_axi_eth_arready       ),
            .s_axi_rid     ( s_axi_eth_rid           ),
            .s_axi_rdata   ( s_axi_eth_rdata         ),
            .s_axi_rresp   ( s_axi_eth_rresp         ),
            .s_axi_rlast   ( s_axi_eth_rlast         ),
            .s_axi_rvalid  ( s_axi_eth_rvalid        ),
            .s_axi_rready  ( s_axi_eth_rready        ),
            .phy_tx_clk    ( eth_txck                ),
            .phy_rx_clk    ( eth_rxck                ),
            .phy_crs       ( 1'b0                    ),
            .phy_dv        ( eth_rxctl               ),
            .phy_rx_data   ( eth_rxd                 ),
            .phy_col       ( 1'b0                    ),
            .phy_rx_er     ( 1'b0                    ),
            .phy_rst_n     ( eth_rst_n               ),
            .phy_tx_en     ( eth_tx_en               ),
            .phy_tx_data   ( eth_txd                 ),
            .phy_mdio_i    ( mdio_i                  ),
            .phy_mdio_o    ( mdio_o                  ),
            .phy_mdio_t    ( mdio_t                  ),
            .phy_mdc       ( eth_mdc                 )
        );
        IOBUF mdio_io_iobuf (.I (mdio_o), .IO(mdio), .O (mdio_i), .T (mdio_t));
    end else begin
        assign irq_sources [2] = 1'b0;
        assign ethernet.aw_ready = 1'b1;
        assign ethernet.ar_ready = 1'b1;
        assign ethernet.w_ready = 1'b1;

        assign ethernet.b_valid = ethernet.aw_valid;
        assign ethernet.b_id = ethernet.aw_id;
        assign ethernet.b_resp = axi_pkg::RESP_SLVERR;
        assign ethernet.b_user = '0;

        assign ethernet.r_valid = ethernet.ar_valid;
        assign ethernet.r_resp = axi_pkg::RESP_SLVERR;
        assign ethernet.r_data = 'hdeadbeef;
        assign ethernet.r_last = 1'b1;
    end
    ///////////////////////////////////////////////////////////////////////////////////////
    // ---------------
    //  test.
    // It is the peripheral key table. It reads data from fuse mem and gives that data
    // and the corresponding target address for that data to the processor
    // ---------------

    REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) reg_bus_debug2 (clk_i);
    
    MOP_BUS mop_bus_debug2();

    logic         debug2_penable;
    logic         debug2_pwrite;
    logic [31:0]  debug2_paddr;
    logic         debug2_psel;
    logic [31:0]  debug2_pwdata;
    logic [31:0]  debug2_prdata;
    logic         debug2_pready;
    logic         debug2_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth  ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_ID_WIDTH      ( AxiIdWidth    ),
        .AXI4_USER_WIDTH    ( AxiUserWidth  ),
        .BUFF_DEPTH_SLAVE   ( 2             ),
        .APB_ADDR_WIDTH     ( 32            )
    ) i_axi2apb_64_32_debug2 (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( debug2.aw_id     ),
        .AWADDR_i  ( debug2.aw_addr   ),
        .AWLEN_i   ( debug2.aw_len    ),
        .AWSIZE_i  ( debug2.aw_size   ),
        .AWBURST_i ( debug2.aw_burst  ),
        .AWLOCK_i  ( debug2.aw_lock   ),
        .AWCACHE_i ( debug2.aw_cache  ),
        .AWPROT_i  ( debug2.aw_prot   ),
        .AWREGION_i( debug2.aw_region ),
        .AWUSER_i  ( debug2.aw_user   ),
        .AWQOS_i   ( debug2.aw_qos    ),
        .AWVALID_i ( debug2.aw_valid  ),
        .AWREADY_o ( debug2.aw_ready  ),
        .WDATA_i   ( debug2.w_data    ),
        .WSTRB_i   ( debug2.w_strb    ),
        .WLAST_i   ( debug2.w_last    ),
        .WUSER_i   ( debug2.w_user    ),
        .WVALID_i  ( debug2.w_valid   ),
        .WREADY_o  ( debug2.w_ready   ),
        .BID_o     ( debug2.b_id      ),
        .BRESP_o   ( debug2.b_resp    ),
        .BVALID_o  ( debug2.b_valid   ),
        .BUSER_o   ( debug2.b_user    ),
        .BREADY_i  ( debug2.b_ready   ),
        .ARID_i    ( debug2.ar_id     ),
        .ARADDR_i  ( debug2.ar_addr   ),
        .ARLEN_i   ( debug2.ar_len    ),
        .ARSIZE_i  ( debug2.ar_size   ),
        .ARBURST_i ( debug2.ar_burst  ),
        .ARLOCK_i  ( debug2.ar_lock   ),
        .ARCACHE_i ( debug2.ar_cache  ),
        .ARPROT_i  ( debug2.ar_prot   ),
        .ARREGION_i( debug2.ar_region ),
        .ARUSER_i  ( debug2.ar_user   ),
        .ARQOS_i   ( debug2.ar_qos    ),
        .ARVALID_i ( debug2.ar_valid  ),
        .ARREADY_o ( debug2.ar_ready  ),
        .RID_o     ( debug2.r_id      ),
        .RDATA_o   ( debug2.r_data    ),
        .RRESP_o   ( debug2.r_resp    ),
        .RLAST_o   ( debug2.r_last    ),
        .RUSER_o   ( debug2.r_user    ),
        .RVALID_o  ( debug2.r_valid   ),
        .RREADY_i  ( debug2.r_ready   ),
        .PENABLE   ( debug2_penable   ),
        .PWRITE    ( debug2_pwrite    ),
        .PADDR     ( debug2_paddr     ),
        .PSEL      ( debug2_psel      ),
        .PWDATA    ( debug2_pwdata    ),
        .PRDATA    ( debug2_prdata    ),
        .PREADY    ( debug2_pready    ),
        .PSLVERR   ( debug2_pslverr   )
    );

    apb_to_reg i_apb_to_reg_debug2 (
        .clk_i     ( clk_i        ),
        .rst_ni    ( rst_ni       ),
        .penable_i ( debug2_penable ),
        .pwrite_i  ( debug2_pwrite  ),
        .paddr_i   ( debug2_paddr   ),
        .psel_i    ( debug2_psel    ),
        .pwdata_i  ( debug2_pwdata  ),
        .prdata_o  ( debug2_prdata  ),
        .pready_o  ( debug2_pready  ),
        .pslverr_o ( debug2_pslverr ),
        .reg_o     ( reg_bus_debug2 )
    );

    debug2_wrapper #(
        .LOG_N_INIT(LOG_N_INIT)
    ) i_debug2_wrapper (
        .clk_i              ( clk_i             ),
        .rst_ni             ( rst_ni            ),
        .reglk_ctrl_i       ( TEST_SIGNAL ),
        // .request            (request[ariane_soc::Debug2]),
        // .receive            (receive[ariane_soc::Debug2]),
        // .valid_i            (valid_o[ariane_soc::Debug2]),
        // .valid_o            (valid_i[ariane_soc::Debug2]),
        // .instrut_value      (instrut_value),
        // .load_ctrl          (load_ctrl),
        .mop_bus_io         ( mop_bus_debug2),
        .external_bus_io    ( reg_bus_debug2       )
    );

///////////////////////////////////////////
REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) reg_bus_mop (clk_i);
    MOP_BUS mop_bus_mop();
    logic         mop_penable;
    logic         mop_pwrite;
    logic [31:0]  mop_paddr;
    logic         mop_psel;
    logic [31:0]  mop_pwdata;
    logic [31:0]  mop_prdata;
    logic         mop_pready;
    logic         mop_pslverr;
    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth  ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_ID_WIDTH      ( AxiIdWidth    ),
        .AXI4_USER_WIDTH    ( AxiUserWidth  ),
        .BUFF_DEPTH_SLAVE   ( 2             ),
        .APB_ADDR_WIDTH     ( 32            )
    ) i_axi2apb_64_32_mop (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( mop.aw_id     ),
        .AWADDR_i  ( mop.aw_addr   ),
        .AWLEN_i   ( mop.aw_len    ),
        .AWSIZE_i  ( mop.aw_size   ),
        .AWBURST_i ( mop.aw_burst  ),
        .AWLOCK_i  ( mop.aw_lock   ),
        .AWCACHE_i ( mop.aw_cache  ),
        .AWPROT_i  ( mop.aw_prot   ),
        .AWREGION_i( mop.aw_region ),
        .AWUSER_i  ( mop.aw_user   ),
        .AWQOS_i   ( mop.aw_qos    ),
        .AWVALID_i ( mop.aw_valid  ),
        .AWREADY_o ( mop.aw_ready  ),
        .WDATA_i   ( mop.w_data    ),
        .WSTRB_i   ( mop.w_strb    ),
        .WLAST_i   ( mop.w_last    ),
        .WUSER_i   ( mop.w_user    ),
        .WVALID_i  ( mop.w_valid   ),
        .WREADY_o  ( mop.w_ready   ),
        .BID_o     ( mop.b_id      ),
        .BRESP_o   ( mop.b_resp    ),
        .BVALID_o  ( mop.b_valid   ),
        .BUSER_o   ( mop.b_user    ),
        .BREADY_i  ( mop.b_ready   ),
        .ARID_i    ( mop.ar_id     ),
        .ARADDR_i  ( mop.ar_addr   ),
        .ARLEN_i   ( mop.ar_len    ),
        .ARSIZE_i  ( mop.ar_size   ),
        .ARBURST_i ( mop.ar_burst  ),
        .ARLOCK_i  ( mop.ar_lock   ),
        .ARCACHE_i ( mop.ar_cache  ),
        .ARPROT_i  ( mop.ar_prot   ),
        .ARREGION_i( mop.ar_region ),
        .ARUSER_i  ( mop.ar_user   ),
        .ARQOS_i   ( mop.ar_qos    ),
        .ARVALID_i ( mop.ar_valid  ),
        .ARREADY_o ( mop.ar_ready  ),
        .RID_o     ( mop.r_id      ),
        .RDATA_o   ( mop.r_data    ),
        .RRESP_o   ( mop.r_resp    ),
        .RLAST_o   ( mop.r_last    ),
        .RUSER_o   ( mop.r_user    ),
        .RVALID_o  ( mop.r_valid   ),
        .RREADY_i  ( mop.r_ready   ),
        .PENABLE   ( mop_penable   ),
        .PWRITE    ( mop_pwrite    ),
        .PADDR     ( mop_paddr     ),
        .PSEL      ( mop_psel      ),
        .PWDATA    ( mop_pwdata    ),
        .PRDATA    ( mop_prdata    ),
        .PREADY    ( mop_pready    ),
        .PSLVERR   ( mop_pslverr   )
    );

    apb_to_reg i_apb_to_reg_mop (
        .clk_i     ( clk_i        ),
        .rst_ni    ( rst_ni       ),
        .penable_i ( mop_penable ),
        .pwrite_i  ( mop_pwrite  ),
        .paddr_i   ( mop_paddr   ),
        .psel_i    ( mop_psel    ),
        .pwdata_i  ( mop_pwdata  ),
        .prdata_o  ( mop_prdata  ),
        .pready_o  ( mop_pready  ),
        .pslverr_o ( mop_pslverr ),
        .reg_o     ( reg_bus_mop )
    );

    mop_wrapper #(
        .LOG_N_INIT(LOG_N_INIT)
    ) i_mop_wrapper (
        .clk_i              ( clk_i             ),
        .rst_ni             ( rst_ni            ),
        .reglk_ctrl_i       ( TEST_SIGNAL ),
        .request            (request[ariane_soc::MOP]),
        .receive            (receive[ariane_soc::MOP]),
        .valid_i            (valid_o[ariane_soc::MOP]),
        .valid_o            (valid_i[ariane_soc::MOP]),
        .instrut_value      (instrut_value),
        .MoP_override       (MoP_override),
        .change             (change),
        .load_ctrl          (load_ctrl),
        .external_bus_io    ( reg_bus_mop       )
    );

endmodule
interface MOP_BUS #(
  parameter LOG_N_INIT = 5
);
  logic [LOG_N_INIT-1:0]    request;
  logic                     valid_i;
  logic                     valid_o;
  logic [31:0]              instrut_value;
  logic [1:0]               change;
  logic                     MoP_override;
  logic [LOG_N_INIT-1:0]    receive;
  logic                     idle_IP;
  logic                     override_in;
  logic [32:0]              re_data_in;
  logic                     override_out;
  logic [32:0]              re_data_out;
//   logic [ariane_soc::NB_PERIPHERALS-1 :0] idle;
  logic [ariane_soc::NB_PERIPHERALS-1 :0] load_ctrl;
  modport in (input valid_i, instrut_value, load_ctrl,override_in,re_data_in ,change,MoP_override, output override_out,re_data_out,idle_IP,valid_o,request,receive);
  modport out (output valid_i, instrut_value, load_ctrl,override_in,re_data_in,change,MoP_override, input override_out,re_data_out,idle_IP,receive,valid_o,request);

endinterface
module str_to_mop #(
  parameter LOG_N_INIT = 5
)
(

  output    logic   [LOG_N_INIT-1:0]                    request,
  input     logic                                       valid_i,
  output    logic                                       idle_IP,
  output    logic                                       valid_o,
  input     logic   [31:0]                              instrut_value,
  input     logic   [1:0]                               change,
  input     logic                                       override_in,
  input     logic   [32:0]                              re_data_in,
  output    logic                                       override_out,
  output    logic   [32:0]                              re_data_out,
  input     logic                                       MoP_override,
  output    logic   [LOG_N_INIT-1:0]                    receive,
  input     logic   [ariane_soc::NB_PERIPHERALS-1 :0]   load_ctrl,
  MOP_BUS.out                                           mop_o
//   input  logic [ariane_soc::NB_PERIPHERALS-1 :0] idle,
);

  always_comb begin
    mop_o.valid_i           =   valid_i;
    receive                 =   mop_o.receive;
    idle_IP                 =   mop_o.idle_IP;
    valid_o                 =   mop_o.valid_o;
    mop_o.instrut_value     =   instrut_value ;
    mop_o.change            =   change;
    mop_o.MoP_override      =   MoP_override;
    request                 =   mop_o.request;
    mop_o.load_ctrl         =   load_ctrl ;
    mop_o.override_in       =   override_in;
    override_out            =   mop_o.override_out;
    re_data_out             =   mop_o.re_data_out;
    mop_o.re_data_in = re_data_in;
    // mop_o.idle = idle;
  end
endmodule