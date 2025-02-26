module cell_controller
#(
    parameter DATA_WIDTH        = 256,
    parameter CELL_WIDTH        = 768,
    parameter CELL_NUM          = 1200,
    parameter FRAME_ROW_CNUM    = 30,               // 30 cells
    parameter FRAME_COL_CNUM    = 40,               // 40 cells
    parameter CELL_ROW_PNUM     = 8,                // 8 pixels
    parameter CELL_COL_PNUM     = 8,                // 8 pixels
    parameter FRAME_COL_BNUM    = FRAME_COL_CNUM/2, // 20 blocks
    parameter FRAME_COL_PGNUM   = FRAME_COL_CNUM/4, // 10 pixel groups
    // Do not configur
    parameter CELL_ADDR_W       = $clog2(CELL_NUM),
    parameter ROW_ADDR_W        = $clog2(FRAME_ROW_CNUM),
    parameter COL_ADDR_W        = $clog2(FRAME_COL_CNUM),
    parameter CROW_ADDR_W       = $clog2(CELL_ROW_PNUM),
    parameter BCOL_ADDR_W       = $clog2(FRAME_COL_BNUM),
    parameter PGCOL_ADDR_W      = $clog2(FRAME_COL_PGNUM)
)
(
    // Input declaration
    input                       clk,
    input                       rst,
    // -- To AXI4 Controller
    input                       pgroup_valid_i,
    // Output declaration
    // -- To AXI4 Controller
    output                      pgroup_ready_o,
    output                      frame_complete_o,
    // -- To Cell Buffer
    output                      pgroup_wr_en_o,
    output  [ROW_ADDR_W-1:0]    row_addr_o,
    output  [CROW_ADDR_W-1:0]   crow_addr_o,
    output  [BCOL_ADDR_W-1:0]   bcol_addr_o,
    output  [COL_ADDR_W-1:0]    ccol_addr_o,
    // -- To Cell Cache
    output                      cell_wr_en_o,
    output  [CELL_ADDR_W-1:0]   cell_wr_addr_o,
    // -- To Cell Fetch
    output                      cell_fetch_start_o
);
    // Local param 
    localparam  CBUF_ST         = 1'b0;
    localparam  STORE_RAM_ST    = 1'b1;
    
    // Internal signal
    // -- wire
    wire                        pgroup_handshake;
    reg                         frame_complete;
    reg                         cctrl_st_d;
    reg     [2:0]               ccol_store_ctn_d;
    reg     [ROW_ADDR_W-1:0]    row_addr_d;     // Row addr in 1 frame:             0 -> 239    (240)
    reg     [CROW_ADDR_W-1:0]   crow_addr_d;    // Pixel addr in 1 line of cell:    0 -> 7      (8)
    wire    [PGCOL_ADDR_W-1:0]  pgcol_addr_d;   // Block addr in 1 line:            0 -> 9      (10)
    reg     [COL_ADDR_W-1:0]    ccol_addr_d;    // Cell addr in 1 line:             0 -> 39     (40)
    reg     [CELL_ADDR_W-1:0]   cell_wr_addr_d; // Writed cell addr in 1 frame:     0 -> 1199   (1200) 
    // -- reg
    reg                         cctrl_st_q;
    reg     [2:0]               ccol_store_ctn_q; // 0 -> 3 / 0 -> 7
    reg     [ROW_ADDR_W-1:0]    row_addr_q;     // Row addr in 1 frame(Cell unit:   0 -> 29     (30 cells)
    reg     [CROW_ADDR_W-1:0]   crow_addr_q;    // Pixel addr in 1 line of cell:    0 -> 7      (8)
    reg     [PGCOL_ADDR_W-1:0]  pgcol_addr_q;   // Pixel group addr in 1 line:      0 -> 9      (10)
    reg     [COL_ADDR_W-1:0]    ccol_addr_q;    // Cell addr in 1 line:             0 -> 39     (40)
    reg     [CELL_ADDR_W-1:0]   cell_wr_addr_q; // Writed cell addr in 1 frame:     0 -> 1199   (1200) 
    
    // Combination logic
    // -- Output
    assign frame_complete_o     = frame_complete;
    assign pgroup_wr_en_o       = pgroup_handshake;
    assign pgroup_ready_o       = ~|(cctrl_st_q ^ CBUF_ST);
    assign cell_wr_en_o         = ~|(cctrl_st_q ^ STORE_RAM_ST);
    assign cell_wr_addr_o       = cell_wr_addr_q;
    assign row_addr_o           = row_addr_q;
    assign crow_addr_o          = crow_addr_q;
    assign bcol_addr_o          = {pgcol_addr_q, 1'b0};
    assign ccol_addr_o          = ccol_addr_q;
    // TODO: Quickstart mechanism /////////////////
    assign cell_fetch_start_o   = frame_complete_o;
    // ////////////////////////////////////////////
    // -- Internal
    assign pgroup_handshake     = pgroup_valid_i & pgroup_ready_o;
    assign pgcol_addr_d         = (pgcol_addr_q == FRAME_COL_PGNUM-1) ? {(BCOL_ADDR_W-2){1'b0}} : pgcol_addr_q + 1'b1;
    always @(*) begin
        crow_addr_d = crow_addr_q;
        if(pgcol_addr_q == FRAME_COL_PGNUM-1) begin
            if(crow_addr_q == CELL_ROW_PNUM-1) begin
                crow_addr_d = {CROW_ADDR_W{1'b0}};
            end
            else begin
                crow_addr_d = crow_addr_q + 1'b1;
            end
        end 
    end
    always @(*) begin
        row_addr_d = row_addr_q;
        if((pgcol_addr_q == FRAME_COL_PGNUM-1) && (crow_addr_q == CELL_ROW_PNUM-1)) begin
            if(row_addr_q == FRAME_ROW_CNUM-1) begin
                row_addr_d = {ROW_ADDR_W{1'b0}};
            end
            else begin
                row_addr_d = row_addr_q + 1'b1;
            end
        end 
    end
    always @(*) begin
        cctrl_st_d      = cctrl_st_q;
        cell_wr_addr_d  = cell_wr_addr_q;
        ccol_addr_d     = ccol_addr_q;
        ccol_store_ctn_d= ccol_store_ctn_q;
        frame_complete  = 1'b0;
        case(cctrl_st_q) 
            CBUF_ST: begin
                if(pgroup_handshake && (((~(row_addr_q == {ROW_ADDR_W{1'b0}})) && (crow_addr_q == {CROW_ADDR_W{1'b0}})) || ((row_addr_q == FRAME_ROW_CNUM-1) && (crow_addr_q == CELL_ROW_PNUM-1) && (pgcol_addr_q != 0)))) begin
                    //                     (Is not first row of frame          and   Is first row of cell             ) OR (Last row of frame                and  Last row of cell               but  Skip the first pgroup of this line) 
                    cctrl_st_d          = STORE_RAM_ST;
                    ccol_store_ctn_d    = 3'd0;
                end
            end
            STORE_RAM_ST: begin
                ccol_store_ctn_d    = ccol_store_ctn_q + 1'b1;
                cell_wr_addr_d      = (cell_wr_addr_q == CELL_NUM-1) ? {CELL_ADDR_W{1'b0}} : cell_wr_addr_q + 1'b1;
                ccol_addr_d         = (ccol_addr_q == FRAME_COL_CNUM-1) ? {COL_ADDR_W{1'b0}} : ccol_addr_q + 1'b1;
                frame_complete      = (cell_wr_addr_q == CELL_NUM-1);
                if((row_addr_q == 0) && (crow_addr_q == 0) && (pgcol_addr_q == 0)) begin   // Last 8 cells of a frame (push all 8 cells without any stall)
                    if(~|(ccol_store_ctn_q ^ 3'd7)) begin
                        cctrl_st_d          = CBUF_ST;
                    end
                end
                else begin
                    if(~|(ccol_store_ctn_q ^ 3'd3)) begin   // Push 4 cells 
                        cctrl_st_d          = CBUF_ST;
                    end
                end
            end
        endcase
    end
    // Flip-flop 
    always @(posedge clk) begin
        if(rst) begin
            pgcol_addr_q <= {PGCOL_ADDR_W{1'b0}};
        end
        else if(pgroup_handshake) begin
            pgcol_addr_q <= pgcol_addr_d;
        end
    end
    always @(posedge clk) begin
        if(rst) begin
            crow_addr_q <= {CROW_ADDR_W{1'b0}};
        end
        else if(pgroup_handshake) begin
            crow_addr_q <= crow_addr_d;
        end
    end
    always @(posedge clk) begin
        if(rst) begin
            row_addr_q <= {ROW_ADDR_W{1'b0}};
        end
        else if(pgroup_handshake) begin
            row_addr_q <= row_addr_d;
        end
    end
    always @(posedge clk) begin
        if(rst) begin
            cctrl_st_q      <= 1'b0;
            cell_wr_addr_q  <= {CELL_ADDR_W{1'b0}};
            ccol_addr_q     <= {COL_ADDR_W{1'b0}};
            ccol_store_ctn_q<= 3'd0;
        end
        else begin
            cctrl_st_q      <= cctrl_st_d;
            cell_wr_addr_q  <= cell_wr_addr_d;
            ccol_addr_q     <= ccol_addr_d; 
            ccol_store_ctn_q<= ccol_store_ctn_d;
        end
    end
    
endmodule
