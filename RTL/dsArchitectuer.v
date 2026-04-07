module dynamicScedulerArch #(
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

    // (Autogenerate) Elements
    localparam BITWIDTH_EX_PATH_NUM = $clog2(EX_PATH_NUM),
    localparam BITWIDTH_PHYREG_NUM  = $clog2(PHYREG_NUM),
    localparam BITWIDTH_IST_ENTRY_NUM = $clog2(IST_ENTRY_NUM),
    localparam BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER = $clog2(INST_NUM_OF_LOGICAL_REGISTER)
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
