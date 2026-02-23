module reservation_station #(
    parameter RS_NEW_ENTRY = 5,
    parameter ISSUES = 5,
    parameter RS_ENTRIES = 32,

    parameter ROB_NUM_MAX = 128,
    parameter INST_MICROOP_WIDTH = 8, // microOP = {EX No, EX opcode}
    parameter INST_PHYSICALREG_WIDTH = 6,
    parameter INST_OPERANDS = 2,
    parameter ROB_NUM_WIDTH = $clog2(ROB_NUM_MAX),
    parameter RS_ENTRY_BIT_WIDTH = 
                    ( ROB_NUM_WIDTH + INST_MICROOP_WIDTH +
                      INST_PHYSICALREG_WIDTH + (INST_OPERANDS*INST_PHYSICALREG_WIDTH) ),
    
    parameter MICROOP_ISSUE_WIDTH = $clog2(ISSUES)
) (
    input clk,
    input reset_n,

    // ROB Push
    input [RS_NEW_ENTRY*ISSUES]
    input [RS_ENTRY_BIT_WIDTH*RS_NEW_ENTRY*ISSUES]
);

    wire issue_chan_fifo_push [0:ISSUES-1];
    wire [RS_ENTRY_BIT_WIDTH-1:0] issue_chan_fifo_input [0:ISSUES-1];

    genvar rs_channels;

    generate


        fifo_multi_chan_sram #(
            .READ_CHANNEL    (1),
            .WRITE_CHANNEL   (ISSUES),
            .ENTRIES         (RS_ENTRIES),
            .REG_WIDTH       (RS_ENTRY_BIT_WIDTH),
        ) (
            input                                               .clk                 (clk),
            input                                               .reset_n             (reset_n),
            input       [READ_CHANNEL-1:0]                      .i_read_get          (),
            input       [WRITE_CHANNEL-1:0]                     .i_write_wes         (issue_chan_fifo_push[rs_channels]),
            input       [WRITE_CHANNEL*REG_WIDTH-1:0]           .i_write_data        (issue_chan_fifo_input[rs_channels]),
            output reg                                          .o_write_ready       (),
            output reg  [READ_CHANNEL*REG_WIDTH-1:0]            .o_read_data         (),
            output reg  [READ_CHANNEL-1:0]                      .o_read_valid        ()
        );
    endgenerate
endmodule
