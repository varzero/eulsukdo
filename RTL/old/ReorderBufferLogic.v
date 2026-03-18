/*
    ROB READY PROCESS
    COMBINATIONAL LOGIC
*/
module rob_update #() ();
endmodule

module rob #(
    parameter ROB_ENTRIES = 128,
    parameter INST_OPERANDS = 2,
    parameter NEW_ENTRIES_INPUT_MAX = 4,
    parameter ISSUES = 5,
    parameter COMPLETE_RUN = 5,
    parameter UNALLOCATE_ROBS = 4,
) (
    input clk,
    input reset_n,

);

    entrynum #(
        .ENTRIES                        (ROB_ENTRIES),
        .NEW_ENTRIES_MAX_ONE_TIME       (NEW_ENTRIES_INPUT_MAX),
        .DESTROY_ENTRIES_MAX_ONE_TIME   (UNALLOCATE_ROBS)
    ) U_ROB_UNALLOCATE_LIST (
        .clk                            (clk),
        .reset_n                        (reset_n),
        .init                           (i_start_unit_init),
        .init_fifo_done                 (),
        .new_entries_get                (),
        .new_entries_valid              (),
        .new_entries                    (),
        .destroy_entries_update         (),
        .destroy_entries                ()
    );

    // 2chan_SRAM

    regfile #(
        .READ_CHANNEL                   (COMPLETE_RUN),
        .WRITE_CHANNEL                  (NEW_ENTRIES_INPUT_MAX+COMPLETE_RUN),
        .ENTRIES                        (ROB_ENTRIES),
        .REG_WIDTH                      (INST_OPERANDS),
    ) U_ROB_READY (
        .clk                            (clk),
        .reset_n                        (reset_n),
        .i_read_addresses               (),
        .i_write_wes                    (),
        .i_write_addresses              (),
        .i_write_data                   (),
        .o_read_data                    ()
    )

endmodule
