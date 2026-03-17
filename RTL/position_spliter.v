module position_spliter #(
	parameter INPUT_ENTRIES = 5,
	parameter DATA_WIDTH = 32,
	parameter BIT_WIDTH_INPUT_ENTRIES = $clog2(INPUT_ENTRIES)
) (
	input [INPUT_ENTRIES-1:0] valid_position_i,
	input [(INPUT_ENTRIES*DATA_WIDTH)-1:0] position_data_i,
	output reg [INPUT_ENTRIES-1:0] out_position_o,
	output reg [(INPUT_ENTRIES*DATA_WIDTH)-1:0] data_o
);
	integer out_position_last, check_position_target;	

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
	always @(*) begin // comb logic
		push_fifo_we = &( push_fifoready_valid[FIFO_IO_ENTRIES-1:0] );
		push_fifo_data = push_fifoready_data[FIFO_WIDTH-1:0];

		if (push_fifo_we) begin
			push_fifoready_new_valid = {push_ordering_valid, {READY_PUSH_PS_ENTRIES{1'b0}} };
			push_fifoready_new_data = {push_ordering_data, {READY_PUSH_PS_WIDTH{1'b0}} };
		end
		else begin
			push_fifoready_new_valid = {push_ordering_valid, push_fifoready_valid};
			push_fifoready_new_data = {push_ordering_data, push_fifoready_data};
		end
	end

	// for U_INTERNAL_FIFO and U_PS_FIFO_2_OUT
	//

	always @(posedge clk or negedge reset_n) begin
		if (reset_n == 1'b0) begin
		end
		else begin
		end
	end

	position_spliter #(
		.INPUT_ENTRIES(PUSH_DATA),
		.DATA_WIDTH(ENTRY_WIDTH)
	) U_PS_PUSH (
		.valid_position_i	(push_valid_i),
		.position_data_i	(push_data_i),
		.out_position_o		(push_ordering_valid),
		.data_o				(push_ordering_data)
	);

	position_spliter #(
		.INPUT_ENTRIES(FIFO_IO_ENTRIES),
		.DATA_WIDTH(ENTRY_WIDTH)
	) U_PS_PUSH_2_FIFO (
		.valid_position_i	(push_fifoready_new_valid),
		.position_data_i	(push_fifoready_new_data),
		.out_position_o		(push_fifoready_valid),
		.data_o				(push_fifoready_data)
	);

    fifo_sram #(
		.ENTRIES(FIFO_DEPTH), 
		.REG_WIDTH(FIFO_WIDTH)
	) U_INTERNAL_FIFO (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_get          (),
        .i_write_we          (push_fifo_we),
        .i_write_data        (push_fifo_data),
        .o_read_data         (),
        .o_empty             (),
        .o_full              ()
    );

	position_spliter #(
		.INPUT_ENTRIES(FIFO_IO_ENTRIES),
		.DATA_WIDTH(ENTRY_WIDTH)
	) U_PS_FIFO_2_OUT (
		.valid_position_i	(),
		.position_data_i	(),
		.out_position_o		(),
		.data_o				()
	);



endmodule