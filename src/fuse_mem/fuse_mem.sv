 /*
 * FUSE mem: Which have all the secure data
 */

module fuse_mem 
(
   input  logic         clk_i,
   input  logic [31:0]  jtag_key_o,
   input  logic         req_i,
   input  logic [31:0]  addr_i,
   output logic [31:0]  rdata_o
);
    parameter  MEM_SIZE = 34;

// Store key values here. // Replication of fuse. 
    const logic [MEM_SIZE-1:0][31:0] mem = {
        // JTAG Key
        32'h28aed2a6,    
        // Access control for master 2. First 4 bits for peripheral 0, next 4 for p1 and so on.
        32'h00000000, 
        32'hffff88ff, 
        32'hff8fffff, 
        // Access control for master 1. First 4 bits for peripheral 0, next 4 for p1 and so on.
        32'h00000000, 
        32'h0fff88ff, 
        32'hff88ffff, 
        // Access control for master 0. First 4 bits for peripheral 0, next 4 for p1 and so on.
        32'h00000000, 
        32'h0ff888ff, 
        32'hff88ffff, 
        // SHA Key
        32'h28aed2a6,
        32'h28aed2a6,
        32'habf71588,
        32'h09cf4f3c,
        32'h2b7e1516,
        32'h28aed2a6,
        // AES Key 2
        32'h28aed9a6,
        32'h207e1516,
        32'h09c94f3c,
        32'ha6f71558,
        32'h28aef2a6,
        32'h2b3e1216,    // LSB 32 bits
        // AES Key 1
        32'h28aed2a6,
        32'h2b7e1616,
        32'h09cf4f3c,
        32'habf51588,
        32'h23aed2a6,
        32'h2b7e1816,    // LSB 32 bits
        // AES Key 0
        32'h2b7e1516,    
        32'h28aed2a6,
        32'habf71588,
        32'h09cf4f3c,
        32'h2b7e1516,
        32'h28aed2a6    // LSB 32 bits
    };

    logic [$clog2(MEM_SIZE)-1:0] addr_q;
    
    always_ff @(posedge clk_i) begin
        if (req_i) begin
            addr_q <= addr_i[$clog2(MEM_SIZE)-1:0];
        end
    end

    // this prevents spurious Xes from propagating into
    // the speculative fetch stage of the core
    assign rdata_o = (addr_q < MEM_SIZE) ? mem[addr_q] : '0;

    assign jtag_key_o = mem[MEM_SIZE-1];  // jtag key is not a AXI mapped address space, so passing the value directly


endmodule
