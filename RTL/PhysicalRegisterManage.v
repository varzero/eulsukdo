// 컨셉변경: PHYREG 내부 버퍼 다쓰면 걍 멈추기

module prm #(
	parameter NUM_OF_PHY_REGS = 64,
	parameter IST_ENTRIES = 128,
	parameter OPREANDS = 2,
    
    parameter NUM_OF_NEW_ENTRIES = 2,
    parameter NUM_OF_WB_ENTRIES = 5,
	parameter NUM_OF_DESTROY_ENTRIES = 4,
	parameter BUF_ENTRIES_PER_PHYREG = 4,
	parameter OPREANDS = 2,

    parameter FIFO_DEPTH = 10,

	localparam BUF_ENTRIES_CNT_BITWIDTH = $clog2(BUF_ENTRIES_PER_PHYREG),
	localparam IST_ADDR_WIDTH = $clog2(IST_ENTRIES),
	localparam PHYREG_ADDR_WIDTH = $clog2(NUM_OF_PHY_REGS)
) (
    input clk,
    input reset_n,

	// Allocate PHYREG
	input [NUM_OF_NEW_ENTRIES-1:0] allocate_phyreg_get_i,
	output [NUM_OF_NEW_ENTRIES-1:0] allocate_phyreg_valid_o,
	output [(NUM_OF_NEW_ENTRIES * PHYREG_ADDR_WIDTH)-1:0] allocate_phyregs_o,

	// Unallocate PHYREG
	input [NUM_OF_DESTROY_ENTRIES-1:0] unallocate_phyreg_valid_i,
	input [(NUM_OF_DESTROY_ENTRIES * PHYREG_ADDR_WIDTH)-1:0] unallocate_phyregs_i,

	// PHYREG Use IST Mapping, Process on New Entry Logic
	input [(NUM_OF_NEW_ENTRIES * OPREANDS)-1:0] target_ist_valid_i,
	input [(NUM_OF_NEW_ENTRIES * IST_ADDR_WIDTH)-1:0] target_ist_entry_i,
	input [((NUM_OF_NEW_ENTRIES * OPREANDS) * PHYREG_ADDR_WIDTH)-1:0] target_phyregs_i,

	// Ready signal send to IST from PHYREG
	output [NUM_OF_WB_ENTRIES-1:0] ready_valid_o,
	output [(NUM_OF_WB_ENTRIES * PHYREG_ADDR_WIDTH)-1:0] ready_phyreg_o,
	output [(NUM_OF_WB_ENTRIES * IST_ADDR_WIDTH)-1:0] ready_ist_entrites_o,

	// Write Back PHY Registers NUMBERS
	input [NUM_OF_WB_ENTRIES-1:0] wb_done_valid_i,
	input [(NUM_OF_WB_ENTRIES * PHYREG_ADDR_WIDTH)-1:0] wb_done_phyreg_i,

    output active
);
		// 주소는 PHYREG 번호 엔트리는 [ (d_n-1, ... , d_2, d_1, d_0) | 채워진 버퍼 수 ]
	localparam MAP_RF_ENTRY_WIDTH = ( IST_ADDR_WIDTH * BUF_ENTRIES_PER_PHYREG )+ BUF_ENTRIES_CNT_BITWIDTH;
	localparam MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH = NUM_OF_NEW_ENTRIES * OPREANDS;

		// 엔트리는 [ IST INDEX | PHYREG ]
	localparam OUT_WB_ENTRY_WIDTH = IST_ADDR_WIDTH + PHYREG_ADDR_WIDTH;

	wire phyreg_allocate_reg_done, sram_allocate_reg_done;
	wire [(MAP_RF_ENTRY_WIDTH * (NUM_OF_WB_ENTRIES + MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH))-1:0] map_rf_read_out;
	
	// BUFFER RF 업데이트용
	reg [MAP_RF_ENTRY_WIDTH-1:0] map_rf_read_update_split[0:(MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH)-1];
	reg [MAP_RF_ENTRY_WIDTH-1:0] map_rf_read_wb_split[0:(NUM_OF_WB_ENTRIES)-1];
	reg [(MAP_RF_ENTRY_WIDTH * (NUM_OF_WB_ENTRIES + MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH))-1:0] map_rf_write_update_split;
	
	reg [OUT_WB_ENTRY_WIDTH] map_rf_2_ready_out[BUF_ENTRIES_PER_PHYREG];
	reg [OUT_WB_ENTRY_WIDTH * BUF_ENTRIES_PER_PHYREG] map_rf_2_ready_out_fifo_push[OUT_WB_ENTRY_WIDTH];

	reg [PHYREG_ADDR_WIDTH-1:0] current_phyreg;
	reg [IST_ADDR_WIDTH-1:0] current_ist;
	reg [BUF_ENTRIES_CNT_BITWIDTH-1:0] current_rf_data_cnt;
	reg [BUF_ENTRIES_CNT_BITWIDTH-1:0] new_rf_data_cnt;
	reg [IST_ADDR_WIDTH-1:0] rf_buf[BUF_ENTRIES_PER_PHYREG];
	reg [(IST_ADDR_WIDTH * BUF_ENTRIES_PER_PHYREG)-1:0] rf_buf_wide;
	reg [NUM_OF_PHY_REGS-1:0] max_buf, max_buf_next;

	integer now_rf_target, now_buf_target;

	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			max_buf <= 0;
		end
		else begin
			max_buf <= max_buf_next;
		end
	end

	always @(*) begin
		max_buf_next = max_buf;

		// RF Out 분리부터, WB쪽은 따로 분리
		for (now_rf_target = 0; now_rf_target < MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH; now_rf_target = now_rf_target + 1) begin
			map_rf_read_update_split[now_rf_target] = map_rf_read_out[(now_rf_target * MAP_RF_ENTRY_WIDTH) +: MAP_RF_ENTRY_WIDTH]; 
		end
		for (now_rf_target = 0; now_rf_target < NUM_OF_WB_ENTRIES; now_rf_target = now_rf_target + 1) begin
			map_rf_read_wb_split[now_rf_target] 
				= map_rf_read_out[ ((now_rf_target + MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH) * MAP_RF_ENTRY_WIDTH) +: MAP_RF_ENTRY_WIDTH]; 
		end

		// RF 업데이트
		for (now_rf_target = 0; now_rf_target < MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH; now_rf_target = now_rf_target + 1) begin
			current_phyreg = target_phyregs_i[(now_rf_target * PHYREG_ADDR_WIDTH) +: PHYREG_ADDR_WIDTH];
			current_rf_data_cnt = map_rf_read_update_split[now_rf_target][BUF_ENTRIES_CNT_BITWIDTH-1:0];
			
			for (now_buf_target = 0; now_buf_target < BUF_ENTRIES_PER_PHYREG; now_buf_target = now_buf_target + 1) begin
				rf_buf[now_buf_target] // Counter 뒤족 부터
					= map_rf_read_update_split[now_rf_target][ (BUF_ENTRIES_CNT_BITWIDTH + (now_buf_target * IST_ADDR_WIDTH)) +: IST_ADDR_WIDTH];
			end

			if (current_rf_data_cnt == (BUF_ENTRIES_PER_PHYREG-1)) begin // 일단 새로 들어오는건 멈추게 하기
				max_buf_next[current_phyreg] = 1'b1;
			end
			// Buffer에 채우기
			rf_buf[now_rf_target] = target_phyregs_i[(now_rf_target * IST_ADDR_WIDTH) +: IST_ADDR_WIDTH]; // 새롭게 들어올 값
			new_rf_data_cnt = current_rf_data_cnt + 1;

			rf_buf_wide = 0;
			for (now_buf_target = 0; now_buf_target < BUF_ENTRIES_PER_PHYREG; now_buf_target = now_buf_target + 1) begin
				rf_buf_wide[(now_buf_target * BUF_ENTRIES_PER_PHYREG) +: BUF_ENTRIES_PER_PHYREG] = rf_buf[now_buf_target];
			end

			map_rf_read_update_split[now_rf_target] = {rf_buf_wide, new_rf_data_cnt};
		end
		for (now_rf_target = 0; now_rf_target < NUM_OF_WB_ENTRIES; now_rf_target = now_rf_target + 1) begin // WB 구역 FIFO 내보내는 부분
			current_phyreg = target_phyregs_i[((now_rf_target + MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH) * PHYREG_ADDR_WIDTH) +: PHYREG_ADDR_WIDTH];
			
			for (now_buf_target = 0; now_buf_target < BUF_ENTRIES_PER_PHYREG; now_buf_target = now_buf_target + 1) begin
				rf_buf[now_buf_target] // Buffer 부분 추출
					= map_rf_read_wb_split[now_rf_target][ (BUF_ENTRIES_CNT_BITWIDTH + (now_buf_target * IST_ADDR_WIDTH)) +: IST_ADDR_WIDTH];
			end

			for (now_buf_target = 0; now_buf_target < BUF_ENTRIES_PER_PHYREG; now_buf_target = now_buf_target + 1) begin
				map_rf_2_ready_out[now_buf_target] = {rf_buf[now_buf_target], current_phyreg};
			end
			for (now_buf_target = 0; now_buf_target < BUF_ENTRIES_PER_PHYREG; now_buf_target = now_buf_target + 1) begin
				map_rf_2_ready_out_fifo_push[now_rf_target][(now_buf_target * OUT_WB_ENTRY_WIDTH) +: OUT_WB_ENTRY_WIDTH]
					= map_rf_2_ready_out[now_buf_target];
			end
		end

		// RF쪽 업데이트 된거 묶기, WB쪽은 0으로 초기화 (이건 하는김에 Block도 끄기)
		for (now_rf_target = 0; now_rf_target < MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH; now_rf_target = now_rf_target + 1) begin
			map_rf_write_update_split[(now_rf_target * MAP_RF_ENTRY_WIDTH) +: MAP_RF_ENTRY_WIDTH] = map_rf_read_update_split[now_rf_target];
		end
		for (now_rf_target = 0; now_rf_target < NUM_OF_WB_ENTRIES; now_rf_target = now_rf_target + 1) begin
			current_phyreg = target_phyregs_i[(now_rf_target * PHYREG_ADDR_WIDTH) +: PHYREG_ADDR_WIDTH];
			max_buf_next[current_phyreg] = 1'b0;

			map_rf_write_update_split[ ((now_rf_target + MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH) * MAP_RF_ENTRY_WIDTH) +: MAP_RF_ENTRY_WIDTH] 
				= {MAP_RF_ENTRY_WIDTH{1'b0}};
		end
	end
 
	regfile #(
    	.READ_CHANNEL    (NUM_OF_WB_ENTRIES + MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH),
    	.WRITE_CHANNEL   (NUM_OF_WB_ENTRIES + MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH),
    	.ENTRIES         (NUM_OF_PHY_REGS),
    	.REG_WIDTH       (MAP_RF_ENTRY_WIDTH),
	) U_PHY_REG_IST_MAPPING_RF ( // 엔트리는 [ (d_n-1, ... , d_2, d_1, d_0) | 채워진 버퍼 수 ]
	    .clk                 (clk),
	    .reset_n             (reset_n),
	    .i_read_addresses    ({wb_done_phyreg_i, target_phyregs_i}),
	    .i_write_wes         ({wb_done_valid_i, target_ist_valid_i}),
	    .i_write_addresses   ({wb_done_phyreg_i, target_phyregs_i}),
	    .i_write_data        (map_rf_write_update_split),
	    .o_read_data		 (map_rf_read_out)
	);

	allocator_start_one #(
		.NUM_OF_ENTRIES (NUM_OF_PHY_REGS),
    	.UNALLOCATES 	(NUM_OF_DESTROY_ENTRIES),
    	.ALLOCATES 		(NUM_OF_NEW_ENTRIES)
	) U_UNALLOCATE_PHY_REG_ALLOCATOR (
	    .clk					(clk),
	    .reset_n				(reset_n),
	    .unallocate_valid_i		(unallocate_phyreg_valid_i),
	    .unallocate_entries_i	(unallocate_phyregs_i),
	    .allocating_i			(allocate_phyreg_get_i),
		.allocate_valid_o		(allocate_phyreg_valid_o),
	    .allocate_entries_o		(allocate_phyregs),
		.init_done				(phyreg_allocate_reg_done)
	);

	// 출력된 ist 처리
	wire [NUM_OF_WB_ENTRIES-1:0] push_available;
	wire [OUT_WB_ENTRY_WIDTH-1:0] pop_fifo[NUM_OF_WB_ENTRIES]; 

	genvar target_fifo;
	generate
		for (target_fifo = 0; target_fifo < NUM_OF_WB_ENTRIES; target_fifo = target_fifo + 1) begin
			fifo_ordering_position_out_one #(
				.PUSH_DATA		(BUF_ENTRIES_PER_PHYREG),
				.ENTRY_WIDTH	(OUT_WB_ENTRY_WIDTH),
				.FIFO_DEPTH		(FIFO_DEPTH)
			) U_RS_EX_FIFO (
				.clk				(clk),
				.reset_n			(reset_n),
				.push_valid_i		(wb_done_valid_i),
				.push_data_i		(map_rf_2_ready_out_fifo_push[target_fifo]),
				.pop_get_i			(wb_done_valid_i),
				.pop_valid_o		(ready_valid_o[target_fifo]),
				.pop_data_o			(pop_fifo[target_fifo]),
				.push_available_o	(push_available[target_fifo])
			);

			assign ready_phyreg_o[(target_fifo * PHYREG_ADDR_WIDTH) +: PHYREG_ADDR_WIDTH] 
				= pop_fifo[target_fifo][PHYREG_ADDR_WIDTH-1:0];
			assign ready_ist_entrites_o[(target_fifo * IST_ADDR_WIDTH) +: IST_ADDR_WIDTH] 
				= pop_fifo[target_fifo][OUT_WB_ENTRY_WIDTH-1:PHYREG_ADDR_WIDTH];
		end
	endgenerate

	assign active = phyreg_allocate_reg_done & ( |max_buf ) & ( &push_available );

endmodule
