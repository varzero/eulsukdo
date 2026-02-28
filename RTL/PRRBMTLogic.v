module prrbmt_allocate_reg #(
    parameter PHYSICAL_REGISTERS = 64,
    parameter NEW_ENTRIES_INPUT_MAX = 4,
    parameter INST_PHYSICALREG_WIDTH = 6,
    parameter INST_OPERANDS = 2,
    parameter COMPLETE_RUN = 7,
) (
    input clk,
    input reset_n,

    // init_unit
    input i_start_unit_init,
    output o_prrbmt_init_done,

    // New ROB Entry Logic
        // Allocate PHY Reg
    output [:0] o_prrbmt_available_position,
    output [:0] o_prrbmt_available_reg,
    input [:0] i_nrobel_get_entries,

        // PHY Reg ROB Num Update: Opreand input
    input [:0] i_update_phyreg_from_opreands,
    input [:0] i_rob_number,

    // Inst. Flow Logic
        // Unallocate PHY Reg
    input [:0] i_ifl_data_valid_position,
    input [:0] i_ifl_unallocate_regs,

    // Write Back Logic
        // Done PHY Register Nums..
    input [:0] i_wb_data_valid_position,
    input [:0] i_wb_done_regs,

    // ROBs
        // ROB Ready Update
    output [:0] o_done_reg_rob_num,
    output [:0] o_done_phy_reg_num,

    // PRRBMT BLOCK STATUS
    output o_allocate_all_phy_reg,
    output o_full_entryrobnum_mem
);


    entrynum #(
        .ENTRIES(PHYSICAL_REGISTERS),
        .NEW_ENTRIES_MAX_ONE_TIME(NEW_ENTRIES_INPUT_MAX),
        .DESTROY_ENTRIES_MAX_ONE_TIME(COMPLETE_RUN)
    ) U_PRRBMT_PHYREG_AVAILABLE_LIST (
        .clk                            (clk),
        .reset_n                        (reset_n),
        .init                           (i_start_unit_init),
        .init_fifo_done                 (init_fifo_done),
        .new_entries_get                (new_entries_get),
        .new_entries_valid              (w_entrynum_valid),
        .new_entries                    (new_entries),
        .destroy_entries_update         (destroy_entries_update),
        .destroy_entries                (destroy_entries)
    );

    regfile #(
        .READ_CHANNEL                   (),
        .WRITE_CHANNEL                  (),
        .ENTRIES                        (),
        .REG_WIDTH                      (),
    ) U_PRRBMT_ROBNUM_BUF (
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
        .ENTRIES                        (),
        .REG_WIDTH                      (),
    ) U_PRRBMT_ROBNUM_SRAM_MAPPER (
        .clk                            (clk),
        .reset_n                        (reset_n),
        .i_read_addresses               (),
        .i_write_wes                    (),
        .i_write_addresses              (),
        .i_write_data                   (),
        .o_read_data                    ()
    );

    entrynum #(
        .ENTRIES                        (),
        .NEW_ENTRIES_MAX_ONE_TIME       (),
        .DESTROY_ENTRIES_MAX_ONE_TIME   ()
    ) U_PRRBMT_SRAMENTRY_AVAILABLE_LIST (
        .clk                            (clk),
        .reset_n                        (reset_n),
        .init                           (),
        .init_fifo_done                 (),
        .new_entries_get                (),
        .new_entries_valid              (),
        .new_entries                    (),
        .destroy_entries_update         (),
        .destroy_entries                ()
    );

    // SRAM Controller..

endmodule




