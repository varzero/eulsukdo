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

module rv32i_get_registers (
	input  wire [31:0] inst_i,
	output wire [4:0]  rd_o,
	output wire [4:0]  rs1_o,
	output wire [4:0]  rs2_o
);
    assign rd_o  = inst_i[11:7];
    assign rs1_o = inst_i[19:15];
    assign rs2_o = inst_i[24:20];
endmodule

module new_entry_logic #(
    // Dynamic Schedular Description
    parameter DECODE_NEW_INST   = 1,
    parameter PHYREG_NUM        = 64,
    parameter IST_ENTRY_NUM     = 128,
    parameter EX_PATH_NUM       = 3,
    parameter PRM_ENTRY_BUFFER  = 4,
    parameter RS_ENTRY_NUM      = 16,
    parameter RS_PUSH_WIDTH     = 3,
    parameter FCL_RB_NUM        = 8,
    parameter FCL_PC_GAP        = 4,
    parameter UNALLOCATE_PHYREG = 4,

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
    localparam BITWIDTH_FCL_RB_NUM                      = $clog2(FCL_RB_NUM),

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
    localparam WB_PHYREGS_BITWIDTH          = BITWIDTH_PHYREG_NUM * EX_PATH_NUM,

    localparam BITWIDTH_FCL_PC_WIDTH                    = BITWIDTH_FCL_RB_NUM + INST_PC_WIDTH
) (
    input                                       clk,
    input                                       reset_n,

    // Instruction Memory
        // <- New Inst Input
    input [DECODE_NEW_INST-1:0] i_im_inst_valid,
    input [(DECODE_NEW_INST*BITWIDTH_FCL_PC_WIDTH)-1:0] i_im_inst_pc,
    input [(DECODE_NEW_INST*INST_BITWIDTH)-1:0] i_im_inst,

    // Create IST Field
        // -> Instruction State Table Update
    input  wire                                         i_ist_insert_available,
    output wire [DECODE_NEW_INST-1:0]                   o_ist_field_insert,
    input  wire [DECODE_NEW_INST-1:0]                   i_ist_field_valid,
    output wire [IST_PACKET_BITWIDTH-1:0]               o_ist_field,

    // PRM
    output wire [DECODE_NEW_INST-1:0]                   o_allocate_position,
        // <- Physical Register Manager Allocator
    input  wire [DECODE_NEW_INST-1:0]                   i_prm_allocate_valid,
    input  wire [PRM_ALLOCATE_BITWIDTH-1:0]             i_prm_allocate_phyreg,
    
    // WBC
        // <- Ready Register number
    input  wire [EX_PATH_NUM-1:0]                       i_wbc2nel_done,
    input  wire [(EX_PATH_NUM*BITWIDTH_PHYREG_NUM)-1:0] i_wbc2nel_done_phyreg,

    // New Entry Logic
        // <- Block
    output wire                                               o_nel_block,
        // <- Jump Instruction Input
    output wire                                               o_nel_jump_inst,
    output wire                                               o_nel_jreg_branch_inst,
    output wire [INST_PC_WIDTH-1:0]                           o_nel_jump_branch_pc,
        // <- Allocate Registers input
    output wire [DECODE_NEW_INST-1:0]                         o_nel_newpc_valid,
    output wire [(BITWIDTH_FCL_PC_WIDTH*DECODE_NEW_INST)-1:0] o_nel_newpc,
    output wire [DECODE_NEW_INST-1:0]                         o_nel_newreg_valid,
    output wire [(BITWIDTH_PHYREG_NUM*DECODE_NEW_INST)-1:0]   o_nel_newreg
);
    wire                     rd          [0:DECODE_NEW_INST-1];
    wire                     rs1         [0:DECODE_NEW_INST-1];
    wire                     rs2         [0:DECODE_NEW_INST-1];
    wire                     exception   [0:DECODE_NEW_INST-1];
    wire                     newreg_alloc[0:DECODE_NEW_INST-1];
    wire                     jump        [0:DECODE_NEW_INST-1];
    wire                     jump_reg    [0:DECODE_NEW_INST-1];
    wire                     branch      [0:DECODE_NEW_INST-1];
    wire [INST_OPREANDS-1:0] ready       [0:DECODE_NEW_INST-1];
    wire [MICROOP_WIDTH-1:0] microop     [0:DECODE_NEW_INST-1];
    wire [31:0]              imm         [0:DECODE_NEW_INST-1];

    

    genvar decoder_idx;
    generate
        for (decoder_idx = 0; decoder_idx < DECODE_NEW_INST; decoder_idx = decoder_idx+1) begin
            rv32i_decode_opcode #(
                .EX_PATH_NUM  (EX_PATH_NUM),
                .INST_OPREANDS(INST_OPREANDS),
                .MICROOP_WIDTH(MICROOP_WIDTH)
            ) U_DECODER (
                .inst_i         (o_ist_field[(INST_BITWIDTH*decoder_idx) +: INST_BITWIDTH]),
                .exception_o    (exception[decoder_idx]), 
                .newreg_alloc_o (newreg_alloc[decoder_idx]),
                .jump_o         (jump[decoder_idx]),
                .jump_reg_o     (jump_reg[decoder_idx]),
                .branch_o       (branch[decoder_idx]),
                .ready_o        (ready[decoder_idx]),
                .microop_o      (microop[decoder_idx])
            );
            
            rv32i_get_registers U_REGISTER_GET (
            	.inst_i (o_ist_field[(INST_BITWIDTH*decoder_idx) +: INST_BITWIDTH]),
            	.rd_o   (rd[decoder_idx]),
            	.rs1_o  (rs1[decoder_idx]),
            	.rs2_o  (rs2[decoder_idx])
            );

            imm_extender U_IMM_EXT (
        	    .inst_i         (o_ist_field[(INST_BITWIDTH*decoder_idx) +: INST_BITWIDTH]),
        	    .imm_o          (imm[decoder_idx])
            );
        end
    endgenerate

    regfile #(
        .READ_CHANNEL  (DECODE_NEW_INST),
        .WRITE_CHANNEL (EX_PATH_NUM+DECODE_NEW_INST),
        .ENTRIES       (INST_NUM_OF_LOGICAL_REGISTER),
        .REG_WIDTH     (BITWIDTH_PHYREG_NUM)
    ) U_LOGICREG_PHYREG_MAP (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_addresses    (),
        .i_write_wes         (),
        .i_write_addresses   (),
        .i_write_data        (),
        .o_read_data         ()
    );

    regfile #(
        .READ_CHANNEL  (DECODE_NEW_INST),
        .WRITE_CHANNEL (EX_PATH_NUM+DECODE_NEW_INST),
        .ENTRIES       (INST_NUM_OF_LOGICAL_REGISTER),
        .REG_WIDTH     (1)
    ) U_LOGICREG_READY (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_addresses    (),
        .i_write_wes         (),
        .i_write_addresses   (),
        .i_write_data        (),
        .o_read_data         ()
    );

endmodule
