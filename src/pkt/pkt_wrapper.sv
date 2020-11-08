// Description: Wrapper for the PKT.
//


module pkt_wrapper #(
    parameter int ADDR_WIDTH         = 32,   // width of external address bus
    parameter int DATA_WIDTH         = 32   // width of external data bus
)(
           clk_i,
           rst_ni,
           fuse_req_o,
           fuse_addr_o,
           fuse_rdata_i,
           external_bus_io
       );

    parameter FUSE_MEM_SIZE = 34;

    input  logic                   clk_i;
    input  logic                   rst_ni;
    output logic                   fuse_req_o;
    output logic [31:0]            fuse_addr_o;
    input  logic [31:0]            fuse_rdata_i;
    REG_BUS.in                     external_bus_io;

// internal signals

wire [63:0] pkey_loc; 


assign external_bus_io.ready = 1'b1;
assign external_bus_io.error = 1'b0;

///////////////////////////////////////////////////////////////////////////
// Implement APB I/O map to PKT interface
// Write side
always @(posedge clk_i)
    begin
        if(~rst_ni)
            begin
                fuse_req_o <= 0;
                fuse_addr_o <= 0;
            end
        else if(external_bus_io.write)
            case(external_bus_io.addr[6:2])
                0:
                    fuse_req_o  <= external_bus_io.wdata[0];
                1:
                    fuse_addr_o <= external_bus_io.wdata;
                default:
                    ;
            endcase
    end // always @ (posedge wb_clk_i)

//// Read side
always @(*)
    begin
        case(external_bus_io.addr[6:2])
            0:
                external_bus_io.rdata = {31'b0, fuse_req_o};
            1:
                external_bus_io.rdata = fuse_addr_o;
            2:
                external_bus_io.rdata = pkey_loc[63:32];
            3:
                external_bus_io.rdata = pkey_loc[31:0];
            4:
                external_bus_io.rdata = fuse_rdata_i;
            default:
                external_bus_io.rdata = 32'b0;
        endcase
    end // always @ (*)

pkt # (
        .FUSE_MEM_SIZE(FUSE_MEM_SIZE)
    ) i_pkt(
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .req_i(1'b1),
            .fuse_indx_i(fuse_addr_o),
            .pkey_loc_o(pkey_loc)
        );

endmodule
