// module aes2_wrapper #(
//     parameter int ADDR_WIDTH         = 32,   // width of external address bus
//     parameter int DATA_WIDTH         = 32   // width of external data bus
// )(
//            clk_i,
//            rst_ni,
//            external_bus_io
//        );

//     input  logic                   clk_i;
//     input  logic                   rst_ni;
//     REG_BUS.in                     external_bus_io;

// // internal signals

// logic start;
// // internal signals - sc456
// logic [31:0] firmware [127:0];
// // logic [31:0] test [7:0];
// logic [31:0]reg_address;
// logic [31:0]reg_data;

// logic [31:0] storage;
// logic [31:0] out_wdata;
// logic [31:0] test_addr;

// // firmware[1] : address firmware[2] : data IP transfer itself
// assign test_addr = (firmware[1] - ariane_soc::AES2Base);
// assign external_bus_io.ready = 1'b1;
// assign external_bus_io.error = 1'b0;

// ///////////////////////////////////////////////////////////////////////////
// // Implement APB I/O map to AES interface
// // Write side
// always @(posedge clk_i)
//     begin
//         if(~rst_ni)
//             begin
//                 start <= 0;
//                 storage <= 0;
//                 reg_address <= 0;
//                 out_wdata <=0;
//                 reg_data <= 0;
//                 for(integer i = 0 ;i< 127;i=i+1)
//                 begin
//                     firmware[i]<=0;
//                 end

//             end
//         else if(external_bus_io.write)
//         begin
//             if(external_bus_io.addr[8:2] == 2)
//             begin
//                 reg_data <= external_bus_io.wdata;
//                 start <=1;
//             end
//             firmware[external_bus_io.addr[8:2]]<=external_bus_io.wdata;
//         end
//     end // always @ (posedge wb_clk_i)

// always @(*)
//     begin
//             if(start == 1)
//             begin
//                 firmware[test_addr[8:2]] = firmware[2];
//                 reg_address = reg_data;
//             end
//             external_bus_io.rdata = firmware[external_bus_io.addr[8:2]];
        
//     end // always @ (*)

// // newmop mop1 (   
// //                 .clk(clk_i),
// //                 .reset(rst_ni),
// //                 .i_addr({external_bus_io.addr}),
// //                 .i_write(1'b0),
// //                 .i_rdata(external_bus_io.rdata),
// //                 .i_wdata(firmware[external_bus_io.addr[8:2]]),
// //                 .i_valid(1'b1),
// //                 .i_ready(external_bus_io.ready),
// //                 .o_addr(firmware[102]),
// //                 .o_write(storage[0]),
// //                 .o_rdata(firmware[100]),
// //                 .o_wdata(out_wdata),
// //                 .o_valid(storage[1]),
// //                 .o_ready(storage[2])

// //             );
// endmodule

//////////////////////////////////////////////////////////////////////////////////


