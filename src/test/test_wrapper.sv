// Description: Wrapper for the test.
//


module test_wrapper #(
    parameter int ADDR_WIDTH         = 32,   // width of external address bus
    parameter int DATA_WIDTH         = 32   // width of external data bus
)(
           clk_i,
           rst_ni,
           reglk_ctrl_o,
           external_bus_io
       );


    input  logic                   clk_i;
    output  logic [7 :0]            reglk_ctrl_o; // register lock values
    input  logic                   rst_ni;
    REG_BUS.in                     external_bus_io;

// internal signals
localparam CTRL_IDLE = 'd0; 
localparam CTRL_START_LOAD = 'd1;
localparam CTRL_LOAD = 'd2; 
localparam CTRL_STORE = 'd3;
localparam CTRL_DONE = 'd4;
logic [63:0] storage;
logic [31:0] test[127:0];
logic [3:0]state;

assign external_bus_io.ready = 1'b1;
assign external_bus_io.error = 1'b0;
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
        else if(external_bus_io.write)begin
          if(external_bus_io.addr[8:2] == 0)
            test[0] = external_bus_io.wdata;
          else if(test[1] == 1)
            test[external_bus_io.addr[8:2]] = external_bus_io.wdata;
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
            test[1] = 1;
            if(test[0] == 2)
              state <= CTRL_STORE;
          end
        CTRL_STORE:
          begin
            state <= CTRL_DONE;
            reglk_ctrl_o <= test[2];
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



endmodule
