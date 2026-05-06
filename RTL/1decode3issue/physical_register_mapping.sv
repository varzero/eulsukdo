module physical_register_mapping #(
    // Dynamic Schedular Description
    parameter DECODE_NEW_INST   = 1,
    parameter PHYREG_NUM        = 64,
    parameter IST_ENTRY_NUM     = 128,
    parameter EX_PATH_NUM       = 3,
    parameter PRM_ENTRY_BUFFER  = 4,
    parameter PRM_ENTRY_UPDATE  = 3,
    parameter RS_ENTRY_NUM      = 16,
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
    localparam BITWIDTH_PHYREG_BUFFER                   = $clog2(PRM_ENTRY_BUFFER),
    localparam BITWIDTH_IST_ENTRY_NUM                   = $clog2(IST_ENTRY_NUM),
    localparam BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER    = $clog2(INST_NUM_OF_LOGICAL_REGISTER),
    
    localparam RS_PUSH_WIDTH     = PRM_ENTRY_UPDATE + DECODE_NEW_INST,

    // (Autogenerate) Field of Allocator in Physical Register Manager
    localparam PRM_ALLOCATE_BITWIDTH        = BITWIDTH_PHYREG_NUM * DECODE_NEW_INST
    localparam PRM_UNALLOCATE_BITWIDTH      = BITWIDTH_PHYREG_NUM * UNALLOCATE_PHYREG
) (
    input                                       clk,
    input                                       reset_n,

    // Allocators
    input  wire [DECODE_NEW_INST-1:0]           i_allocate_position,
        // <- Physical Register Manager Allocator
    output wire [DECODE_NEW_INST-1:0]           o_prm_allocate_valid,
    output wire [PRM_ALLOCATE_BITWIDTH-1:0]     o_prm_allocate_phyreg,
        // -> Physical Register Manager Unallocator
    input  wire [UNALLOCATE_PHYREG-1:0]           i_prm_unallocate_valid,
    input  wire [PRM_UNALLOCATE_BITWIDTH-1:0]     i_prm_unallocate_phyreg,

        // -> Physical Register Manager Opreands Update
    input  reg  [(DECODE_NEW_INST*INST_OPREANDS)-1:0]                          i_prm_istindex_valid,
    input  reg  [(BITWIDTH_PHYREG_NUM*(DECODE_NEW_INST*INST_OPREANDS))-1:0]    i_prm_istindex_phyreg,
    input  reg  [(BITWIDTH_IST_ENTRY_NUM*(DECODE_NEW_INST*INST_OPREANDS))-1:0] i_prm_istindex_istidx,
    
    // Update Ready Field
        // <- Physical Register Manager Opreands POP
    output wire [(PRM_ENTRY_UPDATE)-1:0]                                       o_ready_update_valid,
    output wire [(BITWIDTH_PHYREG_NUM*PRM_ENTRY_UPDATE)-1:0]                   o_ready_update_phyreg,
    output wire [(BITWIDTH_IST_ENTRY_NUM*PRM_ENTRY_UPDATE)-1:0]                o_ready_update_istidx,

        // -> WB Physical Register Ready
    input  wire [EX_PATH_NUM-1:0] i_wb_done,
    input  wire [(EX_PATH_NUM*BITWIDTH_PHYREG_NUM)-1:0] i_wb_done_phyreg,

    // Block
    output wire o_prm_active
);
    wire allocator_active;

    assign o_prm_active = allocator_active & ;

    // Allocate PHYREG
    allocator #(
    	.NUM_OF_ENTRIES (PHYREG_NUM),
        .UNALLOCATES    (UNALLOCATE_PHYREG),
        .ALLOCATES      (DECODE_NEW_INST)
    ) U_ALLOCATE_PHYREG (
        .clk                    (clk),
        .reset_n                (reset_n),
        .unallocate_valid_i     (i_prm_unallocate_valid),
        .unallocate_entries_i   (i_prm_unallocate_phyreg),
        .allocating_i           (i_allocate_position),
    	.allocate_valid_o       (o_ist_allocate_valid),
        .allocate_entries_o     (o_ist_allocate_addr),
    	.init_done              (allocator_active)
    );

    // PHYREG Counter
    regfile #(
        .READ_CHANNEL  ( EX_PATH_NUM+(DECODE_NEW_INST*INST_OPREANDS) ),
        .WRITE_CHANNEL ( (DECODE_NEW_INST*INST_OPREANDS) ),
        .ENTRIES       (PHYREG_NUM),
        .REG_WIDTH     (BITWIDTH_PHYREG_BUFFER)
    ) U_PHYREG_CNT_REG (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_addresses    (),
        .i_write_wes         (),
        .i_write_addresses   (),
        .i_write_data        (),
        .o_read_data         ()
    );

    // PHYREG Mapping IST Entry
    genvar phyreg_buf_idx;
    generate
        for (phyreg_buf_idx = 0; phyreg_buf_idx < PRM_ENTRY_BUFFER; phyreg_buf_idx = phyreg_buf_idx+1) begin
            regfile #(
                .READ_CHANNEL  (),
                .WRITE_CHANNEL (),
                .ENTRIES       (PHYREG_NUM),
                .REG_WIDTH     ()
            ) U_PHYREG_BUF (
                .clk                 (clk),
                .reset_n             (reset_n),
                .i_read_addresses    (),
                .i_write_wes         (),
                .i_write_addresses   (),
                .i_write_data        (),
                .o_read_data         ()
            );
        end
    endgenerate

endmodule