module aes2_wrapper #(
    parameter LOG_N_INIT = 3,
    parameter int ADDR_WIDTH         = 32,   // width of external address bus
    parameter int DATA_WIDTH         = 32   // width of external data bus
)(
           input  logic clk_i,
           input  logic rst_ni,
           input logic [7 :0] reglk_ctrl_i,
           MOP_BUS.out mop_bus_io,
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
logic [2:0]counter ;
logic [31:0]finish_counter ;

// assign external_bus_io.ready = 1'b1;
assign external_bus_io.error = 1'b0;
assign mop_bus_io.request = 0;
assign mop_bus_io.valid_o = 0;
assign mop_bus_io.receive = 0;

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
logic t_o_valid ;
logic t_o_ready ;
logic alarm;
logic ext_wr;
logic [10:0] ext_data_in;
logic [19:0] ext_act_in;
logic [2:0] ext_addr;
logic [17:0] re_ext_data_in;
logic re_ext_wr;
logic [1:0] re_ext_addr;
logic [3:0] source;
logic [3:0] target;
///////////////////////////////////////////////////////////////////////////
logic test;
///////////////////////////////////////////////////////////////////////////
assign t_clk = clk_i;
assign t_reset = ~rst_ni;
assign t_i_addr = external_bus_io.addr;
assign t_i_write = external_bus_io.write;
assign t_i_rdata = external_bus_io.rdata;
assign t_i_ready = external_bus_io.ready;
assign t_i_wdata = external_bus_io.wdata;
assign t_i_valid = external_bus_io.valid;
assign t_i_wstrb = external_bus_io.wstrb;
// assign test = t_i_valid+t_i_write;
///////////////////////////////////////////////////////////////////////////
// Implement APB I/O map to AES interface
always @(posedge clk_i)
    begin
        if(~rst_ni)
            begin
                start <= 0;
                p_c[0] <= 0;
                p_c[1] <= 0;
                p_c[2] <= 0;
                clock <=0;
                p_c[3] <= 0;
                counter <= 0 ;
                finish_counter <= 0; 
                external_bus_io.ready <= 1'b0;
                state[0] <= 0;
                state[1] <= 0;
                state[2] <= 0;
                state[3] <= 0;
                // clock <= 0;
                // $display("start at : %d, clock %b\n",testCycle,clk_i);
            end
        else if(external_bus_io.write)begin
            counter <= counter+1;
            if(counter == 5)
                external_bus_io.ready <= 1'b1;
            case(external_bus_io.addr[8:2])
                0:
                    start  <= reglk_ctrl_i[1] ? start  : external_bus_io.wdata[0];
                1:
                    p_c[3] <= reglk_ctrl_i[3] ? p_c[3] : external_bus_io.wdata;
                2:
                    p_c[2] <= reglk_ctrl_i[3] ? p_c[2] : external_bus_io.wdata;
                3:
                    p_c[1] <= reglk_ctrl_i[3] ? p_c[1] : external_bus_io.wdata;
                4:
                    p_c[0] <= reglk_ctrl_i[3] ? p_c[0] : external_bus_io.wdata;
                5:   
                    key0[5] <= reglk_ctrl_i[5] ? key0[5] : external_bus_io.wdata;
                6:                                        
                    key0[4] <= reglk_ctrl_i[5] ? key0[4] : external_bus_io.wdata;
                7:                                        
                    key0[3] <= reglk_ctrl_i[5] ? key0[3] : external_bus_io.wdata;
                8:                                        
                    key0[2] <= reglk_ctrl_i[5] ? key0[2] : external_bus_io.wdata;
                9:                                        
                    key0[1] <= reglk_ctrl_i[5] ? key0[1] : external_bus_io.wdata;
                10:
                    key0[0] <= reglk_ctrl_i[5] ? key0[0] : external_bus_io.wdata;
                16:
                    state[3] <= reglk_ctrl_i[7] ? state[3] : external_bus_io.wdata;
                17:                                        
                    state[2] <= reglk_ctrl_i[7] ? state[2] : external_bus_io.wdata;
                18:                                        
                    state[1] <= reglk_ctrl_i[7] ? state[1] : external_bus_io.wdata;
                19:                                        
                    state[0] <= reglk_ctrl_i[7] ? state[0] : external_bus_io.wdata;
                20:
                    key1[5] <= reglk_ctrl_i[5] ? key1[5] : external_bus_io.wdata;
                21:                                       
                    key1[4] <= reglk_ctrl_i[5] ? key1[4] : external_bus_io.wdata;
                22:                                       
                    key1[3] <= reglk_ctrl_i[5] ? key1[3] : external_bus_io.wdata;
                23:                                       
                    key1[2] <= reglk_ctrl_i[5] ? key1[2] : external_bus_io.wdata;
                24:                                       
                    key1[1] <= reglk_ctrl_i[5] ? key1[1] : external_bus_io.wdata;
                25:                                        
                    key1[0] <= reglk_ctrl_i[5] ? key1[0] : external_bus_io.wdata;
                26:
                    key2[5] <= reglk_ctrl_i[5] ? key2[5] : external_bus_io.wdata;
                27:                                       
                    key2[4] <= reglk_ctrl_i[5] ? key2[4] : external_bus_io.wdata;
                28:                                       
                    key2[3] <= reglk_ctrl_i[5] ? key2[3] : external_bus_io.wdata;
                29:                                       
                    key2[2] <= reglk_ctrl_i[5] ? key2[2] : external_bus_io.wdata;
                30:                                       
                    key2[1] <= reglk_ctrl_i[5] ? key2[1] : external_bus_io.wdata;
                31:                                        
                    key2[0] <= reglk_ctrl_i[5] ? key2[0] : external_bus_io.wdata;
                32: 
                    key_sel <= reglk_ctrl_i[5] ? key_sel : external_bus_io.wdata;
                33:
                    finish_counter <= external_bus_io.wdata;
                default:
                    ;
            endcase
        end
        else begin
            counter <= 0;
        end
    end // always @ (posedge wb_clk_i)

// Implement MD5 I/O memory map interface
// Read side
//always @(~external_bus_io.write)
always @(*)
    begin
        case(external_bus_io.addr[8:2])
            0:
                external_bus_io.rdata = reglk_ctrl_i[0] ? 'b0 : {31'b0, start};
            1:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : p_c[3];
            2:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : p_c[2];
            3:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : p_c[1];
            4:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : p_c[0];
            11:
                external_bus_io.rdata = reglk_ctrl_i[6] ? 'b0 : {31'b0, ct_valid};
                // external_bus_io.rdata = reglk_ctrl_i[6] ? 'b0 : {31'b0, test};
            12:
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : ct[31:0];
            13:                                                 
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : ct[63:32];
            14:                                                 
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : ct[95:64];
            15:                                                 
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : ct[127:96];
            default:
                external_bus_io.rdata = 32'b0;
        endcase
    end // always @ (*)

load_instruction load(
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .instrut_value(mop_bus_io.instrut_value),
            .load_ctrl(mop_bus_io.load_ctrl),
            .id(ariane_soc::AES2),
            .ext_wr(ext_wr),
            .ext_data_in(ext_data_in),
            .ext_addr(ext_addr),
            .re_ext_wr(re_ext_wr),
            .ext_act_in(ext_act_in),
            .re_ext_data_in(re_ext_data_in),
            .re_ext_addr(re_ext_addr),
            .change(mop_bus_io.change)
);
// redirectmop mop(   
//                 .clk(clk_i),
//                 .reset(rst_ni),
//                 .i_addr(t_i_addr),
//                 .i_write(t_i_write),
//                 .i_rdata(t_i_rdata),
//                 .i_wdata(t_i_wdata),
//                 .i_wstrb(t_i_wstrb),
//                 .i_error(t_i_error),
//                 .i_valid(t_i_valid),
//                 .i_ready(t_i_ready),
//                 .o_addr(t_o_addr),
//                 .o_write(t_o_write),
//                 .o_rdata(t_o_rdata),
//                 .o_wdata(t_o_wdata),
//                 .o_valid(t_o_valid),
//                 .o_ready(t_o_ready),
//                 .alarm(alarm),
//                 .ext_wr(ext_wr),
//                 .ext_data_in(ext_data_in),
//                 .ext_act_in(ext_act_in),
//                 .ext_addr(ext_addr)
//             );
// select the proper key
assign key_big = key_sel[1] ? key_big2 : ( key_sel[0] ? key_big1 : key_big0 );  
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
