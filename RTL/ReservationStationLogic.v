module reservation_station #(
    parameter RS_NEW_ENTRY = 5,
    parameter ISSUES = 5,
    parameter RS_FIFO_ENTRIES = 32,
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
    
);
endmodule
