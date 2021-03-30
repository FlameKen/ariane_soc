
module redirect_mop(
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic [ariane_soc::LOG_N_INIT-1 : 0]     target,
  input  logic [ariane_soc::LOG_N_INIT-1 : 0]     source,
  input logic                     override,
  input  logic                    valid_i,
  output logic [ariane_soc::LOG_N_INIT-1:0]   request,
  output logic [ariane_soc::LOG_N_INIT-1:0]   receive,
  output  logic                   valid_o
);
logic redirected;
  always@(*)begin
    if(~rst_ni)begin
        redirected = 0;
        request = 0;
        receive = 0;
    end
    else begin
        if(valid_i)begin
            request = source;
            receive = target;
            redirected = 1;
        end
        else begin
            request = 0;
            receive = 0;
            redirected = (redirected == 0) ? 0 : 1;
        end
    end
    
end
always @(posedge clk_i)begin
    if(override && valid_i == 0 && redirected == 0)
        valid_o  <= 1;

    else 
        valid_o <= 0 ;
end
endmodule
module load_instruction(
  input logic clk_i,
  input logic rst_ni,
  input  logic    [31:0]           instrut_value,
  input logic [ariane_soc::NB_PERIPHERALS-1 :0]   load_ctrl,
  input  logic [ariane_soc::LOG_N_INIT-1 : 0]     id,
  input   logic [1:0]                   change, 
  output logic ext_wr,
  output logic re_ext_wr,
  output  logic [10:0] ext_data_in,
  output  logic [19:0] ext_act_in,
  output  logic [17:0] re_ext_data_in,
  output logic [1:0]   re_ext_addr,
  output logic [2:0] ext_addr

);
localparam CTRL_IDLE = 'd0; 
localparam CTRL_START_LOAD = 'd1;
localparam CTRL_LOAD = 'd2; 
logic [3:0]instru_state;
logic [3:0] count;
logic [31:0] test_data;
logic [2:0] test_addr;
logic  test_wr;
assign ext_data_in = (change == 0)? test_data[10:0] : 0;
assign ext_act_in = (change == 1)? test_data[19:0] : 0;
assign re_ext_data_in = (change == 2)? test_data[17:0] : 0;
assign ext_addr = (change[1] == 0) ? test_addr : 0;
assign re_ext_addr = (change[1] == 1) ? test_addr[1:0] : 0;
assign ext_wr = (change[1] == 0) ? test_wr : 0;
assign re_ext_wr = (change[1] == 1) ? test_wr : 0;
always@(*)begin
    case (instru_state)
        CTRL_START_LOAD:
        begin
            if(load_ctrl[id] == 1)begin
                test_wr = 1;
                test_data = instrut_value;
                test_addr = count;
            end
            else begin
                test_wr = 0;
                test_data = 0;
                test_addr = 0;
            end
        end
        CTRL_LOAD: 
        begin
            test_wr = 0;
            test_data = 0;
            test_addr = 0;
        end
        default:
        begin
            test_wr = 0;
            test_data = 0;
            test_addr = 0;
        end

    endcase
end
always @(posedge clk_i)
begin
    if(~rst_ni)begin
        instru_state <= 1;
        count <=0;
    end
    else begin
      case (instru_state)
        CTRL_START_LOAD:
            begin
                if(load_ctrl[id] == 1)begin
                    count<=count + 1;
                end
                else begin
                  if(count == 8)
                        instru_state <= 2;
                end
            end
        CTRL_LOAD: 
            begin
                instru_state <= 1;
                count <=0;
            end
        endcase
    end
end
endmodule