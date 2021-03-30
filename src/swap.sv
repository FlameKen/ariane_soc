// module swap
// #(
//   parameter  N_INIT_PORT = 8,
//   parameter N_REGION = 3,
//   parameter LOG_N_INIT = 2
// )
// (
//   // input  logic                                                        clk,
//   // input  logic                                                        rst_n,
//   input  logic [N_REGION-1:0][N_INIT_PORT-1:0]                 match_region_int_i,
//   input  logic [N_INIT_PORT-1:0]                                               select,
//   input  logic [N_INIT_PORT-1:0][LOG_N_INIT-1:0]                                source,
//   input  logic [N_INIT_PORT-1:0][LOG_N_INIT-1:0]                                target,
//   output  logic [N_REGION-1:0][N_INIT_PORT-1:0]                match_region_int_o
// );
// logic [N_REGION-1:0][N_INIT_PORT-1:0]   match;
// logic bool;
// integer t,s;
// integer i,j;
// always @ (*)begin
//       for(j=0;j<N_REGION;j++)
//       begin
//         bool = 0;
//         for(i=0;i<N_INIT_PORT;i++)
//         begin
//           if(1 == source[i]&& select[i])begin
//             match[j][i]  =  0;
//             s = i;
//             t = target[i];
//             bool = 1;
//           end
//           else begin
//             match[j][i]  =  match_region_int_i[j][i];
//           end
//         end
//         if(bool == 1)
//           match[j][t] = (match_region_int_i[j][s]) ? 1 : match[j][t];
//       end

// end
// always @ (*)begin
//     for(i=0;i<N_INIT_PORT;i++)
//     begin
//       for(j=0;j<N_REGION;j++)
//       begin
//         match_region_int_o[j][i] = match[j][i];
//       end
//     end
// end
// endmodule

// module swap_r
// #(
//   parameter  N_INIT_PORT = 8,
//   parameter N_REGION = 3,
//   parameter LOG_N_INIT = 2
// )
// (
//   // input  logic                                                        clk,
//   // input  logic                                                        rst_n,
//   input  logic [N_REGION-1:0][N_INIT_PORT-1:0]                 match_region_int_i,
//   input  logic                                                select,
//   input  logic [LOG_N_INIT-1:0]                                source,
//   input  logic [LOG_N_INIT-1:0]                                target,
//   output  logic [N_REGION-1:0][N_INIT_PORT-1:0]                match_region_int_o
// );
// logic [N_REGION-1:0][N_INIT_PORT-1:0]   match;
// logic bool;
// integer t,s;
// integer i,j;
// always @ (*)begin
//       for(j=0;j<N_REGION;j++)
//       begin
//         for(i = 0 ; i < N_INIT_PORT;i++)
//         begin
//           if(select)
//           begin
//             if(i == target)
//               match[j][i] = (match_region_int_i[j][source]);
//             else if( i == source)
//               match[j][i] = 0;
//             else 
//               match[j][i] = (match_region_int_i[j][i]);
//           end
//           else begin
//             match[j][i] = (match_region_int_i[j][i]);
//           end
//         end
//       end
// end
// always @ (*)begin
//     for(i=0;i<N_INIT_PORT;i++)
//     begin
//       for(j=0;j<N_REGION;j++)
//       begin
//         match_region_int_o[j][i] = match[j][i];
//       end
//     end
// end
// endmodule
module swap
#(
  parameter  ADDR_WIDTH     = 32,
  parameter  N_INIT_PORT = 8,
  parameter N_REGION = 3,
  parameter LOG_N_INIT = 2
)
(
  input  logic                                                        clk,
  input  logic                                                        rst_n,
  input  logic [N_REGION-1:0][N_INIT_PORT-1:0][ADDR_WIDTH-1:0]        START_ADDR_i,
  input  logic [N_REGION-1:0][N_INIT_PORT-1:0][ADDR_WIDTH-1:0]        END_ADDR_i,
  input  logic [N_REGION-1:0][N_INIT_PORT-1:0]                        enable_region_i,
  input  logic [ADDR_WIDTH-1:0]                                       awaddr_i,
  input  logic                                                select,
  input  logic [LOG_N_INIT-1:0]                                source,
  input  logic [LOG_N_INIT-1:0]                                target,
  output  logic [N_REGION-1:0][N_INIT_PORT-1:0]                match_region_int_o
);
logic [N_INIT_PORT-1:0][LOG_N_INIT-1:0] change_q;
logic [N_INIT_PORT-1:0][LOG_N_INIT-1:0] change_n;
// integer i,j;
always@(*) begin
  for(integer j=0;j<N_REGION;j++)
    begin: for1
          for(integer i=0;i<N_INIT_PORT;i++)
          begin:for2
              match_region_int_o[j][i] = 0;
          end
          for(integer i=0;i<N_INIT_PORT;i++)
          begin:for3
            if((awaddr_i >= START_ADDR_i[j][i]) && (awaddr_i <= END_ADDR_i[j][i]) && (enable_region_i[j][i] == 1'b1 ) )begin
              match_region_int_o[j][change_q[i]] = 1; 
            end
          end
    end
end
always @ (*)begin
  for(integer i=0;i<N_INIT_PORT;i++)
    begin:for4
      change_n[i] = change_q[i];
    end
    if(select)
    begin
      change_n[source] = target;
    end
end
always_ff @(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    for(integer i=0;i<N_INIT_PORT;i++)begin
      change_q[i]  <= i;
    end
  end else begin
      for(integer i=0;i<N_INIT_PORT;i++)begin
        change_q[i]  <= change_n[i] ;
    end
  end
end
endmodule
