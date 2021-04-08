// Description: Wrapper for the test.
//


module mop_wrapper #(
  parameter LOG_N_INIT = 3,
    parameter int ADDR_WIDTH         = 32,   // width of external address bus
    parameter int DATA_WIDTH         = 32   // width of external data bus
)(
           input  logic clk_i,
           input  logic rst_ni,
           input  logic [7 :0] reglk_ctrl_i,
           output logic [LOG_N_INIT-1:0] request,
           output logic [LOG_N_INIT-1:0] receive,
           input  logic valid_i,
           output  logic valid_o,
           output  logic    [31:0] instrut_value,
           output logic MoP_override,
           output logic [1:0] change,
           output logic [ariane_soc::NB_PERIPHERALS-1 :0] load_ctrl, 
           REG_BUS.in  external_bus_io
       );

// internal signals
localparam CTRL_IDLE = 'd0; 
localparam CTRL_START_LOAD = 'd1;
localparam CTRL_LOAD = 'd2; 
localparam CTRL_RED= 'd3;
localparam CTRL_NOR = 'd4;
localparam CTRL_DONE = 'd5;
logic [ariane_soc::LOG_N_INIT-1:0] target;
logic [3:0] count;
////////////////////////////////////////////////////////////////
// logic [31:0]t_i_addr;
// logic t_i_write ; // 0=read, 1=write
// logic [31:0]t_i_rdata;
// logic [31:0]t_i_wdata;
// logic [3:0]t_i_wstrb ; //// byte-wise strobe
// logic t_i_error ; // 0=ok, 1=error
// logic t_i_valid ;
// logic t_i_ready ;
// logic [31:0]t_o_addr ;
// logic t_o_write ;
// logic [31:0]t_o_rdata ;
// logic [31:0]t_o_wdata ;
// logic [3:0]t_o_wstrb ;
// logic t_o_error ;
// logic t_o_valid ;
// logic t_o_ready ;
// logic alarm;
// logic ext_wr;
// logic [16:0] ext_data_in;
// logic [19:0] ext_act_in;
// logic [2:0] ext_addr;
logic override;
logic [ariane_soc::LOG_N_INIT-1:0] r_target;
logic [ariane_soc::LOG_N_INIT-1:0] r_source;
///////////////////////////////////////////////////////////////
logic [31:0] test[127:0];
logic [3:0]state;

// // assign test[0] = {24'b0, reglk_ctrl_i};
assign external_bus_io.ready = 1'b1;
assign external_bus_io.error = 1'b0;
assign request = 0;
assign receive = 0;
assign valid_o = 0;
// ///////////////////////////////////////////////////////////////////////////
// // Implement APB I/O map to PKT interface
always@(*)begin
    if(state == 0)
        MoP_override = 0;
    else  
        MoP_override = 1; 
end
always @(posedge clk_i)
    begin
    if(~rst_ni)begin
        state <= 0;
        count <= 0;
        load_ctrl <= 0;
        instrut_value <= 0;
    end
    else begin
      case (state)
        CTRL_IDLE: 
          begin
            load_ctrl <= 0;
            count <= 0;
            if(external_bus_io.write && external_bus_io.wdata == 32'b0)begin
                state <= CTRL_START_LOAD;
            end
          end
        CTRL_START_LOAD: 
          begin
            if(external_bus_io.write)begin
                state <= CTRL_LOAD;
                target <= external_bus_io.wdata;
            end
          end
        CTRL_LOAD: 
          begin
            if(external_bus_io.write )begin
                change <= external_bus_io.wdata[1:0];
                if(external_bus_io.wdata[1] == 1)
                    state <= CTRL_RED;
                else 
                    state <= CTRL_NOR;
            end
          end
        CTRL_NOR:
        begin
            if(external_bus_io.write )begin
                instrut_value <= external_bus_io.wdata;
                load_ctrl[target] <= 1;
                count <= count+1;
            end
            else begin
                if(count == 8)
                    state <= CTRL_IDLE;
                load_ctrl[target] <= 0;
            end
        end 
        CTRL_RED:
        begin
            if(external_bus_io.write )begin
                instrut_value <= external_bus_io.wdata;
                load_ctrl[target] <= 1;
                count <= count+1;
            end
            else begin
                if(count == 8)
                    state <= CTRL_IDLE;
                load_ctrl[target] <= 0;
            end
        end 
        default:
            ;
      endcase
    end  // dma_ctrl
end
always @(posedge clk_i)
    begin
        if(~rst_ni)
            begin
                override <= 0;
                r_source <= 0; 
                r_target <= 0;
            end
        else if(external_bus_io.write)begin
            case(external_bus_io.addr[8:2])
                0:
                    override  <= external_bus_io.wdata[0];
                1:
                    r_source <= external_bus_io.wdata;
                2:
                    r_target <= external_bus_io.wdata;
                default:
                    ;
            endcase
        end
    end
endmodule
