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

    parameter SRAM_ENTRIES_SIZE = 128,
	parameter SRAM_ADDR_WIDTH = $clog2(SRAM_SIZE),
	parameter BUF_ENTRIES_CNT_BITWIDTH = $clog2(BUF_ENTRIES_PER_PHYREG),
	parameter IST_ADDR_WIDTH = $clog2(IST_ENTRIES),
	parameter PHYREG_ADDR_WIDTH = $clog2(NUM_OF_PHY_REGS)
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

	wire phyreg_allocate_reg_done, sram_allocate_reg_done;
	wire [(MAP_RF_ENTRY_WIDTH * (NUM_OF_WB_ENTRIES + MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH))-1:0] map_rf_read_out;
	
	// BUFFER RF 업데이트용
	reg [MAP_RF_ENTRY_WIDTH-1:0] map_rf_read_update_split[0:(MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH)-1];
	reg [MAP_RF_ENTRY_WIDTH-1:0] map_rf_read_wb_split[0:(NUM_OF_WB_ENTRIES)-1];
	reg [(MAP_RF_ENTRY_WIDTH * (NUM_OF_WB_ENTRIES + MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH))-1:0] map_rf_write_update_split;

	reg [PHYREG_ADDR_WIDTH-1:0] current_phyreg;
	reg [IST_ADDR_WIDTH-1:0] current_ist;
	reg [BUF_ENTRIES_CNT_BITWIDTH-1:0] current_rf_data_cnt;
	reg [BUF_ENTRIES_CNT_BITWIDTH-1:0] new_rf_data_cnt;
	reg [IST_ADDR_WIDTH-1:0] rf_buf[BUF_ENTRIES_PER_PHYREG];
	reg [(IST_ADDR_WIDTH * BUF_ENTRIES_PER_PHYREG)-1:0] rf_buf_wide;

	integer now_rf_target, now_buf_target, now_ist_target, now_opreand;

	// SRAM에 저장용
		// 주소는 할당된 번호 엔트리는 [ 해당 PHYREG의 다음 Entry 위치 | IST 엔트리 위치 | PHYREG 번호 ]
	localparam SRAM_ENTRY_WIDTH = SRAM_ADDR_WIDTH + IST_ADDR_WIDTH + BUF_ENTRIES_PER_PHYREG;
		// 주소는 PHYREG 번호 엔트리는 [ SRAM에 저장된 엔트리 끝 주소 | SRAM에 저장된 엔트리 시작 주소 | 업데이트 대기여부 | 유효 ]
	localparam SRAM_ADDR_MAP_WIDTH = SRAM_ADDR_WIDTH + SRAM_ADDR_WIDTH + 2;

		// SRAM에 저장된 정보 처리용
	reg [MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH-1:0] sram_fifo_valid;
	reg [MAP_RF_ENTRY_WIDTH-1:0] sram_fifo_entry[MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH];
	reg [(MAP_RF_ENTRY_WIDTH * MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH)-1:0] sram_fifo_input;
	
	integer now_sram_fifo_target;

		// SRAM 매핑용 RF 처리용
	reg [MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH-1:0] sram_map_update;
	

	always @(*) begin
		// RF Out 분리부터, WB쪽은 따로 분리
		for (now_rf_target = 0; now_rf_target < MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH; now_rf_target = now_rf_target + 1) begin
			map_rf_read_update_split[now_rf_target] = map_rf_read_out[(now_rf_target * MAP_RF_ENTRY_WIDTH) +: MAP_RF_ENTRY_WIDTH]; 
		end
		for (now_rf_target = 0; now_rf_target < NUM_OF_WB_ENTRIES; now_rf_target = now_rf_target + 1) begin
			map_rf_read_wb_split[now_rf_target] 
				= map_rf_read_out[ ((now_rf_target + MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH) * MAP_RF_ENTRY_WIDTH) +: MAP_RF_ENTRY_WIDTH]; 
		end

		// SRAM 입력쪽도 초기화
		sram_fifo_valid = 0;
		for (now_sram_fifo_target = 0; now_sram_fifo_target < MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH; now_sram_fifo_target = now_sram_fifo_target + 1) begin
			sram_fifo_entry[now_sram_fifo_target] = 0;
		end

		// RF 업데이트
		now_ist_target = 0; now_opreand = 0;
		for (now_rf_target = 0; now_rf_target < MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH; now_rf_target = now_rf_target + 1) begin
			if (now_opreand == OPREANDS) begin
				now_ist_target = now_ist_target + 1;
				now_opreand = 0;
			end

			current_phyreg = target_phyregs_i[(now_rf_target * PHYREG_ADDR_WIDTH) +: PHYREG_ADDR_WIDTH];
			current_ist = target_ist_entry_i[(now_ist_target * IST_ADDR_WIDTH) +: IST_ADDR_WIDTH];
			current_rf_data_cnt = map_rf_read_update_split[now_rf_target][BUF_ENTRIES_CNT_BITWIDTH-1:0];
			
			for (now_buf_target = 0; now_buf_target < BUF_ENTRIES_PER_PHYREG; now_buf_target = now_buf_target + 1) begin
				rf_buf[now_buf_target] // Counter 뒤족 부터
					= map_rf_read_update_split[ (BUF_ENTRIES_CNT_BITWIDTH + (now_buf_target * IST_ADDR_WIDTH)) +: IST_ADDR_WIDTH];
			end

			if (current_rf_data_cnt == BUF_ENTRIES_PER_PHYREG) begin // SRAM에 채우기
				sram_fifo_entry = { {SRAM_ADDR_WIDTH{1'b0}}, current_ist, current_phyreg };
				new_rf_data_cnt = current_rf_data_cnt;
			end
			else begin // Buffer에 채우기
				rf_buf[current_rf_data_cnt] = target_phyregs_i[(now_rf_target * IST_ADDR_WIDTH) +: IST_ADDR_WIDTH]; // 새롭게 들어올 값
				new_rf_data_cnt = current_rf_data_cnt + 1;
			end

			for (now_buf_target = 0; now_buf_target < BUF_ENTRIES_PER_PHYREG; now_buf_target = now_buf_target + 1) begin
				rf_buf_wide[(now_buf_target * IST_ADDR_WIDTH) +: IST_ADDR_WIDTH] 
					= rf_buf[now_buf_target];
			end

			map_rf_read_update_split[now_rf_target] = {rf_buf_wide, new_rf_data_cnt};

			now_opreand = now_opreand + 1;
		end

		// RF쪽 업데이트 된거 묶기, WB쪽은 0으로 초기화
		for (now_rf_target = 0; now_rf_target < MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH; now_rf_target = now_rf_target + 1) begin
			map_rf_write_update_split[(now_rf_target * MAP_RF_ENTRY_WIDTH) +: MAP_RF_ENTRY_WIDTH] = map_rf_read_update_split[now_rf_target];
		end
		for (now_rf_target = 0; now_rf_target < NUM_OF_WB_ENTRIES; now_rf_target = now_rf_target + 1) begin
			map_rf_write_update_split[ ((now_rf_target + MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH) * MAP_RF_ENTRY_WIDTH) +: MAP_RF_ENTRY_WIDTH] 
				= {MAP_RF_ENTRY_WIDTH{1'b0}};
		end

		// SRAM쪽 업데이트 된거 묶기
		for (now_sram_fifo_target = 0; now_sram_fifo_target < MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH; now_sram_fifo_target = now_sram_fifo_target + 1) begin
			sram_fifo_input[(now_sram_fifo_target * MAP_RF_ENTRY_WIDTH) +: MAP_RF_ENTRY_WIDTH] = sram_fifo_entry[now_sram_fifo_target];
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
	    .i_write_wes         (target_ist_valid_i),
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

	regfile #(
    	.READ_CHANNEL    (NUM_OF_WB_ENTRIES),
    	.WRITE_CHANNEL   (NUM_OF_NEW_ENTRIES * OPREANDS),
    	.ENTRIES         (NUM_OF_PHY_REGS),
    	.REG_WIDTH       (SRAM_ADDR_WIDTH + SRAM_ADDR_WIDTH + 2),
	) U_PRRM_LIST_BUF (
	    .clk                 (clk),
	    .reset_n             (reset_n),
	    .i_read_addresses    (),
	    .i_write_wes         (),
	    .i_write_addresses   (),
	    .i_write_data        (),
	    .o_read_data		 ()
	);

	allocator #(
		.NUM_OF_ENTRIES (SRAM_ENTRIES_SIZE),
    	.UNALLOCATES 	(NUM_OF_WB_ENTRIES),
    	.ALLOCATES 		(MAP_RF_CHANNEL_UPDATE_ENTRY_APPEND_WIDTH)
	) U_PRRM_LIST_SRAM_ADDR_ALLOCATOR (
	    .clk					(clk),
	    .reset_n				(reset_n),
	    .unallocate_valid_i		(),
	    .unallocate_entries_i	(),
	    .allocating_i			(),
		.allocate_valid_o		(),
	    .allocate_entries_o		(),
		.init_done				(sram_allocate_reg_done)
	);
	
	on_chip_sync_dual_port_ram #(
	    .ENTRIES         (SRAM_ENTRIES_SIZE),
	    .ENTRY_WIDTH     (PHYREG_ADDR_WIDTH * BUF_ENTRIES_PER_PHYREG)
	) U_PRRM_LIST_SRAM (
	    .clk	(clk),
	    .r_addr	(),
	    .we		(),
	    .w_addr	(),
	    .w_data	(),
	    .r_data	()
	);

	assign active = phyreg_allocate_reg_done;

endmodule
