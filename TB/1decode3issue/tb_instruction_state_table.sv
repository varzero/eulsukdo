module tb_instruction_state_table ();

    // Dynamic Schedular Description
    parameter DECODE_NEW_INST   = 1;
    parameter PHYREG_NUM        = 64;
    parameter IST_ENTRY_NUM     = 128;
    parameter EX_PATH_NUM       = 3;
    parameter PRM_ENTRY_BUFFER  = 4;
    parameter PRM_ENTRY_UPDATE  = 3;
    parameter RS_ENTRY_NUM      = 16;
    parameter FCL_RB_NUM        = 8;

    // Instruction Field Description
    parameter INST_PC_WIDTH                 = 32;
    parameter INST_BITWIDTH                 = 32;
    parameter INST_OPCODE_WIDTH             = 7;
    parameter INST_OPTIONAL_OPCODE_WIDTH    = 10;
    parameter INST_IMM_WIDTH                = 32;
    parameter INST_NUM_OF_LOGICAL_REGISTER  = 32;
    parameter INST_OPREANDS                 = 2;

    // Internal Field Description (Decoder Compiler (or Human) Generate)
    parameter MICROOP_WIDTH                 = 7; // Micro-OP is not contained information of EX_PATH

    // (Autogenerate) Elements
    localparam BITWIDTH_EX_PATH_NUM                     = $clog2(EX_PATH_NUM);
    localparam BITWIDTH_PHYREG_NUM                      = $clog2(PHYREG_NUM);
    localparam BITWIDTH_IST_ENTRY_NUM                   = $clog2(IST_ENTRY_NUM);
    localparam BITWIDTH_INST_NUM_OF_LOGICAL_REGISTER    = $clog2(INST_NUM_OF_LOGICAL_REGISTER);
    localparam BITWIDTH_FCL_RB_NUM                      = $clog2(FCL_RB_NUM);
    localparam BITWIDTH_FCL_PC_WIDTH                    = BITWIDTH_FCL_RB_NUM + INST_PC_WIDTH;
    
    localparam RS_PUSH_WIDTH     = PRM_ENTRY_UPDATE + DECODE_NEW_INST;

    // (Autogenerate) Field of Entry in Instruction State Table
        /* Entry: MSB [ ( Opreand Reday_n, ... , Opreand Reday_1 ) | 
                        ( Opreand Rename Register_n, ... , Opreand Rename Register_1 ) | 
                        Destination Rename Register | 
                        IMM | PC | Micro-OP | EX_PATH ] LSB */    
    localparam IST_BITWIDTH_OPREAND_PHYREG_FULL = BITWIDTH_PHYREG_NUM * INST_OPREANDS;
    localparam IST_BITWIDTH_OPREAND_READY_FULL  = INST_OPREANDS;
    localparam IST_BITWIDTH = BITWIDTH_FCL_PC_WIDTH + BITWIDTH_EX_PATH_NUM + MICROOP_WIDTH + INST_IMM_WIDTH + BITWIDTH_PHYREG_NUM
                              + IST_BITWIDTH_OPREAND_PHYREG_FULL + IST_BITWIDTH_OPREAND_READY_FULL;

    localparam IST_STARTPOINT_PHYREG            = BITWIDTH_FCL_PC_WIDTH + BITWIDTH_EX_PATH_NUM + MICROOP_WIDTH + INST_IMM_WIDTH;
    localparam IST_STARTPOINT_OPREAND_PHYREG    = IST_STARTPOINT_PHYREG + BITWIDTH_PHYREG_NUM;
    localparam IST_STARTPOINT_OPREAND_READY     = IST_STARTPOINT_OPREAND_PHYREG + IST_BITWIDTH_OPREAND_PHYREG_FULL;

    localparam IST_PACKET_BITWIDTH              = IST_BITWIDTH * DECODE_NEW_INST;

    // (Autogenerate) Ready Station Entry
    localparam RS_ENTRY_BITWIDTH            = BITWIDTH_FCL_PC_WIDTH + BITWIDTH_EX_PATH_NUM + MICROOP_WIDTH + INST_IMM_WIDTH 
                                                + BITWIDTH_PHYREG_NUM + IST_BITWIDTH_OPREAND_PHYREG_FULL;
                                                
    reg                                                                 clk;
    reg                                                                 reset_n;
    wire                                                                o_ist_insert_available;
    reg  [DECODE_NEW_INST-1:0]                                          i_ist_field_insert;
    wire [DECODE_NEW_INST-1:0]                                          o_ist_field_valid;
    reg  [IST_PACKET_BITWIDTH-1:0]                                      i_ist_field;
    wire [(DECODE_NEW_INST*INST_OPREANDS)-1:0]                          o_prm_istindex_valid;
    wire [(BITWIDTH_PHYREG_NUM*(DECODE_NEW_INST*INST_OPREANDS))-1:0]    o_prm_istindex_phyreg;
    wire [(BITWIDTH_IST_ENTRY_NUM*(DECODE_NEW_INST*INST_OPREANDS))-1:0] o_prm_istindex_istidx;
    reg  [(PRM_ENTRY_UPDATE)-1:0]                                       i_ready_update_valid;
    wire [(PRM_ENTRY_UPDATE)-1:0]                                       o_ready_update_get;
    reg  [(BITWIDTH_PHYREG_NUM*PRM_ENTRY_UPDATE)-1:0]                   i_ready_update_phyreg;
    reg  [(BITWIDTH_IST_ENTRY_NUM*PRM_ENTRY_UPDATE)-1:0]                i_ready_update_istidx;
    reg                                                                 i_push_rs_available;
    wire [(RS_PUSH_WIDTH)-1:0]                                          o_push_rs_valid;
    wire [(RS_PUSH_WIDTH*RS_ENTRY_BITWIDTH)-1:0]                        o_push_rs_data;

    int                                         ist_entry_cnt; 
    reg  [IST_BITWIDTH-1:0]                     ist_entry_data [0:IST_ENTRY_NUM-1];
    reg  [BITWIDTH_PHYREG_NUM-1:0]              ist_entry_rs   [0:IST_ENTRY_NUM-1][0:INST_OPREANDS-1];
    reg  [IST_BITWIDTH_OPREAND_READY_FULL-1:0]  ist_entry_ready[0:IST_ENTRY_NUM-1];

    int                                         phyreg_ist_cnt [0:PHYREG_NUM-1]; 
    reg  [BITWIDTH_IST_ENTRY_NUM-1:0]           phyreg_ist_data[0:PHYREG_NUM-1][$]; 

    instruction_state_table #(
        .DECODE_NEW_INST               (DECODE_NEW_INST),
        .PHYREG_NUM                    (PHYREG_NUM),
        .IST_ENTRY_NUM                 (IST_ENTRY_NUM),
        .EX_PATH_NUM                   (EX_PATH_NUM),
        .PRM_ENTRY_BUFFER              (PRM_ENTRY_BUFFER),
        .PRM_ENTRY_UPDATE              (PRM_ENTRY_UPDATE),
        .RS_ENTRY_NUM                  (RS_ENTRY_NUM),
        .FCL_RB_NUM                    (FCL_RB_NUM),
        .INST_PC_WIDTH                 (INST_PC_WIDTH),
        .INST_BITWIDTH                 (INST_BITWIDTH),
        .INST_OPCODE_WIDTH             (INST_OPCODE_WIDTH),
        .INST_OPTIONAL_OPCODE_WIDTH    (INST_OPTIONAL_OPCODE_WIDTH),
        .INST_IMM_WIDTH                (INST_IMM_WIDTH),
        .INST_NUM_OF_LOGICAL_REGISTER  (INST_NUM_OF_LOGICAL_REGISTER),
        .INST_OPREANDS                 (INST_OPREANDS),
        .MICROOP_WIDTH                 (MICROOP_WIDTH)
    ) dut (
        .clk                           (clk),
        .reset_n                       (reset_n),
        .o_ist_insert_available        (o_ist_insert_available),
        .i_ist_field_insert            (i_ist_field_insert),
        .o_ist_field_valid             (o_ist_field_valid),
        .i_ist_field                   (i_ist_field),
        .o_prm_istindex_valid          (o_prm_istindex_valid),
        .o_prm_istindex_phyreg         (o_prm_istindex_phyreg),
        .o_prm_istindex_istidx         (o_prm_istindex_istidx),
        .i_ready_update_valid          (i_ready_update_valid),
        .o_ready_update_get            (o_ready_update_get),
        .i_ready_update_phyreg         (i_ready_update_phyreg),
        .i_ready_update_istidx         (i_ready_update_istidx),
        .i_push_rs_available           (i_push_rs_available),
        .o_push_rs_valid               (o_push_rs_valid),
        .o_push_rs_data                (o_push_rs_data)
    );

    always #5 clk = ~clk;

    task insert_entry;
        bit [RS_PUSH_WIDTH-1:0]                    push_valid;
        bit [INST_PC_WIDTH-1:0]                    pc;
        bit [BITWIDTH_FCL_RB_NUM-1:0]              fclpath;
        bit [BITWIDTH_EX_PATH_NUM-1:0]             expath;
        bit [MICROOP_WIDTH-1:0]                    microop;
        bit [INST_IMM_WIDTH-1:0]                   imm;
        bit [BITWIDTH_PHYREG_NUM-1:0]              rd;
        bit [IST_BITWIDTH_OPREAND_PHYREG_FULL-1:0] rs;
        bit [IST_BITWIDTH_OPREAND_READY_FULL-1:0]  ready;
        int expath_idx;

        i_ist_field_insert = 0;
        for (int nel_push_idx = 0; nel_push_idx < DECODE_NEW_INST; nel_push_idx++) begin
            if ($urandom % 2) begin
                i_ist_field_insert[nel_push_idx] = 1'b1;
                pc      = $urandom;
                fclpath = $urandom;
                expath  = $urandom % EX_PATH_NUM;
                microop = $urandom;
                imm     = $urandom;
                rd      = $urandom % PHYREG_NUM;
                for (int rs_idx = 0; rs_idx < INST_OPREANDS; rs_idx++) begin
                    rs[(BITWIDTH_PHYREG_NUM*rs_idx) +: BITWIDTH_PHYREG_NUM] = $urandom % PHYREG_NUM;
                end
                ready   = $urandom % (2 ** IST_BITWIDTH_OPREAND_READY_FULL);

                i_ist_field[(IST_BITWIDTH*nel_push_idx) +: IST_BITWIDTH] 
                    = {ready, rs, rd, imm, microop, expath, fclpath, pc};

                ist_entry_data[ist_entry_cnt]  = i_ist_field[RS_ENTRY_BITWIDTH-1:0];
                ist_entry_ready[ist_entry_cnt] = ready;
                for (int rs_idx = 0; rs_idx < INST_OPREANDS; rs_idx++) begin
                    ist_entry_rs[ist_entry_cnt][rs_idx] = rs[(BITWIDTH_PHYREG_NUM*rs_idx) +: BITWIDTH_PHYREG_NUM];
                end
                ist_entry_cnt = (ist_entry_cnt == (IST_ENTRY_NUM-1))? 0 : ist_entry_cnt+1;

                // Two Opreand output
                $display(" [%t] PUSH IST ENTRY: %h (expath: %d / rd: r%d / rs: r%d(%b), r%d(%b) )",
                            $time, i_ist_field[(IST_BITWIDTH*nel_push_idx) +: IST_BITWIDTH] ,
                            expath, rd, 
                            rs[BITWIDTH_PHYREG_NUM-1:0], ready[0],
                            rs[IST_BITWIDTH_OPREAND_PHYREG_FULL-1:BITWIDTH_PHYREG_NUM], ready[1]);
            end
        end
        #1;

    endtask

    task prm_insert;

    endtask;

    task prm_output_sim;
    endtask;

    initial begin
        #0;
        clk = 1'b0; reset_n = 1'b0;
        i_ist_field_insert = 0;
        i_ist_field = 0;
        i_ready_update_valid = 0;
        i_ready_update_phyreg = 0;
        i_ready_update_istidx = 0;
        i_push_rs_available = 0;

        ist_entry_cnt = 0;

        @(negedge clk);
        @(negedge clk);
        reset_n = 1'b1;
        @(negedge clk);
        wait(o_ist_insert_available);
        i_push_rs_available = 1'b1;
        @(negedge clk);
        @(negedge clk);
            
        repeat(100) begin
            insert_entry();
            @(negedge clk);
        end
        @(negedge clk);

        $finish;
    end

endmodule