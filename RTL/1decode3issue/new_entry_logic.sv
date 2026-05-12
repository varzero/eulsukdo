`timescale 1ns / 1ps

`include "../memories.v"

// NEW ENTRY LOGIC

module rv32i_decode_opcode #(
    parameter EX_PATH_NUM           = 3,
    parameter INST_OPREANDS         = 2,
    parameter MICROOP_WIDTH         = 7, // Micro-OP is not contained information of EX_PATH

    // (Autogenerate) Elements
    localparam BITWIDTH_EX_PATH_NUM = $clog2(EX_PATH_NUM)
) (
    input  wire [31:0]              inst_i,
    output reg                      exception_o,
    output reg                      newreg_alloc_o,
    output reg                      jump_o,
    output reg                      jump_reg_o,
    output reg                      branch_o,
    output reg  [INST_OPREANDS-1:0] ready_o,
    output reg  [MICROOP_WIDTH-1:0] microop_o
);
    /*
    ==( Opcode, funct3/7 -> MicroOp )==
      
      [EX Channel 1: Branch, Jump Reg]
       - Branch Equal
       - Branch Not Equal
       - Branch Less Than (Signed)
       - Branch Less Than (Unsigned)
       - Branch Greater Equal (Signed)
       - Branch Greater Equal (Unsigned)
       - Jump Reg (Other Jump instrunction Process in Flow Control Logic and New Entry Logic)
      [EX Channel 2: ALU Reg/IMM]
       - ADD
       - SUB
       - SLL
       - SLT
       - SLTU
       - XOR
       - SRL
       - SRA
       - OR
       - AND
       - (IMM) ADD
       - (IMM) SLL
       - (IMM) SLT
       - (IMM) SLTU
       - (IMM) XOR
       - (IMM) SRL
       - (IMM) SRA
       - (IMM) OR
       - (IMM) AND
       - LUI
       - AUIPC
       - JUMP IMM
      [EX Channel 3: Memory Access]
       - LB
       - LH
       - LW
       - LBU
       - LHU
       - SB
       - SH
       - SW

    ===================================
    */

    always @(*) begin : Decoding
        case(inst_i[6:0])
            7'b1100011: begin // EX 1: Branch
                exception_o = 1'b0;
                newreg_alloc_o = 1'b0;
                jump_o = 1'b0;
                jump_reg_o = 1'b0;
                branch_o = 1'b1;
                ready_o = 2'b00;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b00;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = {2'b00, inst_i[14:12]};
            end
            7'b1100111: begin // EX 1: Jump Reg
                exception_o = 1'b0;
                newreg_alloc_o = 1'b1;
                jump_o = 1'b0;
                jump_reg_o = 1'b1;
                branch_o = 1'b0;
                ready_o = 2'b10;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b00;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = 5'b01000;
            end
            
            7'b0110011: begin // EX 2: ALU Reg
                exception_o = 1'b0;
                newreg_alloc_o = 1'b1;
                jump_o = 1'b0;
                jump_reg_o = 1'b0;
                branch_o = 1'b0;
                ready_o = 2'b00;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b01;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = {1'b0, inst_i[30], inst_i[14:12]};
            end
            7'b0010011: begin // EX 2: ALU IMM
                exception_o = 1'b0;
                newreg_alloc_o = 1'b1;
                jump_o = 1'b0;
                jump_reg_o = 1'b0;
                branch_o = 1'b0;
                ready_o = 2'b10;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b01;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = 
                    {1'b1, (inst_i[14:12] == 3'b101)? inst_i[30] : 1'b0, inst_i[14:12]};
            end
            7'b0110111: begin // EX 2: LUI
                exception_o = 1'b0;
                newreg_alloc_o = 1'b1;
                jump_o = 1'b0;
                jump_reg_o = 1'b0;
                branch_o = 1'b0;
                ready_o = 2'b11;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b01;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = 5'b11000;
            end
            7'b0010111: begin // EX 2: AUIPC
                exception_o = 1'b0;
                newreg_alloc_o = 1'b1;
                jump_o = 1'b0;
                jump_reg_o = 1'b0;
                branch_o = 1'b0;
                ready_o = 2'b11;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b01;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = 5'b11001;
            end
            7'b1101111: begin // EX 2: JAL
                exception_o = 1'b0;
                newreg_alloc_o = 1'b1;
                jump_o = 1'b1;
                jump_reg_o = 1'b0;
                branch_o = 1'b0;
                ready_o = 2'b11;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b01;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = 5'b11010;
            end

            7'b0000011: begin // EX 3: Memory Access Load
                exception_o = 1'b0;
                newreg_alloc_o = 1'b1;
                jump_o = 1'b0;
                jump_reg_o = 1'b0;
                branch_o = 1'b0;
                ready_o = 2'b10;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b10;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = {2'b00, inst_i[14:12]};
            end
            7'b0100011: begin // EX 3: Memory Access Store
                exception_o = 1'b0;
                newreg_alloc_o = 1'b0;
                jump_o = 1'b0;
                jump_reg_o = 1'b0;
                branch_o = 1'b0;
                ready_o = 2'b00;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b10;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = {2'b10, inst_i[14:12]};
            end

            default: begin
                exception_o = 1'b1;
                newreg_alloc_o = 1'b1;
                jump_o = 1'b0;
                jump_reg_o = 1'b0;
                branch_o = 1'b0;
                ready_o = 2'b11;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b11;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = 5'b00000;
            end
        endcase
    end
