

module aes_wrapper #(
    parameter LOG_N_INIT = 3,
    parameter int ADDR_WIDTH         = 32,   // width of external address bus
    parameter int DATA_WIDTH         = 32   // width of external data bus
)(
           input  logic clk_i,
           input  logic rst_ni,
           input logic [7 :0] reglk_ctrl_i,
           input  logic    [191:0]        testCycle,
           input  logic    [191:0] key_in,
           MOP_BUS.in mop_bus_io,
           REG_BUS.in external_bus_io
       );

// internal logics

logic start;
logic [31:0] p_c [0:3];
logic [31:0] state [0:3];
logic [31:0] key0 [0:5]; 
logic [31:0] key1 [0:5]; 
logic [31:0] key2 [0:5]; 

logic [1:0] key_sel; 

logic   [127:0] p_c_big   ;  
logic   [127:0] state_big ;  
logic   [191:0] key_big ;  
logic   [191:0] key_big0, key_big1, key_big2 ;  
logic   [127:0] ct;
logic           ct_valid;
logic  [3:0]clock;


assign p_c_big    = {p_c[0], p_c[1], p_c[2], p_c[3]};
assign state_big  = {state[0], state[1], state[2], state[3]};
assign key_big0    = {key0[0], key0[1], key0[2], key0[3], key0[4], key0[5]}; 
assign key_big1    = {key1[0], key1[1], key1[2], key1[3], key1[4], key1[5]}; 
assign key_big2    = {key2[0], key2[1], key2[2], key2[3], key2[4], key2[5]}; 
///////////////////////////////////////////////////////////////////////////
logic [31:0]t_i_addr;
logic t_i_write ; // 0=read, 1=write
logic [31:0]t_i_rdata;
logic [31:0]t_i_wdata;
logic [3:0]t_i_wstrb ; //// byte-wise strobe
logic t_i_error ; // 0=ok, 1=error
logic t_i_valid ;
logic t_i_ready ;
logic [31:0]t_o_addr ;
logic t_o_write ;
logic [31:0]t_o_rdata ;
logic [31:0]t_o_wdata ;
logic [3:0]t_o_wstrb ;
logic t_o_error ;
logic error;
logic t_o_valid ;
logic t_o_ready ;
logic alarm;
logic ext_wr;
logic [11:0] ext_data_in;
logic [19:0] ext_act_in;
logic [2:0] ext_addr;
logic [18:0] re_ext_data_in;
logic re_ext_wr;
logic [2:0] re_ext_addr;
logic [3:0] source;
logic [3:0] target;
////////////////////////////////////////////////////////////////////////////
// logic test;
// logic redirected;
logic override;
logic override_update;
///////////////////////////////////////////////////////////////////////////
assign source = 4'h5;
assign target = 4'he;
assign external_bus_io.ready = t_o_ready;
// assign external_bus_io.error = t_o_error;
assign external_bus_io.error = override_update;
assign external_bus_io.rdata = t_o_rdata;
// assign mop_bus_io.override_out = override;
assign t_i_addr = external_bus_io.addr;
assign t_i_write = external_bus_io.write;
// assign t_i_rdata = t_i_rdata;
assign t_i_ready = 1;
assign t_i_error = 0;

