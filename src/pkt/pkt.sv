 /*
 * Peripheral Key Table (PKT) takes the fuse mem index and returns the actual destination address
 * for that FUSE data
 */



module pkt (
   input  logic         clk_i,
   input  logic         rst_ni,
   input  logic         req_i,
   input  logic [31:0]  fuse_indx_i, // peripheral index of the key
   output logic [63:0]  pkey_loc_o // peripheral key location in ROM2 as the output
);

    parameter FUSE_MEM_SIZE = 34;

// Store dest address values here. 
    const logic [FUSE_MEM_SIZE-1:0][63:0] fuse_indx_mem = {
        // JTAG (only a place holder, JTAG key is not mapped to AXI mem)
        ariane_soc::JTAGKEY, 
        // Access control for master 2. First 4 bits for peripheral 0, next 4 for p1 and so on.
        ariane_soc::AcCt_M_22, 
        ariane_soc::AcCt_M_21, 
        ariane_soc::AcCt_M_20, 
        // Access control for master 1. First 4 bits for peripheral 0, next 4 for p1 and so on.
        ariane_soc::AcCt_M_12, 
        ariane_soc::AcCt_M_11, 
        ariane_soc::AcCt_M_10, 
        // Access control for master 0. First 4 bits for peripheral 0, next 4 for p1 and so on.
        ariane_soc::AcCt_M_02, 
        ariane_soc::AcCt_M_01, 
        ariane_soc::AcCt_M_00, 
        // SHA Key
        ariane_soc::SHAKey_5,
        ariane_soc::SHAKey_4,
        ariane_soc::SHAKey_3,
        ariane_soc::SHAKey_2,
        ariane_soc::SHAKey_1,
        ariane_soc::SHAKey_0,
        // AES Key 2
        ariane_soc::AESKey2_5,
        ariane_soc::AESKey2_4,
        ariane_soc::AESKey2_3,
        ariane_soc::AESKey2_2,
        ariane_soc::AESKey2_1,
        ariane_soc::AESKey2_0,   // address for LSB 32 bits
        // AES Key 1
        ariane_soc::AESKey1_5,
        ariane_soc::AESKey1_4,
        ariane_soc::AESKey1_3,
        ariane_soc::AESKey1_2,
        ariane_soc::AESKey1_1,
        ariane_soc::AESKey1_0,   // address for LSB 32 bits
        // AES Key 0
        ariane_soc::AESKey0_5,
        ariane_soc::AESKey0_4,
        ariane_soc::AESKey0_3,
        ariane_soc::AESKey0_2,
        ariane_soc::AESKey0_1,
        ariane_soc::AESKey0_0    // address for LSB 32 bits
    };

    logic [$clog2(FUSE_MEM_SIZE)-1:0] fuse_indx_q;
    
    always_ff @(posedge clk_i) begin
        if (req_i) begin
            fuse_indx_q <= fuse_indx_i[$clog2(FUSE_MEM_SIZE)-1:0];
        end
    end

    // this prevents spurious Xes from propagating into
    // the speculative fetch stage of the core
    assign pkey_loc_o = (fuse_indx_q < FUSE_MEM_SIZE) ? fuse_indx_mem[fuse_indx_q] : 64'hffffffff;


endmodule
