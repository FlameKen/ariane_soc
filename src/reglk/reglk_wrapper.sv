// Description: Access Control registers
//



module reglk_wrapper (
           clk_i,
           rst_ni,
           reglk_ctrl_o,
           external_bus_io
       );

    parameter NB_SLAVE = 3;

    input  logic                   clk_i;
    input  logic                   rst_ni;
    output logic [8*ariane_soc::NB_PERIPHERALS-1 :0]   reglk_ctrl_o; // register lock values
    REG_BUS.in                     external_bus_io;


// internal signals

reg [5:0][31:0] reglk_mem ;   // this size is sufficient for 24 slaves where each slave gets 8 bits

assign reglk_ctrl_o = {reglk_mem[5], reglk_mem[4], reglk_mem[3], reglk_mem[2], reglk_mem[1], reglk_mem[0]}; 

assign external_bus_io.ready = 1'b1;
assign external_bus_io.error = 1'b0;

///////////////////////////////////////////////////////////////////////////
// Implement APB I/O map to PKT interface
// Write side
integer j;
always @(posedge clk_i)
    begin
        if(~rst_ni)
            begin
              for (j=0; j < 6; j=j+1) begin
                reglk_mem[j] <= 'h0;
              end
            end
        else if(external_bus_io.write)
            case(external_bus_io.addr[6:2])
                0:
                    reglk_mem[0]  <= external_bus_io.wdata;
                1:
                    reglk_mem[1]  <= external_bus_io.wdata; 
                2:
                    reglk_mem[2]  <= external_bus_io.wdata;
                3:
                    reglk_mem[3]  <= external_bus_io.wdata;
                4:
                    reglk_mem[4]  <= external_bus_io.wdata;
                5:
                    reglk_mem[5]  <= external_bus_io.wdata;
                default:
                    ;
            endcase
    end // always @ (posedge wb_clk_i)

//// Read side
always @(*)
    begin
        case(external_bus_io.addr[6:2])
            0:
                external_bus_io.rdata = reglk_mem[0]; 
            1:                                    
                external_bus_io.rdata = reglk_mem[1];
            2:                                    
                external_bus_io.rdata = reglk_mem[2];
            3:                                    
                external_bus_io.rdata = reglk_mem[3];
            4:                                    
                external_bus_io.rdata = reglk_mem[4];
            5:                                    
                external_bus_io.rdata = reglk_mem[5];
            default:
                external_bus_io.rdata = 32'b0;
        endcase
    end // always @ (*)


endmodule
