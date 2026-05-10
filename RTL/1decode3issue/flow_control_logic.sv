`timescale 1ns / 1ps

`include "../memories.v"
`include "../position_splitter.v"

module flow_control_logic #(
    // Dynamic Schedular Description
    parameter DECODE_NEW_INST   = 1,
    parameter PHYREG_NUM        = 64,
    parameter IST_ENTRY_NUM     = 128,
    parameter EX_PATH_NUM       = 3,
    parameter PRM_ENTRY_BUFFER  = 4,
    parameter RS_ENTRY_NUM      = 16,
    parameter RS_PUSH_WIDTH     = 3,
    parameter FCL_RB_NUM        = 8,
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
    localparam BITWIDTH_INST_NUM_OF_OGICAL_REGISTER     = $clog2(INST_NUM_OF_LOGICAL_REGISTER),
    localparam BITWIDTH_FCL_RB_NUM                      = $clog2(FCL_RB_NUM)
) (
    input  wire                  clk,
    input  wire                  reset_n,

    // New Entry Logic
        // <- Jump Instruction Input
    input  wire                                               i_nel_jump_inst,
    input  wire [INST_PC_WIDTH-1:0]                           i_nel_jump_pc,
    input  wire                                               i_nel_branch_inst,
        // <- Allocate Registers input
    input  wire [DECODE_NEW_INST-1:0]                         i_nel_newpc_valid,
    input  wire [(INST_PC_WIDTH*DECODE_NEW_INST)-1:0]         i_nel_newpc,
    input  wire [DECODE_NEW_INST-1:0]                         i_nel_newreg_valid,
    input  wire [(BITWIDTH_PHYREG_NUM*DECODE_NEW_INST)-1:0]   i_nel_newreg,

    // Physical Register Mapper
        // -> Unallocate Registers Output
    output wire [UNALLOCATE_PHYREG-1:0]                       o_prm_unallocate_valid,
    output wire [(BITWIDTH_PHYREG_NUM*UNALLOCATE_PHYREG)-1:0] o_prm_unallocate_phyreg,

    // Write Back Concatenation
        // <- PC Input
    input  wire [EX_PATH_NUM-1:0]                             i_wbc2fcl_done,
    input  wire [(EX_PATH_NUM*INST_PC_WIDTH)-1:0]             i_wbc2fcl_pc,
    input  wire [INST_PC_WIDTH-1:0]                           i_wbc2fcl_branch_pc,

    // Instruction Memory
        // -> New PC Output
    output wire                                               o_im_re, // read enable
    output wire [INST_PC_WIDTH-1:0]                           o_im_pc
);

endmodule

module flow_detect_unit #(
    parameter DECODE_NEW_INST               = 1,
    parameter PHYREG_NUM                    = 64,
    parameter UNALLOCATE_PHYREG             = 4,
    parameter INST_PC_WIDTH                 = 32,

    localparam MAX_PC_RANGE                 = PHYREG_NUM/2,
    localparam BITWIDTH_PC_RANGE            = $clog2(MAX_PC_RANGE)
    localparam BITWIDTH_PHYREG_NUM          = $clog2(PHYREG_NUM)
) (
    input  wire                  clk,
    input  wire                  reset_n,

    // Flow Control Logic
        // <- Entry Valid input
    input  wire                                               i_entry_force_deactive,
        // -> Entry Valid output
    output wire                                               o_entry_active,
    output reg                                                o_entry_free,
        // <- PC Input
    input  wire [DECODE_NEW_INST-1:0]                         i_nel_newpc_valid,
    input  wire [(INST_PC_WIDTH*DECODE_NEW_INST)-1:0]         i_nel_newpc,
    output reg  [DECODE_NEW_INST-1:0]                         o_this_range,
    input  wire                                               i_set_start_pc_valid,
    input  wire [INST_PC_WIDTH-1:0]                           i_set_start_pc,
    input  wire                                               i_set_last_pc_valid,
    input  wire [INST_PC_WIDTH-1:0]                           i_set_last_pc,
        // <- Allocate Registers input
    input  wire [DECODE_NEW_INST-1:0]                         i_nel_newreg_valid,
    input  wire [(BITWIDTH_PHYREG_NUM*DECODE_NEW_INST)-1:0]   i_nel_newreg,
    
    // Physical Register Mapper
        // -> Unallocate Registers Output
    output wire [UNALLOCATE_PHYREG-1:0]                       o_prm_unallocate_valid,
    output wire [(BITWIDTH_PHYREG_NUM*UNALLOCATE_PHYREG)-1:0] o_prm_unallocate_phyreg,
);
    reg                          active,    active_next;
    reg [INST_PC_WIDTH-1:0]      pc_start,  pc_start_next;
    reg [INST_PC_WIDTH-1:0]      pc_last,   pc_last_next;
    reg [BITWIDTH_PC_RANGE-1:0]  range_cnt, range_cnt_next;
    reg [BITWIDTH_PC_RANGE-1:0]  range,     range_next;

    always @(posedge clk or negedge reset_n) begin
        if (reset_n == 1'b0) begin
            active    <= 1'b0;
            pc_start  <= 0;
            pc_last   <= 0;
            range_cnt <= 0;
            range     <= 0;
        end
        else begin
            active    <= active_next;
            pc_start  <= pc_start_next;
            pc_last   <= pc_last_next;
            range_cnt <= range_cnt_next;
            range     <= range_next;
        end
    end

    fifo_ordering_position #(
    	parameter PUSH_DATA = 4,
    	parameter POP_DATA = 7,
    	parameter ENTRY_WIDTH = 32,
    	parameter FIFO_DEPTH = 128
    ) (
    	input clk,
    	input reset_n,
    	input [PUSH_DATA-1:0] push_valid_i,
    	input [(PUSH_DATA * ENTRY_WIDTH)-1:0] push_data_i,
    	input [POP_DATA-1:0] pop_get_i,
    	output [POP_DATA-1:0] pop_valid_o,
    	output [(POP_DATA * ENTRY_WIDTH)-1:0] pop_data_o,
    	output push_available_o
    );

endmodule
