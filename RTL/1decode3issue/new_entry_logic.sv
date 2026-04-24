// NEW ENTRY LOGIC

module rv32i_decode_opcode #(
    parameter EX_PATH_NUM           = 3,
    parameter INST_OPREANDS         = 2,
    parameter MICROOP_WIDTH         = 7, // Micro-OP is not contained information of EX_PATH

    // (Autogenerate) Elements
    localparam BITWIDTH_EX_PATH_NUM = $clog2(EX_PATH_NUM)
) (
    input  wire [31:0]              inst_i,
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
                ready_o = 2'b00;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b00;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = {2'b00, inst_i[14:12]};
            end
            7'b1100111: begin // EX 1: Jump Reg
                ready_o = 2'b10;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b00;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = 5'b01000;
            end
            
            7'b0110011: begin // EX 2: ALU Reg
                ready_o = 2'b00;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b01;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = {1'b0, inst_i[30], inst_i[14:12]};
            end
            7'b0010011: begin // EX 2: ALU IMM
                ready_o = 2'b10;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b01;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = 
                    {1'b1, (inst_i[14:12] == 3'b101)? inst_i[30] : 1'b0, inst_i[14:12]};
            end
            7'b0110111: begin // EX 2: LUI
                ready_o = 2'b11;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b01;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = 5'b11000;
            end
            7'b0010111: begin // EX 2: AUIPC
                ready_o = 2'b11;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b01;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = 5'b11001;
            end
            7'b0110111: begin // EX 2: JUMP IMM
                ready_o = 2'b11;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b01;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = 5'b11010;
            end

            7'b0000011: begin // EX 3: Memory Access Load
                ready_o = 2'b10;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b10;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = {2'b00, inst_i[14:12]};
            end
            7'b0100011: begin // EX 3: Memory Access Store
                ready_o = 2'b00;
                microop_o[BITWIDTH_EX_PATH_NUM-1:0] = 2'b10;
                microop_o[MICROOP_WIDTH-1:BITWIDTH_EX_PATH_NUM] = {2'b10, inst_i[14:12]};
            end

            default: begin
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
    localparam IST_BITWIDTH = INST_PC_WIDTH + MICROOP_WIDTH + INST_PC_WIDTH + INST_IMM_WIDTH + BITWIDTH_PHYREG_NUM
                              + IST_BITWIDTH_OPREAND_PHYREG_FULL + IST_BITWIDTH_OPREAND_READY_FULL,

    localparam IST_STARTPOINT_PHYREG            = INST_PC_WIDTH + MICROOP_WIDTH + INST_PC_WIDTH + INST_IMM_WIDTH,
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

    // <-> Instruction Memory
    input  wire [DECODE_NEW_INST-1:0]           i_inst_valid,
    input  wire [INST_INPUT_BITWIDTH-1:0]       i_inst,
    input  wire [INST_PC_WIDTH-1:0]             i_pc,

    // Allocators
    output wire [DECODE_NEW_INST-1:0]           o_allocate_position,
        // -> Instruction State Table Allocator
    input  wire [DECODE_NEW_INST-1:0]           i_ist_allocate_valid,
    input  wire [IST_ALLOCATE_BITWIDTH-1:0]     i_ist_allocate_addr,

    // Create IST Field
        // <- Instruction State Table Update
    output wire [DECODE_NEW_INST-1:0]           o_ist_field_valid,
    output wire [IST_PACKET_BITWIDTH-1:0]       o_ist_field,

        // -> Physical Register Manager Allocator
    input  wire [DECODE_NEW_INST-1:0]           i_prm_allocate_valid,
    input  wire [PRM_ALLOCATE_BITWIDTH-1:0]     i_prm_allocate_phyreg,
    output wire                                 o_prm_allocate_get,

    // -> Write Back PHYREGs (Ready Update)
    input  wire [EX_PATH_NUM-1:0]               i_wb_done,
    input  wire [WB_PHYREGS_BITWIDTH-1:0]       i_wb_done_phyregs
);

    // Blocking..
    wire block;
    assign block = ~i_inst_valid | ~i_ist_allocate_valid | ~i_prm_allocate_valid;

    // ISA Decoder, IMM
    localparam MICROOP_WIDTH_INTERNAL = MICROOP_WIDTH * DECODE_NEW_INST;
    localparam IMM_WIDTH_INTERNAL     = INST_IMM_WIDTH * DECODE_NEW_INST;
    
    wire [MICROOP_WIDTH_INTERNAL-1:0] microop_entries_w;
    wire [INST_OPREANDS-1:0]          opcode_ready_w;
    wire [IMM_WIDTH_INTERNAL-1:0]     imm_entries_w;
        
        // Decoder Section START

    rv32i_decode_opcode #(
        .EX_PATH_NUM  (EX_PATH_NUM),
        .MICROOP_WIDTH(MICROOP_WIDTH)
    ) U_RV32I_MICROOP_DECODER (
        .inst_i   (i_inst),
        .ready_o  (opcode_ready_w),
        .microop_o(microop_entries_w)
    );
    
    imm_extender U_IMM_EXTENDER (
	    .inst_i(i_inst),
	    .imm_o (imm_entries_w)
    );
    
        // Decoder Section END

    // Registers
        // Pipelining Register STAGE1: (LSB) [ PC | MicroOP | RD | P_src1 | P_src2 | IMM | Ready1 | Ready2 ] (MSB)
    localparam PIPE_STAGE1_BITWIDTH = INST_PC_WIDTH + MICROOP_WIDTH 
                                      + BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER
                                      + (BITWIDTH_PHYREG_NUM * INST_OPREANDS)
                                      + INST_IMM_WIDTH + INST_OPREANDS;
    reg [PIPE_STAGE1_BITWIDTH-1:0] stage1_reg, stage1_next;
    reg [(BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER*DECODE_NEW_INST)-1:0] stage1_phyreg_reg, stage1_phyreg_next;
        // Output Register: IST OUT
    reg [IST_PACKET_BITWIDTH-1:0] ist_out_reg, ist_out_next;
    assign o_ist_field = ist_out_reg;
        // Registers Modeling
    always @(posedge clk or negedge reset_n) begin
        if (reset_n == 1'b0) begin
            stage1_reg  <= 0;
            stage1_phyreg_reg <= 0;
            ist_out_reg <= 0;
        end
        else begin
            stage1_reg  <= stage1_next;
            stage1_phyreg_reg <= stage1_phyreg_next;
            ist_out_reg <= ist_out_next;
        end
    end

    // Logical Reg <-> Physical Reg Mapping Table
        // Destination Logical Register Input
    wire [(BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER*DECODE_NEW_INST)-1:0] dest_regnum_w;
    localparam INST_STARTPOINT_RD_LOGICALREG = INST_OPCODE_WIDTH;
    assign dest_regnum_w = i_inst[INST_STARTPOINT_RD_LOGICALREG +: BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER];
        // Opreands Logical Registers Input
    wire [(BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER*INST_OPREANDS)-1:0] opreands_regnum_w;
    localparam INST_STARTPOINT_OPREANDS_LOGICREG = INST_OPCODE_WIDTH + BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER + 3; // RV32I Instruction
    assign opreands_regnum_w = i_inst[INST_STARTPOINT_OPREANDS_LOGICREG +: (BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER*INST_OPREANDS)];
        // Opreands Physical Registers Output
    wire [(BITWIDTH_PHYREG_NUM*INST_OPREANDS)-1:0] opreands_phyreg_w;
        // Opreands Physical Register Ready Output
    wire [INST_OPREANDS-1:0] opreands_ready_w;

    // Entry: Logical_Reg = [Physical Reg, Ready]
        // PHYREG Mapping update before stage1
    regfile #(
        .READ_CHANNEL    (INST_OPREANDS),
        .WRITE_CHANNEL   (DECODE_NEW_INST),
        .ENTRIES         (INST_NUM_OF_LOGICAL_REGISTER),
        .REG_WIDTH       (BITWIDTH_PHYREG_NUM)
    ) U_PHYREG_MAPPING (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_addresses    (opreands_regnum_w),
        .i_write_wes         ( ~block ),
        .i_write_addresses   (dest_regnum_w),
        .i_write_data        (i_prm_allocate_phyreg),
        .o_read_data         (opreands_phyreg_w)
    );

        // NEW PHYREG Ready update before stage1
    regfile #(
        .READ_CHANNEL    (INST_OPREANDS),
        .WRITE_CHANNEL   (DECODE_NEW_INST*2),
        .ENTRIES         (INST_NUM_OF_LOGICAL_REGISTER),
        .REG_WIDTH       (1)
    ) U_PHYREG_READY (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_addresses    (opreands_regnum_w),
        .i_write_wes         ( {i_wb_done, ~block} ),
        .i_write_addresses   ( {i_wb_done_phyregs, dest_regnum_w} ),
        .i_write_data        ( {1'b1, 1'b0} ),
        .o_read_data         (opreands_ready_w)
    );

        // Stage1 Position
    localparam PIPE_STAGE1_PC_MICROOP_BITWIDTH = INST_PC_WIDTH + MICROOP_WIDTH;
    localparam PIPE_STAGE1_STARTPOINT_OPREANDS_IMM = INST_PC_WIDTH + MICROOP_WIDTH;

    always @(*) begin
        // Stage 1
        stage1_next        = (~block)? { (opcode_ready_w & opreands_ready_w), 
                                         imm_entries_w, opreands_phyreg_w,
                                         dest_regnum_w, microop_entries_w, i_pc }
                                       : stage1_reg;
        stage1_phyreg_next = (~block)? i_prm_allocate_phyreg : stage1_phyreg_reg;
        ist_out_next       = (~block)? { (opcode_ready_w & opreands_ready_w), 
                                         imm_entries_w, opreands_phyreg_w,
                                         i_prm_allocate_phyreg, microop_entries_w, i_pc } 
                                        : ist_out_reg;
    end

    assign o_allocate_position = ~block;
    assign o_ist_field_valid   = ~block;
    assign o_prm_allocate_get  = ~block;

endmodule
