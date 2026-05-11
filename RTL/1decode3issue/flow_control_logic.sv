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
    input  wire                                               i_nel_branch_inst,
    input  wire [INST_PC_WIDTH-1:0]                           i_nel_jump_branch_pc,
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
    output wire                                               o_pc_entry_max,
    output wire                                               o_entry_active,
    output reg                                                o_entry_free,
        // <- PC Input
    input  wire                                               i_set_start_pc_valid,
    input  wire [INST_PC_WIDTH-1:0]                           i_set_start_pc,
    input  wire                                               i_set_last_pc_valid,
    input  wire [INST_PC_WIDTH-1:0]                           i_set_last_pc,
        // <- Allocate Registers input
    input  wire [DECODE_NEW_INST-1:0]                         i_nel_newpc_valid,
    input  wire [(INST_PC_WIDTH*DECODE_NEW_INST)-1:0]         i_nel_newpc,
    input  wire [DECODE_NEW_INST-1:0]                         i_nel_newreg_valid,
    input  wire [(BITWIDTH_PHYREG_NUM*DECODE_NEW_INST)-1:0]   i_nel_newreg,

    // Write Back Concatenation
        // <- PC Input
    input  wire [EX_PATH_NUM-1:0]                             i_wbc2fcl_done,
    input  wire [(EX_PATH_NUM*INST_PC_WIDTH)-1:0]             i_wbc2fcl_pc,
    
    // Physical Register Mapper
        // -> Unallocate Registers Output
    output wire [UNALLOCATE_PHYREG-1:0]                       o_prm_unallocate_valid,
    output wire [(BITWIDTH_PHYREG_NUM*UNALLOCATE_PHYREG)-1:0] o_prm_unallocate_phyreg,
);
    reg  [EX_PATH_NUM-1:0] entry_range_catch;
    reg  [INST_PC_WIDTH-1:0] split_wb_pc;
    wire [(BITWIDTH_PHYREG_NUM*UNALLOCATE_PHYREG)-1:0] phyreg_unallocate_valid;
    wire [(BITWIDTH_PHYREG_NUM*UNALLOCATE_PHYREG)-1:0] phyreg_unallocate;
    wire [INST_PC_WIDTH-1:0]                           new_range_sub_pc;
    integer target_pc;
    assign new_range_sub_pc = i_set_last_pc-pc_start;

    // Register Variables
    reg [1:0]                    state,     state_next;
    reg [INST_PC_WIDTH-1:0]      pc_start,  pc_start_next;
    reg [INST_PC_WIDTH-1:0]      pc_last,   pc_last_next;
    reg [BITWIDTH_PC_RANGE-1:0]  range_cnt, range_cnt_next;
    reg [BITWIDTH_PC_RANGE-1:0]  range,     range_next;
    
    always @(*) begin
        for (target_pc = 0; target_pc < EX_PATH_NUM; target_pc = target_pc+1) begin
            split_wb_pc = i_wbc2fcl_pc[(INST_PC_WIDTH*target_pc) +: INST_PC_WIDTH];
            if (i_wbc2fcl_done[target_pc]) begin
                entry_range_catch[target_pc] 
                    = ( (split_wb_pc >= pc_start) && (split_wb_pc <= pc_last) )? 1'b1 : 1'b0;
            end
            else entry_range_catch[target_pc] = 1'b0;
        end
    end

    // FSM
    localparam UNACTIVE = 2'b00;
    localparam ACTIVE   = 2'b01;
    localparam FREE     = 2'b10;

    // Registers
    always @(posedge clk or negedge reset_n) begin
        if (reset_n == 1'b0) begin
            state     <= UNACTIVE;
            pc_start  <= 0;
            pc_last   <= 0;
            range_cnt <= 0;
            range     <= 0;
        end
        else begin
            state     <= state_next;
            pc_start  <= pc_start_next;
            pc_last   <= pc_last_next;
            range_cnt <= range_cnt_next;
            range     <= range_next;
        end
    end

    // State Transition
    always @(*) begin
        case(state)
            UNACTIVE: begin
                if (i_set_start_pc_valid) state_next = ACTIVE;
                else                      state_next = UNACTIVE;
            end
            ACTIVE  : begin
                if (!i_set_last_pc_valid && (range_cnt_next == range)) state_next = FREE;
                else                         state_next = ACTIVE;
            end
            FREE    : begin
                if (!(|phyreg_unallocate_valid)) state_next = UNACTIVE;
                else                             state_next = FREE;
            end
            default : begin
                state_next = UNACTIVE;
            end
        endcase
    end

    // State Operations
    integer target_catch;
    reg [DECODE_NEW_INST-1:0] push_valid;
    always @(*) begin
        case(state)
            UNACTIVE: begin
                push_valid = 0;
                if (i_set_start_pc_valid) begin
                    pc_start_next   = i_set_start_pc;
                    pc_last_next    = i_set_start_pc+(MAX_PC_RANGE << 2);
                    range_cnt_next  = 0;
                    range_next      = MAX_PC_RANGE;
                end
                else begin
                    pc_start_next   = 0;
                    pc_last_next    = 0;
                    range_cnt_next  = 0;
                    range_next      = 0;
                end
            end
            ACTIVE  : begin
                push_valid = ;
                pc_start_next   = pc_start;
                pc_last_next    = (i_set_last_pc_valid)? i_set_last_pc : pc_last;
                range_cnt_next = range_cnt;
                for (target_catch = 0; target_catch < INST_PC_WIDTH; target_catch = target_catch+1) begin
                    range_cnt_next = range_cnt_next + ( ( entry_range_catch[target_catch] )? 1 : 0 );
                end
                range_next      = (i_set_last_pc_valid)? new_range_sub_pc[BITWIDTH_PC_RANGE+1:2] : range;
            end
            FREE    : begin
                push_valid = 0;
                pc_start_next   = 0;
                pc_last_next    = 0;
                range_cnt_next  = 0;
                range_next      = 0;
            end
            default : begin
                push_valid = 0;
                pc_start_next   = 0;
                pc_last_next    = 0;
                range_cnt_next  = 0;
                range_next      = 0;
            end
        endcase
    end

    fifo_ordering_position #(
        .PUSH_DATA      (DECODE_NEW_INST),
        .POP_DATA       (UNALLOCATE_PHYREG*2),
        .ENTRY_WIDTH    (BITWIDTH_PHYREG_NUM),
        .FIFO_DEPTH     ( (PHYREG_NUM/ (UNALLOCATE_PHYREG*2) )+1 )
    ) U_END_PHYREG_STORE (
    	.clk                (clk),
    	.reset_n            (reset_n),
    	.push_valid_i       (),
    	.push_data_i        (i_nel_newreg),
    	.pop_get_i          (),
    	.pop_valid_o        (phyreg_unallocate_valid),
    	.pop_data_o         (phyreg_unallocate),
    	.push_available_o   ()
    );

endmodule
