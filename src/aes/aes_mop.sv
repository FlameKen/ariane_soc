module aes_mop(
    clk_i,
    rst_ni,
    pt_i,
    ct_i,
    valid_i,
    valid_o,
    override
);
    input  logic                   clk_i;
    input  logic                   rst_ni;
    input  logic    [127:0]         pt_i;
    input  logic    [127:0]         ct_i;
    input  logic                    valid_i;
    output  logic                   valid_o;
    output logic                    override;

  logic     alarm;
  logic    [127:0]         test;
  assign  test = ct_i;
//   assign  test = pt_i;
always@(*)begin
    if(test == ct_i)begin
        valid_o = 0;
        override = 1;
        alarm = 1;
    end
    else begin
        alarm = 0;
        override = 0;
        valid_o = valid_i;
    end
end
endmodule