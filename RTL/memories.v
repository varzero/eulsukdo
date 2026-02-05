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
            o_read_data[ (var_sel_read_addr_idx*REG_WIDTH) + (REG_WIDTH-1) : var_sel_read_addr_idx*REG_WIDTH ] = 
                mem_reg[ (i_read_addresses[ (var_sel_read_addr_idx*ENTRY_ADDR_WIDTH) + (ENTRY_ADDR_WIDTH-1) : var_sel_read_addr_idx*ENTRY_ADDR_WIDTH ]) ];
        end

        // Write channel
        for (var_sel_write_addr_idx = 0; var_sel_write_addr_idx < READ_CHANNEL; var_sel_write_addr_idx = var_sel_write_addr_idx + 1) begin
            if (i_write_wes[var_sel_write_addr_idx]) begin
                next_mem_reg[ (i_write_addresses[ (var_sel_write_addr_idx*ENTRY_ADDR_WIDTH) + (ENTRY_ADDR_WIDTH-1) : var_sel_write_addr_idx*ENTRY_ADDR_WIDTH ]) ] = 
                    i_write_data[ (var_sel_write_addr_idx*REG_WIDTH) + (REG_WIDTH-1) : var_sel_write_addr_idx*REG_WIDTH ];
            end
        end
    end

endmodule

/*
[fifo_sram]
##########################################################################################
PARAMETERIZE MULTI READ/WRITE CHANNELS FIFO, INTERNAL MEMORY IS SRAM/BRAM
- READ LATENCY          : IMMEDIATELY
- WRITE LATENCY         : 1 CYCLE

* TESTBENCH MODULE      : tb_fifo_sram
------------------------------------------------------------------------------------------
[PARAMETER(USER MODIFY)]
    READ_CHANNEL        : NUMBER OF READ CHANNELS
    WRITE_CHANNEL       : NUMBER OF WRITE CHANNELS
    ENTRIES             : NUMBER OF ENTRIES
    REG_WIDTH           : WIDTH OF ENTRY

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
    parameter       READ_CHANNEL    = 4 ,
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
endmodule
