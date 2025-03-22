`timescale 1ns / 1ps

`define DEBUG

module axi_frame_fetch_tb;
    // Features configuration
    // Image Processor
    parameter IP_AMT            = 1;    // Image processor amount  
    parameter IP_ADDR_W         = $clog2(IP_AMT);
    parameter IP_DATA_W         = 256;
    // AXI-Stream configuration
    parameter AXIS_TDEST_MSK    = 1'b0;
    parameter AXIS_TID_W        = 2;
    parameter AXIS_TDEST_W      = (IP_ADDR_W > 1) ? IP_ADDR_W : 1;
    parameter AXIS_TDATA_W      = IP_DATA_W;
    parameter AXIS_TKEEP_W      = AXIS_TDATA_W/8;
    parameter AXIS_TSTRB_W      = AXIS_TDATA_W/8;
    // Image processor configuaration
    parameter PG_WIDTH          = 256;
    parameter PIXEL_WIDTH       = 8;
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
    
    class image;
        bit [7:0] data[240 - 1 : 0][320 - 1 : 0];
    endclass
    class axi_transaction;
        rand bit [AXIS_TDATA_W - 1 : 0] data;
        bit [2 - 1 : 0] addr = 0;
    endclass
    class image_cell;
        rand bit [CELL_WIDTH - 1 : 0] data;
    endclass
    axi_transaction myAXI;
    axi_transaction axi_queue[$];
    image_cell myCell;
    image_cell cell_queue[$];
    logic                           s_aclk;
    logic                           s_aresetn;
    // -- AXI-Stream interface
    logic  [AXIS_TID_W-1:0]         s_tid_i;    
    logic  [AXIS_TDEST_W-1:0]       s_tdest_i; 
    logic  [AXIS_TDATA_W-1:0]       s_tdata_i;
    logic  [AXIS_TKEEP_W-1:0]       s_tkeep_i;
    logic  [AXIS_TSTRB_W-1:0]       s_tstrb_i;
    logic                           s_tlast_i;
    logic                           s_tvalid_i;
    logic                           s_tready_o;

    logic   [IP_AMT*CELL_WIDTH-1:0] cell_data_o;
    logic   [IP_AMT-1:0]            cell_ready_i;
    logic   [IP_AMT-1:0]            cell_valid_o;
    
    
    logic   [PIXEL_WIDTH-1:0]   cell_ipxl   [0:CELL_ROW_PNUM-1][0:CELL_COL_PNUM-1];
    logic   [PIXEL_WIDTH-1:0]   cell_l_opxl [0:CELL_ROW_PNUM-1];
    logic   [PIXEL_WIDTH-1:0]   cell_r_opxl [0:CELL_ROW_PNUM-1];
    logic   [PIXEL_WIDTH-1:0]   cell_t_opxl [0:CELL_COL_PNUM-1];
    logic   [PIXEL_WIDTH-1:0]   cell_b_opxl [0:CELL_COL_PNUM-1];
    
    
    localparam IPXL_SIZE    = CELL_ROW_PNUM*CELL_COL_PNUM*PIXEL_WIDTH;
    localparam LOPXL_SIZE   = CELL_ROW_PNUM*PIXEL_WIDTH;
    localparam ROPXL_SIZE   = CELL_ROW_PNUM*PIXEL_WIDTH;
    localparam TOPXL_SIZE   = CELL_COL_PNUM*PIXEL_WIDTH;
    localparam BOPXL_SIZE   = CELL_COL_PNUM*PIXEL_WIDTH;
    wire    [IPXL_SIZE-1:0]     ipxl_flat  ;
    wire    [LOPXL_SIZE-1:0]    l_opxl_flat;
    wire    [ROPXL_SIZE-1:0]    r_opxl_flat;
    wire    [TOPXL_SIZE-1:0]    t_opxl_flat;
    wire    [BOPXL_SIZE-1:0]    b_opxl_flat;
    
    assign {ipxl_flat, t_opxl_flat, l_opxl_flat, r_opxl_flat, b_opxl_flat} = cell_data_o;
    
    genvar row_idx;
    genvar col_idx;
    	integer fd;

	initial begin
		// Open a new file by the name "my_file.txt"
		// with "write" permissions, and store the file
		// handler pointer in variable "fd"
		fd = $fopen("L:/Projects/axi4_hog_accel/axi4_frame_fetch/sim/tb/myLog.txt", "w");

	end

    generate
        // -- -- Internal pixel 
        for(row_idx = 0; row_idx < CELL_ROW_PNUM; row_idx = row_idx + 1) begin
            for(col_idx = 0; col_idx < CELL_COL_PNUM; col_idx = col_idx + 1) begin
                assign cell_ipxl[row_idx][col_idx] = ipxl_flat[row_idx*(CELL_COL_PNUM*PIXEL_WIDTH) + (col_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH];
            end
        end
        // -- -- Vertical pixel
        for(row_idx = 0; row_idx < CELL_ROW_PNUM; row_idx = row_idx + 1) begin
            assign cell_l_opxl[row_idx] = l_opxl_flat[(row_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH];
            assign cell_r_opxl[row_idx] = r_opxl_flat[(row_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH];
        end
        // -- -- Horizontal pixel
        for(col_idx = 0; col_idx < CELL_COL_PNUM; col_idx = col_idx + 1) begin
            assign cell_t_opxl[col_idx] = t_opxl_flat[(col_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH];
            assign cell_b_opxl[col_idx] =  b_opxl_flat[(col_idx+1)*PIXEL_WIDTH-1-:PIXEL_WIDTH];
        end
    endgenerate
    
    axi_frame_fetch #(
        .AXIS_TDEST_MSK (AXIS_TDEST_MSK)
    )
    uut(
        .*
    );
    
    reg [31:0]  counter;
    
    initial begin
        s_aclk      <= 1'b0;
        s_aresetn   <= 1'b0;

        s_tid_i     <= 0;
        s_tdest_i   <= 0;   
        s_tdata_i   <= 0;
        s_tkeep_i   <= 0;
        s_tstrb_i   <= 0;
        s_tlast_i   <= 0;
        s_tvalid_i  <= 0;

        cell_ready_i <= 1'b1;

        #9;
        s_aresetn <= 1'b1;
        
        
    end
    initial begin
        forever #1 s_aclk <= ~s_aclk;
    end
    
    initial begin // driver
        #20;
        s_tvalid_i <= 1'b0;
        counter = -1;
        for(int i = 0; i < 2400; i = i + 1) begin
            myAXI = new;
            myAXI.randomize();
            axis_transfer(.s_tdest(1'b0), .s_tdata(myAXI.data), .s_tlast(1'b0));
            // Wait for Handshake occuring
            wait(s_tready_o == 1'b1); #0.1;
            counter = counter + 1;
            axi_queue.push_back(myAXI);
        end
        cl;
        s_tvalid_i <= 1'b0;
        
    end

    initial begin // monitor
        forever begin
            cl;
            wait(cell_valid_o[0]);
            myCell = new;
            myCell.data = cell_data_o;
            cell_queue.push_back(myCell);
        end
    end
    
    bit [CELL_WIDTH - 1 : 0] temp;
    int trans_cnt = 0;
    int v_id = 0;
    int h_id = 0;
    bit cp_flag = 0;
    image gm = new();
    bit [7:0] gm_data;
    string str;
    initial begin // scoreboard
        
        fork
             begin // predictor
                 forever begin
                     wait(axi_queue.size);
`ifdef DEBUG
$sformat(str,"AXI[%0d]: %h\n", trans_cnt, axi_queue[0].data);
$fwrite(fd, str);
`endif
                     for(int i = 0; i < 32; i++) begin
                         v_id = (trans_cnt % 10) * 32 + i;
                         h_id = trans_cnt / 10;

                         gm.data[h_id][v_id] = axi_queue[0].data[i*8+:8];
                     end
                     trans_cnt++;
                     if(trans_cnt == 2400) begin
                         cp_flag = 1;
                         trans_cnt = 0;
                     end
                     axi_queue.pop_front();
                 end
             end
            begin // comparator
                forever begin
                    wait(cp_flag);
                    cp_flag = 0;
                    for(int cell_cnt = 0; cell_cnt < 1200; cell_cnt++) begin
                        wait(cell_queue.size);
`ifdef DEBUG
$sformat(str,"CELL[%0d]: %h\n", cell_cnt, cell_queue[0].data);
$fwrite(fd, str);
`endif
                        for(int j = 0; j < 10*10 - 4; j++) begin
                            gm_data = 0;
                            v_id = (cell_cnt % 40) * 8 + j % 8;
                            h_id = (cell_cnt / 40) * 8  + j / 8;
                            if(j >= 64 && j <= 71) begin
                                if(cell_cnt < 40) begin
                                    v_id = -1;
                                end else begin
                                    v_id = (cell_cnt % 40) * 8 + j % 8;
                                    h_id = (cell_cnt / 40 - 1) * 8  + 7;
                                end
                            end
                            if(j >= 72 && j <= 79) begin
                                if(cell_cnt % 40 == 0) begin
                                    v_id = -1;
                                end else begin
                                    v_id = ((cell_cnt - 1) % 40) * 8 + 7;
                                    h_id = (cell_cnt / 40) * 8  + (j - 72);
                                end
                            end
                            if(j >= 80 && j <= 87) begin
                                if((cell_cnt + 1) % 40 == 0) begin
                                    v_id = -1;
                                end else begin
                                    v_id = ((cell_cnt + 1) % 40) * 8;
                                    h_id = (cell_cnt / 40) * 8  + (j - 80);
                                end
                            end
                            if(j >= 88 && j <= 95) begin
                                if(cell_cnt + 40 >= 1200) begin
                                    v_id = -1;
                                end else begin
                                    v_id = (cell_cnt % 40) * 8 + j % 8;
                                    h_id = (cell_cnt / 40 + 1) * 8;
                                end
                            end
                            if(v_id < 0)
                                gm_data = 0;
                            else
                                gm_data = gm.data[h_id][v_id];
                            temp = cell_queue[0].data;
`ifdef DEBUG
$sformat(str,"---------PRINT GOLDEN MODEL-----\n");
$fwrite(fd, str);
$sformat(str,"v_id: %0d\n", v_id);
$fwrite(fd, str);
$sformat(str,"h_id: %0d\n", h_id);
$fwrite(fd, str);
$sformat(str,"j: %0d\n", j);
$fwrite(fd, str);
$sformat(str,"gm_data: %h\n", gm_data);
$fwrite(fd, str);
$sformat(str,"--------------\n");
$fwrite(fd, str);
`endif
                            if(gm_data != temp[8*j +: 8]) begin
$sformat(str,"ERROR: lhs = %h, rhs = %h\n", gm.data[h_id][v_id], temp[8*j +: 8]);
$fwrite(fd, str);
                            end
                        end
                        cell_queue.pop_front();
                    end
                end
            end
        join
    end
    task automatic axis_transfer (
        input [AXIS_TDEST_W-1:0]    s_tdest,
        input [AXIS_TDATA_W-1:0]    s_tdata,
        input                       s_tlast
    );
        cl;
        s_tdest_i   <= s_tdest;
        s_tdata_i   <= s_tdata;
        s_tlast_i   <= s_tlast;
        s_tvalid_i  <= 1'b1;
    endtask
    task automatic cl;
        @(posedge s_aclk); #0.01;
    endtask
endmodule
