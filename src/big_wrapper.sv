module big_wrapper #(
    parameter LOG_N_INIT = 3,
    parameter int ADDR_WIDTH         = 32,   // width of external address bus
    parameter int DATA_WIDTH         = 32   // width of external data bus
)(
           input  logic clk_i,
           input  logic rst_ni,
           REG_BUS.in reg_bus_mop,
           REG_BUS.in reg_bus_aes,
    output logic [LOG_N_INIT-1:0]              MoP_request     ,
    output logic [LOG_N_INIT-1:0]              MoP_receive     ,
    output logic [ariane_soc::NB_PERIPHERALS-1 :0]  valid_i,
    input logic [ariane_soc::NB_PERIPHERALS-1 :0]  valid_o
       );

logic [LOG_N_INIT-1:0] request[ariane_soc::NB_PERIPHERALS-1 :0];
logic [LOG_N_INIT-1:0] receive[ariane_soc::NB_PERIPHERALS-1 :0];
logic [8*ariane_soc::NB_PERIPHERALS-1 :0]   reglk_ctrl; // Access control values
logic [ariane_soc::NB_PERIPHERALS-1 :0]   load_ctrl; // Access control values
logic [7:0] instrut_value;
genvar i;
generate
    for(i = 0 ; i < ariane_soc::NB_PERIPHERALS; i++)begin: for1
        if(i != 5 && i!= 16)begin
            assign request[i] = 0;
            assign receive[i] = 0;
            // assign redirect_o[i] = 0;
        end
    end
assign MoP_request = request.sum();
assign MoP_receive = receive.sum();
    

endgenerate
mop_wrapper #(
        .LOG_N_INIT(LOG_N_INIT)
    ) i_mop_wrapper (
        .clk_i              ( clk_i             ),
        .rst_ni             ( rst_ni            ),
        .reglk_ctrl_i       ( TEST_SIGNAL ),
        .request            (request[ariane_soc::MOP]),
        .receive            (receive[ariane_soc::MOP]),
        .valid_i            (valid_o[ariane_soc::MOP]),
        .valid_o            (valid_i[ariane_soc::MOP]),
        .instrut_value      (instrut_value),
        .load_ctrl          (load_ctrl),
        .external_bus_io    ( reg_bus_mop       )
    );
// aes_wrapper #(
//         .LOG_N_INIT(LOG_N_INIT)
//     ) i_aes_wrapper (
//         .clk_i              ( clk_i                  ),
//         .rst_ni             ( rst_ni                 ),
//         .key_in             ( aes_key_in             ),
//         .reglk_ctrl_i       ( reglk_ctrl[8*ariane_soc::AES+8-1:8*ariane_soc::AES] ),
//         .testCycle          (testCycle),
//         .request            (request[ariane_soc::AES]),
//         .receive            (receive[ariane_soc::AES]),
//         .valid_i            (valid_o[ariane_soc::AES]),
//         .valid_o            (valid_i[ariane_soc::AES]),
//         .instrut_value      (instrut_value),
//         .load_ctrl          ( load_ctrl),
//         .external_bus_io    ( reg_bus_aes            )
//     );
MOP_BUS mop_bus_aes();
str_to_mop i_str_to_mop_aes(
        .request            (request[ariane_soc::AES]),
        .receive            (receive[ariane_soc::AES]),
        .valid_i            (valid_o[ariane_soc::AES]),
        .valid_o            (valid_i[ariane_soc::AES]),
        .instrut_value      (instrut_value),
        .load_ctrl          ( load_ctrl),
        .change             ( change),
        .mop_o              ( mop_bus_aes)
    );
    aes_wrapper #(
        .LOG_N_INIT(LOG_N_INIT)
    ) i_aes_wrapper (
        .clk_i              ( clk_i                  ),
        .rst_ni             ( rst_ni                 ),
        .key_in             ( aes_key_in             ),
        .reglk_ctrl_i       ( reglk_ctrl[8*ariane_soc::AES+8-1:8*ariane_soc::AES] ),
        .testCycle          (testCycle),
        // .request            (request[ariane_soc::AES]),
        // .receive            (receive[ariane_soc::AES]),
        // .valid_i            (valid_o[ariane_soc::AES]),
        // .valid_o            (valid_i[ariane_soc::AES]),
        // .instrut_value      (instrut_value),
        // .load_ctrl          ( load_ctrl),
        .mop_bus_io         ( mop_bus_aes),
        .external_bus_io    ( reg_bus_aes            )
    );
endmodule