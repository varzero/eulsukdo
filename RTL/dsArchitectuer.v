module new_entry_logic #(
    // Dynamic Schedular Description
    parameter DECODE_NEW_INST   = 3,
    parameter PHYREG_NUM        = 64,
    parameter IST_ENTRY_NUM     = 128,
    parameter EX_PATH_NUM       = 5,

    // Instruction Field Description
    parameter INST_PC_WIDTH                 = 32,
    parameter INST_BITWIDTH                 = 32,
    parameter INST_OPCODE_WIDTH             = 7,
    parameter INST_OPTIONAL_OPCODE_WIDTH    = 10,
    parameter INST_IMM_WIDTH                = 32,
    parameter INST_NUM_OF_LOGICAL_REGISTER  = 32,
    parameter INST_OPREANDS                 = 2,

    // Internal Field Description (Decoder Compiler (or Human) Generate)
    parameter MICROOP_WIDTH                 = 6, // Micro-OP is not contained information of EX_PATH

    // (Autogenerate) Elements
    localparam BITWIDTH_EX_PATH_NUM                     = $clog2(EX_PATH_NUM),
    localparam BITWIDTH_PHYREG_NUM                      = $clog2(PHYREG_NUM),
    localparam BITWIDTH_IST_ENTRY_NUM                   = $clog2(IST_ENTRY_NUM),
    localparam BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER    = $clog2(INST_NUM_OF_LOGICAL_REGISTER),

    // (Autogenerate) Field of Entry in Instruction State Table
        /* Entry: MSB [ ( Opreand Reday_n, ... , Opreand Reday_1 ) | 
                        ( Opreand Rename Register_n, ... , Opreand Rename Register_1 ) | 
                        Destination Logical Register | 
                        Destination Rename Register | 
                        IMM | PC | Micro-OP | EX_PATH ] LSB */    
    localparam IST_BITWIDTH_OPREAND_PHYREG_FULL = BITWIDTH_PHYREG_NUM * INST_OPREANDS,
    localparam IST_BITWIDTH_OPREAND_READY_FULL  = INST_OPREANDS,
    localparam IST_BITWIDTH = INST_PC_WIDTH + MICROOP_WIDTH + INST_PC_WIDTH + INST_IMM_WIDTH
                              + BITWIDTH_PHYREG_NUM + BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER
                              + IST_BITWIDTH_OPREAND_PHYREG_FULL + IST_BITWIDTH_OPREAND_READY_FULL,

    localparam IST_STARTPOINT_PHYREG            = INST_PC_WIDTH + MICROOP_WIDTH + INST_PC_WIDTH + INST_IMM_WIDTH,
    localparam IST_STARTPOINT_LOGREG            = IST_STARTPOINT_PHYREG + BITWIDTH_PHYREG_NUM,
    localparam IST_STARTPOINT_OPREAND_PHYREG    = IST_STARTPOINT_LOGREG + BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER,
    localparam IST_STARTPOINT_OPREAND_READY     = IST_STARTPOINT_OPREAND_PHYREG + IST_BITWIDTH_OPREAND_PHYREG_FULL,

    localparam IST_PACKET_BITWIDTH              = IST_BITWIDTH * DECODE_NEW_INST,

    // (Autogenerate) Field of Allocator in Instruction State Table
    localparam IST_ALLOCATE_BITWIDTH = BITWIDTH_IST_ENTRY_NUM * DECODE_NEW_INST,

    // (Autogenerate) Packet of registing that Opreand Rename Register to Physical Register Manager
    localparam PRM_UPDATE_PHYREG            = DECODE_NEW_INST * INST_OPREANDS,
        /* Packet: MSB [ ( IST Address_n , Opreand Rename Register_n ), ... , ( IST Address_1 , Opreand Rename Register_1 ) ] LSB 
            Frame: ( IST Address_m , Opreand Rename Register_m )
            A Packet has DECODE_NEW_INST * INST_OPREANDS Frames */
    localparam PRM_FRAME_BITWIDTH           = BITWIDTH_PHYREG_NUM + BITWIDTH_IST_ENTRY_NUM,

    localparam PRM_FRAME_STARTPOINT_PHYREG  = 0,
    localparam PRM_FRAME_STARTPOINT_IST     = PRM_FRAME_STARTPOINT_PHYREG + BITWIDTH_PHYREG_NUM,

    localparam PRM_INST_PACK_BITWIDTH       = PRM_FRAME_BITWIDTH * INST_OPREANDS,

    localparam PRM_PACKET_BITWIDTH          = PRM_INST_PACK_BITWIDTH * DECODE_NEW_INST,

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
    output wire [INST_PC_WIDTH-1:0]             o_program_counter, // Start Instruction Word output: Allow Word Addressing
    input  wire [INST_INPUT_BITWIDTH-1:0]       i_instructions,

    // Block
    input                                       i_ist_block,
    input                                       i_prm_block,

    // Allocators
    output wire [DECODE_NEW_INST-1:0]           o_allocate_position,
        // -> Instruction State Table Allocator
    input  wire [DECODE_NEW_INST-1:0]           i_ist_allocate_valid,
    input  wire [IST_ALLOCATE_BITWIDTH-1:0]     i_ist_allocate_addr,

        // -> Physical Register Manager Allocator
    input  wire [DECODE_NEW_INST-1:0]           i_prm_allocate_valid,
    input  wire [PRM_ALLOCATE_BITWIDTH-1:0]     i_prm_allocate_phyreg,

    // Create IST Field
        // <- Instruction State Table Update
    output wire [DECODE_NEW_INST-1:0]           o_ist_field_valid,
    output wire [IST_PACKET_BITWIDTH-1:0]       o_ist_field,

    // Update PRM
        // 새로 할당된 PHYREG는 할당 정보만 수집, 
        // <- Physical Register Manager Mapper
    output wire [PRM_UPDATE_PHYREG-1:0]         o_prm_map_valid,
    output wire [PRM_PACKET_BITWIDTH-1:0]       o_prm_map_list,

    // -> Write Back PHYREGs (Ready Update)
    input  wire [EX_PATH_NUM-1:0]               i_wb_done,
    input  wire [WB_PHYREGS_BITWIDTH-1:0]       i_wb_done_phyregs
);

    // [ 3 Stage ]
    // 1 - Decoding
    // 2 - Get IST, PHYREG Entry
    // 3 - Create IST Field and Mapping Opreand's PHYREG  



