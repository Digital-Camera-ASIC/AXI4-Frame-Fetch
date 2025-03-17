module axi_controller
#(
    // Image Processor
    parameter IP_AMT        = 1,    // Image processor amount  
    parameter IP_ADDR_W     = $clog2(IP_AMT),
    parameter IP_DATA_W     = 256,
    // AXI-Stream configuration
    parameter AXIS_TID_W    = 2,
    parameter AXIS_TDEST_W  = (IP_ADDR_W > 1) ? IP_ADDR_W : 1,
    parameter AXIS_TDATA_W  = IP_DATA_W,
    parameter AXIS_TKEEP_W  = AXIS_TDATA_W/8,
    parameter AXIS_TSTRB_W  = AXIS_TDATA_W/8
)
(
    // Input declaration
    // -- Global signals
    input                       clk,
    input                       rst_n,
    // -- AXI-Stream interface
    input   [AXIS_TID_W-1:0]    s_tid_i,    
    input   [AXIS_TDEST_W-1:0]  s_tdest_i, 
    input   [AXIS_TDATA_W-1:0]  s_tdata_i,
    input   [AXIS_TKEEP_W-1:0]  s_tkeep_i,
    input   [AXIS_TSTRB_W-1:0]  s_tstrb_i,
    input                       s_tlast_i,
    input                       s_tvalid_i,
    output                      s_tready_o,
    // -- To Image Processor
    output  [IP_DATA_W-1:0]     pgroup_o,
    output  [IP_AMT-1:0]        pgroup_valid_o,
    input   [IP_AMT-1:0]        pgroup_ready_i
);
    // Local parameter
    localparam IP_BIT_MAP   = 0; // Select bit is the first bit
    localparam AXIS_INFO_W  = AXIS_TDEST_W + AXIS_TDATA_W;
    
    // Internal variable
    genvar ip_idx;
    
    // Internal signal
    wire    [AXIS_TID_W-1:0]    s_tid;    
    wire    [AXIS_TDEST_W-1:0]  s_tdest;
    wire    [AXIS_TDATA_W-1:0]  s_tdata;
    wire    [AXIS_TKEEP_W-1:0]  s_tkeep;
    wire    [AXIS_TSTRB_W-1:0]  s_tstrb;
    wire                        s_tlast;
    wire                        s_tvalid;
    wire                        s_tready;
    // -- -- Frame fetch
    wire    [IP_ADDR_W-1:0]     ip_addr;      
    wire                        pixel_valid_en;          
    
    // Internal module
    // -- AXI-Stream skid buffer
    skid_buffer #(
        .SBUF_TYPE  (4),          // By-pass
        .DATA_WIDTH (AXIS_INFO_W)
    ) axis_sb (
        .clk        (clk),
        .rst_n      (rst_n),
        .bwd_data_i ({s_tdest_i,    s_tdata_i}),
        .bwd_valid_i(s_tvalid_i),
        .bwd_ready_o(s_tready_o),
        .fwd_data_o ({s_tdest,      s_tdata}),
        .fwd_valid_o(s_tvalid),
        .fwd_ready_i(s_tready)
    );
    
    // Combination logic
    assign ip_addr                      = s_tdest[IP_BIT_MAP];
    assign pixel_valid_en               = s_tvalid;
    assign pgroup_o                     = s_tdata;
    generate
    if(IP_AMT == 1) begin
        assign s_tready                 = pgroup_ready_i;
        assign pgroup_valid_o           = pixel_valid_en;
    end
    else begin
        assign s_tready                 = pgroup_ready_i[ip_addr];
        for(ip_idx = 0; ip_idx < IP_AMT; ip_idx = ip_idx + 1) begin
           assign pgroup_valid_o[ip_idx]= (ip_addr == ip_idx) & pixel_valid_en;
        end
    end
    endgenerate
endmodule
