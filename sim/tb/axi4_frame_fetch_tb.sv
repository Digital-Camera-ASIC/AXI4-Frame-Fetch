`timescale 1ns / 1ps
module axi4_frame_fetch_tb;
    // Features configuration
    parameter IP_AMT            = 1;    // Number of Image processor    
    // AXI4 configurati
    parameter MST_ID_W          = 3;
    parameter DATA_WIDTH        = 256;
    parameter ADDR_WIDTH        = 32;
    parameter TRANS_BURST_W     = 2;    // Width of xBURST 
    parameter TRANS_DATA_LEN_W  = 3;    // Bus width of xLEN
    parameter TRANS_DATA_SIZE_W = 3;    // Bus width of xSIZE
    parameter TRANS_WR_RESP_W   = 2;
    // Image processor configuaration
    parameter PG_WIDTH          = 256;
    parameter CELL_WIDTH        = 768;
    parameter CELL_NUM          = 1200;
    parameter FRAME_ROW_CNUM    = 30;               // 30 cells
    parameter FRAME_COL_CNUM    = 40;               // 40 cells
    parameter CELL_ROW_PNUM     = 8;                // 8 pixels
    parameter CELL_COL_PNUM     = 8;                // 8 pixels
    parameter FRAME_COL_BNUM    = FRAME_COL_CNUM/2; // 20 blocks
    parameter FRAME_COL_PGNUM   = FRAME_COL_CNUM/4; // 10 pixel groups
    // Do not configur
    parameter CELL_ADDR_W       = $clog2(CELL_NUM);
    parameter ROW_ADDR_W        = $clog2(FRAME_ROW_CNUM);
    parameter COL_ADDR_W        = $clog2(FRAME_COL_CNUM);
    parameter CROW_ADDR_W       = $clog2(CELL_ROW_PNUM);
    parameter BCOL_ADDR_W       = $clog2(FRAME_COL_BNUM);
    parameter PGCOL_ADDR_W      = $clog2(FRAME_COL_PGNUM);
    logic                           ACLK_i;
    logic                           ARESETn_i;
    logic   [MST_ID_W-1:0]          m_AWID_i;
    logic   [ADDR_WIDTH-1:0]        m_AWADDR_i;
    logic                           m_AWVALID_i;
    logic   [DATA_WIDTH-1:0]        m_WDATA_i;
    logic                           m_WLAST_i;
    logic                           m_WVALID_i;
    logic                           m_BREADY_i;
    logic   [IP_AMT-1:0]            cell_ready_i;
    logic                           m_AWREADY_o;
    logic                           m_WREADY_o;
    logic   [MST_ID_W-1:0]          m_BID_o;
    logic   [TRANS_WR_RESP_W-1:0]   m_BRESP_o;
    logic                           m_BVALID_o;
    logic   [IP_AMT*CELL_WIDTH-1:0] cell_data_o;
    logic   [IP_AMT-1:0]            cell_valid_o;
    
    
    axi4_frame_fetch uut(
        .*
    );
    
    reg [31:0]  counter;
    
    initial begin
        ACLK_i <= 1'b0;
        ARESETn_i <= 1'b0;
    
        m_AWID_i <= 0;   
        m_AWADDR_i <= 0; 
        m_AWVALID_i <= 0;
        m_WDATA_i <= 0;  
        m_WLAST_i <= 0;  
        m_WVALID_i <= 0; 
        m_BREADY_i <= 1'b1;
        
        #9;
        ARESETn_i <= 1'b1;
        
    end
    initial begin
        forever #1 ACLK_i <= ~ACLK_i;
    end
    
    initial begin
        #20;
        m_AW_transfer(.AWID(3'd0), .AWADDR(32'd0));
        // Wait for Handshake occuring
        wait(m_AWREADY_o == 1'b1); #0.1; cl;
        
        m_AWVALID_i <= 1'b0;
        counter = -1;
        for(int i = 0; i < 2400; i = i + 1) begin
            m_W_transfer(.WDATA({8'd00, 8'd01, 8'd02, 8'd03, 8'd04, 8'd05, 8'd06, 8'd07, 8'd00, 8'd01, 8'd02, 8'd03, 8'd04, 8'd05, 8'd06, 8'd07, 8'd00, 8'd01, 8'd02, 8'd03, 8'd04, 8'd05, 8'd06, 8'd07, 8'd00, 8'd01, 8'd02, 8'd03, 8'd04, 8'd05, 8'd06, 8'd07}), .WLAST(1'b0));
            // Wait for Handshake occuring
            wait(m_WREADY_o == 1'b1); #0.1;
            counter = counter + 1;
        end
        m_WVALID_i <= 1'b0;
        
    end
    task automatic m_AW_transfer(
        input [MST_ID_W-1:0]            AWID,
        input [ADDR_WIDTH-1:0]          AWADDR
    );
        cl;
        m_AWID_i    <= AWID;
        m_AWADDR_i  <= AWADDR;
        m_AWVALID_i <= 1'b1;
    endtask
    task automatic m_W_transfer (
        input [DATA_WIDTH-1:0]          WDATA,
        input                           WLAST
    );
        cl;
        m_WDATA_i   <= WDATA;
        m_WLAST_i   <= WLAST;
        m_WVALID_i  <= 1'b1;
    endtask
    task automatic cl;
        @(posedge ACLK_i); #0.01;
    endtask
endmodule
