// Wrapper for sha_256

module sha256_wrapper #(
    parameter int ADDR_WIDTH         = 32,   // width of external address bus
    parameter int DATA_WIDTH         = 32   // width of external data bus
)(
           clk_i,
           rst_ni,
           reglk_ctrl_i,
           external_bus_io
       );

    input  logic                   clk_i;
    input  logic                   rst_ni;
    input  logic [7 :0]            reglk_ctrl_i; // register lock values
    REG_BUS.in                     external_bus_io;

// internal signals


// Internal registers
reg newMessage_r, startHash_r;
logic startHash;
logic newMessage;
logic [31:0] data [0:15];
logic [511:0] bigData; 
logic [255:0] hash;
logic ready;
logic hashValid;


assign external_bus_io.ready = 1'b1;
assign external_bus_io.error = 1'b0;

assign bigData = {data[15], data[14], data[13], data[12], data[11], data[10], data[9], data[8], data[7], data[6], data[5], data[4], data[3], data[2], data[1], data[0]};
// Implement SHA256 I/O memory map interface
// Write side
always @(posedge clk_i)
    begin
        if(~rst_ni)
        // if(~reset)
            begin
                startHash <= 0;
                newMessage <= 0;
                data[0] <= 0;
                data[1] <= 0;
                data[2] <= 0;
                data[3] <= 0;
                data[4] <= 0;
                data[5] <= 0;
                data[6] <= 0;
                data[7] <= 0;
                data[8] <= 0;
                data[9] <= 0;
                data[10] <= 0;
                data[11] <= 0;
                data[12] <= 0;
                data[13] <= 0;
                data[14] <= 0;
                data[15] <= 0;
            end
        else if(external_bus_io.write)
            begin

                // Generate a registered versions of startHash and newMessage
                startHash_r         <= startHash;
                newMessage_r        <= newMessage;

                case(external_bus_io.addr[6:2])
                    0:
                        begin
                            startHash <= reglk_ctrl_i[1] ? startHash : external_bus_io.wdata[0];
                            newMessage <= reglk_ctrl_i[1] ? newMessage : external_bus_io.wdata[1];
                        end
                    1:
                        data[0] <= reglk_ctrl_i[3] ? data[0] : external_bus_io.wdata;
                    2:                                        
                        data[1] <= reglk_ctrl_i[3] ? data[1] : external_bus_io.wdata;
                    3:                                        
                        data[2] <= reglk_ctrl_i[3] ? data[2] : external_bus_io.wdata;
                    4:                                        
                        data[3] <= reglk_ctrl_i[3] ? data[3] : external_bus_io.wdata;
                    5:                                        
                        data[4] <= reglk_ctrl_i[3] ? data[4] : external_bus_io.wdata;
                    6:                                         
                        data[5] <= reglk_ctrl_i[3] ? data[5] : external_bus_io.wdata;
                    7:
                        data[6] <= reglk_ctrl_i[3] ? data[6] : external_bus_io.wdata;
                    8:                                        
                        data[7] <= reglk_ctrl_i[3] ? data[7] : external_bus_io.wdata;
                    9:                                        
                        data[8] <= reglk_ctrl_i[3] ? data[8] : external_bus_io.wdata;
                    10:                                       
                        data[9] <= reglk_ctrl_i[3] ? data[9] : external_bus_io.wdata;
                    11:                                       
                        data[10] <= reglk_ctrl_i[3] ? data[10] : external_bus_io.wdata;
                    12:                                        
                        data[11] <= reglk_ctrl_i[3] ? data[11] : external_bus_io.wdata;
                    13:
                        data[12] <= reglk_ctrl_i[3] ? data[12] : external_bus_io.wdata;
                    14:                                        
                        data[13] <= reglk_ctrl_i[3] ? data[13] : external_bus_io.wdata;
                    15:                                        
                        data[14] <= reglk_ctrl_i[3] ? data[14] : external_bus_io.wdata;
                    16:                                         
                        data[15] <= reglk_ctrl_i[3] ? data[15] : external_bus_io.wdata;
                    default:
                        ;
                endcase
            end
    end

// Implement SHA256 I/O memory map interface
// Read side
always @(*)
    begin
        case(external_bus_io.addr[6:2])
            0:
                external_bus_io.rdata = reglk_ctrl_i[0] ? 'b0 : {31'b0, ready};
            1:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[0];
            2:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[1];
            3:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[2];
            4:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[3];
            5:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[4];
            6:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[5];
            7:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[6];
            8:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[7];
            9:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[8];
            10:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[9];
            11:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[10];
            12:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[11];
            13:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[12];
            14:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[13];
            15:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[14];
            16:
                external_bus_io.rdata = reglk_ctrl_i[2] ? 'b0 : data[15];
            17:
                external_bus_io.rdata = reglk_ctrl_i[0] ? 'b0 : {31'b0, hashValid};
            18:
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : hash[31:0];
            19:                                                 
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : hash[63:32];
            20:                                                 
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : hash[95:64];
            21:                                                 
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : hash[127:96];
            22:                                                 
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : hash[159:128];
            23:                                                 
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : hash[191:160];
            24:                                                 
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : hash[223:192];
            25:                                                 
                external_bus_io.rdata = reglk_ctrl_i[4] ? 'b0 : hash[255:224];
            default:
                external_bus_io.rdata = 32'b0;
        endcase
    end

sha256 sha256_1(
           .clk(clk_i),
            .rst(rst_ni),
           .init(startHash && ~startHash_r),
           .next(newMessage && ~newMessage_r),
           .block(bigData),
           .digest(hash),
           .digest_valid(hashValid),
           .ready(ready)
       );

endmodule
