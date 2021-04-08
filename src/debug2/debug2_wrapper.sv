// Description: Wrapper for the test.
//


module debug2_wrapper #(
  parameter LOG_N_INIT = 3,
    parameter int ADDR_WIDTH         = 32,   // width of external address bus
    parameter int DATA_WIDTH         = 32   // width of external data bus
)(
           clk_i,
           rst_ni,
           reglk_ctrl_i,
          //  mop_bus_io.request,
          //  mop_bus_io.receive,
          //  mop_bus_io.valid_i,
          //  mop_bus_io.valid_o,
          //  mop_bus_io.instrut_value,
          //  mop_bus_io.load_ctrl,
           mop_bus_io,
           external_bus_io
       );


    input  logic                   clk_i;
    input  logic [7 :0]            reglk_ctrl_i; // register lock values
    input  logic                   rst_ni;
    // output logic [LOG_N_INIT-1:0]   mop_bus_io.request;
    // output logic [LOG_N_INIT-1:0]   mop_bus_io.receive;
    // input  logic                    mop_bus_io.valid_i;
    // output  logic                    mop_bus_io.valid_o;
    // input logic [ariane_soc::NB_PERIPHERALS-1 :0]   mop_bus_io.load_ctrl;
    // input  logic    [31:0]           mop_bus_io.instrut_value;
    MOP_BUS.in                     mop_bus_io;
    REG_BUS.in                     external_bus_io;

// internal signals
localparam CTRL_IDLE = 'd0; 
localparam CTRL_START_LOAD = 'd1;
localparam CTRL_LOAD = 'd2; 
localparam CTRL_START_STORE = 'd3;
localparam CTRL_STORE = 'd4;
localparam CTRL_DONE = 'd5;
logic [63:0] storage;
logic [31:0] test[127:0];
logic [3:0]state;
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
logic [2:0] re_ext_addr;
logic [3:0] source;
logic [3:0] target;
///////////////////////////////////////////////////////////////////////////
// assign test[0] = {24'b0, reglk_ctrl_i};
assign external_bus_io.ready = 1'b1;
assign external_bus_io.error = 1'b0;
// assign mop_bus_io.request = 0;
// assign mop_bus_io.receive = 0;
assign mop_bus_io.valid_o = 0;
///////////////////////////////////////////////////////////////////////////
// Implement APB I/O map to PKT interface
// Write side
always @(posedge clk_i)
    begin
        if(~rst_ni)
            begin
                state <= 0;
                for(integer i = 0 ;i< 128;i=i+1)
                begin
                    test[i]<=32'b0;
                end
            end
        else begin
          if(external_bus_io.write)begin
            // if(external_bus_io.addr[8:2] != 0)
              test[external_bus_io.addr[8:2]] = external_bus_io.wdata;
            // else 
            //   test[0] = {24'b0, reglk_ctrl_i};
          end
        end
    end // always @ (posedge wb_clk_i)
always @(posedge clk_i)
    begin
      case (state)
        CTRL_IDLE: 
          begin
            if(test[0] == 1)
                state <= CTRL_START_LOAD;
          end
        CTRL_START_LOAD: 
          begin
            state <= CTRL_LOAD;
          end
        CTRL_LOAD: 
          begin
            state <= CTRL_STORE;
          end
        CTRL_STORE:
          begin
            state <= CTRL_DONE;
            test[0] <= {24'b0,reglk_ctrl_i};
          end
        CTRL_DONE:
          begin
              if(test[0] == 1)
                state <= CTRL_IDLE;
              if(test[1] == 1)
                state <= CTRL_START_LOAD;
          end 
        default:
            ;
      endcase
    end  // dma_ctrl

//// Read side
always @(*)
    begin
        if(external_bus_io.addr[8:2] == 3)
            external_bus_io.rdata = {31'b0,state};
        else
            external_bus_io.rdata = test[external_bus_io.addr[8:2]];
    end // always @ (*)
load_instruction load(
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .instrut_value(mop_bus_io.instrut_value),
            .load_ctrl(mop_bus_io.load_ctrl),
            .id(ariane_soc::Debug2),
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

endmodule
