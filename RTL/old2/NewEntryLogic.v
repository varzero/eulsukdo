module nel #( // New Entry Logic
    parameter INSTRUCTION_SIZE = 32,
    parameter NEW_INSTRUCTION = 4,
    parameter NUM_OF_WB_ENTRIES = 5,
	parameter NUM_OF_DESTROY_ENTRIES = 4,

	parameter IST_ENTRIES = 128,

    parameter PC_WIDTH = 32,
	parameter MICRO_OP_LENGHT = 5, // LSB 쪽으로 EX_SPECIFY_WIDTH 만큼은 EX 선택용
	parameter NUM_OF_PHY_REGS = 64,
	parameter NUM_OF_LOGICAL_REGS = 32,
	parameter OPREANDS = 2,

	localparam IST_ADDR_WIDTH = $clog2(IST_ENTRIES),
	localparam PHYREG_ADDR_WIDTH = $clog2(NUM_OF_PHY_REGS),
	localparam LOGREG_ADDR_WIDTH = $clog2(NUM_OF_LOGICAL_REGS),
    localparam IST_ENTRY_WIDTH = PC_WIDTH + MICRO_OP_LENGHT 
                                + NUM_OF_PHY_REGS + NUM_OF_LOGICAL_REGS 
                                + (NUM_OF_PHY_REGS * OPREANDS)
) (
    input clk,
    input reset_n,

	// Allocate PHYREG
    input prm_active_i,
	output [NEW_INSTRUCTION-1:0] allocate_phyreg_get_o,
	input [NEW_INSTRUCTION-1:0] allocate_phyreg_valid_i,
	input [(NEW_INSTRUCTION * PHYREG_ADDR_WIDTH)-1:0] allocate_phyregs_i,

	// Unallocate PHYREG
	input [NUM_OF_DESTROY_ENTRIES-1:0] unallocate_phyreg_valid_i,
	input [(NUM_OF_DESTROY_ENTRIES * PHYREG_ADDR_WIDTH)-1:0] unallocate_phyregs_i,

	// Allocate IST
    input ist_active_i,
    output [NEW_INSTRUCTION-1:0] allocate_ist_entry_o,
    input [NEW_INSTRUCTION-1:0] allocate_ist_entry_valid_i,
    input [(NEW_INSTRUCTION * IST_ENTRIES)-1:0] allocate_ist_entry_number_i,

	// Write Back PHY Registers NUMBERS
	input [NUM_OF_WB_ENTRIES-1:0] wb_done_valid_i,
	input [(NUM_OF_WB_ENTRIES * PHYREG_ADDR_WIDTH)-1:0] wb_done_phyreg_i,

    // Create New Instruction
    output [(NEW_INSTRUCTION * IST_ENTRY_WIDTH)-1:0] new_inst_field_o,
    output [(NEW_INSTRUCTION * OPREANDS)-1:0] new_inst_opr_ready_o
);

    // 사이에 디코더 끼우기 (예시로 RV32I 넣어두기)

    // instruction 마다 Logic Reg 추출해서 PhyREG에 연결하고, 새 Register도 연결하기
    regfile #(
        .READ_CHANNEL    (NEW_INSTRUCTION * OPREANDS),
        .WRITE_CHANNEL   (NUM_OF_DESTROY_ENTRIES + NEW_INSTRUCTION), // 지울거는 0으로 변경, 새거는 할당된 REG로 변경
        .ENTRIES         (NUM_OF_LOGICAL_REGS),
        .REG_WIDTH       (PHYREG_ADDR_WIDTH)
    ) U_LOGICREG_PHYREG_MAPPING_RF ( // 주소는 logic Reg, 엔트리는 PHYREG (0이면 unvalid)
        .clk                 (clk),
        .reset_n             (reset_n),
        /*input       [READ_CHANNEL*ENTRY_ADDR_WIDTH-1:0]  */   .i_read_addresses    (),
        /*input       [WRITE_CHANNEL-1:0]                  */   .i_write_wes         (),
        /*input       [WRITE_CHANNEL*ENTRY_ADDR_WIDTH-1:0] */   .i_write_addresses   (),
        /*input       [WRITE_CHANNEL*REG_WIDTH-1:0]        */   .i_write_data        (),
        /*output reg  [READ_CHANNEL*REG_WIDTH-1:0]         */   .o_read_data         ()
    );

    // 할당된 PHYREG의 준비여부 저장: Instruction의 Opreand들이 준비되었으면 바로 준비 띄우기 
    regfile #(
        .READ_CHANNEL    (NEW_INSTRUCTION * OPREANDS),
        .WRITE_CHANNEL   (NUM_OF_WB_ENTRIES + NEW_INSTRUCTION), // 새거는 초기화. WB는 업데이트
        .ENTRIES         (NUM_OF_PHY_REGS),
        .REG_WIDTH       (1)
    ) U_PHYREG_READY_RF ( // 주소는 PHYREG, 엔트리는 {READY}
        .clk                 (clk),
        .reset_n             (reset_n),
        /*input       [READ_CHANNEL*ENTRY_ADDR_WIDTH-1:0]  */   .i_read_addresses    (),
        /*input       [WRITE_CHANNEL-1:0]                  */   .i_write_wes         (),
        /*input       [WRITE_CHANNEL*ENTRY_ADDR_WIDTH-1:0] */   .i_write_addresses   (),
        /*input       [WRITE_CHANNEL*REG_WIDTH-1:0]        */   .i_write_data        (),
        /*output reg  [READ_CHANNEL*REG_WIDTH-1:0]         */   .o_read_data         ()
    );

endmodule

module nel_update_block #(
    
) ();
// After Decoding.. IST Format input

endmodule
