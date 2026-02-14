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
        r_data <= mem[r_addr];

        if (we) begin
            mem[w_addr] <= w_data;
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
    parameter       ENTRY_ADDR_WIDTH= $clog2(ENTRIES)
) (
    input                                               clk                 ,
    input                                               reset_n             ,
    input                                               i_read_get          ,
    input                                               i_write_we          ,
    input       [REG_WIDTH-1:0]                         i_write_data        ,
    output reg  [REG_WIDTH-1:0]                         o_read_data         ,
    output reg                                          o_empty             ,
    output reg                                          o_full
);
    // CONSTANT
    localparam HIGHEST_INDEX_NUMBER = ENTRIES - 1;

    // SRAM/BRAM Control Variables
    reg [ENTRY_ADDR_WIDTH-1:0] ram_read_addr, ram_read_addr_next;
    reg [ENTRY_ADDR_WIDTH-1:0] ram_write_addr, ram_write_addr_next;
    reg [$clog2(ENTRIES+1)-1:0] ram_entry_cnt, ram_entry_cnt_next;
    reg                        sram_updating, sram_updating_next;
    reg                        ram_we;

    // Data buffer
    reg [REG_WIDTH-1:0]        write_buf, write_buf_next;

    // Connect SRAM
    wire [REG_WIDTH-1:0]       ram_read_data;
    on_chip_sync_dual_port_ram #(.ENTRIES(ENTRIES), .ENTRY_WIDTH(REG_WIDTH)) 
            U_INTERNAL_SRAM(.clk(clk), .r_addr(ram_read_addr), .we(ram_we),
                            .w_addr(ram_write_addr), .w_data(i_write_data), 
                            .r_data(ram_read_data));

    // Registers MODELING
    always @(posedge clk or negedge reset_n) begin
        if (reset_n == 0) begin
            ram_read_addr <= 0;
            ram_write_addr <= 0;
            ram_entry_cnt <= 0;
            sram_updating <= 0;

            write_buf <= 0;
        end
        else begin
            ram_read_addr <= ram_read_addr_next;
            ram_write_addr <= ram_write_addr_next;
            ram_entry_cnt <= ram_entry_cnt_next;
            sram_updating <= sram_updating_next;

            write_buf <= write_buf_next;
        end
    end

    always @(*) begin
        // output
        o_read_data = ram_read_data;
        ram_we = 1'b0;

        // register updates 
        ram_read_addr_next = ram_read_addr;
        ram_write_addr_next = ram_write_addr;
        ram_entry_cnt_next = ram_entry_cnt;
        sram_updating_next = 0;

        write_buf_next = write_buf;

        // PUSH/POP CONTROL
        if (i_read_get && (ram_entry_cnt != 0)) begin
            ram_entry_cnt_next = ram_entry_cnt_next - 1;
            if (ram_read_addr == HIGHEST_INDEX_NUMBER) ram_read_addr_next = 0;
            else ram_read_addr_next = ram_read_addr + 1;
        end

        if (i_write_we && ((ram_entry_cnt != ENTRIES) || (i_read_get && (ram_entry_cnt != 0)))) begin
            ram_we = 1'b1;
            ram_entry_cnt_next = ram_entry_cnt_next + 1;
            if (ram_write_addr == HIGHEST_INDEX_NUMBER) ram_write_addr_next = 0;
            else ram_write_addr_next = ram_write_addr + 1;
        end

        // SRAM Read Latency Control - write after read next cycle
        if (i_write_we && (ram_entry_cnt == 0)) begin
            sram_updating_next = 1'b1;
            write_buf_next = i_write_data;
        end
        if (i_read_get && sram_updating) begin
            o_read_data = write_buf;
        end
    
        // OUTPUT MODELING ( COMBINATIONAL LOGIC )
        o_empty = (ram_entry_cnt == 0)      ? 1'b1 : 1'b0;
        o_full  = (ram_entry_cnt == ENTRIES)? 1'b1 : 1'b0;
    end

endmodule

