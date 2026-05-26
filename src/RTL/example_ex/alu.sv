module alu (
	input [31:0] 			rs1,
	input [31:0] 			rs2,
	input [3:0] 			alu_control,
	output logic [31:0] 	alu_result
);
/*
	always_comb begin
		case(alu_control)
			`ALU_CMD_ADD: begin
				alu_result = rs1 + rs2;
			end
			`ALU_CMD_SUB: begin
				alu_result = rs1 - rs2;
			end
			`ALU_CMD_AND: begin
				alu_result = rs1 & rs2;
			end
			`ALU_CMD_OR : begin
				alu_result = rs1 | rs2;
			end
			`ALU_CMD_XOR: begin
				alu_result = rs1 ^ rs2;
			end
			`ALU_CMD_SLT: begin
				alu_result = ( $signed(rs1) < $signed(rs2) )? 32'd1 : 32'b0; // Signed
			end
			`ALU_CMD_SLTU: begin
				alu_result = ( rs1 < rs2 )? 32'd1 : 32'b0; // Unsigned
			end
			`ALU_CMD_SLL: begin
				alu_result = rs1 << rs2[4:0]; // Shift Left
			end
			`ALU_CMD_SRL: begin
				alu_result = rs1 >> rs2[4:0]; // Shift Right
			end
			`ALU_CMD_SRA: begin
				alu_result = $signed(rs1) >>> rs2[4:0]; // Shift Right Arithmetic
			end

			`ALU_CMD_EQ:  begin
				alu_result = ( rs1 == rs2 )? 32'd1 : 32'b0;
			end
			`ALU_CMD_NE:  begin
				alu_result = ( rs1 != rs2 )? 32'd1 : 32'b0;
			end
			`ALU_CMD_GE:  begin
				alu_result = ( $signed(rs1) >= $signed(rs2) )? 32'd1 : 32'b0;
			end
			`ALU_CMD_GEU: begin
				alu_result = ( rs1 >= rs2 )? 32'd1 : 32'b0;
			end

			default: begin
				alu_result = 32'b0;
			end
		endcase
	end
*/
endmodule