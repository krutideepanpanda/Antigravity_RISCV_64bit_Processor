// ============================================================================
// Main Control Unit & ALU Opcode Decoder
// Generates pipeline control flags and ALU operation codes from instruction
// ============================================================================
`default_nettype none
`include "rv64i_types.vh"

module rv64i_control (
    input  wire [31:0] instr,
    output reg         reg_write,
    output reg         mem_to_reg,
    output reg         mem_write,
    output reg         mem_read,
    output reg  [3:0]  alu_op,
    output reg         alu_src,    // 0: rs2, 1: imm
    output reg         branch,
    output reg         jump,
    output reg         word_op,    // 1 for 32-bit W-type instructions
    output reg  [2:0]  mem_width   // byte, halfword, word, doubleword
);

    wire [6:0] opcode  = instr[6:0];
    wire [2:0] funct3  = instr[14:12];
    wire       funct7_5 = instr[30]; // Bit 30 distinguishes ADD/SUB, SRL/SRA

    always @(*) begin
        // Defaults
        reg_write  = 1'b0;
        mem_to_reg = 1'b0;
        mem_write  = 1'b0;
        mem_read   = 1'b0;
        alu_op     = `ALU_ADD;
        alu_src    = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        word_op    = 1'b0;
        mem_width  = `MEM_DWORD;

        case (opcode)
            `OPCODE_OP: begin // R-Type 64-bit
                reg_write = 1'b1;
                alu_src   = 1'b0;
                case (funct3)
                    3'b000: alu_op = funct7_5 ? `ALU_SUB : `ALU_ADD;
                    3'b001: alu_op = `ALU_SLL;
                    3'b010: alu_op = `ALU_SLT;
                    3'b011: alu_op = `ALU_SLTU;
                    3'b100: alu_op = `ALU_XOR;
                    3'b101: alu_op = funct7_5 ? `ALU_SRA : `ALU_SRL;
                    3'b110: alu_op = `ALU_OR;
                    3'b111: alu_op = `ALU_AND;
                    default: alu_op = `ALU_ADD;
                endcase
            end
            `OPCODE_OP_W: begin // R-Type 32-bit Word
                reg_write = 1'b1;
                alu_src   = 1'b0;
                word_op   = 1'b1;
                case (funct3)
                    3'b000: alu_op = funct7_5 ? `ALU_SUB : `ALU_ADD;
                    3'b001: alu_op = `ALU_SLL;
                    3'b101: alu_op = funct7_5 ? `ALU_SRA : `ALU_SRL;
                    default: alu_op = `ALU_ADD;
                endcase
            end
            `OPCODE_IMM: begin // I-Type 64-bit
                reg_write = 1'b1;
                alu_src   = 1'b1;
                case (funct3)
                    3'b000: alu_op = `ALU_ADD; // addi
                    3'b001: alu_op = `ALU_SLL; // slli
                    3'b010: alu_op = `ALU_SLT; // slti
                    3'b011: alu_op = `ALU_SLTU; // sltiu
                    3'b100: alu_op = `ALU_XOR; // xori
                    3'b101: alu_op = funct7_5 ? `ALU_SRA : `ALU_SRL; // srli/srai
                    3'b110: alu_op = `ALU_OR;  // ori
                    3'b111: alu_op = `ALU_AND; // andi
                    default: alu_op = `ALU_ADD;
                endcase
            end
            `OPCODE_IMM_W: begin // I-Type 32-bit Word
                reg_write = 1'b1;
                alu_src   = 1'b1;
                word_op   = 1'b1;
                case (funct3)
                    3'b000: alu_op = `ALU_ADD; // addiw
                    3'b001: alu_op = `ALU_SLL; // slliw
                    3'b101: alu_op = funct7_5 ? `ALU_SRA : `ALU_SRL; // srliw/sraiw
                    default: alu_op = `ALU_ADD;
                endcase
            end
            `OPCODE_LOAD: begin // Load
                reg_write  = 1'b1;
                mem_to_reg = 1'b1;
                mem_read   = 1'b1;
                alu_src    = 1'b1;
                alu_op     = `ALU_ADD;
                mem_width  = funct3;
            end
            `OPCODE_STORE: begin // Store
                mem_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = `ALU_ADD;
                mem_width  = funct3;
            end
            `OPCODE_BRANCH: begin // Branch
                branch  = 1'b1;
                alu_src = 1'b0;
                alu_op  = `ALU_SUB; // subtraction for comparison
            end
            `OPCODE_JAL: begin // Jump and Link
                reg_write = 1'b1;
                jump      = 1'b1;
                alu_op    = `ALU_PASS_B;
            end
            `OPCODE_JALR: begin // Jump and Link Register
                reg_write = 1'b1;
                jump      = 1'b1;
                alu_src   = 1'b1;
                alu_op    = `ALU_ADD;
            end
            `OPCODE_LUI: begin // Load Upper Immediate
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = `ALU_PASS_B;
            end
            `OPCODE_AUIPC: begin // Add Upper Immediate to PC
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = `ALU_ADD; // Will add PC + imm in ALU or EX stage
            end
            default: begin
                // All defaults 0
            end
        endcase
    end

endmodule