/*
[fifo_multi_chan_sram]
##########################################################################################
PARAMETERIZE MULTI READ/WRITE CHANNELS FIFO, INTERNAL MEMORY IS SRAM/BRAM
- READ LATENCY          : IMMEDIATELY
- WRITE LATENCY         : 1 CYCLE

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
    o_write_ready       : [OUTPUT] READY OF WRITE CHANNELS
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
    output reg                                          o_write_ready       ,
    output reg  [READ_CHANNEL*REG_WIDTH-1:0]            o_read_data         ,
    output reg  [READ_CHANNEL-1:0]                      o_read_valid
);
    // Constants
    parameter INTERNAL_CHANNEL = (WRITE_CHANNEL > READ_CHANNEL)? WRITE_CHANNEL : READ_CHANNEL;

    // Synthesis Variables
    integer var_read_entry_idx = 0;
    integer var_read_data_bit_position = 0;
    integer var_read_buf_idx = 0;
    integer var_write_entry_idx = 0;
    integer var_write_data_bit_position = 0;

    // SRAM/BRAM Control Value: SYNTHESIS => WIRES OR COMBINATIONAL LOGIC
    wire fifo_empty;
    wire fifo_full;
        // write
    reg ram_we, ram_we_next;
    reg [(INTERNAL_CHANNEL*REG_WIDTH)-1:0] ram_data_insert;
    reg [(INTERNAL_CHANNEL*REG_WIDTH)-1:0] ram_data_out;

    // DATAPATH Wire, Registers
        // write
    reg write_update_blocking; // wire
    reg upper_area_write, upper_area_write_next;
    reg [$clog2(WRITE_CHANNEL)-1:0] buf_L1_cnt_write, buf_L1_cnt_write_next;
    reg [WRITE_CHANNEL*REG_WIDTH-1:0] buf_L1_write, buf_L1_write_next;
    reg [$clog2(INTERNAL_CHANNEL*2)-1:0] buf_L2_leave_cnt_write;
    reg [$clog2(INTERNAL_CHANNEL*2):0] buf_L2_leave_cnt_write_next;
    reg [(INTERNAL_CHANNEL*2)*REG_WIDTH-1:0] buf_L2_write, buf_L2_write_next;
        // read
    reg read_update_blocking; // wire
    reg [$clog2(INTERNAL_CHANNEL*2)-1:0] buf_cnt_read, buf_cnt_read_next;
    reg [(INTERNAL_CHANNEL*REG_WIDTH)-1:0] buf_read, buf_read_next;

    // FIFO
    fifo_sram #(.ENTRIES(ENTRIES), .REG_WIDTH(INTERNAL_CHANNEL*REG_WIDTH)) U_INTERNAL_FIFO (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_get          (),
        .i_write_we          (ram_we),
        .i_write_data        (ram_data_insert),
        .o_read_data         (),
        .o_empty             (fifo_empty),
        .o_full              (fifo_full)
    );

    // Registers MODELING
    always @(posedge clk or negedge reset_n) begin
        if (reset_n == 0) begin
            ram_we <= 1'b0;

            upper_area_write <= 0;
            buf_L1_cnt_write <= 0;
            buf_L1_write <= 0;
            buf_L2_leave_cnt_write <= 0;
            buf_L2_write <= 0;

            buf_cnt_read <= 0;
            buf_read <= 0;
        end
        else begin
            ram_we <= ram_we_next;

            upper_area_write <= upper_area_write_next;
            buf_L1_cnt_write <= buf_L1_cnt_write_next;
            buf_L1_write <= buf_L1_write_next;
            buf_L2_leave_cnt_write <= buf_L2_leave_cnt_write_next;
            buf_L2_write <= buf_L2_write_next;

            buf_cnt_read <= buf_cnt_read_next;
            buf_read <= buf_read_next;
        end
    end

    // Write System MODELING ( COMBINATIONAL LOGIC )
    always @(*) begin
        ram_we_next = 1'b0;
        ram_data_insert = 0;

        upper_area_write_next = 1'b0;

        write_update_blocking = fifo_full;
        
        buf_L2_leave_cnt_write_next = buf_L2_leave_cnt_write;
        buf_L2_write_next = buf_L2_write;
        
        // RAM Write Data Select
        if (ram_we) begin
            if (upper_area_write) begin
                ram_data_insert = buf_L2_write[((INTERNAL_CHANNEL*2)*REG_WIDTH)-1:(INTERNAL_CHANNEL*REG_WIDTH)];
                buf_L2_write_next[((INTERNAL_CHANNEL*2)*REG_WIDTH)-1:(INTERNAL_CHANNEL*REG_WIDTH)] = 0;
            end
            else begin
                ram_data_insert = buf_L2_write[(INTERNAL_CHANNEL*REG_WIDTH)-1:0];
                buf_L2_write_next[(INTERNAL_CHANNEL*REG_WIDTH)-1:0] = 0;
            end
        end
        
        // Insert Logic/Datapath
        if (~write_update_blocking) begin
            // L1 buffer
            buf_L1_cnt_write_next = 0;
            buf_L1_write_next = 0;
            var_write_data_bit_position = 0;

            for (var_write_entry_idx = 0; var_write_entry_idx < WRITE_CHANNEL; var_write_entry_idx = var_write_entry_idx + 1) begin
                // Gathering scattered input
                if (i_write_wes[var_write_entry_idx]) begin
                    buf_L1_write_next[var_write_data_bit_position +: REG_WIDTH] = i_write_data[(var_write_entry_idx*REG_WIDTH) +: REG_WIDTH];
                    var_write_data_bit_position = var_write_data_bit_position + REG_WIDTH;

                    buf_L1_cnt_write_next = buf_L1_cnt_write_next + 1;
                end
            end

            // L2 buffer
            buf_L2_leave_cnt_write_next = buf_L2_leave_cnt_write_next + buf_L1_cnt_write_next;
            buf_L2_write_next = buf_L2_write_next | (buf_L1_write << (buf_L2_leave_cnt_write*REG_WIDTH) );

            if (buf_L2_leave_cnt_write_next >= (INTERNAL_CHANNEL*2)) begin
                ram_we_next = 1'b1;
                upper_area_write_next = 1'b1;

                if (buf_L2_leave_cnt_write_next > (INTERNAL_CHANNEL*2)) begin
                    buf_L2_write_next = buf_L2_write_next | (buf_L1_write >> (((INTERNAL_CHANNEL*2) - buf_L2_leave_cnt_write) *REG_WIDTH ) );
                end
                buf_L2_leave_cnt_write_next = buf_L2_leave_cnt_write_next - (INTERNAL_CHANNEL*2);
            end
            else if (buf_L2_leave_cnt_write_next >= INTERNAL_CHANNEL) begin
                ram_we_next = 1'b1;
            end
        end
        else begin
            buf_L1_cnt_write_next = buf_L1_cnt_write;
            buf_L1_write_next = buf_L1_write;
        end

        // Output 
        o_write_ready = ~write_update_blocking;
    end
    
    // Read System MODELING ( COMBINATIONAL LOGIC )
    always @(*) begin
        buf_cnt_read_next = buf_cnt_read;
        buf_read_next = buf_read;
        
        var_read_data_bit_position = 0;

        for (var_read_entry_idx = 0; var_read_entry_idx < READ_CHANNEL; var_read_entry_idx = var_read_entry_idx + 1) begin
            // READ CHANNEL Gather
            if (~i_read_get[var_read_entry_idx]) begin
                buf_read_next[var_read_data_bit_position +: REG_WIDTH] = buf_read[(var_read_entry_idx*REG_WIDTH) +: REG_WIDTH];
                var_read_data_bit_position = var_read_data_bit_position + REG_WIDTH;
                
                buf_cnt_read_next = buf_cnt_read_next - 1;
            end
        end

        if (buf_cnt_read_next >= INTERNAL_CHANNEL) begin
            // BUFFER Gather
            for (var_read_entry_idx = READ_CHANNEL; var_read_entry_idx < (INTERNAL_CHANNEL*2); var_read_entry_idx = var_read_entry_idx + 1) begin
                buf_read_next[var_read_data_bit_position +: REG_WIDTH] = buf_read[(var_read_entry_idx*REG_WIDTH) +: REG_WIDTH];
                var_read_data_bit_position = var_read_data_bit_position + REG_WIDTH;
            end
        end
        else begin
            if (~fifo_empty) begin
                // ADDING NEW Entries
                for (var_read_entry_idx = 0; var_read_entry_idx < INTERNAL_CHANNEL; var_read_entry_idx = var_read_entry_idx + 1) begin
                    buf_read_next[var_read_data_bit_position +: REG_WIDTH] = ram_data_out[(var_read_entry_idx*REG_WIDTH) +: REG_WIDTH];
                    var_read_data_bit_position = var_read_data_bit_position + REG_WIDTH;
                end
                buf_cnt_read_next = buf_cnt_read_next + INTERNAL_CHANNEL;
            end
        end
        // FILL BLANK AREA
        buf_read_next[(INTERNAL_CHANNEL*REG_WIDTH):var_read_data_bit_position] = 0;
    end

endmodule

// TODO: Single Channel FIFO, SRAM CONTROLLER, Single Channel SRAM ACCESS FIFO CONTROLLER