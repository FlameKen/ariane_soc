// Copyright 2014-2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// ============================================================================= //
// Company:        Multitherman Laboratory @ DEIS - University of Bologna        //
//                    Viale Risorgimento 2 40136                                 //
//                    Bologna - fax 0512093785 -                                 //
//                                                                               //
// Engineer:       Igor Loi - igor.loi@unibo.it                                  //
//                                                                               //
//                                                                               //
// Additional contributions by:                                                  //
//                                                                               //
//                                                                               //
//                                                                               //
// Create Date:    01/02/2014                                                    //
// Design Name:    AXI 4 INTERCONNECT                                            //
// Module Name:    axi_address_decoder_AW                                        //
// Project Name:   PULP                                                          //
// Language:       SystemVerilog                                                 //
//                                                                               //
// Description:   Address decoder for the address write channel: Decoding        //
//                is performed on the address AR                                 //
//                                                                               //
// Revision:                                                                     //
// Revision v0.1 - 01/02/2014 : File Created                                     //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
// ============================================================================= //

module axi_address_decoder_AW
#(
    parameter  ADDR_WIDTH     = 32,
    parameter  N_INIT_PORT    = 8,
    parameter  LOG_N_INIT     = 3,
    parameter  N_REGION       = 2
)
(
    input  logic                                                        clk,
    input  logic                                                        rst_n,

    input  logic                                                        awvalid_i,
    input  logic [ADDR_WIDTH-1:0]                                       awaddr_i,
    output logic                                                        awready_o,

    output logic [N_INIT_PORT-1:0]                                      awvalid_o,
    input  logic [N_INIT_PORT-1:0]                                      awready_i,

    input  logic                                                        grant_FIFO_DEST_i,
    output logic [N_INIT_PORT-1:0]                                      DEST_o,
    output logic                                                        push_DEST_o,

    //Error Managment
    input  logic [N_REGION-1:0][N_INIT_PORT-1:0][ADDR_WIDTH-1:0]        START_ADDR_i,
    input  logic [N_REGION-1:0][N_INIT_PORT-1:0][ADDR_WIDTH-1:0]        END_ADDR_i,
    input  logic [N_REGION-1:0][N_INIT_PORT-1:0]                        enable_region_i,

    input  logic [N_INIT_PORT-1:0]                                      connectivity_map_i,

    output logic                                                        incr_req_o,
    input  logic                                                        full_counter_i,
    input  logic                                                        outstanding_trans_i,

    output logic                                                        error_req_o,
    input  logic                                                        error_gnt_i,

    output logic                                                        handle_error_o,
    input  logic                                                        wdata_error_completed_i,
    // input  logic [N_REGION-1:0][N_INIT_PORT-1:0]                      match_region_int,
    input logic [N_INIT_PORT-1:0][LOG_N_INIT-1:0]                       change_q,
    output logic                                                        sample_awdata_info_o
);

  logic [N_INIT_PORT-1:0]                                               match_region; // One of the slave or Error!!!
  logic [N_INIT_PORT:0]                                                 match_region_masked;
  logic [N_REGION-1:0][N_INIT_PORT-1:0]                                 match_region_int;
  logic [N_REGION-1:0][N_INIT_PORT-1:0]                                 match_region_int_out;
  logic [N_INIT_PORT-1:0][N_REGION-1:0]                                 match_region_rev;

  logic                                                                 awready_int;


  logic [N_INIT_PORT-1:0]                                               awvalid_int;


  logic                                                                 error_detected;
  logic                                                                 local_increm;
  logic [ADDR_WIDTH-1:0] test_waddr;
  logic test;


  assign DEST_o      = match_region[N_INIT_PORT-1:0];
  assign push_DEST_o = |(awvalid_i & awready_o) & ~error_detected;

  enum logic [1:0]      { OPERATIVE, COMPLETE_PENDING, ACCEPT_WDATA , COMPLETE_ERROR_RESP } CS, NS;


  // genvar i,j;
  // generate
    integer i,j;
    always@(*)begin

      // First calculate for each region where what slave ist matching
      // for(j=0;j<N_REGION;j++)
      // begin: for5
      //      for(i=0;i<N_INIT_PORT;i++)
      //      begin: for4
      //            match_region_int[j][i]  =  (enable_region_i[j][i] == 1'b1 ) ? (awaddr_i >= START_ADDR_i[j][i]) && (awaddr_i <= END_ADDR_i[j][i]) : 1'b0;
      //      end
      // end
      for(integer j=0;j<N_REGION;j++)
      begin: for1
          for(integer i=0;i<N_INIT_PORT;i++)
          begin:for2
              match_region_int[j][i] = 0;
          end
          for(integer i=0;i<N_INIT_PORT;i++)
          begin:for3
            if((awaddr_i >= START_ADDR_i[j][i]) && (awaddr_i <= END_ADDR_i[j][i]) && (enable_region_i[j][i] == 1'b1 ) )begin
              match_region_int[j][change_q[i]] = 1; 
            end
          end
    end
      // transpose the match_region_int bidimensional array
      for(j=0;j<N_INIT_PORT;j++)
      begin: for1
           for(i=0;i<N_REGION;i++)
           begin: for2
             match_region_rev[j][i] = match_region_int[i][j];
           end
      end


      //Or reduction
      for(i=0;i<N_INIT_PORT;i++)
      begin: for3
         match_region[i]  =  | match_region_rev[i];
      end


       match_region_masked[N_INIT_PORT-1:0] = match_region & connectivity_map_i;

      // if there are no moatches, then assert an error
       match_region_masked[N_INIT_PORT] = ~(|match_region_masked[N_INIT_PORT-1:0]);
    end
  // endgenerate
//   swap
// #(
//   .ADDR_WIDTH(ADDR_WIDTH),
//   .N_INIT_PORT(N_INIT_PORT),
//   .N_REGION(N_REGION),
//   .LOG_N_INIT(LOG_N_INIT)
// )
// i_swap_n
// (
//   .clk(clk),
//   .rst_n(rst_n),
//   .START_ADDR_i(START_ADDR_i),
//   .END_ADDR_i(END_ADDR_i),
//   .enable_region_i(enable_region_i),
//   .awaddr_i(awaddr_i),
//   .select(redirect_valid_r),
//   .source(source_r),
//   .target(target_r),
//   .match_region_int_o(match_region_int)
// );
  



  always_comb
  begin
      // if(awaddr_i >=64'h9000 && awaddr_i < 64'h10000)
      //   test = 1;
      // else 
      //   test = 0;
      if(grant_FIFO_DEST_i == 1'b1)
      begin
            if(awvalid_i)
            begin
                {error_detected,awvalid_int} = {N_INIT_PORT+1{awvalid_i}} & match_region_masked;
            end
            else
            begin
                awvalid_int      = '0;
                error_detected = 1'b0;
            end

            awready_int = |({error_gnt_i,awready_i} & match_region_masked);
      end
      else
      begin
          awvalid_int       = '0;
          awready_int     = 1'b0;
          error_detected  = 1'b0; //FIXME
      end

  end



  // --------------------------------------------------------------------------------------------------------------------------------------------------//
  // ERROR MANAGMENT BLOCK - STALL in case of ERROR, WAIT untill there are no more pending transactions then deliver the error req to the BR ALLOCATOR.
  // --------------------------------------------------------------------------------------------------------------------------------------------------//
  always_ff @(posedge clk, negedge rst_n)
  begin
    if(rst_n == 1'b0)
    begin
        CS <= OPERATIVE;
    end
    else
    begin
        CS <= NS;
    end
  end

  assign local_increm =  |(awvalid_o & awready_i);

  always_comb
  begin
      awready_o            = 1'b0;
      handle_error_o       = 1'b0;
      sample_awdata_info_o = 1'b0;
      error_req_o          = 1'b0;
      incr_req_o           = 1'b0;
      awvalid_o            = '0;

      case(CS)
          OPERATIVE:
          begin
              handle_error_o  = 1'b0;
              incr_req_o =   local_increm;

              if(error_detected)
              begin
                NS = COMPLETE_PENDING;
                awready_o = 1'b1;
                sample_awdata_info_o = 1'b1;
                awvalid_o            = '0;
              end
              else
              begin
                NS = OPERATIVE;
                awready_o = awready_int;
                awvalid_o = awvalid_int;
              end
          end

          COMPLETE_PENDING:
          begin

              awready_o     = 1'b0;
              handle_error_o  = 1'b0;

              if(outstanding_trans_i)
              begin
                NS        = COMPLETE_PENDING;
                awready_o = 1'b0;
              end
              else
              begin // There are no pending transactions
                awready_o = 1'b0;
                NS = ACCEPT_WDATA;
              end
          end


          ACCEPT_WDATA :
          begin
              awready_o     = 1'b0;
              handle_error_o  = 1'b1;

              if(wdata_error_completed_i)
                NS = COMPLETE_ERROR_RESP;
              else
                NS = ACCEPT_WDATA;
          end


          COMPLETE_ERROR_RESP :
          begin
              handle_error_o  = 1'b0;
              error_req_o     = 1'b1;

              if(error_gnt_i)
                NS = OPERATIVE;
              else
                NS = COMPLETE_ERROR_RESP;
          end


          default :
          begin
              NS              = OPERATIVE;
              awready_o       = awready_int;
              handle_error_o  = 1'b0;
          end

      endcase
  end

endmodule
