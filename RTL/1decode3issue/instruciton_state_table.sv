`timescale 1ns / 1ps

`include "../memories.sv"
`include "../position_splitter.sv"

module instruction_state_table #(
    // Dynamic Schedular Description
    parameter DECODE_NEW_INST   = 1,
    parameter PHYREG_NUM        = 64,
    parameter IST_ENTRY_NUM     = 128,
    parameter EX_PATH_NUM       = 3,
    parameter PRM_ENTRY_BUFFER  = 4,
    parameter PRM_ENTRY_UPDATE  = 3,
    parameter RS_ENTRY_NUM      = 16,

    // Instruction Field Description
    parameter INST_PC_WIDTH                 = 32,
    parameter INST_BITWIDTH                 = 32,
    parameter INST_OPCODE_WIDTH             = 7,
    parameter INST_OPTIONAL_OPCODE_WIDTH    = 10,
    parameter INST_IMM_WIDTH                = 32,
    parameter INST_NUM_OF_LOGICAL_REGISTER  = 32,
    parameter INST_OPREANDS                 = 2,

    // Internal Field Description (Decoder Compiler (or Human) Generate)
    parameter MICROOP_WIDTH                 = 7, // Micro-OP is not contained information of EX_PATH

    // (Autogenerate) Elements
    localparam BITWIDTH_EX_PATH_NUM                     = $clog2(EX_PATH_NUM),
    localparam BITWIDTH_PHYREG_NUM                      = $clog2(PHYREG_NUM),
    localparam BITWIDTH_IST_ENTRY_NUM                   = $clog2(IST_ENTRY_NUM),
    localparam BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER    = $clog2(INST_NUM_OF_LOGICAL_REGISTER),
    
    localparam RS_PUSH_WIDTH     = PRM_ENTRY_UPDATE + DECODE_NEW_INST,

    // (Autogenerate) Field of Entry in Instruction State Table
        /* Entry: MSB [ ( Opreand Reday_n, ... , Opreand Reday_1 ) | 
                        ( Opreand Rename Register_n, ... , Opreand Rename Register_1 ) | 
                        Destination Rename Register | 
                        IMM | PC | Micro-OP | EX_PATH ] LSB */    
    localparam IST_BITWIDTH_OPREAND_PHYREG_FULL = BITWIDTH_PHYREG_NUM * INST_OPREANDS,
    localparam IST_BITWIDTH_OPREAND_READY_FULL  = INST_OPREANDS,
    localparam IST_BITWIDTH = INST_PC_WIDTH + BITWIDTH_EX_PATH_NUM + MICROOP_WIDTH + INST_IMM_WIDTH + BITWIDTH_PHYREG_NUM
                              + IST_BITWIDTH_OPREAND_PHYREG_FULL + IST_BITWIDTH_OPREAND_READY_FULL,

    localparam IST_STARTPOINT_PHYREG            = INST_PC_WIDTH + BITWIDTH_EX_PATH_NUM + MICROOP_WIDTH + INST_IMM_WIDTH,
    localparam IST_STARTPOINT_OPREAND_PHYREG    = IST_STARTPOINT_PHYREG + BITWIDTH_PHYREG_NUM,
    localparam IST_STARTPOINT_OPREAND_READY     = IST_STARTPOINT_OPREAND_PHYREG + IST_BITWIDTH_OPREAND_PHYREG_FULL,

    localparam IST_PACKET_BITWIDTH              = IST_BITWIDTH * DECODE_NEW_INST,

    // (Autogenerate) Ready Station Entry
    localparam RS_ENTRY_BITWIDTH            = INST_PC_WIDTH + BITWIDTH_EX_PATH_NUM + MICROOP_WIDTH + INST_IMM_WIDTH 
                                                + BITWIDTH_PHYREG_NUM + IST_BITWIDTH_OPREAND_PHYREG_FULL,
) (
    input                                                                      clk,
    input                                                                      reset_n,

    // Create IST Field
        // <- Instruction State Table Update
    output wire                                                                o_ist_insert_available,
    input  wire [DECODE_NEW_INST-1:0]                                          i_ist_field_insert,
    output wire [DECODE_NEW_INST-1:0]                                          o_ist_field_valid,
    input  wire [IST_PACKET_BITWIDTH-1:0]                                      i_ist_field,

        // <- Physical Register Manager Opreands Update
    output reg  [(DECODE_NEW_INST*INST_OPREANDS)-1:0]                          o_prm_istindex_valid,
    output reg  [(BITWIDTH_PHYREG_NUM*(DECODE_NEW_INST*INST_OPREANDS))-1:0]    o_prm_istindex_phyreg,
    output reg  [(BITWIDTH_IST_ENTRY_NUM*(DECODE_NEW_INST*INST_OPREANDS))-1:0] o_prm_istindex_istidx,

    // Update Ready Field
        // -> Physical Register Manager Opreands POP
    input  wire [(PRM_ENTRY_UPDATE)-1:0]                                       i_ready_update_valid,
    output wire [(PRM_ENTRY_UPDATE)-1:0]                                       o_ready_update_get,
    input  wire [(BITWIDTH_PHYREG_NUM*PRM_ENTRY_UPDATE)-1:0]                   i_ready_update_phyreg,
    input  wire [(BITWIDTH_IST_ENTRY_NUM*PRM_ENTRY_UPDATE)-1:0]                i_ready_update_istidx,

    // Output Ready Station
        // <- Ready Station Create Entry
    input  wire                                                                i_push_rs_available,
    output reg  [(RS_PUSH_WIDTH)-1:0]                                          o_push_rs_valid,
    output wire [(RS_PUSH_WIDTH*RS_ENTRY_BITWIDTH)-1:0]                        o_push_rs_data

    // 추후에 여기에 분기 예측 실패에서 IST 엔트리 지우는 부분 추가하기
);
    assign o_ready_update_get = (i_push_rs_available)? {PRM_ENTRY_UPDATE{1'b1}} : {PRM_ENTRY_UPDATE{1'b0}};

    wire [(DECODE_NEW_INST*2)-1:0]             new_ist_valid;
    wire [(IST_ENTRY_NUM*DECODE_NEW_INST)-1:0] new_ist_num;
    assign o_ist_field_valid = new_ist_valid[DECODE_NEW_INST-1:0];

    // Internal wires
    reg [RS_ENTRY_BITWIDTH-1:0]                                  ist_entries_split [0:DECODE_NEW_INST-1];
    reg [(RS_ENTRY_BITWIDTH*DECODE_NEW_INST)-1:0]                ist_entries_spread;
    reg [IST_BITWIDTH_OPREAND_PHYREG_FULL-1:0]                   ist_opreands_split[0:DECODE_NEW_INST-1];
    reg [(IST_BITWIDTH_OPREAND_PHYREG_FULL*DECODE_NEW_INST)-1:0] ist_opreands_spread;
    reg [IST_BITWIDTH_OPREAND_READY_FULL-1:0]                    ist_readys_split  [0:DECODE_NEW_INST-1];
    reg [(IST_BITWIDTH_OPREAND_READY_FULL*DECODE_NEW_INST)-1:0]  ist_readys_spread;
    always @(*) begin
        o_push_rs_valid[DECODE_NEW_INST-1:0] = 0;

        for (integer new_entry = 0; new_entry < DECODE_NEW_INST; new_entry = new_entry+1) begin
            ist_entries_split[new_entry]                                           
                = i_ist_field[(IST_BITWIDTH*new_entry) +: RS_ENTRY_BITWIDTH];
            ist_entries_spread[(RS_ENTRY_BITWIDTH*new_entry) +: RS_ENTRY_BITWIDTH] 
                = i_ist_field[(IST_BITWIDTH*new_entry) +: RS_ENTRY_BITWIDTH];

            ist_opreands_split[new_entry] 
                = i_ist_field[((IST_BITWIDTH*new_entry)+IST_STARTPOINT_OPREAND_PHYREG) +: IST_BITWIDTH_OPREAND_PHYREG_FULL];
            ist_opreands_spread[(IST_BITWIDTH_OPREAND_PHYREG_FULL*new_entry) +: IST_BITWIDTH_OPREAND_PHYREG_FULL]
                = i_ist_field[((IST_BITWIDTH*new_entry)+IST_STARTPOINT_OPREAND_PHYREG) +: IST_BITWIDTH_OPREAND_PHYREG_FULL];

            ist_readys_split[new_entry]
                = i_ist_field[((IST_BITWIDTH*new_entry)+IST_STARTPOINT_OPREAND_READY) +: IST_BITWIDTH_OPREAND_READY_FULL];
            ist_readys_spread[(IST_BITWIDTH_OPREAND_READY_FULL*new_entry) +: IST_BITWIDTH_OPREAND_READY_FULL]
                = i_ist_field[((IST_BITWIDTH*new_entry)+IST_STARTPOINT_OPREAND_READY) +: IST_BITWIDTH_OPREAND_READY_FULL];
            if (&ist_readys_split[new_entry] && i_push_rs_available) o_push_rs_valid[new_entry] = 1'b1;

            for (integer new_opr_sel = 0; new_opr_sel < INST_OPREANDS; new_opr_sel = new_opr_sel+1) begin
                if (ist_readys_split[new_entry][new_opr_sel]) begin
                    o_prm_istindex_valid[((INST_OPREANDS*new_entry)+new_opr_sel)] = 1'b0;
                end
                else begin
                    o_prm_istindex_valid[((INST_OPREANDS*new_entry)+new_opr_sel)]
                        = i_ist_field_insert[((INST_OPREANDS*new_entry)+new_opr_sel)] & o_ist_field_valid[((INST_OPREANDS*new_entry)+new_opr_sel)];
                end
                o_prm_istindex_phyreg[( BITWIDTH_PHYREG_NUM*((INST_OPREANDS*new_entry)+new_opr_sel) ) +: BITWIDTH_PHYREG_NUM]
                    = ist_opreands_split[new_entry][(BITWIDTH_PHYREG_NUM*new_opr_sel) +: BITWIDTH_PHYREG_NUM];
                o_prm_istindex_istidx[( BITWIDTH_IST_ENTRY_NUM*((INST_OPREANDS*new_entry)+new_opr_sel) ) +: BITWIDTH_IST_ENTRY_NUM]
                    = new_ist_num[ (IST_ENTRY_NUM*new_entry) +: IST_ENTRY_NUM];
            end
        end
    end
    assign o_push_rs_data[(DECODE_NEW_INST*RS_ENTRY_BITWIDTH)-1:0] = ist_entries_spread;

    reg  [BITWIDTH_PHYREG_NUM-1:0]                                 comp_target_opreands_split[0:PRM_ENTRY_UPDATE-1];
    always @(*) begin
        for (integer comp_target_opr = 0; comp_target_opr < PRM_ENTRY_UPDATE; comp_target_opr = comp_target_opr+1) begin
            comp_target_opreands_split[comp_target_opr]
                = i_ready_update_phyreg[(BITWIDTH_PHYREG_NUM*comp_target_opr) +: BITWIDTH_PHYREG_NUM];
        end
    end

    wire [(PRM_ENTRY_UPDATE*IST_BITWIDTH_OPREAND_PHYREG_FULL)-1:0] done_opreands;
    reg  [BITWIDTH_PHYREG_NUM-1:0]                                 done_opreands_split[0:PRM_ENTRY_UPDATE-1][0:INST_OPREANDS-1];
    always @(*) begin
        for (integer done_entries = 0; done_entries < PRM_ENTRY_UPDATE; done_entries = done_entries+1) begin
            for (integer opreand_sel = 0; opreand_sel < INST_OPREANDS; opreand_sel = opreand_sel+1) begin
                done_opreands_split[done_entries][opreand_sel]
                    = done_opreands[((IST_BITWIDTH_OPREAND_PHYREG_FULL*done_entries)+(BITWIDTH_PHYREG_NUM*opreand_sel)) +: BITWIDTH_PHYREG_NUM];
            end
        end
    end

    wire [(PRM_ENTRY_UPDATE*IST_BITWIDTH_OPREAND_READY_FULL)-1:0] done_readys[0:PRM_ENTRY_UPDATE-1];
    reg  [IST_BITWIDTH_OPREAND_READY_FULL-1:0]                    done_readys_update[0:PRM_ENTRY_UPDATE-1];
    always @(*) begin
        o_push_rs_valid[PRM_ENTRY_UPDATE+DECODE_NEW_INST-1:DECODE_NEW_INST] = 0;

        for (integer comp_opr = 0; comp_opr < PRM_ENTRY_UPDATE; comp_opr = comp_opr+1) begin
            for (integer opr_sel = 0; opr_sel < INST_OPREANDS; opr_sel = opr_sel+1) begin
                if (done_opreands_split[comp_opr][opr_sel] == comp_target_opreands_split[comp_opr])
                    done_readys_update[comp_opr][opr_sel] = 1'b1;
                else 
                    done_readys_update[comp_opr][opr_sel] = 1'b0;
            end
            done_readys_update[comp_opr] = done_readys_update[comp_opr] | done_readys[comp_opr];

            if (&done_readys_update && i_push_rs_available) begin
                o_push_rs_valid[comp_opr+DECODE_NEW_INST] = 1'b1;
            end
        end
    end

    // Allocate IST Entry
    allocator #(
    	.NUM_OF_ENTRIES (IST_ENTRY_NUM),
        .UNALLOCATES    (RS_PUSH_WIDTH),
        .ALLOCATES      (DECODE_NEW_INST*2)
    ) U_ALLOCATE_IST_ENTRY (
        .clk                    (clk),
        .reset_n                (reset_n),
        .unallocate_valid_i     (o_push_rs_valid),
        .unallocate_entries_i   (i_ready_update_istidx),
        .allocating_i           ({ {DECODE_NEW_INST{1'b0}}, i_ist_field_insert }),
    	.allocate_valid_o       (new_ist_valid),
        .allocate_entries_o     (new_ist_num),
    	.init_done              (o_ist_insert_available)
    );
 
        // IST Entry 
    regfile #(
        .READ_CHANNEL    (PRM_ENTRY_UPDATE),
        .WRITE_CHANNEL   (DECODE_NEW_INST),
        .ENTRIES         (RS_ENTRY_BITWIDTH),
        .REG_WIDTH       (IST_ENTRY_NUM)
    ) U_IST_ENTRIES (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_addresses    (i_ready_update_istidx),
        .i_write_wes         (i_ist_field_insert & new_ist_valid[DECODE_NEW_INST-1:0]),
        .i_write_addresses   (new_ist_num),
        .i_write_data        (ist_entries_spread),
        .o_read_data         (o_push_rs_data[(DECODE_NEW_INST*RS_ENTRY_BITWIDTH) +: (PRM_ENTRY_UPDATE*RS_ENTRY_BITWIDTH)])
    );
    
        // IST Opreands
    regfile #(
        .READ_CHANNEL    (PRM_ENTRY_UPDATE),
        .WRITE_CHANNEL   (DECODE_NEW_INST),
        .ENTRIES         (IST_BITWIDTH_OPREAND_PHYREG_FULL),
        .REG_WIDTH       (IST_ENTRY_NUM)
    ) U_IST_OPREANDS (
        .clk                 (clk),
        .reset_n             (reset_n),
        .i_read_addresses    (i_ready_update_istidx),
        .i_write_wes         (i_ist_field_insert & new_ist_valid[DECODE_NEW_INST-1:0]),
        .i_write_addresses   (new_ist_num),
        .i_write_data        (ist_opreands_spread),
        .o_read_data         (done_opreands)
    );

    genvar target_ready;
    generate
        for (target_ready = 0; target_ready < INST_OPREANDS; target_ready = target_ready+1) begin
                // IST Readys
            regfile #(
                .READ_CHANNEL    (PRM_ENTRY_UPDATE),
                .WRITE_CHANNEL   (PRM_ENTRY_UPDATE+DECODE_NEW_INST),
                .ENTRIES         (1),
                .REG_WIDTH       (IST_ENTRY_NUM)
            ) U_IST_READY (
                .clk                 (clk),
                .reset_n             (reset_n),
                .i_read_addresses    (i_ready_update_istidx),
                .i_write_wes         ({ {PRM_ENTRY_UPDATE{1'b1}} , i_ist_field_insert & new_ist_valid[target_ready]}),
                .i_write_addresses   ({i_ready_update_istidx, new_ist_num}),
                .i_write_data        ({done_readys_update[target_ready], ist_readys_spread}),
                .o_read_data         (done_readys[target_ready])
            );
        end
    endgenerate

endmodule
