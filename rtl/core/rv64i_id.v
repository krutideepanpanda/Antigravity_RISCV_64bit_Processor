// ============================================================================
// Stage 2: Instruction Decode (ID)
// Register File, Immediate Generator, Control Unit, and ID/EX Pipeline Register
// ============================================================================
`default_nettype none

module rv64i_id (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,          // From hazard unit: freeze ID/EX reg
    input  wire        flush,          // From hazard unit: clear ID/EX reg to NOP/bubble
    input  wire [63:0] id_pc,
    input  wire [63:0] id_pc_plus4,
    input  wire [31:0] id_instr,
    input  wire        wb_reg_write,   // From WB stage
    input  wire [4:0]  wb_rd_addr,     // From WB stage
    input  wire [63:0] wb_rd_data,     // From WB stage
    // Outputs to EX stage (via ID/EX register)
    output reg  [63:0] ex_pc,
    output reg  [63:0] ex_pc_plus4,
    output reg  [63:0] ex_rs1_data,
    output reg  [63:0] ex_rs2_data,
    output reg  [63:0] ex_imm,
    output reg  [4:0]  ex_rs1_addr,
    output reg  [4:0]  ex_rs2_addr,
    output reg  [4:0]  ex_rd_addr,
    output reg  [2:0]  ex_funct3,
    output reg         ex_reg_write,
    output reg         ex_mem_to_reg,
    output reg         ex_mem_write,
    output reg         ex_mem_read,
    output reg  [3:0]  ex_alu_op,
    output reg         ex_alu_src,
    output reg         ex_branch,
    output reg         ex_jump,
    output reg         ex_word_op,
    output reg  [2:0]  ex_mem_width
);

    wire [4:0] rs1_addr = id_instr[19:15];
    wire [4:0] rs2_addr = id_instr[24:20];
    wire [4:0] rd_addr  = id_instr[11:7];
    wire [2:0] funct3   = id_instr[14:12];

    wire [63:0] rs1_data;
    wire [63:0] rs2_data;
    wire [63:0] imm;

    wire        reg_write;
    wire        mem_to_reg;
    wire        mem_write;
    wire        mem_read;
    wire [3:0]  alu_op;
    wire        alu_src;
    wire        branch;
    wire        jump;
    wire        word_op;
    wire [2:0]  mem_width;

    // Instantiate Register File
    rv64i_regfile u_regfile (
        .clk      (clk),
        .rst      (rst),
        .we       (wb_reg_write),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (wb_rd_addr),
        .rd_data  (wb_rd_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // Instantiate Immediate Generator
    rv64i_imm_gen u_imm_gen (
        .instr    (id_instr),
        .imm      (imm)
    );

    // Instantiate Control Unit
    rv64i_control u_control (
        .instr      (id_instr),
        .reg_write  (reg_write),
        .mem_to_reg (mem_to_reg),
        .mem_write  (mem_write),
        .mem_read   (mem_read),
        .alu_op     (alu_op),
        .alu_src    (alu_src),
        .branch     (branch),
        .jump       (jump),
        .word_op    (word_op),
        .mem_width  (mem_width)
    );

    // ID/EX Synchronous Pipeline Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_pc         <= 64'h0;
            ex_pc_plus4   <= 64'h0;
            ex_rs1_data   <= 64'h0;
            ex_rs2_data   <= 64'h0;
            ex_imm        <= 64'h0;
            ex_rs1_addr   <= 5'h0;
            ex_rs2_addr   <= 5'h0;
            ex_rd_addr    <= 5'h0;
            ex_funct3     <= 3'h0;
            ex_reg_write  <= 1'b0;
            ex_mem_to_reg <= 1'b0;
            ex_mem_write  <= 1'b0;
            ex_mem_read   <= 1'b0;
            ex_alu_op     <= 4'h0;
            ex_alu_src    <= 1'b0;
            ex_branch     <= 1'b0;
            ex_jump       <= 1'b0;
            ex_word_op    <= 1'b0;
            ex_mem_width  <= 3'h0;
        end else if (flush) begin
            ex_pc         <= 64'h0;
            ex_pc_plus4   <= 64'h0;
            ex_rs1_data   <= 64'h0;
            ex_rs2_data   <= 64'h0;
            ex_imm        <= 64'h0;
            ex_rs1_addr   <= 5'h0;
            ex_rs2_addr   <= 5'h0;
            ex_rd_addr    <= 5'h0;
            ex_funct3     <= 3'h0;
            ex_reg_write  <= 1'b0;
            ex_mem_to_reg <= 1'b0;
            ex_mem_write  <= 1'b0;
            ex_mem_read   <= 1'b0;
            ex_alu_op     <= 4'h0;
            ex_alu_src    <= 1'b0;
            ex_branch     <= 1'b0;
            ex_jump       <= 1'b0;
            ex_word_op    <= 1'b0;
            ex_mem_width  <= 3'h0;
        end else if (!stall) begin
            ex_pc         <= id_pc;
            ex_pc_plus4   <= id_pc_plus4;
            ex_rs1_data   <= rs1_data;
            ex_rs2_data   <= rs2_data;
            ex_imm        <= imm;
            ex_rs1_addr   <= rs1_addr;
            ex_rs2_addr   <= rs2_addr;
            ex_rd_addr    <= rd_addr;
            ex_funct3     <= funct3;
            ex_reg_write  <= reg_write;
            ex_mem_to_reg <= mem_to_reg;
            ex_mem_write  <= mem_write;
            ex_mem_read   <= mem_read;
            ex_alu_op     <= alu_op;
            ex_alu_src    <= alu_src;
            ex_branch     <= branch;
            ex_jump       <= jump;
            ex_word_op    <= word_op;
            ex_mem_width  <= mem_width;
        end
    end

endmodule
