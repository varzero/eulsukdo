module eulsukdo_1dec_3issue #(
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
    localparam BITWIDTH_FCL_PC_WIDTH                    = BITWIDTH_FCL_RB_NUM + INST_PC_WIDTH
) (
    input                                             clk,
    input                                             reset_n,

    input  wire [DECODE_NEW_INST-1:0]                 i_im_inst_valid,
    input  wire [(DECODE_NEW_INST*INST_PC_WIDTH)-1:0] i_im_inst_pc,
    input  wire [(DECODE_NEW_INST*INST_BITWIDTH)-1:0] i_im_inst,
    output wire [DECODE_NEW_INST-1:0]                 o_im_inst_get,
    
    output reg                                        o_im_re,
    output wire [INST_PC_WIDTH-1:0]                   o_im_pc,

    // EX INOUT Section Start

    // EX INOUT Section End
);

    new_entry_logic #(
        .DECODE_NEW_INST               (DECODE_NEW_INST),
        .PHYREG_NUM                    (PHYREG_NUM),
        .IST_ENTRY_NUM                 (IST_ENTRY_NUM),
        .EX_PATH_NUM                   (EX_PATH_NUM),
        .PRM_ENTRY_BUFFER              (PRM_ENTRY_BUFFER),
        .RS_ENTRY_NUM                  (RS_ENTRY_NUM),
        .RS_PUSH_WIDTH                 (RS_PUSH_WIDTH),
        .FCL_RB_NUM                    (FCL_RB_NUM),
        .FCL_PC_GAP                    (FCL_PC_GAP),
        .UNALLOCATE_PHYREG             (UNALLOCATE_PHYREG),
        .INST_PC_WIDTH                 (INST_PC_WIDTH),
        .INST_BITWIDTH                 (INST_BITWIDTH),
        .INST_OPCODE_WIDTH             (INST_OPCODE_WIDTH),
        .INST_OPTIONAL_OPCODE_WIDTH    (INST_OPTIONAL_OPCODE_WIDTH),
        .INST_IMM_WIDTH                (INST_IMM_WIDTH),
        .INST_NUM_OF_LOGICAL_REGISTER  (INST_NUM_OF_LOGICAL_REGISTER),
        .INST_OPREANDS                 (INST_OPREANDS),
        .MICROOP_WIDTH                 (MICROOP_WIDTH)
    ) U_NEL (
        .clk                           (clk),
        .reset_n                       (reset_n),
        .i_im_inst_valid               (i_im_inst_valid),
        .i_im_inst_pc                  (i_im_inst_pc),
        .i_im_inst                     (i_im_inst),
        .o_im_inst_get                 (o_im_inst_get),
        .i_ist_insert_available        (i_ist_insert_available),
        .o_ist_field_insert            (o_ist_field_insert),
        .i_ist_field_valid             (i_ist_field_valid),
        .o_ist_field                   (o_ist_field),
        .o_allocate_position           (o_allocate_position),
        .i_prm_allocate_valid          (i_prm_allocate_valid),
        .i_prm_allocate_phyreg         (i_prm_allocate_phyreg),
        .i_wbc2nel_done                (i_wbc2nel_done),
        .i_wbc2nel_done_phyreg         (i_wbc2nel_done_phyreg),
        .o_nel_block                   (o_nel_block),
        .o_nel_jump_inst               (o_nel_jump_inst),
        .o_nel_jreg_branch_inst        (o_nel_jreg_branch_inst),
        .o_nel_jump_branch_pc          (o_nel_jump_branch_pc),
        .o_nel_newpc_valid             (o_nel_newpc_valid),
        .o_nel_newpc                   (o_nel_newpc),
        .o_nel_newreg_valid            (o_nel_newreg_valid),
        .o_nel_newreg                  (o_nel_newreg)
    );

    instruction_state_table #(
        .DECODE_NEW_INST               (DECODE_NEW_INST),
        .PHYREG_NUM                    (PHYREG_NUM),
        .IST_ENTRY_NUM                 (IST_ENTRY_NUM),
        .EX_PATH_NUM                   (EX_PATH_NUM),
        .PRM_ENTRY_BUFFER              (PRM_ENTRY_BUFFER),
        .PRM_ENTRY_UPDATE              (PRM_ENTRY_UPDATE),
        .RS_ENTRY_NUM                  (RS_ENTRY_NUM),
        .FCL_RB_NUM                    (FCL_RB_NUM),
        .INST_PC_WIDTH                 (INST_PC_WIDTH),
        .INST_BITWIDTH                 (INST_BITWIDTH),
        .INST_OPCODE_WIDTH             (INST_OPCODE_WIDTH),
        .INST_OPTIONAL_OPCODE_WIDTH    (INST_OPTIONAL_OPCODE_WIDTH),
        .INST_IMM_WIDTH                (INST_IMM_WIDTH),
        .INST_NUM_OF_LOGICAL_REGISTER  (INST_NUM_OF_LOGICAL_REGISTER),
        .INST_OPREANDS                 (INST_OPREANDS),
        .MICROOP_WIDTH                 (MICROOP_WIDTH)
    ) U_IST (
        .clk                           (clk),
        .reset_n                       (reset_n),
        .o_ist_insert_available        (o_ist_insert_available),
        .i_ist_field_insert            (i_ist_field_insert),
        .o_ist_field_valid             (o_ist_field_valid),
        .i_ist_field                   (i_ist_field),
        .o_prm_istindex_valid          (o_prm_istindex_valid),
        .o_prm_istindex_phyreg         (o_prm_istindex_phyreg),
        .o_prm_istindex_istidx         (o_prm_istindex_istidx),
        .i_ready_update_valid          (i_ready_update_valid),
        .o_ready_update_get            (o_ready_update_get),
        .i_ready_update_phyreg         (i_ready_update_phyreg),
        .i_ready_update_istidx         (i_ready_update_istidx),
        .i_push_rs_available           (i_push_rs_available),
        .o_push_rs_valid               (o_push_rs_valid),
        .o_push_rs_data                (o_push_rs_data)
    );

    physical_register_mapping #(
        .DECODE_NEW_INST               (DECODE_NEW_INST),
        .PHYREG_NUM                    (PHYREG_NUM),
        .IST_ENTRY_NUM                 (IST_ENTRY_NUM),
        .EX_PATH_NUM                   (EX_PATH_NUM),
        .PRM_ENTRY_BUFFER              (PRM_ENTRY_BUFFER),
        .PRM_ENTRY_UPDATE              (PRM_ENTRY_UPDATE),
        .PRM_READY_OUT_FIFO_DEPTH      (PRM_READY_OUT_FIFO_DEPTH),
        .RS_ENTRY_NUM                  (RS_ENTRY_NUM),
        .UNALLOCATE_PHYREG             (UNALLOCATE_PHYREG),
        .INST_PC_WIDTH                 (INST_PC_WIDTH),
        .INST_BITWIDTH                 (INST_BITWIDTH),
        .INST_OPCODE_WIDTH             (INST_OPCODE_WIDTH),
        .INST_OPTIONAL_OPCODE_WIDTH    (INST_OPTIONAL_OPCODE_WIDTH),
        .INST_IMM_WIDTH                (INST_IMM_WIDTH),
        .INST_NUM_OF_LOGICAL_REGISTER  (INST_NUM_OF_LOGICAL_REGISTER),
        .INST_OPREANDS                 (INST_OPREANDS),
        .MICROOP_WIDTH                 (MICROOP_WIDTH)
    ) U_PRM (
        .clk                           (clk),
        .reset_n                       (reset_n),
        .i_allocate_position           (i_allocate_position),
        .o_prm_allocate_valid          (o_prm_allocate_valid),
        .o_prm_allocate_phyreg         (o_prm_allocate_phyreg),
        .i_prm_unallocate_valid        (i_prm_unallocate_valid),
        .i_prm_unallocate_phyreg       (i_prm_unallocate_phyreg),
        .i_prm_istindex_valid          (i_prm_istindex_valid),
        .i_prm_istindex_phyreg         (i_prm_istindex_phyreg),
        .i_prm_istindex_istidx         (i_prm_istindex_istidx),
        .o_ready_update_valid          (o_ready_update_valid),
        .i_ready_update_get            (i_ready_update_get),
        .o_ready_update_phyreg         (o_ready_update_phyreg),
        .o_ready_update_istidx         (o_ready_update_istidx),
        .i_wb_done                     (i_wb_done),
        .i_wb_done_phyreg              (i_wb_done_phyreg),
        .o_prm_active                  (o_prm_active)
    );

    ready_station #(
        .DECODE_NEW_INST               (DECODE_NEW_INST),
        .PHYREG_NUM                    (PHYREG_NUM),
        .IST_ENTRY_NUM                 (IST_ENTRY_NUM),
        .EX_PATH_NUM                   (EX_PATH_NUM),
        .PRM_ENTRY_BUFFER              (PRM_ENTRY_BUFFER),
        .RS_ENTRY_NUM                  (RS_ENTRY_NUM),
        .RS_PUSH_WIDTH                 (RS_PUSH_WIDTH),
        .FCL_RB_NUM                    (FCL_RB_NUM),
        .FCL_PC_GAP                    (FCL_PC_GAP),
        .UNALLOCATE_PHYREG             (UNALLOCATE_PHYREG),
        .INST_PC_WIDTH                 (INST_PC_WIDTH),
        .INST_BITWIDTH                 (INST_BITWIDTH),
        .INST_OPCODE_WIDTH             (INST_OPCODE_WIDTH),
        .INST_OPTIONAL_OPCODE_WIDTH    (INST_OPTIONAL_OPCODE_WIDTH),
        .INST_IMM_WIDTH                (INST_IMM_WIDTH),
        .INST_NUM_OF_LOGICAL_REGISTER  (INST_NUM_OF_LOGICAL_REGISTER),
        .INST_OPREANDS                 (INST_OPREANDS),
        .MICROOP_WIDTH                 (MICROOP_WIDTH)
    ) U_RS (
        .clk                           (clk),
        .reset_n                       (reset_n),
        .o_ist_ready_entry_get         (o_ist_ready_entry_get),
        .i_ist_ready_entry_valid       (i_ist_ready_entry_valid),
        .i_ist_ready_entry             (i_ist_ready_entry),
        .i_ex_entry_get                (i_ex_entry_get),
        .o_ex_entry_valid              (o_ex_entry_valid),
        .o_ex_entry                    (o_ex_entry)
    );

    // EX Section Start

    // EX Section End

    write_back_concatenation #(
        .DECODE_NEW_INST               (DECODE_NEW_INST),
        .PHYREG_NUM                    (PHYREG_NUM),
        .IST_ENTRY_NUM                 (IST_ENTRY_NUM),
        .EX_PATH_NUM                   (EX_PATH_NUM),
        .PRM_ENTRY_BUFFER              (PRM_ENTRY_BUFFER),
        .RS_ENTRY_NUM                  (RS_ENTRY_NUM),
        .RS_PUSH_WIDTH                 (RS_PUSH_WIDTH),
        .INST_PC_WIDTH                 (INST_PC_WIDTH),
        .INST_BITWIDTH                 (INST_BITWIDTH),
        .INST_OPCODE_WIDTH             (INST_OPCODE_WIDTH),
        .INST_OPTIONAL_OPCODE_WIDTH    (INST_OPTIONAL_OPCODE_WIDTH),
        .INST_IMM_WIDTH                (INST_IMM_WIDTH),
        .INST_NUM_OF_LOGICAL_REGISTER  (INST_NUM_OF_LOGICAL_REGISTER),
        .INST_OPREANDS                 (INST_OPREANDS),
        .MICROOP_WIDTH                 (MICROOP_WIDTH)
    ) U_WBC (
        .clk                           (clk),
        .reset_n                       (reset_n),
        .i_ex_done                     (i_ex_done),
        .i_ex_done_pc                  (i_ex_done_pc),
        .i_ex_done_branch              (i_ex_done_branch),
        .i_ex_done_branch_pc           (i_ex_done_branch_pc),
        .i_ex_done_phyreg              (i_ex_done_phyreg),
        .o_wbc2prm_done                (o_wbc2prm_done),
        .o_wbc2prm_done_phyreg         (o_wbc2prm_done_phyreg),
        .o_wbc2nel_done                (o_wbc2nel_done),
        .o_wbc2nel_done_phyreg         (o_wbc2nel_done_phyreg),
        .o_wbc2fcl_done                (o_wbc2fcl_done),
        .o_wbc2fcl_pc                  (o_wbc2fcl_pc),
        .o_wbc2fcl_branch              (o_wbc2fcl_branch),
        .o_wbc2fcl_branch_pc           (o_wbc2fcl_branch_pc)
    );

    flow_control_logic #(
        .DECODE_NEW_INST               (DECODE_NEW_INST),
        .PHYREG_NUM                    (PHYREG_NUM),
        .IST_ENTRY_NUM                 (IST_ENTRY_NUM),
        .EX_PATH_NUM                   (EX_PATH_NUM),
        .PRM_ENTRY_BUFFER              (PRM_ENTRY_BUFFER),
        .RS_ENTRY_NUM                  (RS_ENTRY_NUM),
        .RS_PUSH_WIDTH                 (RS_PUSH_WIDTH),
        .FCL_RB_NUM                    (FCL_RB_NUM),
        .FCL_PC_GAP                    (FCL_PC_GAP),
        .UNALLOCATE_PHYREG             (UNALLOCATE_PHYREG),
        .INST_PC_WIDTH                 (INST_PC_WIDTH),
        .INST_BITWIDTH                 (INST_BITWIDTH),
        .INST_OPCODE_WIDTH             (INST_OPCODE_WIDTH),
        .INST_OPTIONAL_OPCODE_WIDTH    (INST_OPTIONAL_OPCODE_WIDTH),
        .INST_IMM_WIDTH                (INST_IMM_WIDTH),
        .INST_NUM_OF_LOGICAL_REGISTER  (INST_NUM_OF_LOGICAL_REGISTER),
        .INST_OPREANDS                 (INST_OPREANDS),
        .MICROOP_WIDTH                 (MICROOP_WIDTH)
    ) (
        .clk                           (clk),
        .reset_n                       (reset_n),
        .i_nel_block                   (i_nel_block),
        .i_nel_jump_inst               (i_nel_jump_inst),
        .i_nel_jreg_branch_inst        (i_nel_jreg_branch_inst),
        .i_nel_jump_branch_pc          (i_nel_jump_branch_pc),
        .i_nel_newpc_valid             (i_nel_newpc_valid),
        .i_nel_newpc                   (i_nel_newpc),
        .i_nel_newreg_valid            (i_nel_newreg_valid),
        .i_nel_newreg                  (i_nel_newreg),
        .o_prm_unallocate_valid        (o_prm_unallocate_valid),
        .o_prm_unallocate_phyreg       (o_prm_unallocate_phyreg),
        .i_wbc2fcl_done                (i_wbc2fcl_done),
        .i_wbc2fcl_pc                  (i_wbc2fcl_pc),
        .i_wbc2fcl_branch              (i_wbc2fcl_branch),
        .i_wbc2fcl_branch_pc           (i_wbc2fcl_branch_pc),
        .o_im_re                       (o_im_re),
        .o_im_pc                       (o_im_pc)
    );

endmodule