// Description: Access Control registers
//


module acct_wrapper (
           clk_i,
           rst_ni,
           reglk_ctrl_i,
           acc_ctrl_o,
           external_bus_io
       );

    parameter NB_SLAVE = 3;

    input  logic                   clk_i;
    input  logic                   rst_ni;
    input  logic [7 :0]            reglk_ctrl_i; // register lock values
    output logic [NB_SLAVE-1:0][4*ariane_soc::NB_PERIPHERALS-1 :0]   acc_ctrl_o; // Access control values
    REG_BUS.in                     external_bus_io;

    localparam AcCt_MEM_SIZE = NB_SLAVE*3 ;  // 32*3 bytes of access control for each slave interface

// internal signals

reg [AcCt_MEM_SIZE-1:0][31:0] acct_mem ; 

genvar i; 
generate
    for (i=0; i < NB_SLAVE; i=i+1) begin : ACCT_MEM
        assign acc_ctrl_o[i] = {acct_mem[3*i+2], acct_mem[3*i+1], acct_mem[3*i+0]}; 
    end
endgenerate

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
              for (j=0; j < AcCt_MEM_SIZE; j=j+1) begin
                acct_mem[j] <= 32'h88888888; // Default full access only for machine mode
              end
            end
        else if(external_bus_io.write)
            case(external_bus_io.addr[9:2])
                0:
                    acct_mem[00]  <= reglk_ctrl_i[5] ? acct_mem[00] : external_bus_io.wdata;
                1:    
                begin                                            
                    acct_mem[01]  <= acct_mem[01]; 
                    // acct_mem[01]  <= reglk_ctrl_i[5] ? acct_mem[01] : external_bus_io.wdata; 
                    // $finish();
                end
                2:                                                
                    // acct_mem[02]  <= reglk_ctrl_i[5] ? acct_mem[02] : external_bus_io.wdata;
                    acct_mem[02]  <= acct_mem[02]; 
                3:                                                
                    acct_mem[03]  <= reglk_ctrl_i[3] ? acct_mem[03] : external_bus_io.wdata;
                4:                                                
                    acct_mem[04]  <= reglk_ctrl_i[3] ? acct_mem[04] : external_bus_io.wdata;
                5:                                                
                    acct_mem[05]  <= reglk_ctrl_i[3] ? acct_mem[05] : external_bus_io.wdata;
                6:                                                
                    acct_mem[06]  <= reglk_ctrl_i[1] ? acct_mem[06] : external_bus_io.wdata;
                7:                                                
                    acct_mem[07]  <= reglk_ctrl_i[1] ? acct_mem[07] : external_bus_io.wdata;
                8:                                                
                    acct_mem[08]  <= reglk_ctrl_i[1] ? acct_mem[08] : external_bus_io.wdata;
                9:                                                
                    acct_mem[09]  <= reglk_ctrl_i[7] ? acct_mem[09] : external_bus_io.wdata;
                10:                                                
                    acct_mem[10]  <= reglk_ctrl_i[7] ? acct_mem[10] : external_bus_io.wdata;
                11:                                                
                    acct_mem[11]  <= reglk_ctrl_i[7] ? acct_mem[11] : external_bus_io.wdata;
                default:
                    ;
            endcase
    end // always @ (posedge wb_clk_i)

//// Read side
always @(*)
    begin
        case(external_bus_io.addr[9:2])
            0:
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : acct_mem[0]; 
            1:                                    
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : acct_mem[1];
            2:                                    
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : acct_mem[2];
            3:                                    
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : acct_mem[3];
            4:                                    
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : acct_mem[4];
            5:                                    
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : acct_mem[5];
            6:                                    
                external_bus_io.rdata = reglk_ctrl_i[0] ? 'b0 : acct_mem[6];
            7:                                    
                external_bus_io.rdata = reglk_ctrl_i[0] ? 'b0 : acct_mem[7];
            8:                                    
                external_bus_io.rdata = reglk_ctrl_i[0] ? 'b0 : acct_mem[8];
            9:                                    
                external_bus_io.rdata = reglk_ctrl_i[6] ? 'b0 : acct_mem[9];
            10:                                   
                external_bus_io.rdata = reglk_ctrl_i[6] ? 'b0 : acct_mem[10];
            11:                                   
                external_bus_io.rdata = reglk_ctrl_i[6] ? 'b0 : acct_mem[11];
            default:
                external_bus_io.rdata = 32'b0;
        endcase
    end // always @ (*)


endmodule
