module redirect_mop #(
    parameter                   N_TARG_PORT    = 7,
    parameter                   AXI_DATA_W     = 64,
    parameter LOG_N_INIT = 2
)(
  input  logic                                                        clk,
    input  logic                                                          rst_n,
    input  logic [N_TARG_PORT-1:0] [AXI_DATA_W-1:0]                       wdata_i,
    input  logic [N_TARG_PORT-1:0]                                        wvalid_i,
  output logic [N_TARG_PORT-1:0]                                                         redirect_valid,
  output logic [N_TARG_PORT-1:0][LOG_N_INIT-1:0]                                         source_o,
  output logic [N_TARG_PORT-1:0][LOG_N_INIT-1:0]                                         target_o
  // output  logic [N_TARG_PORT-1:0]                                        wvalid_r_o
);
    
integer ii;
integer                                                                          source[N_TARG_PORT-1:0];
integer                                                                         target[N_TARG_PORT-1:0];
logic [N_TARG_PORT-1:0][1:0]                                                    redirect_start;

always @(posedge clk) begin
  for (ii=0; ii<N_TARG_PORT; ii=ii+1) begin
    if(rst_n == 1'b0)begin
       redirect_start[ii] = 0 ;
       target[ii]         = 0 ;
       source[ii]         = 0;
      //  wvalid_r_o[ii] = wvalid_i[ii];
       redirect_valid[ii] = 0;
    end
    else begin
      if(wdata_i[ii] == ariane_soc::ERROR_REDIRECT && wvalid_i[ii] == 1)begin
         redirect_start[ii] = 1;
         source[ii]         = 1;
         redirect_valid[ii] = 0;
        //  wvalid_r_o[ii] = 0;
        // wvalid_r_o[ii] = wvalid_i[ii];
      end
      else if (redirect_start[ii] == 1 && wvalid_i[ii] == 1) begin
        //  target[ii] = 1;
         target[ii] = wdata_i[ii][63:32];
         redirect_start[ii] = 0 ;
         redirect_valid[ii] = 1;
        //  wvalid_r_o[ii] = 0;
        // wvalid_r_o[ii] = wvalid_i[ii];
      end
      
      else if(wdata_i[ii] == ariane_soc::ERROR_REDIRECT_STOP && wvalid_i[ii] == 1)begin
         redirect_valid[ii] = 0;
         redirect_start[ii] = 0 ;
        //  wvalid_r_o[ii] = 0;
        // wvalid_r_o[ii] = wvalid_i[ii];
      end
      else begin
         target[ii] = target[ii];
         source[ii] = source[ii];
        //  wvalid_r_o[ii] = wvalid_i[ii];
         redirect_valid[ii] = redirect_valid[ii];
         redirect_start[ii] = redirect_start[ii];
      end
    end
  end
end

always @(*)begin
  for (ii=0; ii<N_TARG_PORT; ii=ii+1) begin
    source_o[ii] = source[ii];
    target_o[ii] = target[ii];
  end
end
endmodule