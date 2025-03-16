module cell_fetch
#(
    parameter CELL_WIDTH        = 768,
    parameter CELL_NUM          = 1200,
    parameter FRAME_ROW_CNUM    = 30,               // 30 cells
    parameter FRAME_COL_CNUM    = 40,               // 40 cells
    // Do not configure
    parameter CELL_ADDR_W       = $clog2(CELL_NUM),
    parameter ROW_ADDR_W        = $clog2(FRAME_ROW_CNUM),
    parameter COL_ADDR_W        = $clog2(FRAME_COL_CNUM)
)
(
    // Input declaration
    input                       clk,
    input                       rst,
    // -- To Cell Cache
    input   [CELL_WIDTH-1:0]    bwd_cell_data_i,
    // -- To Cell Controller
    input                       cell_fetch_start_i,
    // -- To HOG
    input                       fwd_cell_ready_i,
    // Output declaration 
    // -- To Cell Cache
    output                      bwd_cell_en_o,
    output  [CELL_ADDR_W-1:0]   bwd_cell_addr_o,
    // -- To HOG
    output  [CELL_WIDTH-1:0]    fwd_cell_data_o,
    output                      fwd_cell_valid_o
);
    // Local parameter
    localparam              IDLE_ST     = 2'd0;
    localparam              FETCH_ST    = 2'd2;
    localparam              SETUP_ST    = 2'd1;
    localparam              HOLD_ST     = 2'd3;
    // Internal signal
    // -- wire
    wire                    cs_bwd_valid;
    wire                    cs_bwd_ready;
    wire[CELL_WIDTH-1:0]    cell_msk;
    reg [CELL_WIDTH-1:0]    cell_d;        // Cell pipeline
    reg [1:0]               cell_fetch_st_d;
    reg [CELL_ADDR_W-1:0]   cell_counter_d;
    reg [ROW_ADDR_W-1:0]    cell_row_counter_d;
    reg [COL_ADDR_W-1:0]    cell_col_counter_d;
    // -- reg
    reg [CELL_WIDTH-1:0]    cell_q;         // Cell pipeline
    reg [1:0]               cell_fetch_st_q;
    reg [CELL_ADDR_W-1:0]   cell_counter;
    reg [ROW_ADDR_W-1:0]    cell_row_counter;
    reg [COL_ADDR_W-1:0]    cell_col_counter;
    
//    // Module declaration
//    // -- Skid buffer (To pipelining for CACHE timing path)
//    skid_buffer #(
//        .SBUF_TYPE(0),          // Full-registered
//        .DATA_WIDTH(CELL_WIDTH)
//    ) cell_stage_reg (
//        .clk        (clk),
//        .rst_n      (~rst),
//        .bwd_data_i (bwd_cell_data_i),
//        .bwd_valid_i(cs_bwd_valid),
//        .fwd_ready_i(fwd_cell_ready_i),
//        .fwd_data_o (fwd_cell_data_o),
//        .bwd_ready_o(cs_bwd_ready),
//        .fwd_valid_o(fwd_cell_valid_o)
//    );
    cell_mask #(
    
    ) cell_mask (
        .cell_i     (bwd_cell_data_i),
        .t_msk_en_i (~|(cell_row_counter)),
        .b_msk_en_i (~|(cell_row_counter^(FRAME_ROW_CNUM-1))),
        .l_msk_en_i (~|(cell_col_counter)),
        .r_msk_en_i (~|(cell_col_counter^(FRAME_COL_CNUM-1))),
        .cell_o     (cell_msk)
    );
    
    // Combination logic
    // -- Output
    assign fwd_cell_data_o  = cell_q;
    assign fwd_cell_valid_o = cs_bwd_valid;
    assign bwd_cell_en_o    = cell_fetch_start_i | (cell_fetch_st_q == SETUP_ST) | (cs_bwd_ready & cs_bwd_valid);
    assign bwd_cell_addr_o  = cell_counter;
    // -- Internal
    assign cs_bwd_valid     = (cell_fetch_st_q == FETCH_ST) || (cell_fetch_st_q == HOLD_ST);
    assign cs_bwd_ready     = fwd_cell_ready_i;
    // -- Pipelined RAM controller
    always @(*) begin
        cell_d              = cell_q;
        cell_fetch_st_d     = cell_fetch_st_q;
        cell_counter_d      = cell_counter;
        cell_row_counter_d  = cell_row_counter;
        cell_col_counter_d  = cell_col_counter;
        case(cell_fetch_st_q)
            IDLE_ST: begin
                if(cell_fetch_start_i) begin
                    cell_fetch_st_d = SETUP_ST;
                    cell_counter_d = cell_counter + 1'b1;
                    cell_row_counter_d = {ROW_ADDR_W{1'b0}};
                    cell_col_counter_d = {COL_ADDR_W{1'b0}};
                end
            end
            SETUP_ST: begin // Setup state in Pipelined RAM
                cell_fetch_st_d = FETCH_ST;
                cell_d = cell_msk;
                cell_counter_d = cell_counter + 1'b1;
                cell_col_counter_d = cell_col_counter + 1'b1;
            end
            FETCH_ST: begin
                if(cs_bwd_ready) begin
                    cell_d = cell_msk;
                    cell_counter_d = cell_counter + 1'b1;
                    cell_col_counter_d = {COL_ADDR_W{(|(cell_col_counter^(FRAME_COL_CNUM-1)))}} & (cell_col_counter + 1'b1);
                    if(cell_counter == CELL_NUM) begin    // Last cell in 1 frame
                        cell_fetch_st_d = HOLD_ST;
                    end
                    if(cell_col_counter == FRAME_COL_CNUM-1) begin
                        cell_row_counter_d = {ROW_ADDR_W{(|(cell_row_counter^(FRAME_ROW_CNUM-1)))}} & (cell_row_counter + 1'b1);
                    end
                end
            end
            HOLD_ST: begin  // Hold state in Pipeline RAM
                if(cs_bwd_ready) begin
                    cell_fetch_st_d = IDLE_ST;
                end
            end
        endcase
    end
    
    // Flip-flop 
    always @(posedge clk) begin
        if(rst) begin
            cell_fetch_st_q <= IDLE_ST;
            cell_counter    <= {CELL_ADDR_W{1'b0}};
            cell_row_counter <= {ROW_ADDR_W{1'b0}};
            cell_col_counter <= {COL_ADDR_W{1'b0}};
        end
        else begin
            cell_fetch_st_q <= cell_fetch_st_d;
            cell_q          <= cell_d;
            cell_counter    <= cell_counter_d;
            cell_row_counter <= cell_row_counter_d;
            cell_col_counter <= cell_col_counter_d;
        end
    end
endmodule
