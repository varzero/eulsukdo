module ist #( // Instruction State Table
	parameter IST_ENTRIES = 128,
) (
    input clk,
    input reset_n,
);

    allocator #(
    	parameter NUM_OF_ENTRIES = 64,
        parameter UNALLOCATES = 4,
        parameter ALLOCATES = 7,
    	parameter ENTRY_NUM_WIDTH = $clog2(NUM_OF_ENTRIES),
    ) U_IST_ENTRIES_ALLOCATOR (
        input clk,
        input reset_n,
        input [PUSH_DATA-1:0] unallocate_valid_i,
        input [(UNALLOCATES * ENTRY_NUM_WIDTH)-1:0] unallocate_entries_i,
        input [ALLOCATES-1:0] allocating_i,
        output [(ALLOCATES * ENTRY_NUM_WIDTH)-1:0] allocate_entries_o,
        output nothing_entry,
    	output init_done
    );

    // Opreands
    regfile #(
        parameter       READ_CHANNEL    = 8 ,
        parameter       WRITE_CHANNEL   = 4 ,
        parameter       ENTRIES         = 16,
        parameter       REG_WIDTH       = 32,
        parameter       ENTRY_ADDR_WIDTH= $clog2(ENTRIES+1)
    ) U_OPERANDS_LIST (
        input                                               clk                 ,
        input                                               reset_n             ,
        input       [READ_CHANNEL*ENTRY_ADDR_WIDTH-1:0]     i_read_addresses    ,
        input       [WRITE_CHANNEL-1:0]                     i_write_wes         ,
        input       [WRITE_CHANNEL*ENTRY_ADDR_WIDTH-1:0]    i_write_addresses   ,
        input       [WRITE_CHANNEL*REG_WIDTH-1:0]           i_write_data        ,
        output reg  [READ_CHANNEL*REG_WIDTH-1:0]            o_read_data
    );

    // Readies
    genvar target_opreand;
    generate
        for (target_opreand) begin
            regfile #(
                parameter       READ_CHANNEL    = 8 ,
                parameter       WRITE_CHANNEL   = 4 ,
                parameter       ENTRIES         = 16,
                parameter       REG_WIDTH       = 32,
                parameter       ENTRY_ADDR_WIDTH= $clog2(ENTRIES+1)
            ) U_READY_OPERAND (
                input                                               clk                 ,
                input                                               reset_n             ,
                input       [READ_CHANNEL*ENTRY_ADDR_WIDTH-1:0]     i_read_addresses    ,
                input       [WRITE_CHANNEL-1:0]                     i_write_wes         ,
                input       [WRITE_CHANNEL*ENTRY_ADDR_WIDTH-1:0]    i_write_addresses   ,
                input       [WRITE_CHANNEL*REG_WIDTH-1:0]           i_write_data        ,
                output reg  [READ_CHANNEL*REG_WIDTH-1:0]            o_read_data
            );
        end
    endgenerate

endmodule
