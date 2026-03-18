module rs #( // Ready Station
	parameter IN_ENTRIES = 5,
	parameter NUM_OF_EX = 5,
	parameter ROB_ENTRIES = 128,
	parameter MICRO_OP_LENGHT = 5,
	parameter NUM_OF_PHY_REGS = 64,
	parameter OPREANDS = 2,
	parameter FIFO_ENTRIES = 32,
	parameter EX_SPECIFY_WIDTH = $clog2(NUM_OF_EX),
	parameter ROB_ADDR_WIDTH = $clog2(ROB_ENTRIES),
	parameter PHYREG_ADDR_WIDTH = $clog2(NUM_OF_PHY_REGS),
	parameter RS_ENTRY_WIDTH = ROB_ADDR_WIDTH + MICRO_OP_LENGHT + PHYREG_ADDR_WIDTH + (PHYREG_ADDR_WIDTH * OPREANDS)
) (
	input clk,
	input reset_n,
	input [(IN_ENTRIES * EX_SPECIFY_WIDTH)-1:0] ex_target_i,
	input [(IN_ENTRIES * RS_ENTRY_WIDTH)-1:0] entry_data_i,
	input [NUM_OF_EX-1:0] ex_busy_i,
	output [NUM_OF_EX-1:0] ex_fifo_valid_o,
	output [(NUM_OF_EX * RS_ENTRY_WIDTH)-1:0] ex_fifo_data_o,
	output fifo_full_block
);
	reg [IN_ENTRIES-1:0] input_valid_position [0:NUM_OF_EX-1];
	wire [IN_ENTRIES-1:0] position_ordering [0:NUM_OF_EX-1]; 
	wire [(IN_ENTRIES * RS_ENTRY_WIDTH)-1:0] data_ordering [0:NUM_OF_EX-1]; 
	wire [IN_ENTRIES-1:0] fifo_empty, fifo_full;

	assign ex_fifo_valid_o = ~fifo_empty;
	assign fifo_full_block = &fifo_full;s

	genvar ex_path;
	integer valid_check, check_target;

	generate
		for (ex_path = 0; ex_path < NUM_OF_EX; ex_path = ex_path+1) begin
			position_spliter U_RS_IN_PSP #(
					.INPUT_ENTRIES(IN_ENTRIES),
					.DATA_WIDTH(RS_ENTRY_WIDTH)
				) (
					.valid_position_i(input_valid_position[ex_path]),
					.position_data_i(entry_data_i),
					.out_position_o(position_ordering[ex_path])
					.data_o(data_ordering[ex_path])
				);

			fifo_sram U_RS_FIFO #(
    			.ENTRIES            ((FIFO_ENTRIES / IN_ENTRIES) + (((FIFO_ENTRIES % IN_ENTRIES) == 0)? 0 : 1)),
    			.REG_WIDTH          (IN_ENTRIES * RS_ENTRY_WIDTH)
			) (
			    .clk                (clk),
			    .reset_n            (reset_n),
			    .i_read_get         (ex_busy_i[ex_path]),
			    .i_write_we         (position_ordering[ex_path]),
			    .i_write_data       (data_ordering[ex_path]),
			    .o_read_data        (ex_fifo_data_o[(ex_path*RS_ENTRY_WIDTH) +: RS_ENTRY_WIDTH]),
			    .o_empty            (fifo_empty[ex_path]),
			    .o_full             (fifo_full[ex_path])
			);
		end
	endgenerate

	always @(*) begin
		input_valid_position = 0;
		for (valid_check = 1; valid_check <= NUM_OF_EX, valid_check = valid_check + 1) begin
			for (check_target = 0; check_target <= IN_ENTRIES, check_target = check_target + 1) begin
				if ( ex_target_i[( ((IN_ENTRIES * EX_SPECIFY_WIDTH) * (valid_check-1)) 
									+ (EX_SPECIFY_WIDTH * check_target) ) 
								+: EX_SPECIFY_WIDTH] 
					&& valid_check )
				begin
					input_valid_position[velid_check-1][check_target] = 1'b1;
				end
			end
		end
	end

endmodule

