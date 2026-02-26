module prrbmt_allocate_reg #(
    parameter PHYSICAL_REGISTERS = 64,
    parameter NEW_ENTRIES_INPUT_MAX = 4,
    parameter INST_OPERANDS = 2,
    parameter COMPLETE_RUN = 7,
) (
    input clk,
    input reset_n,

    input i_start_unit_init,


);
    entrynum #(
        .ENTRIES(PHYSICAL_REGISTERS),
        .NEW_ENTRIES_MAX_ONE_TIME(NEW_ENTRIES_INPUT_MAX),
        .DESTROY_ENTRIES_MAX_ONE_TIME(COMPLETE_RUN)
    ) U_PRRBMT_AVAILABLE_LIST (
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

endmodule




