`timescale 1ns / 10ps
module cell_cache_tb;
    // 
    parameter   PIXEL_DATA_W        = 8;
    // Frame FIFO configuration
    parameter   FRAME_COL_NUM       = 320;
    parameter   FRAME_ROW_NUM       = 240;
    parameter   FRAME_SIZE          = FRAME_COL_NUM*FRAME_ROW_NUM*PIXEL_DATA_W;
    // Image processor configuaration
    parameter   CELL_ADDR_W         = 13;
    parameter   CELL_COL_NUM        = 8;
    parameter   CELL_ROW_NUM        = 8;
    parameter   CELL_EXP_BDRY_NUM   = 1;     // Expand each side by 1 unit
    parameter   CELL_SIZE           = CELL_COL_NUM*CELL_ROW_NUM*PIXEL_DATA_W;
    parameter   PROC_CELL_SIZE      = (CELL_COL_NUM+2*CELL_EXP_BDRY_NUM)+(CELL_ROW_NUM+2*CELL_EXP_BDRY_NUM)*PIXEL_DATA_W;
    // Pipeline configuration
    parameter   PIPELINE_STAGE_NUM  = 2;     // 2 - 1 - 0
    // Input declaration
    logic                           clk;
    logic                           rst_n;
    // -- To Frame FIFO
    logic   [FRAME_SIZE-1:0]        frame_i;
    logic                           frame_rd_ready_i;
    // -- To HOG
    logic                           cell_rd_valid_i;
    // Output declaration
    // -- To Frame FIFO
    logic                           frame_rd_valid_o;
    // -- To HOG
    logic   [CELL_SIZE-1:0]         cell_o;
    logic                           cell_rd_ready_o;
    
    cell_cache #(
    
    ) uut (
        .*
    );
    genvar pxl_idx;
    generate
        for(pxl_idx = 0; pxl_idx < FRAME_COL_NUM*FRAME_ROW_NUM; pxl_idx = pxl_idx + 1) begin
            assign frame_i[PIXEL_DATA_W*(pxl_idx+1)-1:PIXEL_DATA_W*pxl_idx] = pxl_idx;
        end
    endgenerate
endmodule
