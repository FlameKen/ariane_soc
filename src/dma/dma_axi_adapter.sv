/* Copyright 2018 ETH Zurich and University of Bologna.
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the “License”); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * File:  axi_adapter.sv
 * Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
 * Date:   1.8.2018
 *
 * Description: Manages communication with the AXI Bus
 */


module dma_axi_adapter #(
    parameter int unsigned DATA_WIDTH            = 256,
    parameter int unsigned AXI_ID_WIDTH          = 10,  //,
    parameter AXI_ADDR_WIDTH = 64, 
    parameter AXI_BE_WIDTH = 8, 
    parameter AXI_LEN_WIDTH = 8, 
    parameter AXI_SIZE_WIDTH = 3  
)(
    input  logic                                        clk_i,  // Clock
    input  logic                                        rst_ni, // Asynchronous reset active low

    input  logic                                        req_i,
    input  logic                                        type_i,
    output logic                                        gnt_o,
    output logic [AXI_ID_WIDTH-1:0]                     gnt_id_o,
    input  logic [AXI_ADDR_WIDTH-1:0]                   addr_i,
    input  logic                                        we_i,
    input  logic [AXI_BE_WIDTH-1:0]                     be_i,
    input  logic [AXI_LEN_WIDTH-1:0]                    len_i, 
    input  logic [AXI_SIZE_WIDTH-1:0]                   size_i,
    input  logic [AXI_ID_WIDTH-1:0]                     id_i,
    // read port
    output logic                                        valid_o,
    output logic [AXI_ID_WIDTH-1:0]                     id_o,
    // AXI port
    output ariane_axi::req_t                            axi_req_o,
    input  ariane_axi::resp_t                           axi_resp_i
);

    enum logic [3:0] {
        IDLE, WAIT_B_VALID, WAIT_AW_READY, WAIT_LAST_W_READY, WAIT_LAST_W_READY_AW_READY, WAIT_AW_READY_BURST,
        WAIT_R_VALID, WAIT_R_VALID_MULTIPLE, COMPLETE_READ
    } state_q, state_d;

    // counter for AXI transfers
    logic [AXI_LEN_WIDTH-1:0] cnt_d, cnt_q;
    logic [(2**AXI_LEN_WIDTH)-1:0][63:0] mem; // used to store the data that needs to be transfered 
    logic [63:0] mem_wdata; 
    logic [AXI_LEN_WIDTH-1:0] mem_waddr; 
    logic mem_wen; 
    logic [AXI_ID_WIDTH-1:0]    id_d, id_q;
    logic [AXI_LEN_WIDTH-1:0]      index;

    always_comb begin : axi_fsm
        // Default assignments
        axi_req_o.aw_valid  = 1'b0;
        axi_req_o.aw.addr   = addr_i;
        axi_req_o.aw.prot   = 3'b0;
        axi_req_o.aw.region = 4'b0;
        axi_req_o.aw.len    = 8'b0;
        axi_req_o.aw.size   = size_i;
        axi_req_o.aw.burst  = (type_i == 1) ? 2'b00 :  2'b01;  // fixed size for single request and incremental transfer for everything else
        axi_req_o.aw.lock   = 1'b0;
        axi_req_o.aw.cache  = 4'b0;
        axi_req_o.aw.qos    = 4'b0;
        axi_req_o.aw.id     = id_i;
        axi_req_o.aw.atop   = '0; // currently not used

        axi_req_o.ar_valid  = 1'b0;
        axi_req_o.ar.addr   = addr_i; 
        axi_req_o.ar.prot   = 3'b0;
        axi_req_o.ar.region = 4'b0;
        axi_req_o.ar.len    = 8'b0;
        axi_req_o.ar.size   = size_i; 
        axi_req_o.ar.burst  = (type_i == 1) ? 2'b00 :  2'b01;  
        axi_req_o.ar.lock   = 1'b0;
        axi_req_o.ar.cache  = 4'b0;
        axi_req_o.ar.qos    = 4'b0;
        axi_req_o.ar.id     = id_i;

        axi_req_o.w_valid   = 1'b0;
        axi_req_o.w.data    = mem[0];
        axi_req_o.w.strb    = be_i;
        axi_req_o.w.last    = 1'b0;

        axi_req_o.b_ready   = 1'b0;
        axi_req_o.r_ready   = 1'b0;

        gnt_o         = 1'b0;
        gnt_id_o      = id_i;
        valid_o       = 1'b0;
        id_o          = axi_resp_i.r.id;

        state_d                 = state_q;
        cnt_d                   = cnt_q;
        id_d                    = id_q;
        index                   = '0;
        mem_wen                 = 1'b0; 

        case (state_q)

            IDLE: begin
                cnt_d = '0;
                // we have an incoming request
                if (req_i) begin
                    // is this a read or write?
                    // write
                    if (we_i) begin
                        // the data is valid
                        axi_req_o.aw_valid = 1'b1;
                        axi_req_o.w_valid  = 1'b1;
                        // its a single write
                        if (type_i == 1) begin
                            // only a single write so the data is already the last one
                            axi_req_o.w.last   = 1'b1;
                            // single req can be granted here
                            gnt_o = axi_resp_i.aw_ready & axi_resp_i.w_ready;
                            case ({axi_resp_i.aw_ready, axi_resp_i.w_ready})
                                2'b11: state_d = WAIT_B_VALID;
                                2'b01: state_d = WAIT_AW_READY;
                                2'b10: state_d = WAIT_LAST_W_READY;
                                default: state_d = IDLE;
                            endcase

                        // its a request for multiple blocks
                        end else begin
                            axi_req_o.aw.len = len_i; // number of bursts to do
                            axi_req_o.w.data = mem[0];
                            axi_req_o.w.strb = be_i;

                            if (axi_resp_i.w_ready)
                                cnt_d = len_i - 1;
                            else
                                cnt_d = len_i;

                            case ({axi_resp_i.aw_ready, axi_resp_i.w_ready})
                                2'b11: state_d = WAIT_LAST_W_READY;
                                2'b01: state_d = WAIT_LAST_W_READY_AW_READY;
                                2'b10: state_d = WAIT_LAST_W_READY;
                                default:;
                            endcase
                        end
                    // read
                    end else begin

                        axi_req_o.ar_valid = 1'b1;
                        gnt_o = axi_resp_i.ar_ready;
                        if (type_i != 1) begin
                            axi_req_o.ar.len = len_i;
                            cnt_d = len_i;
                        end

                        if (axi_resp_i.ar_ready) begin
                            state_d = (type_i == 1) ? WAIT_R_VALID : WAIT_R_VALID_MULTIPLE;
                        end
                    end
                end
            end

            // ~> from single write
            WAIT_AW_READY: begin
                axi_req_o.aw_valid = 1'b1;

                if (axi_resp_i.aw_ready) begin
                    gnt_o   = 1'b1;
                    state_d = WAIT_B_VALID;
                end
            end

            // ~> we need to wait for an aw_ready and there is at least one outstanding write
            WAIT_LAST_W_READY_AW_READY: begin
                axi_req_o.w_valid  = 1'b1;
                axi_req_o.w.last   = (cnt_q == '0);
                if (type_i == 1) begin
                    axi_req_o.w.data   = mem[0];
                    axi_req_o.w.strb   = be_i;
                end else begin
                    axi_req_o.w.data   = mem[len_i-cnt_q];
                    axi_req_o.w.strb   = be_i;
                end
                axi_req_o.aw_valid = 1'b1;
                // we are here because we want to write
                axi_req_o.aw.len   = len_i;
                // we got an aw_ready
                case ({axi_resp_i.aw_ready, axi_resp_i.w_ready})
                    // we got an aw ready
                    2'b01: begin
                        // are there any outstanding transactions?
                        if (cnt_q == 0)
                            state_d = WAIT_AW_READY_BURST;
                        else // yes, so reduce the count and stay here
                            cnt_d = cnt_q - 1;
                    end
                    2'b10: state_d = WAIT_LAST_W_READY;
                    2'b11: begin
                        // we are finished
                        if (cnt_q == 0) begin
                            state_d  = WAIT_B_VALID;
                            gnt_o    = 1'b1;
                        // there are outstanding transactions
                        end else begin
                            state_d = WAIT_LAST_W_READY;
                            cnt_d = cnt_q - 1;
                        end
                    end
                    default:;
               endcase

            end

            // ~> all data has already been sent, we are only waiting for the aw_ready
            WAIT_AW_READY_BURST: begin
                axi_req_o.aw_valid = 1'b1;
                axi_req_o.aw.len   = len_i;

                if (axi_resp_i.aw_ready) begin
                    state_d  = WAIT_B_VALID;
                    gnt_o    = 1'b1;
                end
            end

            // ~> from write, there is an outstanding write
            WAIT_LAST_W_READY: begin
                axi_req_o.w_valid = 1'b1;

                if (type_i != 1) begin
                    axi_req_o.w.data   = mem[len_i-cnt_q];
                    axi_req_o.w.strb   = be_i;
                end

                // this is the last write
                if (cnt_q == '0) begin
                    axi_req_o.w.last = 1'b1;
                    if (axi_resp_i.w_ready) begin
                        state_d  = WAIT_B_VALID;
                        gnt_o    = 1'b1;
                    end
                end else if (axi_resp_i.w_ready) begin
                    cnt_d = cnt_q - 1;
                end
            end

            // ~> finish write transaction
            WAIT_B_VALID: begin
                axi_req_o.b_ready = 1'b1;
                id_o = axi_resp_i.b.id;

                // Write is valid
                if (axi_resp_i.b_valid) begin
                    state_d = IDLE;
                    valid_o = 1'b1;
                end
            end

            //  read
            WAIT_R_VALID_MULTIPLE, WAIT_R_VALID: begin
                index = len_i-cnt_q;

                // reads are always wrapping here
                axi_req_o.r_ready = 1'b1;
                // this is the first read 
                if (axi_resp_i.r_valid) begin

                    // this is the last read
                    if (axi_resp_i.r.last) begin
                        id_d    = axi_resp_i.r.id;
                        state_d = COMPLETE_READ;
                    end

                    // save the word
                    if (state_q == WAIT_R_VALID_MULTIPLE) begin
                        mem_wen = 1'b1; 
                        mem_waddr = index; 
                        mem_wdata = axi_resp_i.r.data; 

                    end else begin
                        mem_wen = 1'b1; 
                        mem_waddr = 'b0; 
                        mem_wdata = axi_resp_i.r.data; 
                    end

                    // Decrease the counter
                    cnt_d = cnt_q - 1;
                end
            end
            // ~> read is complete
            COMPLETE_READ: begin
                valid_o = 1'b1;
                state_d = IDLE;
                id_o    = id_q;
            end
        endcase
    end

    // ----------------
    // Registers
    // ----------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            // start in flushing state and initialize the memory
            state_q       <= IDLE;
            cnt_q         <= '0;
            id_q          <= '0;
        end else begin
            state_q       <= state_d;
            cnt_q         <= cnt_d;
            if (mem_wen)
                mem[mem_waddr]  <= mem_wdata;
            id_q          <= id_d;
        end
    end

endmodule
