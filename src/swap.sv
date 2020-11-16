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
logic bool;
integer t,s;
integer i,j;
always @ (*)begin
      for(j=0;j<N_REGION;j++)
      begin
        bool = 0;
        for(i=0;i<N_INIT_PORT;i++)
        begin
          if(1 == source[i]&& select[i])begin
            match[j][i]  =  0;
            s = i;
            t = target[i];
            bool = 1;
          end
          else begin
            match[j][i]  =  match_region_int_i[j][i];
          end
        end
        if(bool == 1)
          match[j][t] = (match_region_int_i[j][s]) ? 1 : match[j][t];
      end

end
always @ (*)begin
    for(i=0;i<N_INIT_PORT;i++)
    begin
      for(j=0;j<N_REGION;j++)
      begin
        match_region_int_o[j][i] = match[j][i];
      end
    end
end
endmodule

module swap_r
#(
  parameter  N_INIT_PORT = 8,
  parameter N_REGION = 3,
  parameter LOG_N_INIT = 2
)
(
  // input  logic                                                        clk,
  // input  logic                                                        rst_n,
  input  logic [N_REGION-1:0][N_INIT_PORT-1:0]                 match_region_int_i,
  input  logic                                                select,
  input  logic [LOG_N_INIT-1:0]                                source,
  input  logic [LOG_N_INIT-1:0]                                target,
  output  logic [N_REGION-1:0][N_INIT_PORT-1:0]                match_region_int_o
);
logic [N_REGION-1:0][N_INIT_PORT-1:0]   match;
logic bool;
integer t,s;
integer i,j;
always @ (*)begin
      for(j=0;j<N_REGION;j++)
      begin
        for(i = 0 ; i < N_INIT_PORT;i++)
        begin
          if(select)
          begin
            if(i == target)
              match[j][i] = (match_region_int_i[j][source]);
            else if( i == source)
              match[j][i] = 0;
            else 
              match[j][i] = (match_region_int_i[j][i]);
          end
          else begin
            match[j][i] = (match_region_int_i[j][i]);
          end
        end
      end
end
always @ (*)begin
    for(i=0;i<N_INIT_PORT;i++)
    begin
      for(j=0;j<N_REGION;j++)
      begin
        match_region_int_o[j][i] = match[j][i];
      end
    end
end
endmodule