endmodule

module decode_position #(
    parameter CHECK_DUPLICATION_WIDTH                   = 2,
    parameter CHECK_OPREANDS                            = 2,
    parameter INST_NUM_OF_LOGICAL_REGISTER              = 32,

    localparam BITWIDTH_DUPLICATION_LOGREG              = CHECK_DUPLICATION_WIDTH * BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER,
    localparam BITWIDTH_OPREAND_LOGREG                  = CHECK_OPREANDS * CHECK_DUPLICATION_WIDTH * INST_NUM_OF_LOGICAL_REGISTER,

    localparam BITWIDTH_OUT_TARGET                      = CHECK_OPREANDS * CHECK_DUPLICATION_WIDTH,

    localparam BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER    = $clog2(INST_NUM_OF_LOGICAL_REGISTER)
) (
    input       [BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER-1:0]     i_target_logical_reg,
    input       [BITWIDTH_DUPLICATION_LOGREG-1:0]               i_check_dup_logical_reg,
    input       [BITWIDTH_OPREAND_LOGREG-1:0]                   i_check_opreand_use_logical_reg,
    
    output reg  [BITWIDTH_OUT_TARGET-1:0]                       o_use_opreand
);
    // 목적지가 동일한 필드까지의 Opreand 사용 여부만 확인
endmodule
