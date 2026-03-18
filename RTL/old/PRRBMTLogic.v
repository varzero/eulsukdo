module prrbmt_allocate_reg #(
    parameter ROB_ENTRIES = 128,
    parameter PHYSICAL_REGISTERS = 64,
    parameter LIST_SRAN_CAPASITY = 128,
    parameter NEW_ENTRIES_INPUT_MAX = 4,
    parameter INST_PHYSICALREG_WIDTH = 6,
    parameter INST_OPERANDS = 2,
    parameter COMPLETE_RUN = 7,
    parameter BUFFER_ENTRY = 4,
    parameter UNALLOCATE_PHY_REGS = 4,
    parameter ROB_ADDR_WIDTH = $clog2(ROB_ENTRIES),
    parameter PHY_REG_ADDR_WIDTH = $clog2(PHYSICAL_REGISTERS),
    parameter LIST_SRAM_ADDR_WIDTH = $clog2(LIST_SRAN_CAPASITY),
    parameter COUNTER_BUFFER_WIDTH = $clog2(BUFFER_ENTRY)
) (
    input clk,
    input reset_n,

    // init_unit
    input i_start_unit_init,
    output o_prrbmt_init_done,

    // New ROB Entry Logic
        // Allocate PHY Reg
    output [NEW_ENTRIES_INPUT_MAX-1:0] o_prrbmt_available_position,
    output [NEW_ENTRIES_INPUT_MAX*PHY_REG_ADDR_WIDTH-1:0] o_prrbmt_available_reg,
    input [NEW_ENTRIES_INPUT_MAX-1:0] i_nrobel_get_entries,

        // PHY Reg ROB Num Update: Opreand input
    input [NEW_ENTRIES_INPUT_MAX*INST_OPERANDS-1:0] i_update_phyreg_position,
    input [NEW_ENTRIES_INPUT_MAX*INST_OPERANDS*PHY_REG_ADDR_WIDTH-1:0] i_update_phyreg_from_opreands,
    input [ROB_ADDR_WIDTH-1:0] i_rob_numbers,

    // Inst. Flow Logic
        // Unallocate PHY Reg
    input [UNALLOCATE_PHY_REGS*ROB_ADDR_WIDTH-1:0] i_ifl_data_valid_position,
    input [UNALLOCATE_PHY_REGS*PHY_REG_ADDR_WIDTH-1:0] i_ifl_unallocate_regs,

    // Write Back Logic
        // Done PHY Register Nums..
    input [COMPLETE_RUN-1:0] i_wb_data_valid_position,
    input [COMPLETE_RUN*PHY_REG_ADDR_WIDTH-1:0] i_wb_done_regs,

    // ROBs
        // ROB Ready Update
    output [:0] o_done_reg_rob_num,
    output [:0] o_done_phy_reg_num,

    // PRRBMT BLOCK STATUS
    output o_allocate_all_phy_reg,
    output o_full_entryrobnum_mem
);

    entrynum #(
        .ENTRIES                        (PHYSICAL_REGISTERS),
        .NEW_ENTRIES_MAX_ONE_TIME       (NEW_ENTRIES_INPUT_MAX),
        .DESTROY_ENTRIES_MAX_ONE_TIME   (UNALLOCATE_PHY_REGS)
    ) U_PRRBMT_PHYREG_AVAILABLE_LIST (
        .clk                            (clk),
        .reset_n                        (reset_n),
        .init                           (i_start_unit_init),
        .init_fifo_done                 (init_fifo_done_phyreg_avaliable),
        .new_entries_get                (new_entries_get),
        .new_entries_valid              (w_entrynum_valid),
        .new_entries                    (new_entries),
        .destroy_entries_update         (destroy_entries_update),
        .destroy_entries                (destroy_entries)
    );

    regfile #(
        .READ_CHANNEL                   (INST_OPERANDS*NEW_ENTRIES_INPUT_MAX),
        .WRITE_CHANNEL                  (INST_OPERANDS*NEW_ENTRIES_INPUT_MAX),
        .ENTRIES                        (PHYSICAL_REGISTERS),
        .REG_WIDTH                      (ROB_ADDR_WIDTH*BUFFER_ENTRY),
    ) U_PRRBMT_ROBNUM_BUF (
        .clk                            (clk),
        .reset_n                        (reset_n),
        .i_read_addresses               (i_update_phyreg_from_opreands),
        .i_write_wes                    (i_update_phyreg_position),
        .i_write_addresses              (i_update_phyreg_from_opreands),
        .i_write_data                   (),
        .o_read_data                    ()
    );

    regfile #(
        .READ_CHANNEL                   (INST_OPERANDS*NEW_ENTRIES_INPUT_MAX),
        .WRITE_CHANNEL                  (INST_OPERANDS*NEW_ENTRIES_INPUT_MAX),
        .ENTRIES                        (PHYSICAL_REGISTERS),
        .REG_WIDTH                      (COUNTER_BUFFER_WIDTH),
    ) U_PRRBMT_ROBNUM_CNT (
        .clk                            (clk),
        .reset_n                        (reset_n),
        .i_read_addresses               (i_update_phyreg_from_opreands),
        .i_write_wes                    (i_update_phyreg_position),
        .i_write_addresses              (i_update_phyreg_from_opreands),
        .i_write_data                   (),
        .o_read_data                    ()
    );

    regfile #(
        .READ_CHANNEL                   (),
        .WRITE_CHANNEL                  (),
        .ENTRIES                        (PHYSICAL_REGISTERS),
        .REG_WIDTH                      (LIST_SRAM_ADDR_WIDTH+1), // SRAM ADDRESS + VALID
    ) U_PRRBMT_ROBNUM_SRAM_MAPPER_START (
        .clk                            (clk),
        .reset_n                        (reset_n),
        .i_read_addresses               (),
        .i_write_wes                    (),
        .i_write_addresses              (),
        .i_write_data                   (),
        .o_read_data                    ()
    );

    regfile #(
        .READ_CHANNEL                   (),
        .WRITE_CHANNEL                  (),
        .ENTRIES                        (PHYSICAL_REGISTERS),
        .REG_WIDTH                      (LIST_SRAM_ADDR_WIDTH),
    ) U_PRRBMT_ROBNUM_SRAM_MAPPER_LAST (
        .clk                            (clk),
        .reset_n                        (reset_n),
        .i_read_addresses               (),
        .i_write_wes                    (),
        .i_write_addresses              (),
        .i_write_data                   (),
        .o_read_data                    ()
    )

    entrynum #(
        .ENTRIES                        (LIST_SRAN_CAPASITY),
        .NEW_ENTRIES_MAX_ONE_TIME       (),
        .DESTROY_ENTRIES_MAX_ONE_TIME   ()
    ) U_PRRBMT_SRAMENTRY_AVAILABLE_LIST (
        .clk                            (clk),
        .reset_n                        (reset_n),
        .init                           (i_start_unit_init),
        .init_fifo_done                 (init_fifo_done_list_avaliable),
        .new_entries_get                (),
        .new_entries_valid              (),
        .new_entries                    (),
        .destroy_entries_update         (),
        .destroy_entries                ()
    );

    // SRAM Controller..

    assign o_prrbmt_init_done = init_fifo_done_phyreg_avaliable & init_fifo_done_list_avaliable;

endmodule




