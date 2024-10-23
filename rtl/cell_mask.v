module cell_mask
#(
    parameter CELL_WIDTH        = 768,
    parameter PIXEL_WIDTH       = 8,
    parameter CELL_ROW_PNUM     = 8,                // 8 pixels
    parameter CELL_COL_PNUM     = 8                 // 8 pixels
)
(
    // Input declaration
    input   [CELL_WIDTH-1:0]    cell_i,
    input                       t_msk_en_i,
    input                       b_msk_en_i,
    input                       l_msk_en_i,
    input                       r_msk_en_i,
    
    // Output declaration
    output  [CELL_WIDTH-1:0]    cell_o
);
    localparam IPXL_SIZE    = CELL_ROW_PNUM*CELL_COL_PNUM*PIXEL_WIDTH;
    localparam LOPXL_SIZE   = CELL_ROW_PNUM*PIXEL_WIDTH;
    localparam ROPXL_SIZE   = CELL_ROW_PNUM*PIXEL_WIDTH;
    localparam TOPXL_SIZE   = CELL_COL_PNUM*PIXEL_WIDTH;
    localparam BOPXL_SIZE   = CELL_COL_PNUM*PIXEL_WIDTH;
    
    wire    [IPXL_SIZE-1:0]     ipxl_flat  ;
    wire    [LOPXL_SIZE-1:0]    l_opxl_flat;
    wire    [ROPXL_SIZE-1:0]    r_opxl_flat;
    wire    [TOPXL_SIZE-1:0]    t_opxl_flat;
    wire    [BOPXL_SIZE-1:0]    b_opxl_flat;
    wire    [LOPXL_SIZE-1:0]    l_opxl_msk;
    wire    [ROPXL_SIZE-1:0]    r_opxl_msk;
    wire    [TOPXL_SIZE-1:0]    t_opxl_msk;
    wire    [BOPXL_SIZE-1:0]    b_opxl_msk;
    
    assign {ipxl_flat, t_opxl_flat, l_opxl_flat, r_opxl_flat, b_opxl_flat} = cell_i;
    assign t_opxl_msk   = {TOPXL_SIZE{~(t_msk_en_i)}} & t_opxl_flat;
    assign l_opxl_msk   = {LOPXL_SIZE{~(l_msk_en_i)}} & l_opxl_flat;
    assign r_opxl_msk   = {ROPXL_SIZE{~(r_msk_en_i)}} & r_opxl_flat;
    assign b_opxl_msk   = {BOPXL_SIZE{~(b_msk_en_i)}} & b_opxl_flat;
    assign cell_o       = {ipxl_flat, t_opxl_msk, l_opxl_msk, r_opxl_msk, b_opxl_msk};
endmodule
