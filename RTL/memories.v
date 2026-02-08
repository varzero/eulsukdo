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

// (FOR FIFO_RAM)=======================================================================
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

/*
[fifo_multi_chan_sram]
##########################################################################################
PARAMETERIZE MULTI READ/WRITE CHANNELS FIFO, INTERNAL MEMORY IS SRAM/BRAM
- READ LATENCY          : IMMEDIATELY
- WRITE LATENCY         : 1 CYCLE

LOGICAL  

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
);
    // Synthesis Variables
    integer var_read_entry_idx = 0;
    integer var_read_data_bit_position = 0;
    integer var_write_entry_idx = 0;
    integer var_write_data_bit_position = 0;
    
    // Constant
    localparam INTERNAL_DEPTH = ENTRIES / WRITE_CHANNEL;
    localparam INTERNAL_ADDR_WIDTH = $clog2(INTERNAL_DEPTH);
    localparam INTERNAL_DATA_WIDTH = (REG_WIDTH*WRITE_CHANNEL);

    // SRAM/BRAM Control Value: SYNTHESIS => WIRES OR COMBINATIONAL LOGIC
    reg ram_we, ram_we_next;
    reg [INTERNAL_ADDR_WIDTH-1:0] ram_addr, ram_addr_next;
    wire [INTERNAL_DATA_WIDTH-1:0] ram_data_insert, ram_data_insert_next;

    // DATAPATH Registers
    reg [INTERNAL_DATA_WIDTH-1:0] buf_read, buf_read_next;
    reg [INTERNAL_DATA_WIDTH-1:0] buf_write, buf_write_next;

    // Registers MODELING
    always @(posedge clk or negedge reset_n) begin
        if (reset_n == 0) begin
            ram_we <= 1'b0;
            ram_addr <= 0;
            ram_data_insert <= 0;

            buf_read <= 0;
            buf_write <= 0;
        end
        else begin
            ram_we <= ram_we_next;
            ram_addr <= ram_addr_next;
            ram_data_insert <= ram_data_insert_next;

            buf_read <= buf_read_next;
            buf_write <= buf_write_next;
        end
    end

    // Read System MODELING ( COMBINATIONAL LOGIC )
    always @(*) begin
        o_read_data = '0;
        var_read_data_bit_position = 0;
        
        for (var_read_entry_idx = 0; var_read_entry_idx < READ_CHANNEL; var_read_entry_idx = var_read_entry_idx + 1) begin
            if (i_read_get[0]) begin
                o_read_data[var_read_data_bit_position +: REG_WIDTH] = buf_read[];
            end
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
