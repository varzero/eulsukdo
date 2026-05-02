module instruction_state_table #(
    // Dynamic Schedular Description
    parameter DECODE_NEW_INST   = 1,
    parameter PHYREG_NUM        = 64,
    parameter IST_ENTRY_NUM     = 128,
    parameter EX_PATH_NUM       = 3,
    parameter PRM_ENTRY_BUFFER  = 4,

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
                        Destination Logical Register | 
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

    // Create IST Field
        // <- Instruction State Table Update
    input  wire [DECODE_NEW_INST-1:0]           i_ist_field_valid,
    input  wire [IST_PACKET_BITWIDTH-1:0]       i_ist_field,

        // -> Physical Register Manager Opreands Update
    output wire [(DECODE_NEW_INST*INST_OPREANDS)-1:0] o_prm_istindex_valid,
    output wire [(BITWIDTH_PHYREG_NUM*(DECODE_NEW_INST*INST_OPREANDS))-1:0] o_prm_istindex_phyreg,
    output wire [(BITWIDTH_IST_ENTRY_NUM*(DECODE_NEW_INST*INST_OPREANDS))-1:0] o_prm_istindex_istidx,

    // Update Ready Field
        // <= Physical Register Manager Opreands POP
    input  wire [(EX_PATH_NUM)-1:0] i_ready_update_valid,
    input  wire [(BITWIDTH_PHYREG_NUM*EX_PATH_NUM)-1:0] i_ready_update_phyreg,
    input  wire [(BITWIDTH_IST_ENTRY_NUM*EX_PATH_NUM)-1:0] i_ready_update_istidx,


    // 추후에 여기에 분기 예측 실패에서 IST 엔트리 지우는 부분 추가하기
);
    // 

    // Allocate IST Entry
    allocator #(
    	.NUM_OF_ENTRIES (IST_ENTRY_NUM),
        .UNALLOCATES    (),
        .ALLOCATES      (DECODE_NEW_INST)
    ) U_ALLOCATE_IST_ENTRY (
        .clk                    (clk),
        .reset_n                (reset_n),
        .unallocate_valid_i     (),
        .unallocate_entries_i   (),
        .allocating_i           (),
    	.allocate_valid_o       (),
        .allocate_entries_o     (),
    	.init_done              ()
    );

    /* Entry: MSB [ IMM | Destination Rename Register | 
                    PC | Micro-OP | EX_PATH ] LSB */   
        // IST Entry 
    regfile #(
        .READ_CHANNEL    (),
        .WRITE_CHANNEL   (DECODE_NEW_INST),
        .ENTRIES         (IST_ENTRY_NUM),
        .REG_WIDTH       ()
    ) U_ (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_addresses    (),
        .i_write_wes         (),
        .i_write_addresses   (),
        .i_write_data        (),
        .o_read_data         ()
    );

endmodule
