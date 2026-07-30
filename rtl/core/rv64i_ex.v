// ============================================================================
// Stage 3: Execute (EX)
// ALU, Forwarding Muxes, Branch Target Adder, Branch Comparator, EX/MEM Reg
// ============================================================================
`default_nettype none
`include "rv64i_types.vh"

module rv64i_ex (
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] ex_pc,
    input  wire [63:0] ex_pc_plus4,
    input  wire        ex_predicted_taken, // From ID stage
    input  wire [63:0] ex_predicted_target, // From ID stage
    input  wire [63:0] ex_rs1_data,
    input  wire [63:0] ex_rs2_data,
    input  wire [63:0] ex_imm,
    input  wire [4:0]  ex_rs1_addr,
    input  wire [4:0]  ex_rs2_addr,
    input  wire [4:0]  ex_rd_addr,
    input  wire [2:0]  ex_funct3,
    input  wire        ex_reg_write,
    input  wire        ex_mem_to_reg,
    input  wire        ex_mem_write,
    input  wire        ex_mem_read,
    input  wire [3:0]  ex_alu_op,
    input  wire        ex_alu_src,
    input  wire        ex_branch,
    input  wire        ex_jump,
    input  wire        ex_word_op,
    input  wire [2:0]  ex_mem_width,
    // Forwarding inputs
    input  wire [1:0]  fwd_a_sel,
    input  wire [1:0]  fwd_b_sel,
    input  wire [63:0] mem_fwd_data,   // From MEM stage (mem_alu_result)
    input  wire [63:0] wb_fwd_data,    // From WB stage (wb_rd_data)
    // Outputs to IF stage (branch resolution and prediction training)
    output wire        ex_mispredict,
    output wire [63:0] ex_correct_pc,
    output wire        ex_branch_valid,
    output wire        ex_branch_taken,
    output wire [63:0] ex_branch_target,
    
    // Outputs to MEM stage (via EX/MEM register)
    output reg  [63:0] mem_alu_result,
    output reg  [63:0] mem_wdata,
    output reg  [4:0]  mem_rd_addr,
    output reg         mem_reg_write,
    output reg         mem_mem_to_reg,
    output reg         mem_mem_write,
    output reg         mem_mem_read,
    output reg  [2:0]  mem_mem_width,
    output reg  [63:0] mem_pc_plus4,
    output reg         mem_jump
);

    // Forwarding Multiplexers for Operand A and Operand B
    reg [63:0] fwd_rs1;
    reg [63:0] fwd_rs2;

    always @(*) begin
        case (fwd_a_sel)
            `FWD_EX:   fwd_rs1 = mem_fwd_data;
            `FWD_MEM:  fwd_rs1 = wb_fwd_data;
            default:   fwd_rs1 = ex_rs1_data;
        endcase
    end

    always @(*) begin
        case (fwd_b_sel)
            `FWD_EX:   fwd_rs2 = mem_fwd_data;
            `FWD_MEM:  fwd_rs2 = wb_fwd_data;
            default:   fwd_rs2 = ex_rs2_data;
        endcase
    end

    // ALU Operands
    wire [63:0] alu_in_a = fwd_rs1;
    wire [63:0] alu_in_b = ex_alu_src ? ex_imm : fwd_rs2;

    // Instantiate 64-bit ALU
    wire [63:0] alu_res;
    wire        alu_zero;

    rv64i_alu u_alu (
        .a       (alu_in_a),
        .b       (alu_in_b),
        .alu_op  (ex_alu_op),
        .word_op (ex_word_op),
        .result  (alu_res),
        .zero    (alu_zero)
    );

    // Optimized Shared Branch Comparator (eliminates redundant signed/unsigned and >= comparator trees)
    wire br_eq  = (fwd_rs1 == fwd_rs2);
    wire br_ltu = (fwd_rs1 < fwd_rs2);
    wire br_lt  = (fwd_rs1[63] ^ fwd_rs2[63]) ? fwd_rs1[63] : br_ltu;

    reg br_cond_met;
    always @(*) begin
        case (ex_funct3)
            `BR_BEQ:  br_cond_met = br_eq;
            `BR_BNE:  br_cond_met = ~br_eq;
            `BR_BLT:  br_cond_met = br_lt;
            `BR_BGE:  br_cond_met = ~br_lt;
            `BR_BLTU: br_cond_met = br_ltu;
            `BR_BGEU: br_cond_met = ~br_ltu;
            default:  br_cond_met = 1'b0;
        endcase
    end

    // Branch Target Calculators
    wire [63:0] pc_target   = ex_pc + ex_imm;              // For BEQ/BNE/BLT/BGE/JAL
    wire [63:0] jalr_target = (fwd_rs1 + ex_imm) & ~64'h1; // For JALR (LSB cleared to 0)

    wire actual_taken  = (ex_branch && br_cond_met) || ex_jump;
    wire [63:0] actual_target = (ex_jump && ex_alu_src) ? jalr_target : pc_target;
    
    wire target_mismatch = ex_predicted_taken && (actual_target != ex_predicted_target);
    assign ex_mispredict = (actual_taken != ex_predicted_taken) || target_mismatch;
    
    // Correct PC calculation:
    // If we predicted TAKEN but it was NOT taken, correct PC is PC+4.
    // If we predicted NOT TAKEN but it was TAKEN, correct PC is actual_target.
    assign ex_correct_pc = actual_taken ? actual_target : ex_pc_plus4;

    // Training signals to IF stage BHT/BTB
    assign ex_branch_valid  = ex_branch || ex_jump;
    assign ex_branch_taken  = actual_taken;
    assign ex_branch_target = actual_target;

    // EX/MEM Synchronous Pipeline Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_alu_result <= 64'h0;
            mem_wdata      <= 64'h0;
            mem_rd_addr    <= 5'h0;
            mem_reg_write  <= 1'b0;
            mem_mem_to_reg <= 1'b0;
            mem_mem_write  <= 1'b0;
            mem_mem_read   <= 1'b0;
            mem_mem_width  <= 3'h0;
            mem_pc_plus4   <= 64'h0;
            mem_jump       <= 1'b0;
        end else begin
            mem_alu_result <= alu_res;
            mem_wdata      <= fwd_rs2; // Store data uses forwarded rs2
            mem_rd_addr    <= ex_rd_addr;
            mem_reg_write  <= ex_reg_write;
            mem_mem_to_reg <= ex_mem_to_reg;
            mem_mem_write  <= ex_mem_write;
            mem_mem_read   <= ex_mem_read;
            mem_mem_width  <= ex_mem_width;
            mem_pc_plus4   <= ex_pc_plus4;
            mem_jump       <= ex_jump;
        end
    end

endmodule
