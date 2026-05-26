module alu_ex #(
    parameter EX_PATH_NUM           = 3,
    parameter INST_OPREANDS         = 2,
    parameter MICROOP_WIDTH         = 7, // Micro-OP is not contained information of EX_PATH
    parameter PHYREG_NUM            = 64,

    // (Autogenerate) Elements
    localparam BITWIDTH_PHYREG_NUM  = $clog2(PHYREG_NUM),
    localparam BITWIDTH_EX_PATH_NUM = $clog2(EX_PATH_NUM)
) (
	input                                  run_i,
	input        [MICROOP_WIDTH-1:0]       microop_i,
	input        [31:0] 			       rs1_i,
	input        [31:0] 			       rs2_i,
	output logic [31:0] 	               alu_result_o,
	output logic                           done_o
);

	always_comb begin
		case(microop_i)
			5'b0_0_000: begin // ADD
				alu_result = rs1_i + rs2_i;
				done_o = run_i;
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
				done_o = 1'b0;
			end
		endcase
	end

endmodule