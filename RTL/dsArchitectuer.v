module new_entry_logic #(
    // Dynamic Schedular Description
    parameter DECODE_NEW_INST   = 3,
    parameter PHYREG_NUM        = 64,
    parameter IST_ENTRY_NUM     = 128,
    parameter EX_PATH_NUM       = 5,

    // Instruction Field Description
    parameter INST_PC_WIDTH                 = 32,
    parameter INST_OPCODE_WIDTH             = 7,
    parameter INST_OPTIONAL_OPCODE_WIDTH    = 10,
    parameter INST_IMM_WIDTH                = 32,
    parameter INST_NUM_OF_LOGICAL_REGISTER  = 32,
    parameter INST_OPREANDS                 = 2,

    // Internal Field Description (Decoder Compiler (or Human) Generate)
    parameter MICROOP_WIDTH                 = 6, // Micro-OP is not contained information of EX_PATH

    // (Autogenerate) Elements
    localparam BITWIDTH_EX_PATH_NUM = $clog2(EX_PATH_NUM),
    localparam BITWIDTH_PHYREG_NUM  = $clog2(PHYREG_NUM),
    localparam BITWIDTH_IST_ENTRY_NUM = $clog2(IST_ENTRY_NUM),
    localparam BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER = $clog2(INST_NUM_OF_LOGICAL_REGISTER),

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

    localparam IST_STARTPOINT_PHYREG = INST_PC_WIDTH + MICROOP_WIDTH + INST_PC_WIDTH + INST_IMM_WIDTH,
    localparam IST_STARTPOINT_LOGREG = IST_STARTPOINT_PHYREG + BITWIDTH_PHYREG_NUM,
    localparam IST_STARTPOINT_OPREAND_PHYREG = IST_STARTPOINT_LOGREG + BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER,
    localparam IST_STARTPOINT_OPREAND_READY = IST_STARTPOINT_OPREAND_PHYREG + IST_BITWIDTH_OPREAND_PHYREG_FULL,

    // (Autogenerate) Field of Allocator in Instruction State Table
    localparam IST_ALLOCATE_BITWIDTH = BITWIDTH_IST_ENTRY_NUM * DECODE_NEW_INST,

    // (Autogenerate) Packet of registing that Opreand Rename Register to Physical Register Manager
        /* Packet: MSB [ ( IST Address_n , Opreand Rename Register_n ), ... , ( IST Address_1 , Opreand Rename Register_1 ) ] LSB 
            Frame: ( IST Address_m , Opreand Rename Register_m )
            A Packet has DECODE_NEW_INST * INST_OPREANDS Frames */
    localparam PRM_FRAME_BITWIDTH   = BITWIDTH_PHYREG_NUM + BITWIDTH_IST_ENTRY_NUM,

    localparam PRM_FRAME_STARTPOINT_PHYREG  = 0,
    localparam PRM_FRAME_STARTPOINT_IST     = PRM_FRAME_STARTPOINT_PHYREG + BITWIDTH_PHYREG_NUM,

    localparam PRM_PACKET_BITWIDTH  = (PRM_FRAME_BITWIDTH * INST_OPREANDS) * DECODE_NEW_INST;
) (
    input               clk,
    input               reset_n,

    // <-> Instruction Memory

);

    // [ 3 Stage ]
    // 1 - Decoding
    // 2 - Get IST, PHYREG Entry
    // 3 - Create IST Field and Mapping Opreand's PHYREG  



endmodule

