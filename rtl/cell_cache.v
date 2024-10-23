module cell_cache
#(
    parameter CELL_WIDTH        = 768,
    parameter CELL_NUM          = 1200,
    // Do not configure
    parameter CELL_ADDR_W       = $clog2(CELL_NUM)
)
(   
    // Input declaration
    input                           clk,
    input                           rst,
    // -- To Cell Buffer
    input                           cell_wr_en_i,
    input   [CELL_WIDTH-1:0]        cell_wr_data_i,
    input   [CELL_ADDR_W-1:0]       cell_wr_addr_i,
    // -- To Cell Fetch
    input   [CELL_ADDR_W-1:0]       cell_rd_addr_i,
    // Output declaration
    // -- To Cell Fetch 
    output  [CELL_WIDTH-1:0]        cell_rd_data_o
);
    // Internal signal
    reg [CELL_WIDTH-1:0]    cell_mem    [0:CELL_NUM-1];
    
    // Combination logic
    assign cell_rd_data_o = cell_mem[cell_rd_addr_i];
    
    // RAM (Too big to use flip-flops -> Please infer BRAM or other RAM technology)
    always @(posedge clk) begin
        if(cell_wr_en_i) begin
            cell_mem[cell_wr_addr_i] <= cell_wr_data_i;
        end
    end
    
endmodule
