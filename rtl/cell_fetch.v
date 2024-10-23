module cell_fetch
#(
    parameter CELL_WIDTH        = 768,
    parameter CELL_NUM          = 1200,
    // Do not configure
    parameter CELL_ADDR_W       = $clog2(CELL_NUM)
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
    output  [CELL_ADDR_W-1:0]   bwd_cell_addr_o,
    // -- To HOG
    output  [CELL_WIDTH-1:0]    fwd_cell_data_o,
    output                      fwd_cell_valid_o
);
    // Local parameter
    localparam              IDLE_ST     = 1'd0;
    localparam              FETCH_ST    = 1'd1;
    // Internal signal
    // -- wire
    wire                    cs_bwd_valid;
    wire                    cs_bwd_ready;
    reg                     cell_fetch_st_d;
    reg [CELL_ADDR_W-1:0]   cell_counter_d;
    // -- reg
    reg                     cell_fetch_st_q;
    reg [CELL_ADDR_W-1:0]   cell_counter;
    
    // Module declaration
    // -- Skid buffer (To pipelining for CACHE timing path)
    skid_buffer #(
        .SBUF_TYPE(0),          // Full-registered
        .DATA_WIDTH(CELL_WIDTH)
    ) cell_stage_reg (
        .clk        (clk),
        .rst_n      (~rst),
        .bwd_data_i (bwd_cell_data_i),
        .bwd_valid_i(cs_bwd_valid),
        .fwd_ready_i(fwd_cell_ready_i),
        .fwd_data_o (fwd_cell_data_o),
        .bwd_ready_o(cs_bwd_ready),
        .fwd_valid_o(fwd_cell_valid_o)
    );
    
    // Combination logic
    // -- Output
    assign bwd_cell_addr_o  = cell_counter;
    // -- Internal
    assign cs_bwd_valid     = cell_fetch_st_q == FETCH_ST;
    always @(*) begin
        cell_fetch_st_d = cell_fetch_st_q;
        cell_counter_d  = cell_counter;
        case(cell_fetch_st_q)
            IDLE_ST: begin
                if(cell_fetch_start_i) begin
                    cell_fetch_st_d = FETCH_ST;
                end
            end
            FETCH_ST: begin
                if(cs_bwd_ready) begin
                    cell_counter_d = cell_counter + 1'b1;
                    if(cell_counter == CELL_NUM-1) begin    // Last cell in 1 frame
                        cell_fetch_st_d = IDLE_ST;
                    end
                end
            end
        endcase
    end
    
    // Flip-flop 
    always @(posedge clk) begin
        if(rst) begin
            cell_fetch_st_q <= IDLE_ST;
            cell_counter    <= {CELL_ADDR_W{1'b0}};
        end
        else begin
            cell_fetch_st_q <= cell_fetch_st_d;
            cell_counter    <= cell_counter_d;
        end
    end
endmodule
