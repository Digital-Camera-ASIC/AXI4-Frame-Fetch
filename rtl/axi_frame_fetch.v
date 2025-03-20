module axi_frame_fetch
#(
    // Image Processor
    parameter IP_AMT            = 1,    // Image processor amount  
    parameter IP_ADDR_W         = $clog2(IP_AMT),
    parameter IP_DATA_W         = 256,
    // AXI-Stream configuration
    parameter AXIS_TDEST_BASE   = 1'b1,
    parameter AXIS_TID_W        = 2,
    parameter AXIS_TDEST_W      = (IP_ADDR_W > 1) ? IP_ADDR_W : 1,
    parameter AXIS_TDATA_W      = IP_DATA_W,
    parameter AXIS_TKEEP_W      = AXIS_TDATA_W/8,
    parameter AXIS_TSTRB_W      = AXIS_TDATA_W/8,
    // Image processor configuaration
    parameter PG_WIDTH          = 256,
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
    // -- Global signals
    input                           s_aclk,
    input                           s_aresetn,
    // -- AXI-Stream interface
    input   [AXIS_TID_W-1:0]        s_tid_i,    
    input   [AXIS_TDEST_W-1:0]      s_tdest_i, 
    input   [AXIS_TDATA_W-1:0]      s_tdata_i,
    input   [AXIS_TKEEP_W-1:0]      s_tkeep_i,
    input   [AXIS_TSTRB_W-1:0]      s_tstrb_i,
    input                           s_tlast_i,
    input                           s_tvalid_i,
    output                          s_tready_o,
    // -- To HOG
    output  [IP_AMT*CELL_WIDTH-1:0] cell_data_o,
    output  [IP_AMT-1:0]            cell_valid_o,
    input   [IP_AMT-1:0]            cell_ready_i
 );
    // Internal variable
    genvar ip_idx;
    
    // Internal signal
    // -- wire
    wire    [IP_AMT-1:0]        actrl_pgroup_ready;
    wire    [IP_AMT-1:0]        actrl_frame_complete;
    wire    [AXIS_TDATA_W-1:0]  actrl_pgroup_data;
    wire    [IP_AMT-1:0]        actrl_pgroup_valid;
    wire                        cc_pgroup_wr_en         [0:IP_AMT-1];
    wire    [ROW_ADDR_W-1:0]    cc_row_addr             [0:IP_AMT-1];
    wire    [CROW_ADDR_W-1:0]   cc_crow_addr            [0:IP_AMT-1];
    wire    [BCOL_ADDR_W-1:0]   cc_bcol_addr            [0:IP_AMT-1];
    wire    [COL_ADDR_W-1:0]    cc_ccol_addr            [0:IP_AMT-1];
    wire                        cc_cell_wr_en           [0:IP_AMT-1];
    wire    [CELL_ADDR_W-1:0]   cc_cell_wr_addr         [0:IP_AMT-1];
    wire                        cc_cell_fetch_start     [0:IP_AMT-1];
    wire    [CELL_WIDTH-1:0]    cb_cell_data            [0:IP_AMT-1];
    wire    [CELL_WIDTH-1:0]    ccache_cell_rd_data     [0:IP_AMT-1];
    wire                        cf_cell_rd_en           [0:IP_AMT-1];
    wire    [CELL_ADDR_W-1:0]   cf_cell_rd_addr         [0:IP_AMT-1];
    // Internal module 
    // -- AXI4 Controller
    axi_controller #(
        .IP_AMT         (IP_AMT),
        .IP_ADDR_W      (IP_ADDR_W),
        .IP_DATA_W      (IP_DATA_W),
        .AXIS_TDEST_BASE(AXIS_TDEST_BASE),
        .AXIS_TID_W     (AXIS_TID_W),
        .AXIS_TDEST_W   (AXIS_TDEST_W),
        .AXIS_TDATA_W   (AXIS_TDATA_W),
        .AXIS_TKEEP_W   (AXIS_TKEEP_W),
        .AXIS_TSTRB_W   (AXIS_TSTRB_W)
    ) ac (
        .clk            (s_aclk),
        .rst_n          (s_aresetn),
        .s_tid_i        (s_tid_i),
        .s_tdest_i      (s_tdest_i),
        .s_tdata_i      (s_tdata_i),
        .s_tkeep_i      (s_tkeep_i),
        .s_tstrb_i      (s_tstrb_i),
        .s_tlast_i      (s_tlast_i),
        .s_tvalid_i     (s_tvalid_i),
        .s_tready_o     (s_tready_o),
        .pgroup_o       (actrl_pgroup_data),
        .pgroup_valid_o (actrl_pgroup_valid),
        .pgroup_ready_i (actrl_pgroup_ready)
    );
    generate
        for(ip_idx = 0; ip_idx < IP_AMT; ip_idx = ip_idx + 1) begin
        // -- Cell controller
        cell_controller #(
                    
        ) cell_controller (
            .clk                (s_aclk),            
            .rst                (~s_aresetn),            
            .pgroup_valid_i     (actrl_pgroup_valid[ip_idx]), 
            .pgroup_ready_o     (actrl_pgroup_ready[ip_idx]),
            .frame_complete_o   (actrl_frame_complete[ip_idx]),
            .pgroup_wr_en_o     (cc_pgroup_wr_en[ip_idx]),
            .row_addr_o         (cc_row_addr[ip_idx]),
            .crow_addr_o        (cc_crow_addr[ip_idx]),
            .bcol_addr_o        (cc_bcol_addr[ip_idx]),
            .ccol_addr_o        (cc_ccol_addr[ip_idx]),
            .cell_wr_en_o       (cc_cell_wr_en[ip_idx]),
            .cell_wr_addr_o     (cc_cell_wr_addr[ip_idx]),
            .cell_fetch_start_o (cc_cell_fetch_start[ip_idx])
        );
        // -- Cell buffer
        cell_buffer #(
        
        ) cell_buffer (
            .clk                (s_aclk),
            .rst                (~s_aresetn),
            .pgroup_i           (actrl_pgroup_data),
            .pgroup_wr_en_i     (cc_pgroup_wr_en[ip_idx]),
            .row_addr_i         (cc_row_addr[ip_idx]),
            .crow_addr_i        (cc_crow_addr[ip_idx]),
            .bcol_addr_i        (cc_bcol_addr[ip_idx]),
            .ccell_addr_i       (cc_ccol_addr[ip_idx]),
            .cell_store_i       (cc_cell_wr_en[ip_idx]),
            .cell_data_o        (cb_cell_data[ip_idx])
        );
        // -- Cell mapping
        cell_cache #(
        
        ) cell_cache (
            .clk                (s_aclk),
            .rst                (~s_aresetn),
            .cell_wr_en_i       (cc_cell_wr_en[ip_idx]),
            .cell_wr_data_i     (cb_cell_data[ip_idx]),
            .cell_wr_addr_i     (cc_cell_wr_addr[ip_idx]),
            .cell_rd_en_i       (cf_cell_rd_en[ip_idx]),
            .cell_rd_addr_i     (cf_cell_rd_addr[ip_idx]),
            .cell_rd_data_o     (ccache_cell_rd_data[ip_idx])
        );
        // -- Cell fetch
        cell_fetch #(
        
        ) cell_fetch (
            .clk                (s_aclk),
            .rst                (~s_aresetn),
            .bwd_cell_data_i    (ccache_cell_rd_data[ip_idx]),
            .cell_fetch_start_i (cc_cell_fetch_start[ip_idx]),
            .fwd_cell_ready_i   (cell_ready_i[ip_idx]),
            .bwd_cell_en_o      (cf_cell_rd_en[ip_idx]),
            .bwd_cell_addr_o    (cf_cell_rd_addr[ip_idx]),
            .fwd_cell_data_o    (cell_data_o[(ip_idx+1)*CELL_WIDTH-1-:CELL_WIDTH]),
            .fwd_cell_valid_o   (cell_valid_o[ip_idx])
        );
        end
    endgenerate
endmodule
