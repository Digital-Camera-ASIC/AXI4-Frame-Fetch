module axi4_controller
#(
    // Features configuration
    parameter                       IP_AMT              = 1,    // Image processor amount    
    // AXI4 configuration
    parameter                       MST_ID_W            = 3,
    parameter                       DATA_WIDTH          = 256,
    parameter                       ADDR_WIDTH          = 32,
    parameter                       TRANS_BURST_W       = 2,    // Width of xBURST 
    parameter                       TRANS_DATA_LEN_W    = 3,    // Bus width of xLEN
    parameter                       TRANS_DATA_SIZE_W   = 3,    // Bus width of xSIZE
    parameter                       TRANS_WR_RESP_W     = 2
)
(
    // Input declaration
    // -- Global signals
    input                           ACLK_i,
    input                           ARESETn_i,
    // -- To Master (slave interface of the interconnect)
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
    // -- To Image Processor
    input   [IP_AMT-1:0]            pgroup_ready_i,
    input   [IP_AMT-1:0]            frame_complete_i,
    // Output declaration
    // -- To Master (slave interface of interconnect)
    // ---- Write address channel (master)
    output                          m_AWREADY_o,
    // ---- Write data channel (master)
    output                          m_WREADY_o,
    // ---- Write response channel (master)
    output  [MST_ID_W-1:0]          m_BID_o,
    output  [TRANS_WR_RESP_W-1:0]   m_BRESP_o,
    output                          m_BVALID_o,
    // -- To Image Processor
    output  [DATA_WIDTH-1:0]        pgroup_o,
    output  [IP_AMT-1:0]            pgroup_valid_o
);
    // Local parameter intialization
    localparam IP_BIT_MAP   = 27;
    localparam IP_ADDR_W    = $clog2(IP_AMT);
    localparam AW_INFO_W    = MST_ID_W + ADDR_WIDTH;
    localparam W_INFO_W     = DATA_WIDTH;
    localparam B_INFO_W     = MST_ID_W + TRANS_WR_RESP_W;
    
    // Internal variable
    genvar ip_idx;
    
    // Internal signal
    // -- wire declaration
    // -- -- AW skid buffer
    wire    [AW_INFO_W-1:0]     AW_bwd_data_i;
    wire                        AW_bwd_valid;
    wire                        AW_bwd_ready;
    wire    [AW_INFO_W-1:0]     AW_fwd_data_o;
    wire                        AW_fwd_valid;
    wire                        AW_fwd_ready;
    wire    [MST_ID_W-1:0]      AW_fwd_AWID;
    wire    [ADDR_WIDTH-1:0]    AW_fwd_AWADDR;
    // -- -- W skid buffer
    wire    [W_INFO_W-1:0]      W_bwd_data_i;
    wire                        W_bwd_valid;
    wire                        W_bwd_ready;
    wire    [W_INFO_W-1:0]      W_fwd_data_o;
    wire                        W_fwd_valid;
    wire                        W_fwd_ready;
    // -- -- B skid buffer
    wire    [B_INFO_W-1:0]      B_bwd_data_i;
    wire                        B_bwd_valid;
    wire                        B_bwd_ready;
    wire    [B_INFO_W-1:0]      B_fwd_data_o;
    wire                        B_fwd_valid;
    wire                        B_fwd_ready;
    // -- -- Frame fetch
    wire    [IP_ADDR_W-1:0]     ip_addr;      
    wire                        pixel_valid_en;          
    
    // Internal module
    // -- AW skid buffer
    skid_buffer #(
        .SBUF_TYPE(0),          // Full-registered
        .DATA_WIDTH(AW_INFO_W)
    ) AW_skid_buffer (
        .clk        (ACLK_i),
        .rst_n      (ARESETn_i),
        .bwd_data_i (AW_bwd_data_i),
        .bwd_valid_i(AW_bwd_valid),
        .fwd_ready_i(AW_fwd_ready),
        .fwd_data_o (AW_fwd_data_o),
        .bwd_ready_o(AW_bwd_ready),
        .fwd_valid_o(AW_fwd_valid)
    );
    // -- W skid buffer
    skid_buffer #(
        .SBUF_TYPE(0),          // Full-registered
        .DATA_WIDTH(W_INFO_W)
    ) W_skid_buffer (
        .clk        (ACLK_i),
        .rst_n      (ARESETn_i),
        .bwd_data_i (W_bwd_data_i),
        .bwd_valid_i(W_bwd_valid), 
        .fwd_ready_i(W_fwd_ready), 
        .fwd_data_o (W_fwd_data_o),
        .bwd_ready_o(W_bwd_ready), 
        .fwd_valid_o(W_fwd_valid)  
    );
    // -- B skid buffer
    skid_buffer #(
        .SBUF_TYPE(0),          // Full-registered
        .DATA_WIDTH(B_INFO_W)
    ) B_skid_buffer (
        .clk        (ACLK_i),
        .rst_n      (ARESETn_i),
        .bwd_data_i (B_bwd_data_i),
        .bwd_valid_i(B_bwd_valid), 
        .fwd_ready_i(B_fwd_ready), 
        .fwd_data_o (B_fwd_data_o),
        .bwd_ready_o(B_bwd_ready), 
        .fwd_valid_o(B_fwd_valid)  
    );
    
    // Combination logic
    // -- Output
    assign m_AWREADY_o                  = AW_bwd_ready;
    assign m_WREADY_o                   = W_bwd_ready;
    assign m_BVALID_o                   = B_fwd_valid;
    assign m_BID_o                      = B_fwd_data_o;
    assign m_BRESP_o                    = 2'b00;        // Always "OK"
    // -- AW skid buffer
    assign AW_bwd_data_i                = {m_AWID_i, m_AWADDR_i};
    assign AW_bwd_valid                 = m_AWVALID_i;
    assign {AW_fwd_AWID, AW_fwd_AWADDR} = AW_fwd_data_o;
    assign AW_fwd_ready                 = frame_complete_i[ip_addr];
    // -- W skid buffer
    assign W_bwd_data_i                 = m_WDATA_i;
    assign W_bwd_valid                  = m_WVALID_i;
    assign W_fwd_ready                  = AW_fwd_valid & pgroup_ready_i[ip_addr];
    // -- B skid buffer
    assign B_bwd_data_i                 = {AW_fwd_AWID}; 
    assign B_bwd_valid                  = frame_complete_i[ip_addr] & AW_fwd_valid;
    assign B_fwd_ready                  = m_BREADY_i;
    // -- Frame fetch
    assign ip_addr                      = AW_fwd_AWADDR[IP_BIT_MAP];
    assign pixel_valid_en               = AW_fwd_valid & W_fwd_valid;
    assign pgroup_o                     = W_fwd_data_o;
    generate
    if(IP_AMT == 1) begin
        assign pgroup_valid_o           = pixel_valid_en;
    end
    else begin
        for(ip_idx = 0; ip_idx < IP_AMT; ip_idx = ip_idx + 1) begin
           assign pgroup_valid_o[ip_idx]                                = (ip_addr == ip_idx) & pixel_valid_en;
        end
    end
    endgenerate
endmodule
