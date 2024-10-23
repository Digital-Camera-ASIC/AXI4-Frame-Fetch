module axi4_frame_fetch
#(
    // Features configuration
    parameter IP_AMT            = 1,    // Number of Image processor    
    // AXI4 configurati
    parameter MST_ID_W          = 3,
    parameter DATA_WIDTH        = 256,
    parameter ADDR_WIDTH        = 32,
    parameter TRANS_BURST_W     = 2,    // Width of xBURST 
    parameter TRANS_DATA_LEN_W  = 3,    // Bus width of xLEN
    parameter TRANS_DATA_SIZE_W = 3,    // Bus width of xSIZE
    parameter TRANS_WR_RESP_W   = 2,
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
    input                           ACLK_i,
    input                           ARESETn_i,
    // -- To Master
    // ---- Write address channel
    input   [MST_ID_W-1:0]          m_AWID_i,
    input   [ADDR_WIDTH-1:0]        m_AWADDR_i,
    input                           m_AWVALID_i,
    // ---- Write data channel
    input   [DATA_WIDTH-1:0]        m_WDATA_i,
    input                           m_WLAST_i,
    input                           m_WVALID_i,
    // ---- Write response channel
    input                           m_BREADY_i,
    // -- To HOG
    input   [IP_AMT-1:0]            cell_ready_i,
    // Output declaration
    // -- To Master 
    // ---- Write address channel (master)
    output                          m_AWREADY_o,
    // ---- Write data channel (master)
    output                          m_WREADY_o,
    // ---- Write response channel (master)
    output  [MST_ID_W-1:0]          m_BID_o,
    output  [TRANS_WR_RESP_W-1:0]   m_BRESP_o,
    output                          m_BVALID_o,
    // -- To HOG
    output  [IP_AMT*CELL_WIDTH-1:0] cell_data_o,
    output  [IP_AMT-1:0]            cell_valid_o
 );
    // Internal variable
    genvar ip_idx;
    
    // Internal signal
    // -- wire
    wire    [IP_AMT-1:0]        actrl_pgroup_ready;
    wire    [IP_AMT-1:0]        actrl_frame_complete;
    wire    [DATA_WIDTH-1:0]    actrl_pgroup_data;
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
    wire    [CELL_ADDR_W-1:0]   cf_cell_rd_addr         [0:IP_AMT-1];
    // Internal module 
    // -- AXI4 Controller
    axi4_controller #(
        .IP_AMT                 (IP_AMT)
    ) axi4_controller (
        .ACLK_i                 (ACLK_i),          
        .ARESETn_i              (ARESETn_i),
        .m_AWID_i               (m_AWID_i),        
        .m_AWADDR_i             (m_AWADDR_i),     
        .m_AWVALID_i            (m_AWVALID_i),     
        .m_WDATA_i              (m_WDATA_i),       
        .m_WLAST_i              (m_WLAST_i),       
        .m_WVALID_i             (m_WVALID_i),      
        .m_BREADY_i             (m_BREADY_i),      
        .pgroup_ready_i         (actrl_pgroup_ready),  
        .frame_complete_i       (actrl_frame_complete),
        .m_AWREADY_o            (m_AWREADY_o),     
        .m_WREADY_o             (m_WREADY_o),      
        .m_BID_o                (m_BID_o),         
        .m_BRESP_o              (m_BRESP_o),       
        .m_BVALID_o             (m_BVALID_o),      
        .pgroup_o               (actrl_pgroup_data),   
        .pgroup_valid_o         (actrl_pgroup_valid)
    );
    generate
        for(ip_idx = 0; ip_idx < IP_AMT; ip_idx = ip_idx + 1) begin
        // -- Cell controller
        cell_controller #(
                    
        ) cell_controller (
            .clk                (ACLK_i),            
            .rst                (~ARESETn_i),            
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
            .clk                (ACLK_i),
            .rst                (~ARESETn_i),
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
            .clk                (ACLK_i),
            .rst                (~ARESETn_i),
            .cell_wr_en_i       (cc_cell_wr_en[ip_idx]),
            .cell_wr_data_i     (cb_cell_data[ip_idx]),
            .cell_wr_addr_i     (cc_cell_wr_addr[ip_idx]),
            .cell_rd_addr_i     (cf_cell_rd_addr[ip_idx]),
            .cell_rd_data_o     (ccache_cell_rd_data[ip_idx])
        );
        // -- Cell fetch
        cell_fetch #(
        
        ) cell_fetch (
            .clk                (ACLK_i),
            .rst                (~ARESETn_i),
            .bwd_cell_data_i    (ccache_cell_rd_data[ip_idx]),
            .cell_fetch_start_i (cc_cell_fetch_start[ip_idx]),
            .fwd_cell_ready_i   (cell_ready_i[ip_idx]),
            .bwd_cell_addr_o    (cf_cell_rd_addr[ip_idx]),
            .fwd_cell_data_o    (cell_data_o[(ip_idx+1)*CELL_WIDTH-1-:CELL_WIDTH]),
            .fwd_cell_valid_o   (cell_valid_o[ip_idx])
        );
        end
    endgenerate
endmodule
