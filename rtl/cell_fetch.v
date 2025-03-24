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
    input                       clk,
    input                       rst,

    input                       cell_fetch_start_i,
    // -- To Cell Cache
    output  [CELL_ADDR_W-1:0]   bwd_cell_addr_o,
    input   [CELL_WIDTH-1:0]    bwd_cell_data_i,
    output                      bwd_cell_rd_vld,
    input                       bwd_cell_rd_rdy,
    // -- To HOG
    output  [CELL_WIDTH-1:0]    fwd_cell_data_o,
    output                      fwd_cell_valid_o,
    input                       fwd_cell_ready_i
);
    // Local parameter
    localparam              IDLE_ST     = 2'd0;
    localparam              FETCH_ST    = 2'd1;
    localparam              EOF_ST      = 2'd2;

    // Internal signal
    // -- wire
    wire                    cs_bwd_valid;
    wire                    cs_bwd_ready;
    wire[CELL_WIDTH-1:0]    cell_msk;
    reg [1:0]               cell_fetch_st_d;
    reg [CELL_ADDR_W-1:0]   cell_counter_d;
    reg [ROW_ADDR_W-1:0]    cell_row_counter_d;
    reg [COL_ADDR_W-1:0]    cell_col_counter_d;
    reg                     bwd_cell_rd_vld_int;
    reg                     fwd_cell_valid_int;
    reg [CELL_WIDTH-1:0]    fwd_cell_data_int;
    wire[CELL_WIDTH-1:0]    skid_cell_dat;
    wire                    skid_cell_vld;
    // -- reg
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
    sync_fifo #(
        .FIFO_TYPE      (1), // Normal
        .DATA_WIDTH     (CELL_WIDTH),
        .FIFO_DEPTH     (2) // = Memory latency
    ) cell_skid (
        .clk           (clk),
        .data_i        (cell_msk),
        .wr_valid_i    (bwd_cell_rd_rdy & (~fwd_cell_ready_i)), // cell-skid event occurs
        .wr_ready_o    (),
        .data_o        (skid_cell_dat),
        .rd_ready_o    (skid_cell_vld),
        .rd_valid_i    (skid_cell_vld & (fwd_cell_valid_o & fwd_cell_ready_i)), // Handshaking occurs and that is for skid cell 
        .empty_o       (),
        .full_o        (),
        .almost_empty_o(),
        .almost_full_o (),
        .counter       (),
        .rst_n         (~rst)
    );


    // Combinational logic
    assign bwd_cell_addr_o  = cell_counter;
    assign bwd_cell_rd_vld  = bwd_cell_rd_vld_int;
    assign fwd_cell_data_o  = fwd_cell_data_int;
    assign fwd_cell_valid_o = fwd_cell_valid_int;
    always @* begin
        cell_fetch_st_d     = cell_fetch_st_q;
        cell_counter_d      = cell_counter; // Store address of the cell in Cache
        cell_col_counter_d  = cell_col_counter;
        cell_row_counter_d  = cell_row_counter;
        fwd_cell_data_int   = cell_msk;
        bwd_cell_rd_vld_int = 1'b0;
        fwd_cell_valid_int  = 1'b0;


        case(cell_fetch_st_q)
            IDLE_ST: begin
                if(cell_fetch_start_i) begin
                    cell_fetch_st_d     = FETCH_ST;
                    bwd_cell_rd_vld_int = 1'b1;
                    cell_counter_d      = cell_counter + 1'b1; // Store address of the cell in Cache
                end
            end
            FETCH_ST: begin
                cell_counter_d      = cell_counter + bwd_cell_rd_vld; // Store address of the cell in Cache
                fwd_cell_data_int   = skid_cell_vld ? skid_cell_dat : cell_msk;
                fwd_cell_valid_int  = bwd_cell_rd_rdy | skid_cell_vld;
                bwd_cell_rd_vld_int = fwd_cell_ready_i;
                if((cell_counter == (CELL_NUM-1)) & bwd_cell_rd_vld) begin // Read signal for last cell of a frame is sent
                    cell_fetch_st_d = EOF_ST;
                    cell_counter_d = {CELL_ADDR_W{1'b0}};
                end
                if(bwd_cell_rd_rdy) begin
                    cell_col_counter_d = {COL_ADDR_W{(|(cell_col_counter^(FRAME_COL_CNUM-1)))}} & (cell_col_counter + 1'b1);
                    if(cell_col_counter == (FRAME_COL_CNUM-1)) begin
                        cell_row_counter_d = {ROW_ADDR_W{(|(cell_row_counter^(FRAME_ROW_CNUM-1)))}} & (cell_row_counter + 1'b1);
                    end
                end
            end
            EOF_ST: begin
                fwd_cell_data_int   = skid_cell_vld ? skid_cell_dat : cell_msk;
                fwd_cell_valid_int  = bwd_cell_rd_rdy | skid_cell_vld;
                if(bwd_cell_rd_rdy) begin
                    cell_col_counter_d = {COL_ADDR_W{(|(cell_col_counter^(FRAME_COL_CNUM-1)))}} & (cell_col_counter + 1'b1);
                    if(cell_col_counter == (FRAME_COL_CNUM-1)) begin
                        cell_row_counter_d = {ROW_ADDR_W{(|(cell_row_counter^(FRAME_ROW_CNUM-1)))}} & (cell_row_counter + 1'b1);
                    end
                end
                if(~(bwd_cell_rd_rdy | skid_cell_vld)) begin // No more cell
                    cell_fetch_st_d    = IDLE_ST;
                    cell_col_counter_d = {COL_ADDR_W{(|(cell_col_counter^(FRAME_COL_CNUM-1)))}};
                    cell_row_counter_d = {ROW_ADDR_W{(|(cell_row_counter^(FRAME_ROW_CNUM-1)))}};
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
            cell_counter    <= cell_counter_d;
            cell_row_counter <= cell_row_counter_d;
            cell_col_counter <= cell_col_counter_d;
        end
    end
endmodule
