 /*
 * ROM2: Which have all the keys.
 */

module rom2 #(
    parameter RomSize = 5  
)
(
   input  logic         clk_i,
   input  logic         rst_ni,
   input  logic [31:0]  addr_i,
   output logic [191:0]  rdata_o,
   output logic [RomSize-1:0][191:0]  key_reg // Ideally [1:0] should be [RomSize-1:0]. In this case RomSize is 2. 
);
    //localparam int RomSize = 4;

// Store key values here. // Replication of fuse. 
    const logic [RomSize-1:0][191:0] mem = {
        192'h00000000_00000000_00000000_00000000_ffffffff_ffffffff, // 4th location for Access control master 2. First 4 bits for peripheral 0, next 4 for p1 and so on.
        192'h00000000_00000000_00000000_00000000_000ff8f8_ff6fe00f, // 3rd location for Access control master 1. First 4 bits for peripheral 0, next 4 for p1 and so on.
        192'h00000000_00000000_00000000_00000000_000ffff8_ff6ff00f, // 2nd location for Access control master 0. First 4 bits for peripheral 0, next 4 for p1 and so on.
        192'h2b7e1516_28aed2a6_abf71588_09cf4f3c_2b7e1516_28aed2a6, // 1st location for JTAG
        192'h55555555_28aed2a6_abf71588_09cf4f3c_2b7e1516_28aed2a6  // oth location for AES
    };

// Secure registers. Key values copied from fuse to these registers on reset.
//    logic [RomSize-1:0][191:0] key_reg;
    
// On reset, key values will be copied to registers.
    always_ff @ (posedge clk_i) begin
        if (~rst_ni) begin
            key_reg <= mem;
        end 
    end
    // this prevents spurious Xes from propagating into
    // the speculative fetch stage of the core
    assign rdata_o = (addr_i < RomSize) ? key_reg[addr_i] : '0;


endmodule
