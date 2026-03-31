module prm #(
	parameter NUM_OF_PHY_REGS = 64,
	parameter IST_ENTRIES = 128,
	parameter OPREANDS = 2,
    
    parameter NUM_OF_NEW_ENTRIES = 2,
    parameter NUM_OF_WB_ENTRIES = 5,
	parameter BUF_ENTRIES_PER_PHYREG = 4,

    parameter SRAM_ENTRIES_SIZE = 128,
	parameter PHYREG_ADDR_WIDTH = $clog2(NUM_OF_PHY_REGS),
	parameter SRAM_ADDR_WIDTH = $clog2(SRAM_SIZE)
) (
    input clk,
    input reset_n,
);

	regfile #(
    	.READ_CHANNEL    (),
    	.WRITE_CHANNEL   (),
    	.ENTRIES         (),
    	.REG_WIDTH       (),
	) U_PHY_REG_ROB_MAPPING_RF (
	    .clk                 (),
	    .reset_n             (),
	    .i_read_addresses    (),
	    .i_write_wes         (),
	    .i_write_addresses   (),
	    .i_write_data        (),
	    .o_read_data		 ()
	);

	allocator_start_one #(
		.NUM_OF_ENTRIES (NUM_OF_PHY_REGS),
    	.UNALLOCATES 	(),
    	.ALLOCATES 		(NUM_OF_NEW_ENTRIES)
	) U_UNALLOCATE_PHY_REG_ALLOCATOR (
	    .clk					(),
	    .reset_n				(),
	    .unallocate_valid_i		(),
	    .unallocate_entries_i	(),
	    .allocating_i			(),
		.allocate_valid_o		(),
	    .allocate_entries_o		(),
		.init_done				()
	);

	regfile #(
    	.READ_CHANNEL    (),
    	.WRITE_CHANNEL   (),
    	.ENTRIES         (),
    	.REG_WIDTH       (),
	) U_PRRM_LIST_BUF (
	    .clk                 (),
	    .reset_n             (),
	    .i_read_addresses    (),
	    .i_write_wes         (),
	    .i_write_addresses   (),
	    .i_write_data        (),
	    .o_read_data		 ()
	);

	allocator #(
		.NUM_OF_ENTRIES (SRAM_ENTRIES_SIZE),
    	.UNALLOCATES 	(),
    	.ALLOCATES 		()
	) U_PRRM_LIST_SRAM_ADDR_ALLOCATOR (
	    .clk					(),
	    .reset_n				(),
	    .unallocate_valid_i		(),
	    .unallocate_entries_i	(),
	    .allocating_i			(),
		.allocate_valid_o		(),
	    .allocate_entries_o		(),
		.init_done				()
	);
	
	on_chip_sync_dual_port_ram #(
	    .ENTRIES         (),
	    .ENTRY_WIDTH     ()
	) U_PRRM_LIST_SRAM (
	    .clk	(),
	    .r_addr	(),
	    .we		(),
	    .w_addr	(),
	    .w_data	(),
	    .r_data	()
	);

endmodule
