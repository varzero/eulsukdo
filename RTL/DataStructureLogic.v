/*
    Initialization Entry List Logic
*/
module init_entries_list #(
    parameter ENTRIES = 16,
    parameter NEW_ENTRIES_MAX = 4,
    parameter FIFO_OUT_WIDTH = 4,
    parameter ENTRY_BIT_WIDTH = $clog2(ENTRIES),
    parameter FIFO_IN_BIT_WIDTH = $clog2(NEW_ENTRIES_MAX*ENTRY_BIT_WIDTH)
) (
    input clk,
    input reset_n,
    input init,
    input empty,
    output reg [FIFO_OUT_WIDTH-1:0] out_select,
    output reg [NEW_ENTRIES_MAX-1:0] allocate_position,
    output [FIFO_IN_BIT_WIDTH-1:0] allocate_entry_num,
    output reg done
);
    // Constant
    localparam CHECKER_POSITION = ENTRIES % NEW_ENTRIES_MAX;
    localparam ADDING_ENTRY = NEW_ENTRIES_MAX;

    // Synthsis Variable
    integer target_position = 0;

    // Register
    reg run, run_next;
    reg done_reg, done_next;
    reg [FIFO_IN_BIT_WIDTH-1:0] allocate_entries, allocate_entries_next;

    always @(posedge clk or negedge reset_n) begin
        if (reset_n == 0) begin
            run <= 0;
            done_reg <= 0;
            allocate_entries <= 0;
        end
        else begin
            run <= run_next;
            done_reg <= done_next;
            allocate_entries <= allocate_entries_next;
        end
    end

    always @(*) begin
        out_select = {FIFO_OUT_WIDTH{1'b0}};
        allocate_entries_next = allocate_entries;
        allocate_position = 0;
        run_next = 0;
        done_next = 0;

        if (~empty) begin
            out_select = {FIFO_OUT_WIDTH{1'b1}};
            allocate_entries_next = 0;
            
        end
        else if (init) begin
            run_next = 1;

            for (target_position = 0; target_position < NEW_ENTRIES_MAX; target_position = target_position + 1) begin
                allocate_entries_next[(target_position*ENTRY_BIT_WIDTH) +: ENTRY_BIT_WIDTH] = target_position;
            end
        end

        if (run) begin
            allocate_position = {NEW_ENTRIES_MAX{1'b1}};
            for (target_position = 0; target_position < NEW_ENTRIES_MAX; target_position = target_position + 1) begin
                allocate_entries_next[(target_position*ENTRY_BIT_WIDTH) +: ENTRY_BIT_WIDTH] 
                    = allocate_entries[(target_position*ENTRY_BIT_WIDTH) +: ENTRY_BIT_WIDTH] + ADDING_ENTRY;
            end

            if (allocate_entries[( (CHECKER_POSITION+1)*ENTRY_BIT_WIDTH)-1:CHECKER_POSITION*ENTRY_BIT_WIDTH]) begin
                run_next = 0;
                done_next = 1'b1;
                allocate_entries_next = 0;
                allocate_position = {NEW_ENTRIES_MAX{1'b0}};

                for (target_position = 0; target_position < NEW_ENTRIES_MAX; target_position = target_position + 1) begin
                    allocate_position[target_position] = 1'b1;
                end
            end
        end
    end

    assign allocate_entry_num = allocate_entries;
    
endmodule

/*
    ENTRYNUM MUST BE NOT FULL!!!
*/
module entrynum #(
    parameter ENTRIES = 128,
    parameter NEW_ENTRIES_MAX_ONE_TIME = 4,
    parameter DESTROY_ENTRIES_MAX_ONE_TIME = 7,
    parameter ENTRIES_ADDR_WIDTH = $clog2(ENTRIES),
    parameter NEW_ENTRIES_BITWIDTH = ENTRIES_ADDR_WIDTH*NEW_ENTRIES_MAX_ONE_TIME,
    parameter DESTROY_ENTRIES_BITWIDTH = ENTRIES_ADDR_WIDTH*DESTROY_ENTRIES_MAX_ONE_TIME
) (
    input clk,
    input reset_n,
    
    // NEW ENTRIES
    input [NEW_ENTRIES_MAX_ONE_TIME-1:0] new_entries_get,
    output [NEW_ENTRIES_MAX_ONE_TIME-1:0] new_entries_valid,
    output [NEW_ENTRIES_BITWIDTH-1:0] new_entries,

    // DESTROY ENTRIES
    input [DESTROY_ENTRIES_MAX_ONE_TIME-1:0] destroy_entries_update,
    input [DESTROY_ENTRIES_BITWIDTH-1:0] destroy_entries
);
    
endmodule
