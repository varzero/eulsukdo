module prrbmt #(
    parameter PHYSICAL_REGISTERS = 64,
    parameter NEW_ENTRIES_INPUT_MAX = 4,
    parameter COMPLETE_RUN = 7,
    parameter SRAM_LIST_WIDTH = 8,
    parameter INST_OPERANDS = 2,
    parameter ENTRIES_ADDR_WIDTH = $clog2(PHYSICAL_REGISTERS),
    parameter NEW_ENTRIES_BITWIDTH = ENTRIES_ADDR_WIDTH*NEW_ENTRIES_INPUT_MAX,
    parameter DESTROY_ENTRIES_BITWIDTH = ENTRIES_ADDR_WIDTH*COMPLETE_RUN
) (
    input clk,
    input reset_n,

    // New Physical Registers Allocate
    input [NEW_ENTRIES_INPUT_MAX-1:0]        new_entries_get,
    output [NEW_ENTRIES_INPUT_MAX-1:0]       new_entries_valid,
    output [NEW_ENTRIES_BITWIDTH-1:0]        new_entries,

    // Complete Registers Read

    // Unallocate Physical Registers
    input [COMPLETE_RUN-1:0]    destroy_entries_update,
    input [DESTROY_ENTRIES_BITWIDTH-1:0]        destroy_entries
);

    input                                       init,
    output reg                                  init_fifo_done,

    input  [COMPLETE_RUN*ENTRIES_ADDR_WIDTH-1:0]            i_read_addresses    ;
    input  [NEW_ENTRIES_INPUT_MAX-1:0]                      i_write_wes         ;
    input  [NEW_ENTRIES_INPUT_MAX*ENTRIES_ADDR_WIDTH-1:0]   i_write_addresses   ;
    input  [NEW_ENTRIES_INPUT_MAX*REG_WIDTH-1:0]            i_write_data        ;
    output [COMPLETE_RUN*REG_WIDTH-1:0]                     o_read_data         ;

    entrynum #(
        .ENTRIES(PHYSICAL_REGISTERS),
        .NEW_ENTRIES_MAX_ONE_TIME(NEW_ENTRIES_INPUT_MAX),
        .DESTROY_ENTRIES_MAX_ONE_TIME = 7
    ) (
        .clk                            (clk),
        .reset_n                        (reset_n),
        .init                           (init),
        .init_fifo_done                 (init_fifo_done),
        .new_entries_get                (new_entries_get),
        .new_entries_valid              (new_entries_valid),
        .new_entries                    (new_entries),
        .destroy_entries_update         (destroy_entries_update),
        .destroy_entries                (destroy_entries)
    );

    regfile #(
        .READ_CHANNEL    (COMPLETE_RUN),
        .WRITE_CHANNEL   (NEW_ENTRIES_INPUT_MAX),
        .ENTRIES         (PHYSICAL_REGISTERS),
        .REG_WIDTH       (SRAM_LIST_WIDTH + 1)
    ) U_PRRBMT_VALID_LISTSTART (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_addresses    (i_read_addresses),
        .i_write_wes         (i_write_wes),
        .i_write_addresses   (i_write_addresses),
        .i_write_data        (i_write_data),
        .o_read_data         (o_read_data) 
    );

    regfile #(
        .READ_CHANNEL    (COMPLETE_RUN),
        .WRITE_CHANNEL   (NEW_ENTRIES_INPUT_MAX),
        .ENTRIES         (PHYSICAL_REGISTERS),
        .REG_WIDTH       (SRAM_LIST_WIDTH)
    ) U_PRRBMT_LISTLAST (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_addresses    (i_read_addresses),
        .i_write_wes         (i_write_wes),
        .i_write_addresses   (i_write_addresses),
        .i_write_data        (i_write_data),
        .o_read_data         (o_read_data) 
    );

endmodule


