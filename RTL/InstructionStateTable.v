module ist #( // Instruction State Table
	parameter IST_ENTRIES = 128,
    parameter NEW_INSTRUCTION = 4,
    parameter DONE_INSTRUCTION = 4,

    parameter COMPLETE_EX = 7,
    
    parameter PC_WIDTH = 32,
	parameter MICRO_OP_LENGHT = 5, // LSB 쪽으로 EX_SPECIFY_WIDTH 만큼은 EX 선택용
	parameter NUM_OF_PHY_REGS = 64,
	parameter NUM_OF_LOGICAL_REGS = 32,
	parameter OPREANDS = 2,

	parameter IST_ADDR_WIDTH = $clog2(IST_ENTRIES),
	parameter PHYREG_ADDR_WIDTH = $clog2(NUM_OF_PHY_REGS),
	parameter LOGREG_ADDR_WIDTH = $clog2(NUM_OF_LOGICAL_REGS),
    parameter IST_ENTRY_WIDTH = PC_WIDTH + MICRO_OP_LENGHT 
                                + NUM_OF_PHY_REGS + NUM_OF_LOGICAL_REGS 
                                + (NUM_OF_PHY_REGS * OPREANDS)
) (
    input clk,
    input reset_n,

    input [(COMPLETE_EX * PHYREG_ADDR_WIDTH)-1:0] ready_phyreg_i,

    output active
);

    allocator #(
    	.NUM_OF_ENTRIES (IST_ENTRIES),
        .UNALLOCATES    (DONE_INSTRUCTION),
        .ALLOCATES      (NEW_INSTRUCTION)
    ) U_IST_ENTRIES_ALLOCATOR (
        .clk                  (clk),
        .reset_n              (reset_n),
        /* input [UNALLOCATES-1:0]                     */ .unallocate_valid_i   (),
        /* input [(UNALLOCATES * ENTRY_NUM_WIDTH)-1:0] */ .unallocate_entries_i (),
        /* input [ALLOCATES-1:0]                       */ .allocating_i         (),
	    /* output [ALLOCATES-1:0]                      */ .allocate_valid_o     (),
        /* output [(ALLOCATES * ENTRY_NUM_WIDTH)-1:0]  */ .allocate_entries_o   (),
    	.init_done            (active)
    );

    // Opreands
    wire [(COMPLETE_EX * (NUM_OF_PHY_REGS * OPREANDS))-1:0] inst_opreands;
    regfile #(
        .READ_CHANNEL    (COMPLETE_EX),
        .WRITE_CHANNEL   (NEW_INSTRUCTION),
        .ENTRIES         (IST_ENTRIES),
        .REG_WIDTH       (NUM_OF_PHY_REGS * OPREANDS)
    ) U_OPERANDS_LIST (
        .clk                 (clk),
        .reset_n             (reset_n),
        /* input       [READ_CHANNEL*ENTRY_ADDR_WIDTH-1:0]  */ .i_read_addresses    (),
        /* input       [WRITE_CHANNEL-1:0]                  */ .i_write_wes         (),
        /* input       [WRITE_CHANNEL*ENTRY_ADDR_WIDTH-1:0] */ .i_write_addresses   (),
        /* input       [WRITE_CHANNEL*REG_WIDTH-1:0]        */ .i_write_data        (),
        /* output reg  [READ_CHANNEL*REG_WIDTH-1:0]         */ .o_read_data         (inst_opreands)
    );

    // Readies
    wire [COMPLETE_EX-1:0] opreands_ready_before[0:OPREANDS-1];
    reg  [COMPLETE_EX-1:0] opreands_ready_after[0:OPREANDS-1];
    reg  [NEW_INSTRUCTION-1:0] opreands_ready_new[0:OPREANDS-1];

    genvar target_opreand;
    generate
        for (target_opreand = 0; target_opreand < OPREANDS; target_opreand = target_opreand + 1) begin
            regfile #(
                .READ_CHANNEL    (COMPLETE_EX),
                .WRITE_CHANNEL   (COMPLETE_EX + NEW_INSTRUCTION),
                .ENTRIES         (IST_ENTRIES),
                .REG_WIDTH       (1)
            ) U_READY_OPERAND (
                .clk                 (clk),
                .reset_n             (reset_n),
                /* input       [READ_CHANNEL*ENTRY_ADDR_WIDTH-1:0]  */ .i_read_addresses    (),
                /* input       [WRITE_CHANNEL-1:0]                  */ .i_write_wes         (),
                /* input       [WRITE_CHANNEL*ENTRY_ADDR_WIDTH-1:0] */ .i_write_addresses   (),
                .i_write_data        ( {opreands_ready_new[target_opreand], opreands_ready_after[target_opreand]} ),
                .o_read_data         (opreands_ready_before[target_opreand])
            );
        end
    endgenerate

    integer ready_position_check, opreand_position, ready_entries_num;
    reg [OPREANDS-1:0] ready_vector;
    reg [(COMPLETE_EX + NEW_INSTRUCTION)-1:0] ist_2_rs_valid;
    reg [(IST_ADDR_WIDTH * (COMPLETE_EX + NEW_INSTRUCTION))-1:0] ist_2_rs_inst_num; // SRAM Request
    always @(*) begin
        ready_vector = 0;

        ready_entries_num = 0;

        for (ready_position_check = 0; ready_position_check < COMPLETE_EX; ready_position_check = ready_position_check + 1) begin
            opreands_ready_after[target_opreand] = opreands_ready_before[target_opreand];
            for (opreand_position = 0; opreand_position < OPREANDS; opreand_position = opreand_position + 1) begin
                // 현재 IST의 Ready Vector 추출
                ready_vector[opreand_position] = opreands_ready_before[opreand_position][ready_position_check];
                
                // Ready Update
                if ( inst_opreands [( (ready_position_check * (NUM_OF_PHY_REGS * OPREANDS)) + (opreand_position * NUM_OF_PHY_REGS) ) +: NUM_OF_PHY_REGS] 
                     == ready_phyreg_i[(ready_position_check * PHYREG_ADDR_WIDTH) +: PHYREG_ADDR_WIDTH] )
                begin
                    opreands_ready_after[opreand_position][ready_position_check] = 1'b1;
                    ready_vector[opreand_position] = 1'b1; // 현재 Ready Vector 반영
                end
            end

            // 모두 준비 되었다면 RS로 전달하기 위한 SRAM 접근 부분에 전달
            if (&ready_vector) begin
                ist_2_rs_valid[ready_entries_num] = 1'b1;
                ist_2_rs_inst[(ready_entries_num * IST_ADDR_WIDTH) +: IST_ADDR_WIDTH] = (IST 필드 주소);

                ready_entries_num = ready_entries_num + 1;
            end
        end
    end

endmodule
