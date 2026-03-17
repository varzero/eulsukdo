module position_spliter #(
	parameter INPUT_ENTRIES = 5,
	parameter DATA_WIDTH = 32,
	parameter BIT_WIDTH_INPUT_ENTRIES = $clog2(INPUT_ENTRIES)
) (
	input [INPUT_ENTRIES-1:0] valid_position_i,
	input [(INPUT_ENTRIES*DATA_WIDTH)-1:0] position_data_i,
	output reg [BIT_WIDTH_INPUT_ENTRIES-1: 0] value_entries_o,
	output reg [INPUT_ENTRIES-1:0] out_position_o,
	output reg [(INPUT_ENTRIES*DATA_WIDTH)-1:0] data_o
);
	integer out_position_last, check_position_target;	

	always @(*) begin
		value_entries_o = 0; out_position_o = 0; data_o = 0; 
		
		out_position_last = 0;

		for (check_position_target = 0; check_position_target < INPUT_ENTRIES; check_position_target = check_position_target + 1) begin
			if (valid_position_i[check_position_target]) begin
				data_o[(out_position_last*DATA_WIDTH) +: DATA_WIDTH] = position_data_i[(check_position_target*DATA_WIDTH) +: DATA_WIDTH];
				out_position_o[out_position_last] = 1'b1;
				out_position_last = out_position_last + 1;
			end
		end

		value_entries_o = out_position_last;	
	end

endmodule

