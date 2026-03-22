// 최초 구현은 Register File 기반 Entry 이용
module ist_rf #( // Instruction State Table
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

    input [NEW_INSTRUCTION-1:0] allocate_ist_entry_i,
    output [NEW_INSTRUCTION-1:0] allocate_ist_entry_valid_o,
    output [(NEW_INSTRUCTION * IST_ENTRIES)-1:0] allocate_ist_entry_number_o,

    input [DONE_INSTRUCTION-1:0] unallocate_ist_entry_valid_i,
    input [(DONE_INSTRUCTION * IST_ENTRIES)-1:0] unallocate_ist_entry_number_i,

    input [NEW_INSTRUCTION-1:0] new_inst_valid_i,
    input [(NEW_INSTRUCTION * IST_ENTRY_WIDTH)-1:0]  ,
    input [(NEW_INSTRUCTION * OPREANDS)-1:0] new_inst_opr_ready_i,

    input [(COMPLETE_EX * PHYREG_ADDR_WIDTH)-1:0] ready_phyreg_i,
    input [(COMPLETE_EX * IST_ADDR_WIDTH)-1:0] ready_ist_entrites_i,

    output active
);

    wire [NEW_INSTRUCTION-1:0] allocate_ist_entry_valid;
    wire [(NEW_INSTRUCTION * IST_ENTRIES)-1:0] allocate_ist_entry_number;
    assign allocate_ist_entry_valid_o   = allocate_ist_entry_valid;
    assign allocate_ist_entry_number_o  = allocate_ist_entry_number;

    wire [NEW_INSTRUCTION-1:0] create_ist_entry_valid;
    assign create_ist_entry_valid       = new_inst_valid_i & allocate_ist_entry_valid;

    allocator #(
    	.NUM_OF_ENTRIES (IST_ENTRIES),
        .UNALLOCATES    (DONE_INSTRUCTION),
        .ALLOCATES      (NEW_INSTRUCTION)
    ) U_IST_ENTRIES_ALLOCATOR (
        .clk                  (clk),
        .reset_n              (reset_n),
        .unallocate_valid_i   (unallocate_ist_entry_valid_i),
        .unallocate_entries_i (unallocate_ist_entry_number_i),
        .allocating_i         (allocate_ist_entry_i),
	    .allocate_valid_o     (allocate_ist_entry_valid),
        .allocate_entries_o   (allocate_ist_entry_number),
    	.init_done            (active)
    );

    // IST ENTRIES (This version is Register File)
    regfile #(
        .READ_CHANNEL    (COMPLETE_EX),
        .WRITE_CHANNEL   (NEW_INSTRUCTION),
        .ENTRIES         (IST_ENTRIES),
        .REG_WIDTH       (IST_ENTRY_WIDTH)
    ) U_ (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_write_wes         (create_ist_entry_valid),
        .i_write_addresses   (allocate_ist_entry_number),
        .i_write_data        (new_inst_i),
        .i_read_addresses    (),
        .o_read_data         ()
    );

    // Opreands
    reg []
    wire [(COMPLETE_EX * (NUM_OF_PHY_REGS * OPREANDS))-1:0] inst_opreands;
    regfile #(
        .READ_CHANNEL    (COMPLETE_EX),
        .WRITE_CHANNEL   (NEW_INSTRUCTION),
        .ENTRIES         (),
        .REG_WIDTH       (NUM_OF_PHY_REGS * OPREANDS)
    ) U_OPERANDS_LIST (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_addresses    (ready_ist_entrites_i),
        /* input       [WRITE_CHANNEL-1:0]                  */ .i_write_wes         (),
        /* input       [WRITE_CHANNEL*ENTRY_ADDR_WIDTH-1:0] */ .i_write_addresses   (),
        /* input       [WRITE_CHANNEL*REG_WIDTH-1:0]        */ .i_write_data        (),
        .o_read_data         (inst_opreands)
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
                .i_read_addresses    (ready_ist_entrites_i),
                /* input       [WRITE_CHANNEL-1:0]                  */ .i_write_wes         (),
                /* input       [WRITE_CHANNEL*ENTRY_ADDR_WIDTH-1:0] */ .i_write_addresses   (),
                .i_write_data        ( {opreands_ready_new[target_opreand], opreands_ready_after[target_opreand]} ),
                .o_read_data         (opreands_ready_before[target_opreand])
            );
        end
    endgenerate

    integer ready_position_check, opreand_position;
    reg [OPREANDS-1:0] ready_vector;
    reg [(COMPLETE_EX + NEW_INSTRUCTION)-1:0] ist_2_rs_valid;
    always @(*) begin
        ready_vector = 0;

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

            // 모두 준비 되었다면 RS로 전달하기 위한 SRAM 접근 부분에 유효 부분을 전달 - 는 나중에 합시다.. 먼저 RF로..
            if (&ready_vector) begin
                ist_2_rs_valid[ready_position_check] = 1'b1;
            end
        end
    end

endmodule
