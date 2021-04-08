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
  parameter  AXI_DATA_W = 64,
  parameter N_REGION = 3,
  parameter N_SLAVE_PORT = 18,
  parameter LOG_N_INIT = 2
)
(
  input  logic                                                        clk,
  input  logic                                                        rst_n,
  input  logic [N_REGION-1:0][N_INIT_PORT-1:0][ADDR_WIDTH-1:0]        START_ADDR_i,
  input  logic [N_REGION-1:0][N_INIT_PORT-1:0][ADDR_WIDTH-1:0]        END_ADDR_i,
  input  logic [N_REGION-1:0][N_INIT_PORT-1:0]                        enable_region_i,
  input  logic  [ariane_soc::NB_PERIPHERALS-1 :0]                      redirection_idle,
  input  logic [ADDR_WIDTH-1:0]                                       awaddr_i,
  input  logic [ADDR_WIDTH-1:0]                                       araddr_i,
  input  logic                                                select,
  input  logic [LOG_N_INIT-1:0]                                source,
   input  logic [N_SLAVE_PORT-1:0] [AXI_DATA_W-1:0]                      wdata_i,
   input  logic [N_SLAVE_PORT-1:0]                                       wvalid_i,
   input logic [ariane_soc::NB_PERIPHERALS-1 :0]  valid_i,
   output logic [ariane_soc::NB_PERIPHERALS-1 :0]  valid_o,
  input  logic [LOG_N_INIT-1:0]                                target,
  output logic [N_INIT_PORT-1:0][LOG_N_INIT-1:0]                change_q
  // output  logic [N_REGION-1:0][N_INIT_PORT-1:0]                match_region_int_o_ar,
  // output  logic [N_REGION-1:0][N_INIT_PORT-1:0]                match_region_int_o_aw
);
logic [N_INIT_PORT-1:0][LOG_N_INIT-1:0] change;
logic [N_INIT_PORT-1:0][LOG_N_INIT-1:0] change_n;
logic [LOG_N_INIT-1:0]                  temp_IP;
assign change_q = change;

always @ (*)begin
  for(integer i=0;i<N_INIT_PORT;i++)
    begin:for4
      change_n[i] = change[i];
      temp_IP = 0;
    end
    if(select)
    begin
      if(redirection_idle[target] == 1)
          change_n[source] = target;
      else  begin
        temp_IP = target;
      end

    end
end
always_ff @(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    for(integer i=0;i<N_INIT_PORT;i++)begin
      change[i]  <= i;
    end
  end else begin
      for(integer i=0;i<N_INIT_PORT;i++)begin
        change[i]  <= change_n[i] ;
    end
  end
end
logic bool;
    always@(*)begin
        bool = 0;
        for(integer i = 0 ; i <ariane_soc::NB_PERIPHERALS;i++ )begin
            // if(bool == 0 && valid_i[i] == 1 && redirection_idle[target] == 1 )begin
            //cannot get target if valid_o = 0
            if(bool == 0 && valid_i[i] == 1 )begin
                valid_o[i] = 1;
                bool = 1;
            end
            else begin
                valid_o[i] = 0;
            end
        end
    end
endmodule

