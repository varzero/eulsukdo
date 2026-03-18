module position_splitter #(
	parameter INPUT_ENTRIES = 5,
	parameter DATA_WIDTH = 32,
	parameter BIT_WIDTH_INPUT_ENTRIES = $clog2(INPUT_ENTRIES)
) (
	input [INPUT_ENTRIES-1:0] valid_position_i,
	input [(INPUT_ENTRIES*DATA_WIDTH)-1:0] position_data_i,
	output reg [INPUT_ENTRIES-1:0] out_position_o,
	output reg [(INPUT_ENTRIES*DATA_WIDTH)-1:0] data_o
);
	reg [BIT_WIDTH_INPUT_ENTRIES-1:0] out_position_last;
	integer check_position_target;	

	always @(*) begin
		out_position_o = 0; data_o = 0; 
		
		out_position_last = 0;

		for (check_position_target = 0; check_position_target < INPUT_ENTRIES; check_position_target = check_position_target + 1) begin
			if (valid_position_i[check_position_target]) begin
				data_o[(out_position_last*DATA_WIDTH) +: DATA_WIDTH] = position_data_i[(check_position_target*DATA_WIDTH) +: DATA_WIDTH];
				out_position_o[out_position_last] = 1'b1;
				out_position_last = out_position_last + 1;
			end
		end
	end

endmodule

