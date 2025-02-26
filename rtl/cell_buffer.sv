module cell_buffer 
#(
    parameter DATA_WIDTH            = 256,
    parameter CELL_WIDTH            = 768,
    parameter PIXEL_WIDTH           = 8,
    parameter FRAME_ROW_CNUM        = 30,               // 30 cells
    parameter FRAME_COL_CNUM        = 40,               // 40 cells
    parameter CELL_ROW_PNUM         = 8,                // 8 pixels
    parameter CELL_COL_PNUM         = 8,                // 8 pixels
    parameter FRAME_COL_BNUM        = FRAME_COL_CNUM/2, // 20 blocks
    // Do not configure
    parameter ROW_ADDR_W            = $clog2(FRAME_ROW_CNUM),
    parameter COL_ADDR_W            = $clog2(FRAME_COL_CNUM),
    parameter CROW_ADDR_W           = $clog2(CELL_ROW_PNUM),
    parameter BCOL_ADDR_W           = $clog2(FRAME_COL_BNUM)
)
(
    // Input declaration 
    input                       clk,
    input                       rst,
    // -- To AXI4 Controller
    input   [DATA_WIDTH-1:0]    pgroup_i,
    // -- To Cell Controller
    input                       pgroup_wr_en_i,
    input   [ROW_ADDR_W-1:0]    row_addr_i,
    input   [CROW_ADDR_W-1:0]   crow_addr_i,
    input   [BCOL_ADDR_W-1:0]   bcol_addr_i,
    // -- To Cell Cache
    input   [COL_ADDR_W-1:0]    ccell_addr_i,
    input                       cell_store_i,
    // Output declaration
    // -- To Cell cache
    output  [CELL_WIDTH-1:0]    cell_data_o
);
    // Local parameter
    localparam IPXL_SIZE    = CELL_ROW_PNUM*CELL_COL_PNUM*PIXEL_WIDTH;
    localparam LOPXL_SIZE   = CELL_ROW_PNUM*PIXEL_WIDTH;
    localparam ROPXL_SIZE   = CELL_ROW_PNUM*PIXEL_WIDTH;
    localparam TOPXL_SIZE   = CELL_COL_PNUM*PIXEL_WIDTH;
    localparam BOPXL_SIZE   = CELL_COL_PNUM*PIXEL_WIDTH;
    // Internal variable
    genvar cell_idx;
    genvar crow_idx;
    genvar ccol_idx;
    genvar bit_idx;
    // Internal signal
    // -- wire
    reg     [PIXEL_WIDTH-1:0]   ipxl_d      [0:FRAME_COL_CNUM-1][0:CELL_ROW_PNUM-1][0:CELL_COL_PNUM-1];
    reg     [PIXEL_WIDTH-1:0]   l_opxl_d    [0:FRAME_COL_CNUM-1][0:CELL_ROW_PNUM-1];
    reg     [PIXEL_WIDTH-1:0]   r_opxl_d    [0:FRAME_COL_CNUM-1][0:CELL_ROW_PNUM-1];
    reg     [PIXEL_WIDTH-1:0]   t_opxl_d    [0:FRAME_COL_CNUM-1][0:CELL_COL_PNUM-1];
    reg     [PIXEL_WIDTH-1:0]   b_opxl_d    [0:FRAME_COL_CNUM-1][0:CELL_COL_PNUM-1];
    wire    [IPXL_SIZE-1:0]     ipxl_flat   [0:FRAME_COL_CNUM-1];
    wire    [LOPXL_SIZE-1:0]    l_opxl_flat [0:FRAME_COL_CNUM-1];
    wire    [ROPXL_SIZE-1:0]    r_opxl_flat [0:FRAME_COL_CNUM-1];
    wire    [TOPXL_SIZE-1:0]    t_opxl_flat [0:FRAME_COL_CNUM-1];
    wire    [BOPXL_SIZE-1:0]    b_opxl_flat [0:FRAME_COL_CNUM-1];
    // -- reg 
    reg     [PIXEL_WIDTH-1:0]   ipxl        [0:FRAME_COL_CNUM-1][0:CELL_ROW_PNUM-1][0:CELL_COL_PNUM-1];
    reg     [PIXEL_WIDTH-1:0]   l_opxl      [0:FRAME_COL_CNUM-1][0:CELL_ROW_PNUM-1];
    reg     [PIXEL_WIDTH-1:0]   r_opxl      [0:FRAME_COL_CNUM-1][0:CELL_ROW_PNUM-1];
    reg     [PIXEL_WIDTH-1:0]   t_opxl      [0:FRAME_COL_CNUM-1][0:CELL_COL_PNUM-1];
    reg     [PIXEL_WIDTH-1:0]   b_opxl      [0:FRAME_COL_CNUM-1][0:CELL_COL_PNUM-1];
    
    // Combination logic
    assign cell_data_o = {ipxl_flat[ccell_addr_i], t_opxl_flat[ccell_addr_i], l_opxl_flat[ccell_addr_i], r_opxl_flat[ccell_addr_i], b_opxl_flat[ccell_addr_i]};
    // -- Flattern
    generate
    for(cell_idx = 0; cell_idx < FRAME_COL_CNUM; cell_idx = cell_idx + 1) begin
        // -- -- Internal pixel 
        for(crow_idx = 0; crow_idx < CELL_ROW_PNUM; crow_idx = crow_idx + 1) begin
            for(ccol_idx = 0; ccol_idx < CELL_COL_PNUM; ccol_idx = ccol_idx + 1) begin
                assign ipxl_flat[cell_idx][crow_idx*(CELL_COL_PNUM*PIXEL_WIDTH) + (ccol_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH] = ipxl[cell_idx][crow_idx][ccol_idx];
            end
        end
        // -- -- Vertical pixel
        for(crow_idx = 0; crow_idx < CELL_ROW_PNUM; crow_idx = crow_idx + 1) begin
            assign l_opxl_flat[cell_idx][(crow_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH] = l_opxl[cell_idx][crow_idx];
            assign r_opxl_flat[cell_idx][(crow_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH] = r_opxl[cell_idx][crow_idx];
        end
        // -- -- Horizontal pixel
        for(ccol_idx = 0; ccol_idx < CELL_COL_PNUM; ccol_idx = ccol_idx + 1) begin
            assign t_opxl_flat[cell_idx][(ccol_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH] = t_opxl[cell_idx][ccol_idx];
            assign b_opxl_flat[cell_idx][(ccol_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH] = b_opxl[cell_idx][ccol_idx];
        end
    end
    endgenerate
    // -- Outer-left pixel 
    generate
    for(cell_idx = 0; cell_idx < FRAME_COL_CNUM; cell_idx = cell_idx + 1) begin
        for(crow_idx = 0; crow_idx < CELL_ROW_PNUM; crow_idx = crow_idx + 1) begin
            if(crow_idx != 0) begin // Cell row != 0
                if(cell_idx % 4 == 0) begin
                    always @(*) begin
                        l_opxl_d[cell_idx][crow_idx] = l_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if(((cell_idx-1)>>2) == (bcol_addr_i>>1)) begin
                                if(crow_idx == crow_addr_i) begin
                                    l_opxl_d[cell_idx][crow_idx] = pgroup_i[((31+1)*PIXEL_WIDTH)-1:31*PIXEL_WIDTH];
                                end
                            end
                        end
                    end
                end
                else if(cell_idx % 4 == 1) begin
                    always @(*) begin
                        l_opxl_d[cell_idx][crow_idx] = l_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                                if(crow_idx == crow_addr_i) begin
                                    l_opxl_d[cell_idx][crow_idx] = pgroup_i[((7+1)*PIXEL_WIDTH)-1:7*PIXEL_WIDTH];
                                end
                            end                    
                        end
                    end
                end
                else if(cell_idx % 4 == 2) begin
                    always @(*) begin
                        l_opxl_d[cell_idx][crow_idx] = l_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                                if(crow_idx == crow_addr_i) begin
                                    l_opxl_d[cell_idx][crow_idx] = pgroup_i[((15+1)*PIXEL_WIDTH)-1:15*PIXEL_WIDTH];
                                end
                            end                    
                        end
                    end
                end
                else if(cell_idx % 4 == 3) begin
                    always @(*) begin
                        l_opxl_d[cell_idx][crow_idx] = l_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                                if(crow_idx == crow_addr_i) begin
                                    l_opxl_d[cell_idx][crow_idx] = pgroup_i[((23+1)*PIXEL_WIDTH)-1:23*PIXEL_WIDTH];
                                end
                            end                    
                        end
                    end
                end
            end
            else begin // crow_idx == 0
                if(cell_idx % 4 == 0) begin
                    if(cell_idx != 0) begin // Underflow
                        always @(*) begin
                            l_opxl_d[cell_idx][crow_idx] = l_opxl[cell_idx][crow_idx];
                            if(pgroup_wr_en_i) begin
                                if((crow_addr_i == {CROW_ADDR_W{1'b0}}) & (row_addr_i == 0)) begin
                                    if(((cell_idx-1)>>2) == bcol_addr_i>>1) begin
                                        l_opxl_d[cell_idx][0] = pgroup_i[((31+1)*PIXEL_WIDTH)-1:31*PIXEL_WIDTH];
                                    end
                                end
                            end
                            else if(cell_store_i) begin
                                if(cell_idx == ccell_addr_i) begin
                                    l_opxl_d[cell_idx][0] = ipxl[cell_idx-1][0][7];
                                end
                            end
                        end
                    end
                end
                else if(cell_idx % 4 == 1) begin
                    always @(*) begin
                        l_opxl_d[cell_idx][crow_idx] = l_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((crow_addr_i == {CROW_ADDR_W{1'b0}}) & (row_addr_i == 0)) begin
                                if((cell_idx>>2) == bcol_addr_i>>1) begin
                                    l_opxl_d[cell_idx][0] = pgroup_i[((7+1)*PIXEL_WIDTH)-1:7*PIXEL_WIDTH];
                                end
                            end
                        end
                        else if(cell_store_i) begin
                            if(cell_idx == ccell_addr_i) begin
                                l_opxl_d[cell_idx][0] = b_opxl[cell_idx-1][7];
                            end
                        end
                    end
                end
                else if(cell_idx % 4 == 2) begin
                    always @(*) begin
                        l_opxl_d[cell_idx][crow_idx] = l_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((crow_addr_i == {CROW_ADDR_W{1'b0}}) & (row_addr_i == 0)) begin
                                if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                                    l_opxl_d[cell_idx][0] = pgroup_i[((15+1)*PIXEL_WIDTH)-1:15*PIXEL_WIDTH];
                                end
                            end
                        end
                        else if(cell_store_i) begin
                            if(cell_idx == ccell_addr_i) begin
                                l_opxl_d[cell_idx][0] = b_opxl[cell_idx-1][7];
                            end
                        end
                    end
                end
                else if(cell_idx % 4 == 3) begin
                    always @(*) begin
                        l_opxl_d[cell_idx][crow_idx] = l_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((crow_addr_i == {CROW_ADDR_W{1'b0}}) & (row_addr_i == 0)) begin
                                if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                                    l_opxl_d[cell_idx][0] = pgroup_i[((23+1)*PIXEL_WIDTH)-1:23*PIXEL_WIDTH];
                                end
                            end
                        end
                        else if(cell_store_i) begin
                            if(cell_idx == ccell_addr_i) begin
                                l_opxl_d[cell_idx][0] = b_opxl[cell_idx-1][7];
                            end
                        end
                    end
                end
            end
        end
    end
    endgenerate 
    // -- Outer-right pixel
    generate
    for(cell_idx = 0; cell_idx < FRAME_COL_CNUM; cell_idx = cell_idx + 1) begin
        for(crow_idx = 0; crow_idx < CELL_ROW_PNUM; crow_idx = crow_idx + 1) begin
            if(crow_idx != 0) begin
                if(cell_idx % 4 == 0) begin
                    always @(*) begin
                        r_opxl_d[cell_idx][crow_idx] = r_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                                if(crow_idx == crow_addr_i) begin
                                    r_opxl_d[cell_idx][crow_idx] = pgroup_i[((8+1)*PIXEL_WIDTH)-1:8*PIXEL_WIDTH];
                                end
                            end
                        end
                    end
                end
                else if(cell_idx % 4 == 1) begin
                    always @(*) begin
                        r_opxl_d[cell_idx][crow_idx] = r_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                                if(crow_idx == crow_addr_i) begin
                                    r_opxl_d[cell_idx][crow_idx] = pgroup_i[((16+1)*PIXEL_WIDTH)-1:16*PIXEL_WIDTH];
                                end
                            end
                        end
                    end
                end
                else if(cell_idx % 4 == 2) begin
                    always @(*) begin
                        r_opxl_d[cell_idx][crow_idx] = r_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                                if(crow_idx == crow_addr_i) begin
                                    r_opxl_d[cell_idx][crow_idx] = pgroup_i[((24+1)*PIXEL_WIDTH)-1:24*PIXEL_WIDTH];
                                end
                            end
                        end
                    end
                end
                else if(cell_idx % 4 == 3) begin
                    always @(*) begin
                        r_opxl_d[cell_idx][crow_idx] = r_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((cell_idx>>2) + 1 == (bcol_addr_i>>1)) begin
                                if(crow_idx == crow_addr_i) begin
                                    r_opxl_d[cell_idx][crow_idx] = pgroup_i[((0+1)*PIXEL_WIDTH)-1:0*PIXEL_WIDTH];
                                end
                            end
                        end
                    end
                end
            end
            else begin // crow_addr == 0
                if(cell_idx % 4 == 0) begin
                    always @(*) begin
                        r_opxl_d[cell_idx][crow_idx] = r_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((crow_addr_i == 0) & (row_addr_i == 0)) begin
                                if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                                    r_opxl_d[cell_idx][crow_idx] = pgroup_i[((8+1)*PIXEL_WIDTH)-1:8*PIXEL_WIDTH];
                                end
                            end
                        end
                        else if(cell_store_i) begin
                            if(cell_idx == ccell_addr_i) begin
                                r_opxl_d[cell_idx][crow_idx] = b_opxl[cell_idx + 1][0];
                            end
                        end
                    end
                end
                else if(cell_idx % 4 == 1) begin
                    always @(*) begin
                        r_opxl_d[cell_idx][crow_idx] = r_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((crow_addr_i == 0) & (row_addr_i == 0)) begin
                                if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                                    r_opxl_d[cell_idx][crow_idx] = pgroup_i[((16+1)*PIXEL_WIDTH)-1:16*PIXEL_WIDTH];
                                end
                            end
                        end
                        else if(cell_store_i) begin
                            if(cell_idx == ccell_addr_i) begin
                                r_opxl_d[cell_idx][crow_idx] = b_opxl[cell_idx + 1][0];
                            end
                        end
                    end
                end
                else if(cell_idx % 4 == 2) begin
                    always @(*) begin
                        r_opxl_d[cell_idx][crow_idx] = r_opxl[cell_idx][crow_idx];
                        if(pgroup_wr_en_i) begin
                            if((crow_addr_i == 0) & (row_addr_i == 0)) begin
                                if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                                    r_opxl_d[cell_idx][crow_idx] = pgroup_i[((24+1)*PIXEL_WIDTH)-1:24*PIXEL_WIDTH];
                                end
                            end
                        end
                        else if(cell_store_i) begin
                            if(cell_idx == ccell_addr_i) begin
                                r_opxl_d[cell_idx][crow_idx] = b_opxl[cell_idx + 1][0];
                            end
                        end
                    end
                end
                else if(cell_idx % 4 == 3) begin
                    if(cell_idx == 39) begin    // Last cell in 1 line
                        always @(*) begin
                            r_opxl_d[cell_idx][crow_idx] = r_opxl[cell_idx][crow_idx];
                            if(pgroup_wr_en_i) begin
                                if((crow_addr_i == 0) & (row_addr_i == 0)) begin
                                    if((cell_idx>>2) + 1 == (bcol_addr_i>>1)) begin
                                        r_opxl_d[cell_idx][crow_idx] = pgroup_i[((0+1)*PIXEL_WIDTH)-1:0*PIXEL_WIDTH];
                                    end
                                end
                            end
                        end
                    end
                    else begin
                        always @(*) begin
                            r_opxl_d[cell_idx][crow_idx] = r_opxl[cell_idx][crow_idx];
                            if(pgroup_wr_en_i) begin
                                if((crow_addr_i == 0) & (row_addr_i == 0)) begin
                                    if(((cell_idx+1)>>2) == (bcol_addr_i>>1)) begin
                                        r_opxl_d[cell_idx][crow_idx] = pgroup_i[((0+1)*PIXEL_WIDTH)-1:0*PIXEL_WIDTH];
                                    end
                                end
                            end
                            else if(cell_store_i) begin
                                if(cell_idx == ccell_addr_i) begin
                                    r_opxl_d[cell_idx][crow_idx] = b_opxl[cell_idx + 1][0];
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    endgenerate
    // -- Outer-bottom pixel 
    generate
    for(cell_idx = 0; cell_idx < FRAME_COL_CNUM; cell_idx = cell_idx + 1) begin
        for(ccol_idx = 0; ccol_idx < CELL_COL_PNUM; ccol_idx = ccol_idx + 1) begin
            always @(*) begin
                b_opxl_d[cell_idx][ccol_idx] = b_opxl[cell_idx][ccol_idx];
                if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                    if(crow_addr_i == 0) begin
                        b_opxl_d[cell_idx][ccol_idx] = pgroup_i[(cell_idx%4)*CELL_COL_PNUM*PIXEL_WIDTH + (ccol_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH];
                    end
                end
            end
        end
    end
    endgenerate
    // -- Outer-top pixel 
    generate
    for(cell_idx = 0; cell_idx < FRAME_COL_CNUM; cell_idx = cell_idx + 1) begin
        for(ccol_idx = 0; ccol_idx < CELL_COL_PNUM; ccol_idx = ccol_idx + 1) begin
            always @(*) begin
                t_opxl_d[cell_idx][ccol_idx] = t_opxl[cell_idx][ccol_idx];
                if(cell_store_i) begin
                    if(cell_idx == ccell_addr_i) begin
                        t_opxl_d[cell_idx][ccol_idx] = ipxl[cell_idx][7][ccol_idx];
                    end
                end
            end 
        end
    end
    endgenerate
    // -- Inter-pixel
    generate
    for(cell_idx = 0; cell_idx < FRAME_COL_CNUM; cell_idx = cell_idx + 1) begin
        for(crow_idx = 0; crow_idx < CELL_ROW_PNUM; crow_idx = crow_idx + 1) begin
            for(ccol_idx = 0; ccol_idx < CELL_COL_PNUM; ccol_idx = ccol_idx + 1) begin
                if(crow_idx == 0) begin
                    always @(*) begin
                        ipxl_d[cell_idx][crow_idx][ccol_idx] = ipxl[cell_idx][crow_idx][ccol_idx];
                        if(crow_idx == crow_addr_i) begin
                            if(row_addr_i == {ROW_ADDR_W{1'b0}}) begin
                                if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                                    if(pgroup_wr_en_i) begin
                                        ipxl_d[cell_idx][crow_idx][ccol_idx] = pgroup_i[(cell_idx%4)*CELL_COL_PNUM*PIXEL_WIDTH + (ccol_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH];
                                    end
                                end
                            end
                            else if(cell_store_i) begin
                                if(cell_idx == ccell_addr_i) begin
                                    ipxl_d[cell_idx][crow_idx][ccol_idx] = b_opxl[cell_idx][ccol_idx];
                                end
                            end
                        end
                    end
                end
                else begin  // crow_idx != 0
                    always @(*) begin
                        ipxl_d[cell_idx][crow_idx][ccol_idx] = ipxl[cell_idx][crow_idx][ccol_idx];
                        if((cell_idx>>2) == (bcol_addr_i>>1)) begin
                            if(crow_idx == crow_addr_i) begin
                                ipxl_d[cell_idx][crow_idx][ccol_idx] = pgroup_i[(cell_idx%4)*CELL_COL_PNUM*PIXEL_WIDTH + (ccol_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH];
                            end
                        end
                    end
                end
            end 
        end
    end
    endgenerate
    // Flip-flop logic
    // -- Vertical pixel
    generate
    for(cell_idx = 0; cell_idx < FRAME_COL_CNUM; cell_idx = cell_idx + 1) begin
        for(crow_idx = 0; crow_idx < CELL_ROW_PNUM; crow_idx = crow_idx + 1) begin
            always @(posedge clk) begin
                l_opxl[cell_idx][crow_idx] <= l_opxl_d[cell_idx][crow_idx];
                r_opxl[cell_idx][crow_idx] <= r_opxl_d[cell_idx][crow_idx];
            end
        end
    end
    endgenerate
    // -- Horizontal pixel
    generate
    for(cell_idx = 0; cell_idx < FRAME_COL_CNUM; cell_idx = cell_idx + 1) begin
        for(ccol_idx = 0; ccol_idx < CELL_COL_PNUM; ccol_idx = ccol_idx + 1) begin
            always @(posedge clk) begin
                t_opxl[cell_idx][ccol_idx] <= t_opxl_d[cell_idx][ccol_idx];
                b_opxl[cell_idx][ccol_idx] <= b_opxl_d[cell_idx][ccol_idx];
            end
        end
    end
    endgenerate
    // -- Internal pixel
    generate
    for(cell_idx = 0; cell_idx < FRAME_COL_CNUM; cell_idx = cell_idx + 1) begin
        for(crow_idx = 0; crow_idx < CELL_ROW_PNUM; crow_idx = crow_idx + 1) begin
            for(ccol_idx = 0; ccol_idx < CELL_COL_PNUM; ccol_idx = ccol_idx + 1) begin
                always @(posedge clk) begin
                    ipxl[cell_idx][crow_idx][ccol_idx] <= ipxl_d[cell_idx][crow_idx][ccol_idx];
                end
            end
        end
    end
    endgenerate
endmodule