assign t_i_wdata = external_bus_io.wdata;
assign t_i_valid = external_bus_io.valid;
assign t_i_wstrb = external_bus_io.wstrb;
redirect_mop r_mop(
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .target({1'b0,target}),
    .source({1'b0,source}),
    // .override(override|override_update),
    .override(mop_bus_io.override_out),
    .valid_i(mop_bus_io.valid_i),
    .valid_o(mop_bus_io.valid_o),
    .request(mop_bus_io.request),
    .receive(mop_bus_io.receive)
);
remop_redirec mop(   
    .clk                (   clk_i                   ),
    .reset              (   ~rst_ni                 ),
    .i_addr             (   t_i_addr                ),
    .i_write            (   t_i_write               ),
    .i_rdata            (   t_i_rdata               ),
    .i_wdata            (   t_i_wdata               ),
    .i_wstrb            (   t_i_wstrb               ),
    .i_error            (   t_i_error               ),
    .i_valid            (   t_i_valid               ),
    .i_ready            (   t_i_ready               ),
    .o_addr             (   t_o_addr                ),
    .o_write            (   t_o_write               ),
    .o_rdata            (   t_o_rdata               ),
    .o_wdata            (   t_o_wdata               ),
    .o_valid            (   t_o_valid               ),
    .o_wstrb            (   t_o_wstrb               ),
    .o_error            (   t_o_error               ),
    .o_ready            (   t_o_ready               ),
    .alarm              (   alarm                   ),
    .ext_wr             (   ext_wr                  ),
    .ext_data_in        (   {1'b0,ext_data_in}      ),
    .ext_act_in         (   ext_act_in              ),
    .ext_addr           (   {1'b0,ext_addr}         ),
    .re_ext_wr          (   re_ext_wr               ),
    .re_ext_data_in     (   re_ext_data_in          ),
    .re_ext_addr        (   re_ext_addr             ),
    .redirection        (   override                ),
    // .source             (   source                  ),
    // .target             (   target                  ),
    .override_in        (   mop_bus_io.override_in  ),
    .override_dataout   (   mop_bus_io.re_data_out  ),
    .override_out       (   mop_bus_io.override_out ),
    .override_datain    (   mop_bus_io.re_data_in   ),
    .idle               (   mop_bus_io.idle_IP      )
);

///////////////////////////////////////////////////////////////////////////
load_instruction load(
            .clk_i              (   clk_i                       ),
            .rst_ni             (   rst_ni                      ),
            .instrut_value      (   mop_bus_io.instrut_value    ),
            .load_ctrl          (   mop_bus_io.load_ctrl        ),
            .id                 (   ariane_soc::AES             ),
            .ext_wr             (   ext_wr                      ),
            .re_ext_wr          (   re_ext_wr                   ),
            .ext_data_in        (   ext_data_in                 ),
            .ext_act_in         (   ext_act_in                  ),
            .re_ext_data_in     (   re_ext_data_in              ),
            .ext_addr           (   ext_addr                    ),
            .re_ext_addr        (   re_ext_addr                 ),
            .change             (   mop_bus_io.change           )
);
// Implement APB I/O map to AES interface
always @(posedge clk_i)
    begin
        if(~rst_ni)
            begin
                start <= 0;
                p_c[0] <= 0;
                p_c[1] <= 0;
                p_c[2] <= 0;
                p_c[3] <= 0;
                state[0] <= 0;
                state[1] <= 0;
                state[2] <= 0;
                state[3] <= 0;
                override_update <= 0;
            end
        else if(t_o_write)begin
            case(t_o_addr[8:2])
                0:
                    start  <= reglk_ctrl_i[1] ? start  : t_o_wdata[0];
                1:
                    p_c[3] <= reglk_ctrl_i[3] ? p_c[3] : t_o_wdata;
                2:
                    p_c[2] <= reglk_ctrl_i[3] ? p_c[2] : t_o_wdata;
                3:
                    p_c[1] <= reglk_ctrl_i[3] ? p_c[1] : t_o_wdata;
                4:
                    p_c[0] <= reglk_ctrl_i[3] ? p_c[0] : t_o_wdata;
                5:   
                    key0[5] <= reglk_ctrl_i[5] ? key0[5] : t_o_wdata;
                6:                                        
                    key0[4] <= reglk_ctrl_i[5] ? key0[4] : t_o_wdata;
                7:                                        
                    key0[3] <= reglk_ctrl_i[5] ? key0[3] : t_o_wdata;
                8:                                        
                    key0[2] <= reglk_ctrl_i[5] ? key0[2] : t_o_wdata;
                9:                                        
                    key0[1] <= reglk_ctrl_i[5] ? key0[1] : t_o_wdata;
                10:
                    key0[0] <= reglk_ctrl_i[5] ? key0[0] : t_o_wdata;
                16:
                    state[3] <= reglk_ctrl_i[7] ? state[3] : t_o_wdata;
                17:                                        
                    state[2] <= reglk_ctrl_i[7] ? state[2] : t_o_wdata;
                18:                                        
                    state[1] <= reglk_ctrl_i[7] ? state[1] : t_o_wdata;
                19:                                        
                    state[0] <= reglk_ctrl_i[7] ? state[0] : t_o_wdata;
                20:
                    key1[5] <= reglk_ctrl_i[5] ? key1[5] : t_o_wdata;
                21:                                       
                    key1[4] <= reglk_ctrl_i[5] ? key1[4] : t_o_wdata;
                22:                                       
                    key1[3] <= reglk_ctrl_i[5] ? key1[3] : t_o_wdata;
                23:                                       
                    key1[2] <= reglk_ctrl_i[5] ? key1[2] : t_o_wdata;
                24:                                       
                    key1[1] <= reglk_ctrl_i[5] ? key1[1] : t_o_wdata;
                25:                                        
                    key1[0] <= reglk_ctrl_i[5] ? key1[0] : t_o_wdata;
                26:
                    key2[5] <= reglk_ctrl_i[5] ? key2[5] : t_o_wdata;
                27:                                       
                    key2[4] <= reglk_ctrl_i[5] ? key2[4] : t_o_wdata;
                28:                                       
                    key2[3] <= reglk_ctrl_i[5] ? key2[3] : t_o_wdata;
                29:                                       
                    key2[2] <= reglk_ctrl_i[5] ? key2[2] : t_o_wdata;
                30:                                       
                    key2[1] <= reglk_ctrl_i[5] ? key2[1] : t_o_wdata;
                31:                                        
                    key2[0] <= reglk_ctrl_i[5] ? key2[0] : t_o_wdata;
                32: 
                    key_sel <= reglk_ctrl_i[5] ? key_sel : t_o_wdata;
                // 33:
                    // $display("clock : %d\n",testCycle);
                34:
                    override_update <= t_o_wdata;
                default:
                    ;
            endcase
        end
    end // always @ (posedge wb_clk_i)

// Implement MD5 I/O memory map interface
// Read side
//always @(~t_o_write)
always @(*)
    begin
            case(t_o_addr[8:2])
            0:
                t_i_rdata = reglk_ctrl_i[0] ? 'b0 : {31'b0, start};
            1:
                t_i_rdata = reglk_ctrl_i[2] ? 'b0 : p_c[3];
            2:
                t_i_rdata = reglk_ctrl_i[2] ? 'b0 : p_c[2];
            3:
                t_i_rdata = reglk_ctrl_i[2] ? 'b0 : p_c[1];
            4:
                t_i_rdata = reglk_ctrl_i[2] ? 'b0 : p_c[0];
            11:
                t_i_rdata = reglk_ctrl_i[6] ? 'b0 : {31'b0, ct_valid};
            12:
                t_i_rdata = reglk_ctrl_i[4] ? 'b0 : ct[31:0];
            13:                                                 
                t_i_rdata = reglk_ctrl_i[4] ? 'b0 : ct[63:32];
            14:                                                 
                t_i_rdata = reglk_ctrl_i[4] ? 'b0 : ct[95:64];
            15:                                                 
                t_i_rdata = reglk_ctrl_i[4] ? 'b0 : ct[127:96];
            default:
                t_i_rdata = 32'b0;
            endcase
    end // always @ (*)


// select the proper key

assign key_big = key_sel[1] ? key_big2 : ( key_sel[0] ? key_big1 : key_big0 );  

// aes_mop aes_mop_1(
//     .clk_i(clk_i),
//     .rst_ni(rst_ni),
//     .pt_i(p_c_big),
//     .ct_i(ct),
//     .mop_bus_io.valid_i(ct_valid),
//     .mop_bus_io.valid_o(test),
//     .override(override)
// );
aes_192_sed aes(
            .clk(clk_i),
            .state(state_big),
            .p_c_text(p_c_big),
            .key(key_big),
            .start(start),
            .out(ct),
            .out_valid(ct_valid)
        );

endmodule