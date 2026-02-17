/*
    ROB READY PROCESS
    COMBINATIONAL LOGIC
*/
module rob_ready_update #(
    parameter ROB_ENTRY_MAX = 128,
    parameter ROB_PC_BIT_WIDTH = 32,
    parameter ROB_MICROOP_BIT_WIDTH = 8,
    parameter ROB_LOGICALREG_BIT_WIDTH = 4,
    parameter ROB_PHYSICALREG_BIT_WIDTH = 6,
    parameter ROB_OPERANDS = 2,
    parameter ROB_ENTRY_ADDR_WIDTH = $clog2(ROB_ENTRY_MAX),
    parameter ROB_ENTRY_BIT_WIDTH = 
                ( ROB_PC_BIT_WIDTH + ROB_MICROOP_BIT_WIDTH + 
                  ROB_LOGICALREG_BIT_WIDTH + ROB_PHYSICALREG_BIT_WIDTH +
                  (ROB_OPERANDS*ROB_PHYSICALREG_BIT_WIDTH) + ROB_OPERANDS ),
    parameter RS_ENTRY_BIT_WIDTH = 
                ( ROB_ENTRY_ADDR_WIDTH + ROB_PHYSICALREG_BIT_WIDTH + 
                  ROB_PHYSICALREG_BIT_WIDTH + (ROB_OPERANDS*ROB_PHYSICALREG_BIT_WIDTH))
) (
    input active,
    input rs_full,
    input [ROB_ENTRY_ADDR_WIDTH-1:0] rob_addr_in,
    input [ROB_ENTRY_BIT_WIDTH-1:0] rob_entry_current,
    output [ROB_ENTRY_ADDR_WIDTH-1:0] rob_addr_out,
    output reg [ROB_ENTRY_BIT_WIDTH-1:0] rob_entry_next,
    output reg ready_all,
    output reg [RS_ENTRY_BIT_WIDTH-1:0] rs_entry
);
    // Synthsis Variable
    integer operand_index = 0;

    // Positions
    localparam ROB_OPERANDS_POSITION_START = 
                    ROB_PC_BIT_WIDTH + ROB_MICROOP_BIT_WIDTH + 
                    ROB_LOGICALREG_BIT_WIDTH + ROB_PHYSICALREG_BIT_WIDTH;
    localparam ROB_READY_POSITION_START = 
                    ROB_OPERANDS_POSITION_START + (ROB_PHYSICALREG_BIT_WIDTH*ROB_OPERANDS);
    localparam ROB_MICROOP_START = ROB_PC_BIT_WIDTH;
    localparam ROB_PHYSICALREG_START = ROB_MICROOP_START + ROB_LOGICALREG_BIT_WIDTH;

    // Logic
    always @(*) begin
        rob_entry_next = rob_entry_current;
        ready_all = 1'b0;
        rs_entry = 0;

        if (active & ~rs_full) begin
            for (operand_index = 0; operand_index < ROB_OPERANDS; operand_index = operand_index+!) begin
                if (rob_entry_current[((operand_index*ROB_PHYSICALREG_BIT_WIDTH) + ROB_OPERANDS_POSITION_START) +: ROB_PHYSICALREG_BIT_WIDTH]) begin
                    rob_entry_next[ROB_READY_POSITION_START + operand_index] = 1'b1;
                end
            end
            
            if (&rob_entry_next[ROB_READY_POSITION_START +: ROB_OPERANDS]) begin
                ready_all = 1'b1;
                rs_entry = {rob_entry_current[ROB_OPERANDS_POSITION_START +: (ROB_OPERANDS*ROB_PHYSICALREG_BIT_WIDTH)],
                            rob_entry_current[ROB_PHYSICALREG_START +: ROB_PHYSICALREG_BIT_WIDTH],
                            rob_entry_current[ROB_MICROOP_START +: ROB_MICROOP_START],
                            rob_addr_in}; 
                            // OprN...1, PHY Reg, uOP, ROB No
            end
        end
    end

    assign rob_addr_out = rob_addr_in;

endmodule

module rob_ #() ();
endmodule
