module prm #(
	parameter NUM_OF_PHY_REGS = 64,
	parameter IST_ENTRIES = 128,
	parameter OPREANDS = 2,
    
    parameter NUM_OF_NEW_ENTRIES = 2,
    parameter NUM_OF_WB_ENTRIES = 5,
	parameter NUM_OF_DESTROY_ENTRIES = 4,
	parameter BUF_ENTRIES_PER_PHYREG = 4,
	parameter OPREANDS = 2,

    parameter SRAM_ENTRIES_SIZE = 128,
	parameter SRAM_ADDR_WIDTH = $clog2(SRAM_SIZE),
	parameter BUF_ENTRIES_CNT_BITWIDTH = $clog2(BUF_ENTRIES_PER_PHYREG),
	parameter IST_ADDR_WIDTH = $clog2(IST_ENTRIES),
	parameter PHYREG_ADDR_WIDTH = $clog2(NUM_OF_PHY_REGS)
) (
    input clk,
    input reset_n,

	// Allocate PHYREG
	input [NUM_OF_NEW_ENTRIES-1:0] allocate_phyreg_get_i,
	output [NUM_OF_NEW_ENTRIES-1:0] allocate_phyreg_valid_o,
	output [(NUM_OF_NEW_ENTRIES * PHYREG_ADDR_WIDTH)-1:0] allocate_phyregs_o,

	// Unallocate PHYREG
	input [NUM_OF_DESTROY_ENTRIES-1:0] unallocate_phyreg_valid_i,
	input [(NUM_OF_DESTROY_ENTRIES * PHYREG_ADDR_WIDTH)-1:0] unallocate_phyregs_i,

	// PHYREG Use IST Mapping, Process on New Entry Logic
	input [(NUM_OF_NEW_ENTRIES * OPREANDS)-1:0] target_ist_valid_i,
	input [(NUM_OF_NEW_ENTRIES * IST_ADDR_WIDTH)-1:0] target_ist_entry_i,
	input [((NUM_OF_NEW_ENTRIES * OPREANDS) * PHYREG_ADDR_WIDTH)-1:0] target_phyregs_i,

	// Ready signal send to IST from PHYREG
	output [NUM_OF_WB_ENTRIES-1:0] ready_valid_o,
	output [(NUM_OF_WB_ENTRIES * PHYREG_ADDR_WIDTH)-1:0] ready_phyreg_o,
	output [(NUM_OF_WB_ENTRIES * IST_ADDR_WIDTH)-1:0] ready_ist_entrites_o,

	// Write Back PHY Registers NUMBERS
	input [NUM_OF_WB_ENTRIES-1:0] wb_done_valid_i,
	input [(NUM_OF_WB_ENTRIES * PHYREG_ADDR_WIDTH)-1:0] wb_done_phyreg_i,

    output active
);
	wire phyreg_allocate_reg_done, sram_allocate_reg_done, available_sram;
	wire [NUM_OF_NEW_ENTRIES-1:0] allocate_phyreg_target;
	wire [(NUM_OF_NEW_ENTRIES * PHYREG_ADDR_WIDTH)-1:0] allocate_phyregs;

	assign allocate_phyreg_target = allocate_phyreg_get_i & allocate_phyreg_valid_o;
	assign allocate_phyregs_o = allocate_phyregs;

	regfile #(
    	.READ_CHANNEL    (NUM_OF_WB_ENTRIES),
    	.WRITE_CHANNEL   (NUM_OF_NEW_ENTRIES * OPREANDS),
    	.ENTRIES         (NUM_OF_PHY_REGS),
    	.REG_WIDTH       (( PHYREG_ADDR_WIDTH * BUF_ENTRIES_PER_PHYREG )+ BUF_ENTRIES_CNT_BITWIDTH),
	) U_PHY_REG_ROB_MAPPING_RF (
	    .clk                 (clk),
	    .reset_n             (reset_n),
	    .i_read_addresses    (wb_done_phyreg_i),
	    .i_write_wes         (target_ist_valid_i),
	    .i_write_addresses   (),
	    .i_write_data        (target_phyregs_i),
	    .o_read_data		 ()
	);

	allocator_start_one #(
		.NUM_OF_ENTRIES (NUM_OF_PHY_REGS),
    	.UNALLOCATES 	(NUM_OF_DESTROY_ENTRIES),
    	.ALLOCATES 		(NUM_OF_NEW_ENTRIES)
	) U_UNALLOCATE_PHY_REG_ALLOCATOR (
	    .clk					(clk),
	    .reset_n				(reset_n),
	    .unallocate_valid_i		(unallocate_phyreg_valid_i),
	    .unallocate_entries_i	(unallocate_phyregs_i),
	    .allocating_i			(allocate_phyreg_get_i),
		.allocate_valid_o		(allocate_phyreg_valid_o),
	    .allocate_entries_o		(allocate_phyregs),
		.init_done				(phyreg_allocate_reg_done)
	);

	regfile #(
    	.READ_CHANNEL    (NUM_OF_WB_ENTRIES),
    	.WRITE_CHANNEL   (NUM_OF_NEW_ENTRIES * OPREANDS),
    	.ENTRIES         (NUM_OF_PHY_REGS),
    	.REG_WIDTH       (1 + SRAM_ADDR_WIDTH + SRAM_ADDR_WIDTH),
	) U_PRRM_LIST_BUF (
	    .clk                 (clk),
	    .reset_n             (reset_n),
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
	    .clk					(clk),
	    .reset_n				(reset_n),
	    .unallocate_valid_i		(),
	    .unallocate_entries_i	(),
	    .allocating_i			(),
		.allocate_valid_o		(),
	    .allocate_entries_o		(),
		.init_done				(sram_allocate_reg_done)
	);
	
	on_chip_sync_dual_port_ram #(
	    .ENTRIES         (SRAM_ENTRIES_SIZE),
	    .ENTRY_WIDTH     (PHYREG_ADDR_WIDTH * BUF_ENTRIES_PER_PHYREG)
	) U_PRRM_LIST_SRAM (
	    .clk	(clk),
	    .r_addr	(),
	    .we		(),
	    .w_addr	(),
	    .w_data	(),
	    .r_data	()
	);

endmodule
