module prm #(
	parameter NUM_OF_PHY_REGS = 64,
	parameter ROB_ENTRIES = 128,
	parameter OPREANDS = 2,
    parameter NUM_OF_NEW_ENTRIES = 2,
    parameter NUM_OF_WB_ENTRIES = 5,
	parameter BUF_ENTRIES_PER_PHYREG = 4,
    parameter SRAM_SIZE = 128,
	parameter PHYREG_ADDR_WIDTH = $clog2(NUM_OF_PHY_REGS),
	parameter SRAM_ADDR_WIDTH = $clog2(SRAM_SIZE)
) (
    input clk,
    input reset_n,
);


endmodule
