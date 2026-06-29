module eulsukdo_scheduler #(
    // Instruction Set Parameters
    parameter int IS_INST_PC_BITWIDTH                   = 32,
    parameter int IS_INST_PC_STEP                       = 4,
    parameter int IS_INST_BITWIDTH                      = 32,
    parameter int IS_INST_REGS                          = 32,
    parameter int IS_INST_OPERANDS                      = 2,
    parameter int IS_INST_IMM                           = 32,

    // Execution Unit Parameters
    parameter int EX_INST_MICROOP_BITWIDTH              = 5,

    // EULSUKDO Structure Parameters
    parameter int STRUCT_DECODE_NEW_INST                = 2,
    parameter int STRUCT_INST_STATE_ENTRIES             = 128,
    parameter int STRUCT_PHYREGS                        = 64,
    parameter int STRUCT_EX_PATH                        = 3,
    parameter int STRUCT_RS_OUT_ENTRY[STRUCT_EX_PATH]   = {1, 3, 1},
    parameter int STRUCT_EX_CORES                       = 5,
    parameter int STRUCT_EX_OUT_RESULT[STRUCT_EX_CORES] = {1, 1, 1, 1, 1},
    parameter int STRUCT_PRM_ENTRY_UPDATE               = 5,
    parameter int STRUCT_PRM_ENTRY_BUFFER               = 4,
    parameter int STRUCT_UNALLOCATE_PHYREG              = 4,
    parameter int STRUCT_FLOW_WINDOWS                   = 8,
    parameter int STRUCT_FLOW_PC_MAX_RANGE              = 16
) (
    input  wire                                                      clk,
    input  wire                                                      reset_n,

    output wire [STRUCT_DECODE_NEW_INST-1:0]                         o_im_req_pc_valid,
    output wire [(STRUCT_DECODE_NEW_INST * IS_INST_PC_BITWIDTH)-1:0] o_im_req_pc,
    input  wire [STRUCT_DECODE_NEW_INST-1:0]                         i_im_req_pc_get,

    input  wire [STRUCT_DECODE_NEW_INST-1:0]                         i_im_recv_pc_valid,
    input  wire [(STRUCT_DECODE_NEW_INST * IS_INST_BITWIDTH)-1:0]    i_im_recv_pc,
    output wire [STRUCT_DECODE_NEW_INST-1:0]                         o_im_recv_pc_get
);

endmodule
