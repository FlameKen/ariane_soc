module swap
#(
  parameter  N_INIT_PORT = 8,
  parameter N_REGION = 3,
  parameter LOG_N_INIT = 2
)
(
  // input  logic                                                        clk,
  // input  logic                                                        rst_n,
  input  logic [N_REGION-1:0][N_INIT_PORT-1:0]                 match_region_int_i,
  input  logic [N_INIT_PORT-1:0]                                               select,
  input  logic [N_INIT_PORT-1:0][LOG_N_INIT-1:0]                                source,
  input  logic [N_INIT_PORT-1:0][LOG_N_INIT-1:0]                                target,
  output  logic [N_REGION-1:0][N_INIT_PORT-1:0]                match_region_int_o
);
logic [N_REGION-1:0][N_INIT_PORT-1:0]   match;
integer i,j;
always @ (*)begin
      for(j=0;j<N_REGION;j++)
      begin
           for(i=0;i<N_INIT_PORT;i++)
           begin
              if(i ==target[i])begin
                  match[j][i]  =  match_region_int_i[j][source[i]];
              end
              else if (i == source[i])begin
                 match[j][i]  =  0;
              end
              else begin
                  match[j][i]  =  match_region_int_i[j][i];
              end
           end
      end
end
always @ (*)begin
for(i=0;i<N_INIT_PORT;i++)
  begin
      if(select[i]) begin
        for(j=0;j<N_REGION;j++)
        begin
          match_region_int_o[j] = match[j];
        end
      end
      else begin
        match_region_int_o = match_region_int_i;
      end
  end
  
end
endmodule