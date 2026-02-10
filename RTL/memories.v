`timescale 1ns/1ps

/*
[regfile]
##########################################################################################
PARAMETERIZE MULTI READ/WRITE CHANNELS REGISTER FILES
- READ LATENCY          : IMMEDIATELY
- WRITE LATENCY         : 1 CYCLE

* TESTBENCH MODULE      : tb_regfile
------------------------------------------------------------------------------------------
[PARAMETER(USER MODIFY)]
    READ_CHANNEL        : NUMBER OF READ CHANNELS
    WRITE_CHANNEL       : NUMBER OF WRITE CHANNELS
    ENTRIES             : NUMBER OF ENTRIES
    REG_WIDTH           : WIDTH OF REGISTER

[INPUT/OUTPUT]
    clk                 : [INPUT ] SYSTEM CLOCK
    reset_n             : [INPUT ] SYSTEM ACTIVE-LOW RESET
    i_read_addresses    : [INPUT ] ADDRESS OF READ CHANNELS
    i_write_wes         : [INPUT ] WRITE ENABLE OF WRITE CHANNELS
    i_write_addresses   : [INPUT ] ADDRESS OF WRITE CHANNELS
    i_write_data        : [INPUT ] DATA OF WRITE CHANNELS
    o_read_data         : [OUTPUT] DATA OF READ CHANNELS
##########################################################################################
*/
module regfile #(
    parameter       READ_CHANNEL    = 8 ,
    parameter       WRITE_CHANNEL   = 4 ,
    parameter       ENTRIES         = 16,
    parameter       REG_WIDTH       = 32,
    parameter       ENTRY_ADDR_WIDTH= $clog2(ENTRIES+1)
) (
    input                                               clk                 ,
    input                                               reset_n             ,
    input       [READ_CHANNEL*ENTRY_ADDR_WIDTH-1:0]     i_read_addresses    ,
    input       [WRITE_CHANNEL-1:0]                     i_write_wes         ,
    input       [WRITE_CHANNEL*ENTRY_ADDR_WIDTH-1:0]    i_write_addresses   ,
    input       [WRITE_CHANNEL*REG_WIDTH-1:0]           i_write_data        ,
    output reg  [READ_CHANNEL*REG_WIDTH-1:0]            o_read_data
);
    // Synthesis Variables
    integer var_target_idx = 0, var_sel_read_addr_idx = 0, var_sel_write_addr_idx = 0;

    // Register Memory
    reg [REG_WIDTH-1:0] mem_reg [0:ENTRIES-1];
    reg [REG_WIDTH-1:0] next_mem_reg [0:ENTRIES-1];

    always @(posedge clk or negedge reset_n) begin
        if (reset_n == 1'b0) begin
            for (var_target_idx = 0; var_target_idx < ENTRIES; var_target_idx = var_target_idx + 1) begin
                mem_reg[var_target_idx] <= {(REG_WIDTH){1'b0}};
            end
        end
        else begin
            for (var_target_idx = 0; var_target_idx < ENTRIES; var_target_idx = var_target_idx + 1) begin
                mem_reg[var_target_idx] <= next_mem_reg[var_target_idx];
            end
        end
    end

    // R/W
    always @(*) begin
        // Read channel
        for (var_sel_read_addr_idx = 0; var_sel_read_addr_idx < READ_CHANNEL; var_sel_read_addr_idx = var_sel_read_addr_idx + 1) begin
            o_read_data[ var_sel_read_addr_idx*REG_WIDTH +: REG_WIDTH ] = 
                mem_reg[ (i_read_addresses[ var_sel_read_addr_idx*ENTRY_ADDR_WIDTH +: ENTRY_ADDR_WIDTH ]) ];
        end

        // Write channel
        for (var_target_idx = 0; var_target_idx < ENTRIES; var_target_idx = var_target_idx + 1) begin
            next_mem_reg[var_target_idx] = mem_reg[var_target_idx];
        end
        for (var_sel_write_addr_idx = 0; var_sel_write_addr_idx < READ_CHANNEL; var_sel_write_addr_idx = var_sel_write_addr_idx + 1) begin
            if (i_write_wes[var_sel_write_addr_idx]) begin
                next_mem_reg[ i_write_addresses[var_sel_write_addr_idx*ENTRY_ADDR_WIDTH +: ENTRY_ADDR_WIDTH] ] = 
                    i_write_data[ var_sel_write_addr_idx*REG_WIDTH +: REG_WIDTH ];
            end
        end
    end

endmodule

// (FOR FIFO_RAM PIPELINING)=============================================================
module priority_decoder #(
    parameter       ENTRIES         = 7
) (
    input       [ENTRIES-1:0]                           i_entries_list, // priortiy is MSB first
    output reg  [ENTRIES-1:0]                           o_top_entries,
    output reg                                          o_valid
);
    
    // Synthesis Variables
    integer var_target_entry = 0;
    
    // Priority Decoder CL
    always @(*) begin
        o_top_entries = {(ENTRIES){1'b0}};
        o_valid = 1'b0;
        for (var_target_entry = (ENTRIES-1); var_target_entry >= 0; var_target_entry = var_target_entry - 1) begin
            if (i_entries_list[var_target_entry]) begin
                o_top_entries[var_target_entry] = 1'b1;
                o_valid = 1'b1;
            end
        end
    end

endmodule

module on_chip_sync_dual_port_ram #(
    parameter       ENTRIES         = 16,
    parameter       ENTRY_WIDTH     = 32,
    parameter       ENTRY_ADDR_WIDTH= $clog2(ENTRIES+1)
) (
    input                                               clk,
    input       [ENTRY_ADDR_WIDTH-1:0]                  r_addr,
    input                                               we,
    input       [ENTRY_ADDR_WIDTH-1:0]                  w_addr,
    input       [ENTRY_WIDTH-1:0]                       w_data,
    output reg  [ENTRY_WIDTH-1:0]                       r_data
);
    // Set memory
    reg [ENTRY_WIDTH-1:0] mem [0:ENTRIES-1];
    always @(posedge clk) begin
        r_data = mem[r_addr];

        if (we) begin
            mem[w_addr] = w_data;
        end
    end

endmodule

/*
[fifo_sram]
##########################################################################################
PARAMETERIZE SINGLE READ/WRITE CHANNELS FIFO, INTERNAL MEMORY IS SRAM/BRAM
- READ LATENCY          : IMMEDIATELY
- WRITE LATENCY         : 1 CYCLE

* TESTBENCH MODULE      : tb_fifo_sram
------------------------------------------------------------------------------------------
[PARAMETER(USER MODIFY)]
    ENTRIES             : NUMBER OF ENTRIES
    REG_WIDTH           : WIDTH OF ENTRY

[INPUT/OUTPUT]
    clk                 : [INPUT ] SYSTEM CLOCK
    reset_n             : [INPUT ] SYSTEM ACTIVE-LOW RESET
    i_read_get          : [INPUT ] READ ENTRIES FROM READ CHANNEL
    i_write_we          : [INPUT ] WRITE ENABLE OF WRITE CHANNEL
    i_write_data        : [INPUT ] DATA OF WRITE CHANNEL
    o_read_data         : [OUTPUT] DATA OF READ CHANNEL
    o_empty             : [OUTPUT] EMPTY INDECATOR OF FIFO
    o_full              : [OUTPUT] FULL INDECATOR OF FIFO
##########################################################################################
*/
module fifo_sram #(
    parameter       ENTRIES         = 16,
    parameter       REG_WIDTH       = 32,
    parameter       ENTRY_ADDR_WIDTH= $clog2(ENTRIES+1)
) (
    input                                               clk                 ,
    input                                               reset_n             ,
    input                                               i_read_get          ,
    input                                               i_write_we          ,
    input       [REG_WIDTH-1:0]                         i_write_data        ,
    output      [REG_WIDTH-1:0]                         o_read_data         ,
    output reg                                          o_empty             ,
    output reg                                          o_full
);
    // CONSTANT
    localparam HIGHEST_INDEX_NUMBER = ENTRIES - 1;

    // SRAM/BRAM Control Value
    reg [ENTRY_ADDR_WIDTH-1:0] ram_read_addr, ram_read_addr_next;
    reg [ENTRY_ADDR_WIDTH-1:0] ram_write_addr, ram_write_addr_next;
    reg [ENTRY_ADDR_WIDTH-1:0] ram_entry_cnt, ram_entry_cnt_next;
    reg                        ram_we;

    // Connect SRAM
    on_chip_sync_dual_port_ram #(.ENTRIES(ENTRIES), .ENTRY_WIDTH(REG_WIDTH)) 
            U_INTERNAL_SRAM(.clk(clk), .r_addr(ram_read_addr), .we(ram_we),
                            .w_addr(ram_write_addr), .w_data(i_write_data), 
                            .r_data(o_read_data));

    // States
    localparam R_EMPTY      = 1'd0;
    localparam R_READABLE   = 1'd1;

    localparam W_WRITEABLE  = 1'd0;
    localparam W_FULL       = 1'd1;

    // State Register
    reg read_state, read_state_next;
    reg write_state, write_state_next;

    // Registers MODELING
    always @(posedge clk or negedge reset_n) begin
        if (reset_n == 0) begin
            ram_read_addr <= 0;
            ram_write_addr <= 0;
            ram_entry_cnt <= 0;

            read_state <= R_EMPTY;
            write_state <= W_WRITEABLE;
        end
        else begin
            ram_read_addr <= ram_read_addr_next;
            ram_write_addr <= ram_write_addr_next;
            ram_entry_cnt <= ram_entry_cnt_next;

            read_state <= read_state_next;
            write_state <= write_state_next;
        end
    end

    // NEXT STATE, OPERATION MODELING ( COMBINATIONAL LOGIC )
    always @(*) begin
        read_state_next = read_state;
        write_state_next = write_state;

        ram_we = 1'b0; // CL
        ram_read_addr_next = ram_read_addr;
        ram_write_addr_next = ram_write_addr;
        ram_entry_cnt_next = ram_entry_cnt;

        case(read_state)
            R_EMPTY: begin
                if (ram_entry_cnt != 0) read_state_next = R_READABLE;
            end
            R_READABLE: begin
                if (ram_entry_cnt == 0) read_state_next = R_EMPTY;
                
                if (i_read_get) begin
                    ram_entry_cnt_next = ram_entry_cnt - 1;
                    if (ram_read_addr == HIGHEST_INDEX_NUMBER) ram_read_addr_next = 0;
                    else ram_read_addr_next = ram_read_addr + 1;
                end
            end
        endcase

        case(write_state)
            W_WRITEABLE: begin
                if (ram_entry_cnt == HIGHEST_INDEX_NUMBER) write_state_next = W_FULL;

                if (i_write_we) begin
                    ram_we = 1'b1;
                    ram_entry_cnt_next = ram_entry_cnt + 1;
                    if (ram_write_addr == HIGHEST_INDEX_NUMBER) ram_write_addr_next = 0;
                    else ram_write_addr_next = ram_write_addr + 1;
                end
            end
            W_FULL: begin
                if (ram_entry_cnt != HIGHEST_INDEX_NUMBER) write_state_next = W_WRITEABLE;
            end
        endcase
    end

    // OUTPUT MODELING ( COMBINATIONAL LOGIC )
    always @(*) begin
        // outputs
        o_empty = (ram_entry_cnt == 0)? 1'b1 : 1'b0;
        o_full = (ram_entry_cnt == HIGHEST_INDEX_NUMBER)? 1'b1 : 1'b0;
    end

endmodule

/*
[fifo_multi_chan_sram]
##########################################################################################
PARAMETERIZE MULTI READ/WRITE CHANNELS FIFO, INTERNAL MEMORY IS SRAM/BRAM
- READ LATENCY          : IMMEDIATELY
- WRITE LATENCY         : 1 CYCLE

WRITE_CHANNEL > READ_CHANNEL

* TESTBENCH MODULE      : tb_fifo_multi_chan_sram
------------------------------------------------------------------------------------------
[PARAMETER(USER MODIFY)]
    READ_CHANNEL        : NUMBER OF READ CHANNELS
    WRITE_CHANNEL       : NUMBER OF WRITE CHANNELS
    ENTRIES             : NUMBER OF ENTRIES
    REG_WIDTH           : WIDTH OF ENTRY

[INPUT/OUTPUT]
    clk                 : [INPUT ] SYSTEM CLOCK
    reset_n             : [INPUT ] SYSTEM ACTIVE-LOW RESET
    i_read_get          : [INPUT ] READ ENTRIES FROM READ CHANNELS
    i_write_wes         : [INPUT ] WRITE ENABLE OF WRITE CHANNELS
    i_write_data        : [INPUT ] DATA OF WRITE CHANNELS
    o_read_data         : [OUTPUT] DATA OF READ CHANNELS
    o_read_valid        : [OUTPUT] VALID OF READ CHANNELS
##########################################################################################
*/
module fifo_multi_chan_sram #(
    parameter       READ_CHANNEL    = 8 ,
    parameter       WRITE_CHANNEL   = 4 ,
    parameter       ENTRIES         = 16,
    parameter       REG_WIDTH       = 32,
    parameter       ENTRY_ADDR_WIDTH= $clog2(ENTRIES+1)
) (
    input                                               clk                 ,
    input                                               reset_n             ,
    input       [READ_CHANNEL-1:0]                      i_read_get          ,
    input       [WRITE_CHANNEL-1:0]                     i_write_wes         ,
    input       [WRITE_CHANNEL*REG_WIDTH-1:0]           i_write_data        ,
    output reg  [READ_CHANNEL*REG_WIDTH-1:0]            o_read_data
    output reg  [READ_CHANNEL-1:0]                      o_read_valid
);
    // Synthesis Variables
    integer var_read_entry_idx = 0;
    integer var_read_data_bit_position = 0;
    integer var_read_buf_idx = 0;
    integer var_write_entry_idx = 0;
    integer var_write_data_bit_position = 0;
    
    // Constant
    localparam INTERNAL_DEPTH = ENTRIES / WRITE_CHANNEL;
    localparam INTERNAL_ADDR_WIDTH = $clog2(INTERNAL_DEPTH);
    localparam INTERNAL_DATA_WIDTH = (REG_WIDTH*WRITE_CHANNEL);

    // SRAM/BRAM Control Value: SYNTHESIS => WIRES OR COMBINATIONAL LOGIC
    reg ram_we, ram_we_next;
    reg [INTERNAL_ADDR_WIDTH-1:0] ram_addr_insert, ram_addr_insert_next;
    wire [INTERNAL_DATA_WIDTH-1:0] ram_data_insert;

    // DATAPATH Registers
    reg [INTERNAL_DATA_WIDTH-1:0] buf_read, buf_read_next;
    reg [(INTERNAL_DATA_WIDTH*2)-2:0] buf_leave1_read, buf_leave1_read_next;
    reg [INTERNAL_DATA_WIDTH-1:0] buf_leave2_read, buf_leave2_read_next;
    reg [INTERNAL_DATA_WIDTH-1:0] buf_write, buf_write_next;

    // Registers MODELING
    always @(posedge clk or negedge reset_n) begin
        if (reset_n == 0) begin
            ram_we <= 1'b0;
            ram_addr <= 0;

            buf_read <= 0;
            buf_leave1_read <= 0;
            buf_leave2_read <= 0;
            buf_write <= 0;
        end
        else begin
            ram_we <= ram_we_next;
            ram_addr_insert <= ram_addr_insert_next;

            buf_read <= buf_read_next;
            buf_leave1_read <= buf_leave1_read_next;
            buf_leave2_read <= buf_leave2_read_next;
            buf_write <= buf_write_next;
        end
    end

    // Read System MODELING ( COMBINATIONAL LOGIC )
    always @(*) begin
        o_read_data = '0;
        var_read_data_bit_position = 0;
        var_read_buf_idx = 0;
        
        for (var_read_entry_idx = 0; var_read_entry_idx < READ_CHANNEL; var_read_entry_idx = var_read_entry_idx + 1) begin
            if (i_read_get[var_read_entry_idx]) begin
                o_read_data[(var_read_data_bit_position*REG_WIDTH) +: REG_WIDTH] = buf_read[(var_read_entry_idx*REG_WIDTH) +: REG_WIDTH];
                var_read_data_bit_position = var_read_data_bit_position + 1;
            end
            else begin
                buf_read_next[(var_read_buf_idx*REG_WIDTH) +: REG_WIDTH] = buf_read[(var_read_entry_idx*REG_WIDTH) +: REG_WIDTH];
                var_read_buf_idx = var_read_buf_idx + 1;
            end
        end
        var_read_entry_idx = 0;
        for (; var_read_buf_idx < READ_CHANNEL; var_read_buf_idx = var_read_buf_idx + 1) begin
            buf_read_next[(var_read_buf_idx*REG_WIDTH) +: REG_WIDTH] = buf_leave1_read[(var_read_entry_idx*REG_WIDTH) +: REG_WIDTH];
            var_read_entry_idx = var_read_entry_idx + 1;
        end
    end

    // Write System MODELING ( COMBINATIONAL LOGIC )
    always @(*) begin
        buf_write_next = '0;
        var_write_data_bit_position = 0;
        ram_we_next = |i_write_wes;
        for (var_write_entry_idx = 0; var_write_entry_idx < WRITE_CHANNEL; var_write_entry_idx = var_write_entry_idx + 1) begin
            if (i_write_wes[var_write_entry_idx]) begin
                buf_write_next[var_write_data_bit_position +: REG_WIDTH] = i_write_data[(var_write_entry_idx*REG_WIDTH) +: REG_WIDTH];
                var_write_data_bit_position = var_write_data_bit_position + REG_WIDTH;
            end
        end
    end
endmodule

// TODO: Single Channel FIFO, SRAM CONTROLLER, Single Channel SRAM ACCESS FIFO CONTROLLER