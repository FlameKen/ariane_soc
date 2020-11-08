module aes2_wrapper #(
    parameter int ADDR_WIDTH         = 32,   // width of external address bus
    parameter int DATA_WIDTH         = 32   // width of external data bus
)(
           clk_i,
           rst_ni,
           external_bus_io
       );

    input  logic                   clk_i;
    input  logic                   rst_ni;
    REG_BUS.in                     external_bus_io;

// internal signals

logic start;
// internal signals - sc456
logic [31:0] firmware [127:0];
// logic [31:0] test [7:0];
logic [31:0]reg_address;
logic [31:0]reg_data;

logic [31:0] storage;
logic [31:0] out_wdata;
logic [31:0] test_addr;

// firmware[1] : address firmware[2] : data IP transfer itself
assign test_addr = (firmware[1] - ariane_soc::AES2Base);
assign external_bus_io.ready = 1'b1;
assign external_bus_io.error = 1'b0;

///////////////////////////////////////////////////////////////////////////
// Implement APB I/O map to AES interface
// Write side
always @(posedge clk_i)
    begin
        if(~rst_ni)
            begin
                start <= 0;
                storage <= 0;
                reg_address <= 0;
                out_wdata <=0;
                reg_data <= 0;
                for(integer i = 0 ;i< 127;i=i+1)
                begin
                    firmware[i]<=0;
                end

            end
        else if(external_bus_io.write)
        begin
            if(external_bus_io.addr[8:2] == 2)
            begin
                reg_data <= external_bus_io.wdata;
                start <=1;
            end
            firmware[external_bus_io.addr[8:2]]<=external_bus_io.wdata;
        end
    end // always @ (posedge wb_clk_i)

always @(*)
    begin
            if(start == 1)
            begin
                firmware[test_addr[8:2]] = firmware[2];
                reg_address = reg_data;
            end
            external_bus_io.rdata = firmware[external_bus_io.addr[8:2]];
        
    end // always @ (*)

// newmop mop1 (   
//                 .clk(clk_i),
//                 .reset(rst_ni),
//                 .i_addr({external_bus_io.addr}),
//                 .i_write(1'b0),
//                 .i_rdata(external_bus_io.rdata),
//                 .i_wdata(firmware[external_bus_io.addr[8:2]]),
//                 .i_valid(1'b1),
//                 .i_ready(external_bus_io.ready),
//                 .o_addr(firmware[102]),
//                 .o_write(storage[0]),
//                 .o_rdata(firmware[100]),
//                 .o_wdata(out_wdata),
//                 .o_valid(storage[1]),
//                 .o_ready(storage[2])

//             );
endmodule