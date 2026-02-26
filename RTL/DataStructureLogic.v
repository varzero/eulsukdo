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
    output [NEW_ENTRIES_MAX-1:0] allocate_position,
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
    reg [NEW_ENTRIES_MAX-1:0] allocate_position_reg, allocate_position_next;
    reg [FIFO_IN_BIT_WIDTH-1:0] allocate_entries, allocate_entries_next;

    always @(posedge clk or negedge reset_n) begin
        if (reset_n == 0) begin
            run <= 0;
            done_reg <= 0;
            allocate_position_reg <= 0;
            allocate_entries <= 0;
        end
        else begin
            run <= run_next;
            done_reg <= done_next;
            allocate_position_reg <= allocate_position_next;
            allocate_entries <= allocate_entries_next;
        end
    end

    always @(*) begin
        out_select = {FIFO_OUT_WIDTH{1'b0}};
        allocate_position_next = 0;
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
            allocate_position_next = {NEW_ENTRIES_MAX{1'b1}};
            for (target_position = 0; target_position < NEW_ENTRIES_MAX; target_position = target_position + 1) begin
                allocate_entries_next[(target_position*ENTRY_BIT_WIDTH) +: ENTRY_BIT_WIDTH] 
                    = allocate_entries[(target_position*ENTRY_BIT_WIDTH) +: ENTRY_BIT_WIDTH] + ADDING_ENTRY;
            end

            if (allocate_entries[( (CHECKER_POSITION+1)*ENTRY_BIT_WIDTH)-1:CHECKER_POSITION*ENTRY_BIT_WIDTH]) begin
                run_next = 0;
                done_next = 1'b1;
                allocate_entries_next = 0;

                for (target_position = 0; target_position < NEW_ENTRIES_MAX; target_position = target_position + 1) begin
                    allocate_position_next[target_position] = 1'b1;
                end
            end
        end
    end

    assign allocate_position = allocate_position_reg;
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

    input init,
    output reg init_fifo_done,
    
    // NEW ENTRIES
    input [NEW_ENTRIES_MAX_ONE_TIME-1:0] new_entries_get,
    output reg [NEW_ENTRIES_MAX_ONE_TIME-1:0] new_entries_valid,
    output reg [NEW_ENTRIES_BITWIDTH-1:0] new_entries,

    // DESTROY ENTRIES
    input [DESTROY_ENTRIES_MAX_ONE_TIME-1:0] destroy_entries_update,
    input [DESTROY_ENTRIES_BITWIDTH-1:0] destroy_entries
);
    reg [READ_CHANNEL-1:0]                      i_fifo_read_get;
    reg [WRITE_CHANNEL-1:0]                     i_fifo_write_wes;
    reg [WRITE_CHANNEL*REG_WIDTH-1:0]           i_fifo_write_data;
    wire                                        o_fifo_write_ready;
    wire [READ_CHANNEL*REG_WIDTH-1:0]           o_fifo_read_data;
    wire [READ_CHANNEL-1:0]                     o_fifo_read_valid;

    reg                                         init_entry;
    wire                                        fifo_empty;
    wire [FIFO_OUT_WIDTH-1:0]                   out_select;
    wire [NEW_ENTRIES_MAX-1:0]                  allocate_position;
    wire [FIFO_IN_BIT_WIDTH-1:0]                allocate_entry_num;
    wire                                        init_done;

    assign fifo_empty = ~(|o_fifo_read_valid);

    init_entries_list #(
        .ENTRIES(ENTRIES),
        .NEW_ENTRIES_MAX(NEW_ENTRIES_MAX_ONE_TIME),
        .FIFO_OUT_WIDTH(DESTROY_ENTRIES_BITWIDTH)
    ) U_INIT_ENTRIES (
        .clk                (clk),
        .reset_n            (reset_n),
        .init               (init),
        .empty              (empty),
        .out_select         (out_select),
        .allocate_position  (allocate_position),
        .allocate_entry_num (allocate_entry_num),
        .done               (done)
    );

    fifo_multi_chan_sram #(
        .READ_CHANNEL    (DESTROY_ENTRIES_BITWIDTH),
        .WRITE_CHANNEL   (NEW_ENTRIES_BITWIDTH),
        .ENTRIES         (ENTRIES),
        .REG_WIDTH       (ENTRIES_ADDR_WIDTH)
    ) U_ENTRYNUM_FIFO (
        .clk                 (clk               ),
        .reset_n             (reset_n           ),
        .i_read_get          (i_fifo_read_get   ),
        .i_write_wes         (i_fifo_write_wes  ),
        .i_write_data        (i_fifo_write_data ),
        .o_write_ready       (o_fifo_write_ready),
        .o_read_data         (o_fifo_read_data  ),
        .o_read_valid        (o_fifo_read_valid )
    );

    // State
    localparam INIT_START = 2'b00;
    localparam INIT_WAIT = 2'b01;
    localparam INIT_DONE = 2'b01;
    localparam RUNNING = 2'b11;

    // Register
    reg [1:0] state, state_next;
    
    always @(*) begin
        if (reset_n == 1'b0) begin
            state <= INIT_START;
        end
        else begin
            state <= state_next;
        end
    end

    // next, select
    always @(*) begin
        state_next = state;

        init_fifo_done = 0;

        // output
        new_entries_valid = 0;
        new_entries = 0;

        // inner selector
            // FIFO
        i_fifo_read_get = 0;
        i_fifo_write_wes = 0;
        i_fifo_write_data = 0;
            // init ctrl
        init_entry = 0;

        case(state)
            INIT_START: begin
                init_fifo_done = 0;

                new_entries_valid = 0;
                new_entries = 0;

                i_fifo_read_get = 0;
                i_fifo_write_wes = 0;
                i_fifo_write_data = 0;

                init_entry = init;

                if (init) begin
                    state_next = INIT_WAIT;
                end
            end
            INIT_WAIT: begin
                init_fifo_done = 0;
                
                new_entries_valid = 0;
                new_entries = 0;

                i_fifo_read_get = out_select;
                i_fifo_write_wes = allocate_position;
                i_fifo_write_data = allocate_entry_num;

                init_entry = 0;

                if (init_done) begin
                    state_next = INIT_WAIT;
                end
            end
            INIT_DONE: begin
                init_fifo_done = 1;
                
                new_entries_valid = 0;
                new_entries = 0;

                i_fifo_read_get = 0;
                i_fifo_write_wes = 0;
                i_fifo_write_data = 0;

                init_entry = 0;

                state_next = RUNNING;
            end
            RUNNING: begin
                init_fifo_done = 1;

                new_entries_valid = o_fifo_read_valid;
                new_entries = o_fifo_read_data;

                i_fifo_read_get = new_entries_get;
                i_fifo_write_wes = destroy_entries_update;
                i_fifo_write_data = destroy_entries;

                init_entry = 0;

                if (init) begin
                    state_next = INIT_WAIT;
                end
            end
        endcase
    end

endmodule
