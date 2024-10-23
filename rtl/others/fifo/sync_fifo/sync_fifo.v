module sync_fifo
    #(
    parameter  DATA_WIDTH    = 8,
    parameter  FIFO_DEPTH    = 32,
    // Do not configure
    parameter  ADDR_WIDTH    = $clog2(FIFO_DEPTH)
    )
    (
    input                               clk,
    
    input           [DATA_WIDTH - 1:0]  data_i,
    output  wire    [DATA_WIDTH-1:0]    data_o,
    
    input                               wr_valid_i,
    input                               rd_valid_i,
    
    output  reg                         empty_o,
    output  reg                         full_o,
    output  reg                         wr_ready_o,     // Optional
    output  reg                         rd_ready_o,     // Optional
    output  wire                        almost_empty_o, // Optional
    output  wire                        almost_full_o,  // Optional
    
    output  [ADDR_WIDTH:0]              counter,        // Optional
    input                               rst_n
    );
    // Internal variable declaration
    genvar addr;
    
    // Internal signal declaration
    // wire declaration
    // -- Common
    wire[DATA_WIDTH - 1:0]  buffer_nxt [0:FIFO_DEPTH - 1];
    wire                    full_r_en;
    wire                    empty_r_en;
    wire                    full_nxt;
    wire                    empty_nxt;
    // -- Write handle
    wire                    wr_handshake;
    wire[ADDR_WIDTH:0]      wr_addr_inc;
    wire[ADDR_WIDTH - 1:0]  wr_addr_map;
    // -- Read handle
    wire                    rd_handshake;
    wire[ADDR_WIDTH:0]      rd_addr_inc;
    wire[ADDR_WIDTH - 1:0]  rd_addr_map;
    
    // reg declaration
	reg [DATA_WIDTH - 1:0]  buffer     [0:FIFO_DEPTH - 1];
	reg [ADDR_WIDTH:0]      wr_addr;
    reg [ADDR_WIDTH:0]      rd_addr;
    
    // combinational logic
    // -- Common
    assign data_o = buffer[rd_addr_map];
    // -- Write handle
    assign wr_addr_inc      = wr_addr + 1'b1;
    assign wr_addr_map      = wr_addr[ADDR_WIDTH - 1:0];
    assign wr_handshake     = wr_valid_i & !full_o;
    // -- Read handle
    assign rd_addr_inc      = rd_addr + 1'b1;
    assign rd_addr_map      = rd_addr[ADDR_WIDTH - 1:0];
    assign rd_handshake     = rd_valid_i & !empty_o;
    // -- Common
    assign empty_r_en       = wr_handshake | rd_handshake;
    assign full_r_en        = wr_handshake | rd_handshake;
    assign empty_nxt        = (rd_handshake & almost_empty_o) & (~wr_handshake);
    assign full_nxt         = (wr_handshake & almost_full_o) & (~rd_handshake);
    assign almost_empty_o   = rd_addr_inc ==  wr_addr;
    assign almost_full_o    = wr_addr_map + 1'b1 == rd_addr_map;
    assign counter          = wr_addr - rd_addr;
    
    generate
        for(addr = 0; addr < FIFO_DEPTH; addr = addr + 1) begin
            assign buffer_nxt[addr] = (wr_addr_map == addr) ? data_i : buffer[addr];
        end
    endgenerate
    
    // flip-flop logic
    // -- Buffer updater
    generate
        for(addr = 0; addr < FIFO_DEPTH; addr = addr + 1) begin
            always @(posedge clk) begin
                if(!rst_n) begin 
                    buffer[addr] <= {DATA_WIDTH{1'b0}};
                end
                else if(wr_valid_i & !full_o) begin
                    buffer[addr] <= buffer_nxt[addr];
                end
            end
        end
    endgenerate
    // -- Write pointer updater
    always @(posedge clk) begin
        if(!rst_n) begin 
            wr_addr <= 0;        
        end
        else if(wr_handshake) begin
            wr_addr <= wr_addr_inc;
        end
    end
    // -- Read pointer updater
    always @(posedge clk) begin
        if(!rst_n) begin
            rd_addr <= 0;
        end
        else if(rd_handshake) begin
            rd_addr <= rd_addr_inc;
        end
    end
    // -- Full signal update
    always @(posedge clk) begin
        if(!rst_n) begin
            full_o <= 1'b0;
        end
        else if(full_r_en) begin
            full_o <= full_nxt;
        end
    end
    // -- Write Ready update (optional)
    always @(posedge clk) begin
        if(!rst_n) begin
            wr_ready_o <= 1'b1;
        end
        else if(full_r_en) begin
            wr_ready_o <= ~full_nxt;
        end
    end
    // -- Empty signal update
    always @(posedge clk) begin
        if(!rst_n) begin
            empty_o <= 1'b1;
        end
        else if(empty_r_en) begin
            empty_o <= empty_nxt;
        end
    end
    // -- Read ready update
    always @(posedge clk) begin
        if(!rst_n) begin
            rd_ready_o <= 1'b0;
        end
        else if(empty_r_en) begin
            rd_ready_o <= ~empty_nxt;
        end
    end
endmodule
//    sync_fifo 
//        #(
//        .DATA_WIDTH(),
//        .FIFO_DEPTH(32)
//        ) fifo (
//        .clk(clk),
//        .data_i(),
//        .data_o(),
//        .rd_valid_i(),
//        .wr_valid_i(),
//        .empty_o(),
//        .full_o(),
//        .almost_empty_o(),
//        .almost_full_o(),
//        .rst_n(rst_n)
//        );