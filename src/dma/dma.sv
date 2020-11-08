///////////////////////////////////////////
//
// File Name : dma.sv
//
// Notes: 
//  1) Common be to all blocks, can change in future
//     if needed
///////////////////////////////////////////

import ariane_pkg::*;
import ariane_axi::*;

module dma # (
    parameter CONF_START = 0, 
    parameter CONF_CLR_DONE = 1,
    parameter DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 64, 
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_LEN_WIDTH = 8, 
    parameter AXI_SIZE_WIDTH = 3, 
    parameter AXI_ID_WIDTH = 4
)
(   
    clk_i, 
    rst_ni, 
    config_i, 
    length_i, 
    source_addr_i, 
    dest_addr_i, 
    state_o,

    axi_ad_axi_req_o,
    axi_resp_i
     
); 

  //// parameters
  localparam AXI_BE_WIDTH = AXI_DATA_WIDTH/8; 
  localparam DMA_CTRL_WIDTH = 3; 

  localparam CTRL_IDLE = 'd0; 
  localparam CTRL_START_LOAD = 'd1;
  localparam CTRL_LOAD = 'd2; 
  localparam CTRL_START_STORE = 'd3;
  localparam CTRL_STORE = 'd4;
  localparam CTRL_DONE = 'd5;

  
  //// IOs
  input  wire clk_i;
  input  wire rst_ni; 
  input  wire [DATA_WIDTH-1:0] config_i; 
  input  wire [DATA_WIDTH-1:0] length_i;
  input  wire [DATA_WIDTH-1:0] source_addr_i; 
  input  wire [DATA_WIDTH-1:0] dest_addr_i; 
  output wire [DATA_WIDTH-1:0] state_o;
  
  output ariane_axi::req_t  axi_ad_axi_req_o;
  input  ariane_axi::resp_t axi_resp_i;

  //// Registers

  reg [DATA_WIDTH-1:0] config_d; 
  reg [DATA_WIDTH-1:0] length_d;
  reg [DATA_WIDTH-1:0] source_addr_d; 
  reg [DATA_WIDTH-1:0] dest_addr_d; 

  reg req_axi_ad_reg, req_axi_ad_new, req_axi_ad_en; 
  reg we_axi_ad_reg, we_axi_ad_new, we_axi_ad_en; 
  reg [AXI_ADDR_WIDTH-1:0] addr_axi_ad_reg, addr_axi_ad_new; 
  reg addr_axi_ad_en; 
  reg [AXI_BE_WIDTH-1:0] be_axi_ad_reg, be_axi_ad_new; 
  reg be_axi_ad_en; 
  reg [AXI_LEN_WIDTH-1:0] len_axi_ad_reg, len_axi_ad_new; 
  reg len_axi_ad_en; 
  reg [AXI_SIZE_WIDTH-1:0] size_axi_ad_reg, size_axi_ad_new; 
  reg size_axi_ad_en; 
  reg type_axi_ad_reg, type_axi_ad_new, type_axi_ad_en; 
  reg [AXI_ID_WIDTH-1:0] id_axi_ad_reg, id_axi_ad_new; 
  reg id_axi_ad_en; 
  
  reg [DMA_CTRL_WIDTH-1:0] dma_ctrl_reg, dma_ctrl_new; 
  reg dma_ctrl_en; 
  
  //// Wires
  wire start, clr_done;

  wire axi_ad_gnt; 
  wire axi_ad_valid; 
  
  //// Assign Control signals
  assign start = config_d[CONF_START]; 
  assign clr_done = config_d[CONF_CLR_DONE]; 
  
  
  //// Assign the outputs
  assign state_o = {{{DATA_WIDTH-DMA_CTRL_WIDTH}{1'b0}}, dma_ctrl_reg};


  //// Save the input command
  always @ (posedge clk_i or negedge rst_ni)
    begin: save_inputs
      if (!rst_ni)
        begin
          //start_d <= 'b0;
          config_d <= 'b0 ; 
          length_d <= 'b0 ;
          source_addr_d <= 'b0 ; 
          dest_addr_d <= 'b0 ; 
        end
      else 
        begin
          if ( (dma_ctrl_reg == CTRL_IDLE) || (dma_ctrl_reg == CTRL_DONE) )
            begin
              config_d <= config_i;
              length_d <= length_i; 
              source_addr_d <= source_addr_i;
              dest_addr_d <= dest_addr_i;
            end
        end 
    end // save_inputs 
  
  //// Regsiter Update
  always @ (posedge clk_i or negedge rst_ni)
    begin: reg_update
      if (!rst_ni)
        begin
          req_axi_ad_reg = 'h0; 
          we_axi_ad_reg = 'h0; 
          addr_axi_ad_reg = 64'h0; 
          be_axi_ad_reg = 'h0; 
          len_axi_ad_reg = 'h0; 
          size_axi_ad_reg = 'h0;
          type_axi_ad_reg = 'h0; 
          id_axi_ad_reg = 'h0; 
          dma_ctrl_reg = 'h0;  
        end
      else
        begin
          if (req_axi_ad_en)
            req_axi_ad_reg <= req_axi_ad_new; 
          if (we_axi_ad_en)
            we_axi_ad_reg <= we_axi_ad_new; 
          if (addr_axi_ad_en)
            addr_axi_ad_reg <= addr_axi_ad_new; 
          if (be_axi_ad_en)
            be_axi_ad_reg <= be_axi_ad_new; 
          if (len_axi_ad_en)
            be_axi_ad_reg <= be_axi_ad_new; 
          if (len_axi_ad_en)
            len_axi_ad_reg <= len_axi_ad_new; 
          if (size_axi_ad_en)
            size_axi_ad_reg <= size_axi_ad_new; 
          if (type_axi_ad_en)
            type_axi_ad_reg <= type_axi_ad_new; 
          if (id_axi_ad_en)
            id_axi_ad_reg <= id_axi_ad_new; 
          if (dma_ctrl_en)
            dma_ctrl_reg <= dma_ctrl_new; 
        end
    end // reg_update 

  //// AXI adapter for the DMA
  dma_axi_adapter #(
      .DATA_WIDTH            ( AXI_DATA_WIDTH     ),
      .AXI_ID_WIDTH          ( AXI_ID_WIDTH       ),
      .AXI_ADDR_WIDTH        ( AXI_ADDR_WIDTH     ),
      .AXI_BE_WIDTH          ( AXI_BE_WIDTH       ),
      .AXI_LEN_WIDTH         ( AXI_LEN_WIDTH      ),
      .AXI_SIZE_WIDTH        ( AXI_SIZE_WIDTH     )
  ) u_axi_ad (
      .clk_i                 ( clk_i            ),
      .rst_ni                ( rst_ni           ),
      .req_i                 ( req_axi_ad_reg   ),
      .type_i                ( type_axi_ad_reg  ),
      .gnt_o                 ( axi_ad_gnt       ),
      .addr_i                ( addr_axi_ad_reg  ),
      .we_i                  ( we_axi_ad_reg    ),
      .be_i                  ( be_axi_ad_reg    ),
      .len_i                 ( len_axi_ad_reg   ),
      .size_i                ( size_axi_ad_reg  ),
      .id_i                  ( id_axi_ad_reg    ),
      .valid_o               ( axi_ad_valid     ),
      .gnt_id_o              (                  ),
      .id_o                  (                  ),
      .axi_req_o             ( axi_ad_axi_req_o ),
      .axi_resp_i            ( axi_resp_i       )
  );

  //// DMA ctrl
  always @*
    begin: dma_ctrl
      req_axi_ad_new  = 'h0;     
      req_axi_ad_en   = 'h0; 
      we_axi_ad_new   = 'h0; 
      we_axi_ad_en    = 'h0; 
      addr_axi_ad_new = 'h0; 
      addr_axi_ad_en  = 'h0; 
      be_axi_ad_new = 'h0; 
      be_axi_ad_en  = 'h0; 
      len_axi_ad_new  = 'h0; 
      len_axi_ad_en   = 'h0; 
      size_axi_ad_new = 'h0; 
      size_axi_ad_en  = 'h0; 
      type_axi_ad_new = 'h0; 
      type_axi_ad_en  = 'h0; 
      id_axi_ad_new   = 'h0; 
      id_axi_ad_en    = 'h0; 
      dma_ctrl_new = CTRL_LOAD; 
      dma_ctrl_en  = 'h0; 
      
      case (dma_ctrl_reg)
        CTRL_IDLE: 
          begin
            if (start)  // read command to axi
              begin
                dma_ctrl_new = CTRL_START_LOAD; 
                dma_ctrl_en  = 1'b1; 
              end
          end
        CTRL_START_LOAD: 
          begin
            req_axi_ad_new = 1'b1; 
            req_axi_ad_en  = 1'b1; 
            we_axi_ad_new = 1'b0;  // read
            we_axi_ad_en  = 1'b1;
            addr_axi_ad_new = {32'b0, source_addr_d[31:3], 3'b0}; 
            addr_axi_ad_en  = 1'b1; 
            len_axi_ad_new = length_d[7:0]; 
            len_axi_ad_en  = 1'b1;  
            size_axi_ad_new = 3'b11; // 64 bits at a time
            size_axi_ad_en  = 1'b1; 
            type_axi_ad_new = (length_d == 'b0) ; 
            type_axi_ad_en  = 1'b1; 
            id_axi_ad_new = 2'd2;  // dma is master '2'
            id_axi_ad_en  = 1'b1; 
            if (axi_ad_gnt)
              begin
                dma_ctrl_new = CTRL_LOAD; 
                dma_ctrl_en  = 1'b1; 
              end
          end
        CTRL_LOAD: 
          begin
            req_axi_ad_new = 1'b0; 
            req_axi_ad_en  = 1'b1; 
            if (axi_ad_valid)
              begin
                dma_ctrl_new = CTRL_START_STORE; 
                dma_ctrl_en  = 1'b1; 
              end
          end
        CTRL_START_STORE:
          begin // write command to axi
            req_axi_ad_new = 1'b1; 
            req_axi_ad_en  = 1'b1; 
            we_axi_ad_new = 1'b1;  // write 
            we_axi_ad_en  = 1'b1;
            addr_axi_ad_new = {32'b0, dest_addr_d[31:3], 3'b0}; 
            addr_axi_ad_en  = 1'b1; 
            be_axi_ad_new = 8'hff;  // write all bytes
            be_axi_ad_en  = 1'b1; 
            len_axi_ad_new = length_d[7:0]; 
            len_axi_ad_en  = 1'b1;  
            size_axi_ad_new = 3'b11; // 64 bits at a time
            size_axi_ad_en  = 1'b1; 
            type_axi_ad_new = (length_d == 'b0) ; 
            type_axi_ad_en  = 1'b1; 
            id_axi_ad_new = 2'd2;  // dma is master '2'
            id_axi_ad_en  = 1'b1; 
            if (axi_ad_gnt)
              begin
                dma_ctrl_new = CTRL_STORE;
                dma_ctrl_en  = 1'b1; 
              end
          end
        CTRL_STORE:
          begin
            req_axi_ad_new = 1'b0; 
            req_axi_ad_en  = 1'b1; 
            if (axi_ad_valid)
              begin
                dma_ctrl_new = CTRL_DONE; 
                dma_ctrl_en  = 1'b1; 
              end
          end
        CTRL_DONE:
          begin
            if (clr_done)
              begin
                dma_ctrl_new = CTRL_IDLE;
                dma_ctrl_en  = 1'b1; 
              end
          end 
        default:
          begin
            req_axi_ad_new = 1'b0; 
            req_axi_ad_en  = 1'b1; 
            dma_ctrl_new = CTRL_IDLE;
            dma_ctrl_en  = 1'b1; 
          end
      endcase
    end  // dma_ctrl


endmodule
