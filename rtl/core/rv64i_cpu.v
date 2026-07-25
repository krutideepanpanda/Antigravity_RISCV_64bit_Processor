// ============================================================================
// Top-Level 64-bit RISC-V CPU Core (RV64I 5-Stage Pipelined Architecture)
// Integrates IF, ID, EX, MEM, WB stages, Forwarding Unit, and Hazard Unit
// ============================================================================
`default_nettype none
`include "rv64i_types.vh"

module rv64i_cpu (
    input  wire        clk,
    input  wire        rst,
    // Instruction Memory Bus
    output wire [63:0] imem_addr,
    input  wire [31:0] imem_rdata,
    // Data Memory Bus
    output wire [63:0] dmem_addr,
    output wire [63:0] dmem_wdata,
    output wire        dmem_we,
    output wire        dmem_re,
    output wire [7:0]  dmem_be,
    input  wire [63:0] dmem_rdata
);

    // Hazard signals
    wire stall;
    wire if_id_flush;
    wire id_ex_flush;

    // IF stage outputs / IF-ID reg outputs
    wire [63:0] id_pc;
    wire [63:0] id_pc_plus4;
    wire [31:0] id_instr;

    // EX stage branch signals
    wire        branch_taken;
    wire [63:0] branch_target;

    // ID stage outputs / ID-EX reg outputs
    wire [63:0] ex_pc;
    wire [63:0] ex_pc_plus4;
    wire [63:0] ex_rs1_data;
    wire [63:0] ex_rs2_data;
    wire [63:0] ex_imm;
    wire [4:0]  ex_rs1_addr;
    wire [4:0]  ex_rs2_addr;
    wire [4:0]  ex_rd_addr;
    wire [2:0]  ex_funct3;
    wire        ex_reg_write;
    wire        ex_mem_to_reg;
    wire        ex_mem_write;
    wire        ex_mem_read;
    wire [3:0]  ex_alu_op;
    wire        ex_alu_src;
    wire        ex_branch;
    wire        ex_jump;
    wire        ex_word_op;
    wire [2:0]  ex_mem_width;

    // Forwarding unit signals
    wire [1:0] fwd_a_sel;
    wire [1:0] fwd_b_sel;

    // EX stage outputs / EX-MEM reg outputs
    wire [63:0] mem_alu_result;
    wire [63:0] mem_wdata;
    wire [4:0]  mem_rd_addr;
    wire        mem_reg_write;
    wire        mem_mem_to_reg;
    wire        mem_mem_write;
    wire        mem_mem_read;
    wire [2:0]  mem_mem_width;
    wire [63:0] mem_pc_plus4;
    wire        mem_jump;

    // MEM stage outputs / MEM-WB reg outputs
    wire [63:0] wb_alu_result;
    wire [63:0] wb_mem_rdata;
    wire [4:0]  wb_rd_addr;
    wire        wb_reg_write;
    wire        wb_mem_to_reg;
    wire [63:0] wb_pc_plus4;
    wire        wb_jump;

    // WB stage outputs
    wire [63:0] wb_rd_data;

    // ------------------------------------------------------------------------
    // Stage 1: Instruction Fetch (IF)
    // ------------------------------------------------------------------------
    rv64i_if u_if (
        .clk           (clk),
        .rst           (rst),
        .stall         (stall),
        .flush         (if_id_flush),
        .branch_taken  (branch_taken),
        .branch_target (branch_target),
        .imem_rdata    (imem_rdata),
        .imem_addr     (imem_addr),
        .id_pc         (id_pc),
        .id_pc_plus4   (id_pc_plus4),
        .id_instr      (id_instr)
    );

    // ------------------------------------------------------------------------
    // Hazard Detection Unit
    // ------------------------------------------------------------------------
    rv64i_hazard u_hazard (
        .id_rs1_addr   (id_instr[19:15]),
        .id_rs2_addr   (id_instr[24:20]),
        .ex_mem_read   (ex_mem_read),
        .ex_rd_addr    (ex_rd_addr),
        .branch_taken  (branch_taken),
        .stall         (stall),
        .if_id_flush   (if_id_flush),
        .id_ex_flush   (id_ex_flush)
    );

    // ------------------------------------------------------------------------
    // Stage 2: Instruction Decode (ID)
    // ------------------------------------------------------------------------
    rv64i_id u_id (
        .clk           (clk),
        .rst           (rst),
        .stall         (stall),
        .flush         (id_ex_flush),
        .id_pc         (id_pc),
        .id_pc_plus4   (id_pc_plus4),
        .id_instr      (id_instr),
        .wb_reg_write  (wb_reg_write),
        .wb_rd_addr    (wb_rd_addr),
        .wb_rd_data    (wb_rd_data),
        .ex_pc         (ex_pc),
        .ex_pc_plus4   (ex_pc_plus4),
        .ex_rs1_data   (ex_rs1_data),
        .ex_rs2_data   (ex_rs2_data),
        .ex_imm        (ex_imm),
        .ex_rs1_addr   (ex_rs1_addr),
        .ex_rs2_addr   (ex_rs2_addr),
        .ex_rd_addr    (ex_rd_addr),
        .ex_funct3     (ex_funct3),
        .ex_reg_write  (ex_reg_write),
        .ex_mem_to_reg (ex_mem_to_reg),
        .ex_mem_write  (ex_mem_write),
        .ex_mem_read   (ex_mem_read),
        .ex_alu_op     (ex_alu_op),
        .ex_alu_src    (ex_alu_src),
        .ex_branch     (ex_branch),
        .ex_jump       (ex_jump),
        .ex_word_op    (ex_word_op),
        .ex_mem_width  (ex_mem_width)
    );

    // ------------------------------------------------------------------------
    // Data Forwarding Unit
    // ------------------------------------------------------------------------
    rv64i_forwarding u_forwarding (
        .ex_rs1_addr   (ex_rs1_addr),
        .ex_rs2_addr   (ex_rs2_addr),
        .mem_reg_write (mem_reg_write),
        .mem_rd_addr   (mem_rd_addr),
        .wb_reg_write  (wb_reg_write),
        .wb_rd_addr    (wb_rd_addr),
        .fwd_a_sel     (fwd_a_sel),
        .fwd_b_sel     (fwd_b_sel)
    );

    // ------------------------------------------------------------------------
    // Stage 3: Execute (EX)
    // ------------------------------------------------------------------------
    rv64i_ex u_ex (
        .clk            (clk),
        .rst            (rst),
        .ex_pc          (ex_pc),
        .ex_pc_plus4    (ex_pc_plus4),
        .ex_rs1_data    (ex_rs1_data),
        .ex_rs2_data    (ex_rs2_data),
        .ex_imm         (ex_imm),
        .ex_rs1_addr    (ex_rs1_addr),
        .ex_rs2_addr    (ex_rs2_addr),
        .ex_rd_addr     (ex_rd_addr),
        .ex_funct3      (ex_funct3),
        .ex_reg_write   (ex_reg_write),
        .ex_mem_to_reg  (ex_mem_to_reg),
        .ex_mem_write   (ex_mem_write),
        .ex_mem_read    (ex_mem_read),
        .ex_alu_op      (ex_alu_op),
        .ex_alu_src     (ex_alu_src),
        .ex_branch      (ex_branch),
        .ex_jump        (ex_jump),
        .ex_word_op     (ex_word_op),
        .ex_mem_width   (ex_mem_width),
        .fwd_a_sel      (fwd_a_sel),
        .fwd_b_sel      (fwd_b_sel),
        .mem_fwd_data   (mem_alu_result),
        .wb_fwd_data    (wb_rd_data),
        .branch_taken   (branch_taken),
        .branch_target  (branch_target),
        .mem_alu_result (mem_alu_result),
        .mem_wdata      (mem_wdata),
        .mem_rd_addr    (mem_rd_addr),
        .mem_reg_write  (mem_reg_write),
        .mem_mem_to_reg (mem_mem_to_reg),
        .mem_mem_write  (mem_mem_write),
        .mem_mem_read   (mem_mem_read),
        .mem_mem_width  (mem_mem_width),
        .mem_pc_plus4   (mem_pc_plus4),
        .mem_jump       (mem_jump)
    );

    // ------------------------------------------------------------------------
    // Stage 4: Memory Access (MEM)
    // ------------------------------------------------------------------------
    rv64i_mem u_mem (
        .clk            (clk),
        .rst            (rst),
        .mem_alu_result (mem_alu_result),
        .mem_wdata      (mem_wdata),
        .mem_rd_addr    (mem_rd_addr),
        .mem_reg_write  (mem_reg_write),
        .mem_mem_to_reg (mem_mem_to_reg),
        .mem_mem_write  (mem_mem_write),
        .mem_mem_read   (mem_mem_read),
        .mem_mem_width  (mem_mem_width),
        .mem_pc_plus4   (mem_pc_plus4),
        .mem_jump       (mem_jump),
        .dmem_addr      (dmem_addr),
        .dmem_wdata     (dmem_wdata),
        .dmem_we        (dmem_we),
        .dmem_re        (dmem_re),
        .dmem_be        (dmem_be),
        .dmem_rdata     (dmem_rdata),
        .wb_alu_result  (wb_alu_result),
        .wb_mem_rdata   (wb_mem_rdata),
        .wb_rd_addr     (wb_rd_addr),
        .wb_reg_write   (wb_reg_write),
        .wb_mem_to_reg  (wb_mem_to_reg),
        .wb_pc_plus4    (wb_pc_plus4),
        .wb_jump        (wb_jump)
    );

    // ------------------------------------------------------------------------
    // Stage 5: Writeback (WB)
    // ------------------------------------------------------------------------
    rv64i_wb u_wb (
        .wb_alu_result  (wb_alu_result),
        .wb_mem_rdata   (wb_mem_rdata),
        .wb_pc_plus4    (wb_pc_plus4),
        .wb_mem_to_reg  (wb_mem_to_reg),
        .wb_jump        (wb_jump),
        .wb_rd_data     (wb_rd_data)
    );

endmodule
