module tb_eulsukdo_1dec_3issue ();

    // Dynamic Schedular Description
    parameter DECODE_NEW_INST   = 1;
    parameter PHYREG_NUM        = 64;
    parameter IST_ENTRY_NUM     = 128;
    parameter EX_PATH_NUM       = 3;
    parameter PRM_ENTRY_BUFFER  = 4;
    parameter PRM_ENTRY_UPDATE  = 3;
    parameter PRM_READY_OUT_FIFO_DEPTH = 32;
    parameter RS_ENTRY_NUM      = 16;
    parameter RS_PUSH_WIDTH     = 3;
    parameter FCL_RB_NUM        = 8; // test, default = 8
    parameter FCL_PC_GAP        = 4;
    parameter UNALLOCATE_PHYREG = 4;
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

    reg                                        clk;
    reg                                        reset_n;
    reg  [DECODE_NEW_INST-1:0]                 i_im_inst_valid;
    reg  [(DECODE_NEW_INST*INST_PC_WIDTH)-1:0] i_im_inst_pc;
    reg  [(DECODE_NEW_INST*INST_BITWIDTH)-1:0] i_im_inst;
    wire [DECODE_NEW_INST-1:0]                 o_im_inst_get;
    wire                                       o_im_re;
    wire [INST_PC_WIDTH-1:0]                   o_im_pc;

    eulsukdo_1dec_3issue #(
        .DECODE_NEW_INST               (DECODE_NEW_INST),
        .PHYREG_NUM                    (PHYREG_NUM),
        .IST_ENTRY_NUM                 (IST_ENTRY_NUM),
        .EX_PATH_NUM                   (EX_PATH_NUM),
        .PRM_ENTRY_BUFFER              (PRM_ENTRY_BUFFER),
        .PRM_ENTRY_UPDATE              (PRM_ENTRY_UPDATE),
        .PRM_READY_OUT_FIFO_DEPTH      (PRM_READY_OUT_FIFO_DEPTH),
        .RS_ENTRY_NUM                  (RS_ENTRY_NUM),
        .RS_PUSH_WIDTH                 (RS_PUSH_WIDTH),
        .FCL_RB_NUM                    (FCL_RB_NUM),
        .FCL_PC_GAP                    (FCL_PC_GAP),
        .UNALLOCATE_PHYREG             (UNALLOCATE_PHYREG),
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
        .i_im_inst_valid               (i_im_inst_valid),
        .i_im_inst_pc                  (i_im_inst_pc),
        .i_im_inst                     (i_im_inst),
        .o_im_inst_get                 (o_im_inst_get),
        .o_im_re                       (o_im_re),
        .o_im_pc                       (o_im_pc)
    );

    always #5 clk = ~clk;

    initial begin
        #0;
        clk = 1'b0; reset_n = 1'b0;
        i_im_inst_valid = 0;
        i_im_inst_pc    = 0;
        i_im_inst       = 0;

        @(negedge clk);
        @(negedge clk);
        reset_n = 1'b1;
        @(negedge clk);

        wait(o_im_re);
        @(negedge clk);
        
        i_im_inst_valid = 1'b1;
        i_im_inst_pc    = 32'h0001_2350;
        i_im_inst       = 32'h0000_03b3; // add x7, x0, x0
        @(negedge clk);
        i_im_inst_valid = 1'b1;
        i_im_inst_pc    = 32'h0001_2354;
        i_im_inst       = 32'h0000_0433; // add x8, x0, x0
        @(negedge clk);
        i_im_inst_valid = 1'b1;
        i_im_inst_pc    = 32'h0001_2358;
        i_im_inst       = 32'h0000_04b3; // add x9, x0, x0
        @(negedge clk);
        i_im_inst_valid = 1'b1;
        i_im_inst_pc    = 32'h0001_235C;
        i_im_inst       = 32'h0000_0533; // add x10, x0, x0
        @(negedge clk);
        i_im_inst_valid = 1'b1;
        i_im_inst_pc    = 32'h0001_2360;
        i_im_inst       = 32'h0023_80b3; // add x1, x7, x2
        @(negedge clk);
        i_im_inst_valid = 1'b1;
        i_im_inst_pc    = 32'h0001_2364;
        i_im_inst       = 32'h0084_80b3; // add x1, x9, x8
        @(negedge clk);
        i_im_inst_valid = 1'b1;
        i_im_inst_pc    = 32'h0001_2368;
        i_im_inst       = 32'h00a3_00b3; // add x1, x6, x10
        @(negedge clk);
        i_im_inst_valid = 1'b0;
        @(negedge clk);
        /*
        i_im_inst_valid = 1'b1;
        i_im_inst_pc    = 32'h0001_2350;
        i_im_inst       = 32'h0051_83b3; // add x7, x3, x5
        */
        @(negedge clk);@(negedge clk);
        
        @(negedge clk);


        $finish;
    end

endmodule