endmodule

module imm_extender (
	input  wire [31:0] inst_i,
	output reg  [31:0] imm_o
);

	always @(*) begin : Decode_AND_Create_IMM
		imm_o = 0;

		case(inst_i[6:0])
			7'b0100011 : imm_o = { {20{inst_i[31]}}, inst_i[31:25], inst_i[11:7] };
			7'b0000011, 7'b0110011, 7'b1100111 : imm_o = { {20{inst_i[31]}}, inst_i[31:20] };
			7'b1100011 : imm_o = { {20{inst_i[31]}},	inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0 };
			7'b0110111, 7'b0010111 : imm_o = { inst_i[31:12], {12{1'b0}} };
			7'b1101111: imm_o = { {12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0 };
		endcase
	end

endmodule

module new_entry_logic #(
    // Dynamic Schedular Description
    parameter DECODE_NEW_INST   = 1,
    parameter PHYREG_NUM        = 64,
    parameter IST_ENTRY_NUM     = 128,
    parameter EX_PATH_NUM       = 3,

    // Instruction Field Description
    parameter INST_PC_WIDTH                 = 32,
    parameter INST_BITWIDTH                 = 32,
    parameter INST_OPCODE_WIDTH             = 7,
    parameter INST_OPTIONAL_OPCODE_WIDTH    = 10,
    parameter INST_IMM_WIDTH                = 32,
    parameter INST_NUM_OF_LOGICAL_REGISTER  = 32,
    parameter INST_OPREANDS                 = 2,

    // Internal Field Description (Decoder Compiler (or Human) Generate)
    parameter MICROOP_WIDTH                 = 7, // Micro-OP is not contained information of EX_PATH

    // (Autogenerate) Elements
    localparam BITWIDTH_EX_PATH_NUM                     = $clog2(EX_PATH_NUM),
    localparam BITWIDTH_PHYREG_NUM                      = $clog2(PHYREG_NUM),
    localparam BITWIDTH_IST_ENTRY_NUM                   = $clog2(IST_ENTRY_NUM),
    localparam BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER    = $clog2(INST_NUM_OF_LOGICAL_REGISTER),

    // (Autogenerate) Field of Entry in Instruction State Table
        /* Entry: MSB [ ( Opreand Reday_n, ... , Opreand Reday_1 ) | 
                        ( Opreand Rename Register_n, ... , Opreand Rename Register_1 ) | 
                        Destination Rename Register | 
                        IMM | PC | Micro-OP | EX_PATH ] LSB */    
    localparam IST_BITWIDTH_OPREAND_PHYREG_FULL = BITWIDTH_PHYREG_NUM * INST_OPREANDS,
    localparam IST_BITWIDTH_OPREAND_READY_FULL  = INST_OPREANDS,
    localparam IST_BITWIDTH = INST_PC_WIDTH + BITWIDTH_EX_PATH_NUM + MICROOP_WIDTH + INST_PC_WIDTH + INST_IMM_WIDTH + BITWIDTH_PHYREG_NUM
                              + IST_BITWIDTH_OPREAND_PHYREG_FULL + IST_BITWIDTH_OPREAND_READY_FULL,

    localparam IST_STARTPOINT_PHYREG            = INST_PC_WIDTH + BITWIDTH_EX_PATH_NUM + MICROOP_WIDTH + INST_PC_WIDTH + INST_IMM_WIDTH,
    localparam IST_STARTPOINT_LOGREG            = IST_STARTPOINT_PHYREG + BITWIDTH_PHYREG_NUM,
    localparam IST_STARTPOINT_OPREAND_PHYREG    = IST_STARTPOINT_LOGREG + BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER,
    localparam IST_STARTPOINT_OPREAND_READY     = IST_STARTPOINT_OPREAND_PHYREG + IST_BITWIDTH_OPREAND_PHYREG_FULL,

    localparam IST_PACKET_BITWIDTH              = IST_BITWIDTH * DECODE_NEW_INST,

    // (Autogenerate) Field of Allocator in Instruction State Table
    localparam IST_ALLOCATE_BITWIDTH = BITWIDTH_IST_ENTRY_NUM * DECODE_NEW_INST,
    
    // (Autogenerate) Field of Allocator in Physical Register Manager
    localparam PRM_ALLOCATE_BITWIDTH        = BITWIDTH_PHYREG_NUM * DECODE_NEW_INST,

    // (Autogenerate) Width of Instructions
    localparam INST_INPUT_BITWIDTH          = INST_BITWIDTH * DECODE_NEW_INST,

    // (Autogenerate) Write Back Field
    localparam WB_PHYREGS_BITWIDTH          = BITWIDTH_PHYREG_NUM * EX_PATH_NUM
) (
    input                                       clk,
    input                                       reset_n,


);

endmodule