module fifo_ordering_position #(
	parameter PUSH_DATA = 4,
	parameter POP_DATA = 7,
	parameter ENTRY_WIDTH = 32,
	parameter FIFO_DEPTH = 128
) (
	input clk,
	input reset_n,
	input [PUSH_DATA-1:0] push_valid_i,
	input [(PUSH_DATA * ENTRY_WIDTH)-1:0] push_data_i,
	input [POP_DATA-1:0] pop_get_i,
	output [(POP_DATA * ENTRY_WIDTH)-1:0] pop_data_o,
	output fifo_empty
);
	localparam FIFO_IO_ENTRIES = (PUSH_DATA > POP_DATA)? PUSH_DATA : POP_DATA;
	localparam FIFO_WIDTH = FIFO_IO_ENTRIES * ENTRY_WIDTH;
	localparam READY_PUSH_PS_ENTRIES = FIFO_IO_ENTRIES + PUSH_DATA;
	localparam READY_PUSH_PS_WIDTH = FIFO_WIDTH + (PUSH_DATA * ENTRY_WIDTH);
	localparam READY_POP_PS_ENTRIES = FIFO_IO_ENTRIES + POP_DATA;
	localparam READY_POP_PS_WIDTH = FIFO_WIDTH + (POP_DATA * ENTRY_WIDTH);

	// Registers
	reg  [READY_PUSH_PS_ENTRIES-1:0] push_fifoready_valid_reg;
	reg  [READY_PUSH_PS_WIDTH-1:0] push_fifoready_data_reg;
	reg  [READY_POP_PS_ENTRIES-1:0] pop_out_valid_reg;
	reg  [READY_POP_PS_WIDTH-1:0] pop_out_data_reg;

	// for U_PS_PUSH and U_PS_PUSH_2_FIFO
	wire [PUSH_DATA-1:0] push_ordering_valid;
	wire [(PUSH_DATA * ENTRY_WIDTH)-1:0] push_ordering_data;

	// update U_PS_PUSH_2_FIFO
	// for U_PS_PUSH_2_FIFO and U_INTERNAL_FIFO
	wire [READY_PUSH_PS_ENTRIES-1:0] push_fifoready_valid;
	wire [READY_PUSH_PS_WIDTH-1:0] push_fifoready_data;
	reg  [READY_PUSH_PS_ENTRIES-1:0] push_fifoready_new_valid;
	reg  [READY_PUSH_PS_WIDTH-1:0] push_fifoready_new_data;
	reg	 push_fifo_we;
	reg  [FIFO_WIDTH-1:0] push_fifo_data;

	// for U_INTERNAL_FIFO and U_PS_FIFO_2_OUT
	wire fifo_empty;
	wire [FIFO_WIDTH-1:0] pop_fifoout_data;
	wire [READY_POP_PS_ENTRIES-1:0] pop_out_new_valid;
	wire [READY_POP_PS_WIDTH-1:0] pop_out_new_data;
	reg  fifo_get_position;
	reg  [READY_POP_PS_ENTRIES-1:0] pop_out_valid;
	reg  [READY_POP_PS_WIDTH-1:0] pop_out_data;

	always @(*) begin // comb logic
		// PUSH SECTION
			// FIFO 부분 채워졌는지 결정
		push_fifo_we = &( push_fifoready_valid_reg[FIFO_IO_ENTRIES-1:0] );
		push_fifo_data = push_fifoready_data_reg[FIFO_WIDTH-1:0];

		if (push_fifo_we) begin // FIFO 부분 채워짐
			push_fifoready_new_valid = {push_ordering_valid, {READY_PUSH_PS_ENTRIES{1'b0}} };
			push_fifoready_new_data = {push_ordering_data, {READY_PUSH_PS_WIDTH{1'b0}} };
		end
		else begin // FIFO 부분 아직 안채워짐
			push_fifoready_new_valid = {push_ordering_valid, 
										push_fifoready_valid_reg[FIFO_IO_ENTRIES-1:0]};
			push_fifoready_new_data  = {push_ordering_data, 
										push_fifoready_data_reg[FIFO_WIDTH-1:0]};
		end

		// POP SECTION
		if ( |pop_out_valid_reg[READY_POP_PS_ENTRIES-1:POP_DATA] ) begin
			// 가져온것이 아직 남아있는 경우: 유지
			fifo_get_position = 0;
			pop_out_valid = pop_out_valid_reg;
			pop_out_data = pop_out_data_reg;
		end
		else begin
			// 새로 보충해야 하는 경우
			if (~fifo_empty) begin // FIFO의 데이터가 있는 경우
				fifo_get_position = 1'b1;
				pop_out_valid = {{FIFO_IO_ENTRIES{1'b1}}, pop_out_valid_reg[POP_DATA-1:0]};
				pop_out_data = {pop_fifoout_data, pop_out_data_reg[POP_DATA-1:0]};
			end
			else begin // FIFO에 데이터가 없는 경우
				fifo_get_position = 0;
				pop_out_valid = {push_fifoready_valid_reg[FIFO_IO_ENTRIES-1:0], 
								 pop_out_valid_reg[POP_DATA-1:0]};
				pop_out_data  = {push_fifo_data, 
								 pop_out_data_reg[POP_DATA-1:0]};

				// PUSH 부분에서 FIFO 부분은 지우기
				push_fifo_we = 0;
				push_fifoready_new_valid = {push_ordering_valid, {READY_PUSH_PS_ENTRIES{1'b0}} };
				push_fifoready_new_data = {push_ordering_data, {READY_PUSH_PS_WIDTH{1'b0}} };
			end
		end
	end

	// Registers Modeling
	always @(posedge clk or negedge reset_n) begin
		if (reset_n == 1'b0) begin
			push_fifoready_valid_reg <= 0;
			push_fifoready_data_reg <= 0;
			pop_out_valid_reg <= 0;
			pop_out_data_reg <= 0;
		end
		else begin
			push_fifoready_valid_reg <= push_fifoready_valid;
			push_fifoready_data_reg <= push_fifoready_data;
			pop_out_valid_reg <= pop_out_new_valid;
			pop_out_data_reg <= pop_out_new_data;
		end
	end

	position_splitter #(
		.INPUT_ENTRIES(PUSH_DATA),
		.DATA_WIDTH(ENTRY_WIDTH)
	) U_PS_PUSH (
		.valid_position_i	(push_valid_i),
		.positiondata_i	(push_data_i),
		.out_position_o		(push_ordering_valid),
		.data_o				(push_ordering_data)
	);

	position_splitter #(
		.INPUT_ENTRIES(FIFO_IO_ENTRIES),
		.DATA_WIDTH(ENTRY_WIDTH)
	) U_PS_PUSH_2_FIFO (
		.valid_position_i	(push_fifoready_new_valid),
		.position_data_i	(push_fifoready_new_data),
		.out_position_o		(push_fifoready_valid),
		.data_o				(push_fifoready_data)
	);

	// FIFO는 한 FIFO 라인이 모두 채워지면 그때 저장함
    fifo_sram #(
		.ENTRIES(FIFO_DEPTH), 
		.REG_WIDTH(FIFO_WIDTH)
	) U_INTERNAL_FIFO (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_get          (fifo_get_position),
        .i_write_we          (push_fifo_we),
        .i_write_data        (push_fifo_data),
        .o_read_data         (pop_fifoout_data),
        .o_empty             (fifo_empty),
        .o_full              ()
    );

	position_splitter #(
		.INPUT_ENTRIES(FIFO_IO_ENTRIES),
		.DATA_WIDTH(ENTRY_WIDTH)
	) U_PS_FIFO_2_OUT (
		.valid_position_i	(pop_out_valid),
		.position_data_i	(pop_out_data),
		.out_position_o		(pop_out_new_valid),
		.data_o				(pop_out_new_data)
	);

endmodule

module allocator #(
	parameter NUM_OF_ENTRIES = 64,
    parameter UNALLOCATES = 4,
    parameter ALLOCATES = 7,
	parameter ENTRY_NUM_WIDTH = $clog2(NUM_OF_ENTRIES),
) (
    input clk,
    input reset_n,
    input [PUSH_DATA-1:0] unallocate_valid_i,
    input [(UNALLOCATES * ENTRY_NUM_WIDTH)-1:0] unallocate_entries_i,
    input [ALLOCATES-1:0] allocating_i,
    output [(ALLOCATES * ENTRY_NUM_WIDTH)-1:0] allocate_entries_o,
    output nothing_entry,
	output init_done
);
	localparam ALLOCATING_FIFO_WIDTH_ENTRIES = (UNALLOCATES > ALLOCATES)? UNALLOCATES : ALLOCATES;
	localparam ALLOCATING_FIFO_WIDTH = ALLOCATING_FIFO_WIDTH_ENTRIES * ENTRY_NUM_WIDTH;
	localparam ALLOCATING_FIFO_DEPTH = (NUM_OF_ENTRIES / ALLOCATING_FIFO_WIDTH_ENTRIES) 
										+ ( ((NUM_OF_ENTRIES % ALLOCATING_FIFO_WIDTH_ENTRIES) > 0)? 1 : 0 );
	localparam ALLOCATING_FIFO_LAST_ENTRIES = NUM_OF_ENTRIES % ALLOCATING_FIFO_WIDTH_ENTRIES;

	// Initializer FSM
		// State
	localparam INIT = 1'b0;
	localparam ALLOCATING = 1'b1;

		// State, Counter Register
	reg state, state_next;
	reg [ENTRY_NUM_WIDTH-1:0] entry_cnt, entry_cnt_next;
	always @(posedge clk or negedge reset_n) begin
		if (reset_n == 1'b0) begin
			state <= 0;
			entry_cnt <= 0;
		end
		else begin
			state <= state_next;
			entry_cnt <= entry_cnt_next;
		end
	end

		// State Transition
	always @(*) begin
		case (state)
			INIT: begin
				if (entry_cnt >= (NUM_OF_ENTRIES-1)) begin
					state_next = ALLOCATES;
				end
				else begin
					state_next = INIT;
				end
				entry_cnt_next = entry_cnt + ALLOCATING_FIFO_WIDTH_ENTRIES;
			end
			ALLOCATES: begin state_next = ALLOCATES; entry_cnt_next = 0; end
		endcase
	end

		// State Output
	integer position;
	reg [PUSH_DATA-1:0] unallocate_valid_in_fifo;
    reg [(UNALLOCATES * ENTRY_NUM_WIDTH)-1:0] unallocate_entries_in_fifo;
	always @(*) begin
		case (state)
			INIT: begin
				if (entry_cnt == (NUM_OF_ENTRIES - ALLOCATING_FIFO_LAST_ENTRIES)) begin
					unallocate_valid_in_fifo = { {(ALLOCATING_FIFO_WIDTH_ENTRIES-ALLOCATING_FIFO_LAST_ENTRIES){1'b0}},
												 {ALLOCATING_FIFO_LAST_ENTRIES{1'b1}} };
				end
				else begin
					unallocate_valid_in_fifo = {ALLOCATING_FIFO_WIDTH_ENTRIES{1'b1}};
				end
				for (position = 0; position < ALLOCATING_FIFO_WIDTH_ENTRIES; position = position + 1) begin
					unallocate_entries_in_fifo[(ALLOCATING_FIFO_WIDTH*position) 
												+: ALLOCATING_FIFO_WIDTH] = entry_cnt + position;
				end
			end
			ALLOCATES: begin 
				unallocate_valid_in_fifo = unallocate_valid_i; 
				unallocate_entries_in_fifo = unallocate_entries_i; 
			end
		endcase
	end

	assign init_done = (state == ALLOCATING)? 1'b1 : 1'b0;

    fifo_ordering_position #(
    	.PUSH_DATA		(UNALLOCATES),
    	.POP_DATA		(ALLOCATES),
    	.ENTRY_WIDTH	(ENTRY_NUM_WIDTH),
    	.FIFO_DEPTH		(ALLOCATING_FIFO_DEPTH)
    ) U_ALLOCATING_FIFO (
    	.clk			(clk),
    	.reset_n		(reset_n),
    	.push_valid_i	(unallocate_valid_in_fifo),
    	.push_data_i	(unallocate_entries_in_fifo),
    	.pop_get_i		(allocating_i),
    	.pop_data_o		(allocate_entries_o),
    	.fifo_empty		(nothing_entry)
    );

endmodule
