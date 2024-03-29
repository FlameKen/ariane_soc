// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 19.03.2017
// Description: Test-harness for Ariane
//              Instantiates an AXI-Bus and memories

module ariane_testharness #(
    parameter int unsigned AXI_ID_WIDTH      = 4,
    parameter int unsigned AXI_USER_WIDTH    = 1,
    parameter int unsigned AXI_ADDRESS_WIDTH = 64,
    parameter int unsigned AXI_DATA_WIDTH    = 64,
    parameter bit          InclSimDTM        = 1'b1,
    parameter int unsigned NUM_WORDS         = 2**25,         // memory size
    parameter bit          StallRandomOutput = 1'b0,
    parameter bit          StallRandomInput  = 1'b0
) (
    input  logic                           clk_i,
    input  logic                           rtc_i,
    input  logic                           rst_ni,
    input  logic [191:0]                  testCycle,
    output logic [31:0]                    exit_o
);

    localparam NB_SLAVE = 3; 
    
    // disable test-enable
    logic        test_en;
    logic        ndmreset;
    logic        ndmreset1;
    logic        ndmreset_n;
    logic        ndmreset1_n;
    logic        debug_req_core;

    int          jtag_enable;
    logic        init_done;
    logic [31:0] jtag_exit, dmi_exit;

    logic        jtag_TCK;
    logic        jtag_TMS;
    logic        jtag_TDI;
    logic        jtag_TRSTn;
    logic        jtag_TDO_data;
    logic        jtag_TDO_driven;

    logic        debug_req_valid;
    logic        debug_req_ready;
    logic        debug_resp_valid;
    logic        debug_resp_ready;

    logic        jtag_req_valid;
    logic [6:0]  jtag_req_bits_addr;
    logic [1:0]  jtag_req_bits_op;
    logic [31:0] jtag_req_bits_data;
    logic        jtag_resp_ready;
    logic        jtag_resp_valid;

    logic        dmi_req_valid;
    logic        dmi_resp_ready;
    logic        dmi_resp_valid;
    logic [ariane_soc::LOG_N_INIT-1:0]              MoP_request     ;
    logic [ariane_soc::LOG_N_INIT-1:0]              MoP_receive     ;
    logic  [ariane_soc::NB_PERIPHERALS-1 :0]  redirection_idle;
    logic [ariane_soc::NB_PERIPHERALS-1 :0]  valid_i;
    logic [ariane_soc::NB_PERIPHERALS-1 :0]  valid_o;
    logic [31:0] jtag_key; 
    logic [NB_SLAVE-1:0][4*ariane_soc::NB_PERIPHERALS-1 :0]   access_ctrl_reg; 

    dm::dmi_req_t  jtag_dmi_req;
    dm::dmi_req_t  dmi_req;

    dm::dmi_req_t  debug_req;
    dm::dmi_resp_t debug_resp;

    assign test_en = 1'b0;

    localparam AXI_ID_WIDTH_SLAVES = AXI_ID_WIDTH + $clog2(NB_SLAVE);

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH    ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH      ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH    )
    ) slave[NB_SLAVE-1:0]();

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH   ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH      ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_SLAVES ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH      )
    ) master[ariane_soc::NB_PERIPHERALS-1:0]();

    rstgen i_rstgen_main (
        .clk_i        ( clk_i                ),
        .rst_ni       ( rst_ni & (~ndmreset) ),
        .rst1_ni      ( ~ndmreset1           ),
        .test_mode_i  ( test_en              ),
        .rst_no       ( ndmreset_n           ),
        .rst1_no      ( ndmreset1_n          ),
        .init_no      (                      ) // keep open
    );

    // ---------------
    // Debug
    // ---------------
    assign init_done = rst_ni;

    initial begin
        if (!$value$plusargs("jtag_rbb_enable=%b", jtag_enable)) jtag_enable = 'h0;
        // $display("start in testharness\n");
        // $display("testcycle : %d\n",testCycle);
        // $monitor("jtag enable : %b jtag exit %b dmi exit %b \n",jtag_enable[0],jtag_exit,dmi_exit);
    end

    // debug if MUX
    assign debug_req_valid     = (jtag_enable[0]) ? jtag_req_valid     : dmi_req_valid;
    assign debug_resp_ready    = (jtag_enable[0]) ? jtag_resp_ready    : dmi_resp_ready;
    assign debug_req           = (jtag_enable[0]) ? jtag_dmi_req       : dmi_req;
    assign exit_o              = (jtag_enable[0]) ? jtag_exit          : dmi_exit;
    assign jtag_resp_valid     = (jtag_enable[0]) ? debug_resp_valid   : 1'b0;
    assign dmi_resp_valid      = (jtag_enable[0]) ? 1'b0               : debug_resp_valid;

    // SiFive's SimJTAG Module
    // Converts to DPI calls
    SimJTAG i_SimJTAG (
        .clock                ( clk_i                ),
        .reset                ( ~rst_ni              ),
        .enable               ( jtag_enable[0]       ),
        .init_done            ( init_done            ),
        .jtag_TCK             ( jtag_TCK             ),
        .jtag_TMS             ( jtag_TMS             ),
        .jtag_TDI             ( jtag_TDI             ),
        .jtag_TRSTn           ( jtag_TRSTn           ),
        .jtag_TDO_data        ( jtag_TDO_data        ),
        .jtag_TDO_driven      ( jtag_TDO_driven      ),
        .exit                 ( jtag_exit            )
    );

    dmi_jtag i_dmi_jtag (
        .clk_i            ( clk_i           ),
        .rst_ni           ( rst_ni          ),
        .testmode_i       ( test_en         ),
        .jtag_key         ( jtag_key        ), 
        .dmi_req_o        ( jtag_dmi_req    ),
        .dmi_req_valid_o  ( jtag_req_valid  ),
        .dmi_req_ready_i  ( debug_req_ready ),
        .dmi_resp_i       ( debug_resp      ),
        .dmi_resp_ready_o ( jtag_resp_ready ),
        .dmi_resp_valid_i ( jtag_resp_valid ),
        .dmi_rst_no       (                 ), // not connected
        .tck_i            ( jtag_TCK        ),
        .tms_i            ( jtag_TMS        ),
        .trst_ni          ( jtag_TRSTn      ),
        .td_i             ( jtag_TDI        ),
        .td_o             ( jtag_TDO_data   ),
        .tdo_oe_o         ( jtag_TDO_driven )
    );

    // SiFive's SimDTM Module
    // Converts to DPI calls
    logic [1:0] debug_req_bits_op;
    assign dmi_req.op = dm::dtm_op_t'(debug_req_bits_op);

    if (InclSimDTM) begin
        SimDTM i_SimDTM (
            .clk                  ( clk_i                ),
            .reset                ( ~rst_ni              ),
            .debug_req_valid      ( dmi_req_valid        ),
            .debug_req_ready      ( debug_req_ready      ),
            .debug_req_bits_addr  ( dmi_req.addr         ),
            .debug_req_bits_op    ( debug_req_bits_op    ),
            .debug_req_bits_data  ( dmi_req.data         ),
            .debug_resp_valid     ( dmi_resp_valid       ),
            .debug_resp_ready     ( dmi_resp_ready       ),
            .debug_resp_bits_resp ( debug_resp.resp      ),
            .debug_resp_bits_data ( debug_resp.data      ),
            .exit                 ( dmi_exit             )
        );
    end else begin
        assign dmi_req_valid = '0;
        assign debug_req_bits_op = '0;
        assign dmi_exit = 1'b0;
    end

    ariane_axi::req_t    dm_axi_m_req,  dm_axi_s_req;
    ariane_axi::resp_t   dm_axi_m_resp, dm_axi_s_resp;

    // debug module
    dm_top #(
        // current implementation only supports 1 hart
        .NrHarts              ( 1                         ),
        .AxiIdWidth           ( AXI_ID_WIDTH_SLAVES       ),
        .AxiAddrWidth         ( AXI_ADDRESS_WIDTH         ),
        .AxiDataWidth         ( AXI_DATA_WIDTH            ),
        .AxiUserWidth         ( AXI_USER_WIDTH            )
    ) i_dm_top (

        .clk_i                ( clk_i                ),
        .rst_ni               ( rst_ni               ), // PoR
        .testmode_i           ( test_en              ),
        .ndmreset0_o          ( ndmreset             ),
        .ndmreset1_o          ( ndmreset1            ),
        .dmactive_o           (                      ), // active debug session
        .debug_req_o          ( debug_req_core       ),
        .unavailable_i        ( '0                   ),
        .axi_s_req_i          ( dm_axi_s_req         ),
        .axi_s_resp_o         ( dm_axi_s_resp        ),
        .axi_m_req_o          ( dm_axi_m_req         ),
        .axi_m_resp_i         ( dm_axi_m_resp        ),
        .dmi_rst_ni           ( rst_ni               ),
        .dmi_req_valid_i      ( debug_req_valid      ),
        .dmi_req_ready_o      ( debug_req_ready      ),
        .dmi_req_i            ( debug_req            ),
        .dmi_resp_valid_o     ( debug_resp_valid     ),
        .dmi_resp_ready_i     ( debug_resp_ready     ),
        .dmi_resp_o           ( debug_resp           )
    );

    
    axi_slave_connect  i_axi_slave_dm  (.axi_req_o(dm_axi_s_req), .axi_resp_i(dm_axi_s_resp), .slave(master[ariane_soc::Debug]));


    // ---------------
    // ROM
    // ---------------
    logic                         rom_req;
    logic [AXI_ADDRESS_WIDTH-1:0] rom_addr;
    logic [AXI_DATA_WIDTH-1:0]    rom_rdata;

    axi2mem #(
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_SLAVES ),
        .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH   ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH      ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH      )
    ) i_axi2rom  (
        .clk_i   ( clk_i                   ),
        .rst_ni  ( ndmreset_n              ),
        .slave   ( master[ariane_soc::ROM] ),
        .req_o   ( rom_req                 ),
        .we_o    (                         ),
        .addr_o  ( rom_addr                ),
        .be_o    (                         ),
        .data_o  (                         ),
        .data_i  ( rom_rdata               )
    );

    bootrom i_bootrom (
        .clk_i      ( clk_i     ),
        .req_i      ( rom_req   ),
        .addr_i     ( rom_addr  ),
        .rdata_o    ( rom_rdata )
    );

    // ---------------
    // Memory
    // ---------------

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH   ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH      ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_SLAVES ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH      )
    ) dram();

    logic                         req;
    logic                         we;
    logic [AXI_ADDRESS_WIDTH-1:0] addr;
    logic [AXI_DATA_WIDTH/8-1:0]  be;
    logic [AXI_DATA_WIDTH-1:0]    wdata;
    logic [AXI_DATA_WIDTH-1:0]    rdata;

    axi_pkg::aw_chan_t aw_chan_i;
    axi_pkg::w_chan_t  w_chan_i;
    axi_pkg::b_chan_t  b_chan_o;
    axi_pkg::ar_chan_t ar_chan_i;
    axi_pkg::r_chan_t  r_chan_o;
    axi_pkg::aw_chan_t aw_chan_o;
    axi_pkg::w_chan_t  w_chan_o;
    axi_pkg::b_chan_t  b_chan_i;
    axi_pkg::ar_chan_t ar_chan_o;
    axi_pkg::r_chan_t  r_chan_i;

    axi_delayer #(
        .aw_t              ( axi_pkg::aw_chan_t ),
        .w_t               ( axi_pkg::w_chan_t  ),
        .b_t               ( axi_pkg::b_chan_t  ),
        .ar_t              ( axi_pkg::ar_chan_t ),
        .r_t               ( axi_pkg::r_chan_t  ),
        .StallRandomOutput ( StallRandomOutput  ),
        .StallRandomInput  ( StallRandomInput   ),
        .FixedDelayInput   ( 0                  ),
        .FixedDelayOutput  ( 0                  )
    ) i_axi_delayer (
        .clk_i      ( clk_i                             ),
        .rst_ni     ( ndmreset_n                        ),
        .aw_valid_i ( master[ariane_soc::DRAM].aw_valid ),
        .aw_chan_i  ( aw_chan_i                         ),
        .aw_ready_o ( master[ariane_soc::DRAM].aw_ready ),
        .w_valid_i  ( master[ariane_soc::DRAM].w_valid  ),
        .w_chan_i   ( w_chan_i                          ),
        .w_ready_o  ( master[ariane_soc::DRAM].w_ready  ),
        .b_valid_o  ( master[ariane_soc::DRAM].b_valid  ),
        .b_chan_o   ( b_chan_o                          ),
        .b_ready_i  ( master[ariane_soc::DRAM].b_ready  ),
        .ar_valid_i ( master[ariane_soc::DRAM].ar_valid ),
        .ar_chan_i  ( ar_chan_i                         ),
        .ar_ready_o ( master[ariane_soc::DRAM].ar_ready ),
        .r_valid_o  ( master[ariane_soc::DRAM].r_valid  ),
        .r_chan_o   ( r_chan_o                          ),
        .r_ready_i  ( master[ariane_soc::DRAM].r_ready  ),
        .aw_valid_o ( dram.aw_valid                     ),
        .aw_chan_o  ( aw_chan_o                         ),
        .aw_ready_i ( dram.aw_ready                     ),
        .w_valid_o  ( dram.w_valid                      ),
        .w_chan_o   ( w_chan_o                          ),
        .w_ready_i  ( dram.w_ready                      ),
        .b_valid_i  ( dram.b_valid                      ),
        .b_chan_i   ( b_chan_i                          ),
        .b_ready_o  ( dram.b_ready                      ),
        .ar_valid_o ( dram.ar_valid                     ),
        .ar_chan_o  ( ar_chan_o                         ),
        .ar_ready_i ( dram.ar_ready                     ),
        .r_valid_i  ( dram.r_valid                      ),
        .r_chan_i   ( r_chan_i                          ),
        .r_ready_o  ( dram.r_ready                      )
    );

    assign aw_chan_i.atop = '0;
    assign aw_chan_i.id = master[ariane_soc::DRAM].aw_id;
    assign aw_chan_i.addr = master[ariane_soc::DRAM].aw_addr;
    assign aw_chan_i.len = master[ariane_soc::DRAM].aw_len;
    assign aw_chan_i.size = master[ariane_soc::DRAM].aw_size;
    assign aw_chan_i.burst = master[ariane_soc::DRAM].aw_burst;
    assign aw_chan_i.lock = master[ariane_soc::DRAM].aw_lock;
    assign aw_chan_i.cache = master[ariane_soc::DRAM].aw_cache;
    assign aw_chan_i.prot = master[ariane_soc::DRAM].aw_prot;
    assign aw_chan_i.qos = master[ariane_soc::DRAM].aw_qos;
    assign aw_chan_i.region = master[ariane_soc::DRAM].aw_region;

    assign ar_chan_i.id = master[ariane_soc::DRAM].ar_id;
    assign ar_chan_i.addr = master[ariane_soc::DRAM].ar_addr;
    assign ar_chan_i.len = master[ariane_soc::DRAM].ar_len;
    assign ar_chan_i.size = master[ariane_soc::DRAM].ar_size;
    assign ar_chan_i.burst = master[ariane_soc::DRAM].ar_burst;
    assign ar_chan_i.lock = master[ariane_soc::DRAM].ar_lock;
    assign ar_chan_i.cache = master[ariane_soc::DRAM].ar_cache;
    assign ar_chan_i.prot = master[ariane_soc::DRAM].ar_prot;
    assign ar_chan_i.qos = master[ariane_soc::DRAM].ar_qos;
    assign ar_chan_i.region = master[ariane_soc::DRAM].ar_region;

    assign w_chan_i.data = master[ariane_soc::DRAM].w_data;
    assign w_chan_i.strb = master[ariane_soc::DRAM].w_strb;
    assign w_chan_i.last = master[ariane_soc::DRAM].w_last;

    assign master[ariane_soc::DRAM].r_id = r_chan_o.id;
    assign master[ariane_soc::DRAM].r_data = r_chan_o.data;
    assign master[ariane_soc::DRAM].r_resp = r_chan_o.resp;
    assign master[ariane_soc::DRAM].r_last = r_chan_o.last;

    assign master[ariane_soc::DRAM].b_id = b_chan_o.id;
    assign master[ariane_soc::DRAM].b_resp = b_chan_o.resp;


    assign dram.aw_id = aw_chan_o.id;
    assign dram.aw_addr = aw_chan_o.addr;
    assign dram.aw_len = aw_chan_o.len;
    assign dram.aw_size = aw_chan_o.size;
    assign dram.aw_burst = aw_chan_o.burst;
    assign dram.aw_lock = aw_chan_o.lock;
    assign dram.aw_cache = aw_chan_o.cache;
    assign dram.aw_prot = aw_chan_o.prot;
    assign dram.aw_qos = aw_chan_o.qos;
    assign dram.aw_region = aw_chan_o.region;
    assign dram.aw_user = master[ariane_soc::DRAM].aw_user;

    assign dram.ar_id = ar_chan_o.id;
    assign dram.ar_addr = ar_chan_o.addr;
    assign dram.ar_len = ar_chan_o.len;
    assign dram.ar_size = ar_chan_o.size;
    assign dram.ar_burst = ar_chan_o.burst;
    assign dram.ar_lock = ar_chan_o.lock;
    assign dram.ar_cache = ar_chan_o.cache;
    assign dram.ar_prot = ar_chan_o.prot;
    assign dram.ar_qos = ar_chan_o.qos;
    assign dram.ar_region = ar_chan_o.region;
    assign dram.ar_user = master[ariane_soc::DRAM].ar_user;

    assign dram.w_data = w_chan_o.data;
    assign dram.w_strb = w_chan_o.strb;
    assign dram.w_last = w_chan_o.last;
    assign dram.w_user = master[ariane_soc::DRAM].w_user;

    assign r_chan_i.id = dram.r_id;
    assign r_chan_i.data = dram.r_data;
    assign r_chan_i.resp = dram.r_resp;
    assign r_chan_i.last = dram.r_last;
    assign master[ariane_soc::DRAM].r_user = dram.r_user;

    assign b_chan_i.id = dram.b_id;
    assign b_chan_i.resp = dram.b_resp;
    assign master[ariane_soc::DRAM].b_user = dram.b_user;


    axi2mem #(
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_SLAVES ),
        .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH   ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH      ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH      )
    ) i_axi2mem (
        .clk_i  ( clk_i      ),
        .rst_ni ( ndmreset_n ),
        .slave  ( dram       ),
        .req_o  ( req        ),
        .we_o   ( we         ),
        .addr_o ( addr       ),
        .be_o   ( be         ),
        .data_o ( wdata      ),
        .data_i ( rdata      )
    );

    sram #(
        .DATA_WIDTH ( AXI_DATA_WIDTH ),
        .NUM_WORDS  ( NUM_WORDS      )
    ) i_sram (
        .clk_i      ( clk_i                                                                       ),
        .rst_ni     ( rst_ni                                                                      ),
        .req_i      ( req                                                                         ),
        .we_i       ( we                                                                          ),
        .addr_i     ( addr[$clog2(NUM_WORDS)-1+$clog2(AXI_DATA_WIDTH/8):$clog2(AXI_DATA_WIDTH/8)] ),
        .wdata_i    ( wdata                                                                       ),
        .be_i       ( be                                                                          ),
        .rdata_o    ( rdata                                                                       )
    );

    // ---------------
    // AXI Xbar
    // ---------------

    riscv::priv_lvl_t           priv_lvl_processor;   
    logic [riscv::PRIV_LVL_WIDTH-1:0] priv_lvl ; 
    assign priv_lvl = priv_lvl_processor ; 
    logic [NB_SLAVE-1:0][ariane_soc::NB_PERIPHERALS-1:0][riscv::NB_PRIV_LVL-1:0] access_ctrl ;   
    
    genvar i,j;

    generate
        for (i=0; i<NB_SLAVE; i++) begin
            for (j=0; j<ariane_soc::NB_PERIPHERALS; j++) begin
                assign access_ctrl[i][j] = access_ctrl_reg[i][4*j +: 4]; // [4j+4 -1:4j]
            end
        end
    endgenerate

    axi_node_intf_wrap #(
        .NB_SLAVE           ( NB_SLAVE                   ),
        .NB_MASTER          ( ariane_soc::NB_PERIPHERALS ),
	    .NB_PRIV_LVL	    ( riscv::NB_PRIV_LVL	     ), 
    	.PRIV_LVL_WIDTH	    ( riscv::PRIV_LVL_WIDTH	     ),
        .AXI_ADDR_WIDTH     ( AXI_ADDRESS_WIDTH          ),
        .AXI_DATA_WIDTH     ( AXI_DATA_WIDTH             ),
        .AXI_USER_WIDTH     ( AXI_USER_WIDTH             ),
        .AXI_ID_WIDTH       ( AXI_ID_WIDTH               )
        // .MASTER_SLICE_DEPTH ( 0                          ),
        // .SLAVE_SLICE_DEPTH  ( 0                          )
    ) i_axi_xbar (
        .clk          ( clk_i      ),
        .rst_n        ( ndmreset_n ),
        .test_en_i    ( test_en    ),
        .slave        ( slave      ),
        .master       ( master     ),
	.priv_lvl_i   ( priv_lvl   ),  
	.access_ctrl_i( access_ctrl), 
    .MoP_request(MoP_request),
    .MoP_receive(MoP_receive),
    .redirection_idle(redirection_idle),
    .valid_i(valid_i),
    .valid_o(valid_o), 
        .start_addr_i ({
            ariane_soc::DebugBase,
            ariane_soc::MOPBase,
            ariane_soc::Debug2Base,
            ariane_soc::TESTBase,
            ariane_soc::AES2Base,
            ariane_soc::ROMBase,
            ariane_soc::REGLKBase,
            ariane_soc::AcCtBase,
            ariane_soc::PKTBase,
            ariane_soc::DMAbase,
            ariane_soc::CLINTBase,
            ariane_soc::PLICBase,
            ariane_soc::UARTBase,
            ariane_soc::AESBase,
            ariane_soc::SHA256Base, 
            ariane_soc::SPIBase,
            ariane_soc::EthernetBase,
            ariane_soc::GPIOBase,
            ariane_soc::DRAMBase
        }),
        .end_addr_i   ({
            ariane_soc::DebugBase    + ariane_soc::DebugLength - 1,
            ariane_soc::MOPBase      + ariane_soc::MOPLength -1,
            ariane_soc::Debug2Base    + ariane_soc::Debug2Length - 1,
            ariane_soc::TESTBase    + ariane_soc::TESTLength - 1,
            ariane_soc::AES2Base     + ariane_soc::AES2Length - 1,
            ariane_soc::ROMBase      + ariane_soc::ROMLength - 1, 
            ariane_soc::REGLKBase    + ariane_soc::REGLKLength - 1,
            ariane_soc::AcCtBase     + ariane_soc::AcCtLength - 1,
            ariane_soc::PKTBase      + ariane_soc::PKTLength - 1,
            ariane_soc::DMAbase      + ariane_soc::DMALength - 1,
            ariane_soc::CLINTBase    + ariane_soc::CLINTLength - 1,
            ariane_soc::PLICBase     + ariane_soc::PLICLength - 1,
            ariane_soc::UARTBase     + ariane_soc::UARTLength - 1,
            ariane_soc::AESBase      + ariane_soc::AESLength - 1, 
            ariane_soc::SHA256Base   + ariane_soc::SHA256Length - 1, 
            ariane_soc::SPIBase      + ariane_soc::SPILength - 1,
            ariane_soc::EthernetBase + ariane_soc::EthernetLength -1,
            ariane_soc::GPIOBase     + ariane_soc::GPIOLength - 1,
            ariane_soc::DRAMBase     + ariane_soc::DRAMLength - 1
        })
    );

    // ---------------
    // CLINT
    // ---------------
    logic ipi;
    logic timer_irq;

    ariane_axi::req_t    axi_clint_req;
    ariane_axi::resp_t   axi_clint_resp;

    clint #(
        .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH   ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH      ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_SLAVES ),
        .NR_CORES       ( 1                   )
    ) i_clint (
        .clk_i       ( clk_i          ),
        .rst_ni      ( ndmreset_n     ),
        .testmode_i  ( test_en        ),
        .axi_req_i   ( axi_clint_req  ),
        .axi_resp_o  ( axi_clint_resp ),
        .rtc_i       ( rtc_i          ),
        .timer_irq_o ( timer_irq      ),
        .ipi_o       ( ipi            )
    );

    axi_slave_connect i_axi_slave_connect_clint (.axi_req_o(axi_clint_req), .axi_resp_i(axi_clint_resp), .slave(master[ariane_soc::CLINT]));

    // ---------------
    // Peripherals
    // ---------------
    logic tx, rx;
    logic [1:0] irqs;
    
    ariane_axi::req_t    dma_axi_req;  
    ariane_axi::resp_t   dma_axi_resp; 

    ariane_peripherals #(
      .NB_SLAVE     ( NB_SLAVE            ),  
      .AxiAddrWidth ( AXI_ADDRESS_WIDTH   ),
      .AxiDataWidth ( AXI_DATA_WIDTH      ),
      .AxiIdWidth   ( AXI_ID_WIDTH_SLAVES ),
      .InclUART     ( 1'b0                ),
      .InclSPI      ( 1'b0                ),
      .InclEthernet ( 1'b0                )
    ) i_ariane_peripherals (
      .clk_i             ( clk_i                        ),
      .rst_ni            ( ndmreset_n                   ),
      .srst_ni           ( ndmreset1_n                  ),
      .plic              ( master[ariane_soc::PLIC]     ),
      .uart              ( master[ariane_soc::UART]     ),
      .aes               ( master[ariane_soc::AES]      ), 
      .aes2              ( master[ariane_soc::AES2]     ), 
      .mop               (master[ariane_soc::MOP]      ),
      .debug2            ( master[ariane_soc::Debug2]   ), 
      .test              ( master[ariane_soc::TEST]     ), 
      .sha256            ( master[ariane_soc::SHA256]   ), 
      .acct              ( master[ariane_soc::AcCt]     ), 
      .pkt               ( master[ariane_soc::PKT]      ), 
      .reglk             ( master[ariane_soc::REGLK]    ), 
      .spi               ( master[ariane_soc::SPI]      ),
      .ethernet          ( master[ariane_soc::Ethernet] ),
       
      .dma               ( master[ariane_soc::DMA]      ), 
      .dma_axi_req_o     ( dma_axi_req                  ),
      .dma_axi_resp_i    ( dma_axi_resp                 ),  
      
       
      .jtag_key          ( jtag_key                     ), 
      .access_ctrl_reg   ( access_ctrl_reg              ), 
      .irq_o             ( irqs                         ),
      .rx_i              ( rx                           ),
      .tx_o              ( tx                           ),
      .eth_txck          ( ),
      .eth_rxck          ( ),
      .eth_rxctl         ( ),
      .eth_rxd           ( ),
      .eth_rst_n         ( ),
      .eth_tx_en         ( ),
      .eth_txd           ( ),
      .phy_mdio          ( ),
      .eth_mdc           ( ),
      .mdio              ( ),
      .mdc               ( ),
      .spi_clk_o         ( ),
      .spi_mosi          ( ),
      .spi_miso          ( ),
      .testCycle         ( testCycle), 
      .MoP_request          (MoP_request),
      .MoP_receive          (MoP_receive),
      .redirection_idle     (redirection_idle),
      .valid_i          (valid_i),
      .valid_o          (valid_o),
      .spi_ss            ( )
    );
    axi_master_connect i_axi_master_dm (.axi_req_i(dm_axi_m_req), .axi_resp_o(dm_axi_m_resp), .master(slave[1]));
    axi_master_connect i_axi_master_connect_dma (.axi_req_i(dma_axi_req), .axi_resp_o(dma_axi_resp), .master(slave[2]));

    uart_bus #(.BAUD_RATE(115200), .PARITY_EN(0)) i_uart_bus (.rx(tx), .tx(rx), .rx_en(1'b1));

    // ---------------
    // Core
    // ---------------
    ariane_axi::req_t    axi_ariane_req;
    ariane_axi::resp_t   axi_ariane_resp;


    ariane #(
`ifdef PITON_ARIANE
        .SwapEndianess ( 0                                               ),
        .CachedAddrEnd ( (ariane_soc::DRAMBase + ariane_soc::DRAMLength) ),
`endif
        .CachedAddrBeg ( ariane_soc::DRAMBase )
    ) i_ariane (
        .clk_i                ( clk_i               ),
        .rst_ni               ( ndmreset_n          ),
        .boot_addr_i          ( ariane_soc::ROMBase ), // start fetching from ROM
        .hart_id_i            ( '0                  ),
        .irq_i                ( irqs                ),
        .ipi_i                ( ipi                 ),
        .time_irq_i           ( timer_irq           ),
        .debug_req_i          ( debug_req_core      ),
	    .priv_lvl_o	          ( priv_lvl_processor  ),    
        .axi_req_o            ( axi_ariane_req      ),
        .axi_resp_i           ( axi_ariane_resp     )
    );

    axi_master_connect i_axi_master_connect_ariane (.axi_req_i(axi_ariane_req), .axi_resp_o(axi_ariane_resp), .master(slave[0]));

endmodule