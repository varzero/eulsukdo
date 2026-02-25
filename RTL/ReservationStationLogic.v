module reservation_station #(
    parameter ISSUES = 5,
    parameter RS_ENTRIES = 32,
    
    parameter ROB_NUM_MAX = 128,
    parameter INST_MICROOP_WIDTH = 8, // microOP = { EX opcode, EX No }
    parameter INST_PHYSICALREG_WIDTH = 6,
    parameter INST_OPERANDS = 2,

    parameter RS_NEW_ENTRY = ISSUES,
    parameter ROB_NUM_WIDTH = $clog2(ROB_NUM_MAX),
    parameter RS_ENTRY_BIT_WIDTH = 
                    ( ROB_NUM_WIDTH + INST_MICROOP_WIDTH +
                      INST_PHYSICALREG_WIDTH + (INST_OPERANDS*INST_PHYSICALREG_WIDTH) ),
    
    parameter MICROOP_ISSUE_WIDTH = $clog2(ISSUES)
) (
    input clk,
    input reset_n,

    // ROB Push
    input [RS_NEW_ENTRY-1:0] i_rob_new_entry_valid,
    input [(RS_ENTRY_BIT_WIDTH*RS_NEW_ENTRY)-1:0] i_rob_new_entries,
    output [ISSUES-1:0] o_rs_chan_avaliable,

    // RS Pop
    input [ISSUES-1:0] i_rs_get,    // PE's ~busy
);
    // Push Section
    wire [RS_NEW_ENTRY-1:0] issue_chan_fifo_push [0:ISSUES-1];
    wire [(RS_ENTRY_BIT_WIDTH*RS_NEW_ENTRY)-1:0] issue_chan_fifo_input [0:ISSUES-1];

    // Pop Section
    wire [(RS_ENTRY_BIT_WIDTH*ISSUES)-1:0] fifos_data;
    wire [ISSUES-1:0] fifos_data_valid;

    genvar rs_channels;

    generate
        for (rs_channels = 0; rs_channels < ISSUES; rs_channels = rs_channels + 1) begin
            assign issue_chan_fifo_push[rs_channels] = 
                        (i_rob_new_entry_valid[rs_channels] && 
                            (rs_channels == issue_chan_fifo_input[(rs_channels*RS_ENTRY_BIT_WIDTH)+MICROOP_ISSUE_WIDTH-1:rs_channels*RS_ENTRY_BIT_WIDTH]))
                                ? 1'b1 : 1'b0;
            assign issue_chan_fifo_input[rs_channels] 
                        = i_rob_new_entry_valid[(rs_channels+1)*(RS_ENTRY_BIT_WIDTH*RS_NEW_ENTRY):rs_channels*(RS_ENTRY_BIT_WIDTH*RS_NEW_ENTRY)];

            fifo_multi_chan_sram #(
                .READ_CHANNEL    (1),
                .WRITE_CHANNEL   (RS_NEW_ENTRY),
                .ENTRIES         (RS_ENTRIES),
                .REG_WIDTH       (RS_ENTRY_BIT_WIDTH),
            ) U_RS_CHAN (
                .clk                 (clk),
                .reset_n             (reset_n),
                .i_read_get          (i_rs_get[rs_channels]),
                .i_write_wes         (issue_chan_fifo_push[rs_channels]),
                .i_write_data        (issue_chan_fifo_input[rs_channels]),
                .o_write_ready       (o_rs_chan_avaliable[rs_channels]),
                .o_read_data         (fifos_data[rs_channels]),
                .o_read_valid        (fifos_data_valid[rs_channels])
            );
        end
    endgenerate
endmodule
