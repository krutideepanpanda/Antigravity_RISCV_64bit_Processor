// ============================================================================
// RISC-V 64-bit (RV64I) Constants and Instruction Opcodes
// ============================================================================
`ifndef RV64I_TYPES_VH
`define RV64I_TYPES_VH

// Major Opcodes (instr[6:0])
`define OPCODE_LOAD    7'b0000011 // L-type: LB, LH, LW, LD, LBU, LHU, LWU
`define OPCODE_IMM     7'b0010011 // I-type: ADDI, SLLI, SLTI, SLTIU, XORI, SRLI, SRAI, ORI, ANDI
`define OPCODE_AUIPC   7'b0010111 // U-type: AUIPC
`define OPCODE_IMM_W   7'b0011011 // I-type word: ADDIW, SLLIW, SRLIW, SRAIW
`define OPCODE_STORE   7'b0100011 // S-type: SB, SH, SW, SD
`define OPCODE_OP      7'b0110011 // R-type: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
`define OPCODE_LUI     7'b0110111 // U-type: LUI
`define OPCODE_OP_W    7'b0111011 // R-type word: ADDW, SUBW, SLLW, SRLW, SRAW
`define OPCODE_BRANCH  7'b1100011 // B-type: BEQ, BNE, BLT, BGE, BLTU, BGEU
`define OPCODE_JALR    7'b1100111 // I-type jump: JALR
`define OPCODE_JAL     7'b1101111 // J-type jump: JAL
`define OPCODE_SYSTEM  7'b1110011 // System: ECALL, EBREAK

// ALU Control Opcodes (alu_ctrl)
`define ALU_ADD   4'b0000
`define ALU_SUB   4'b1000
`define ALU_SLL   4'b0001
`define ALU_SLT   4'b0010
`define ALU_SLTU  4'b0011
`define ALU_XOR   4'b0100
`define ALU_SRL   4'b0101
`define ALU_SRA   4'b1101
`define ALU_OR    4'b0110
`define ALU_AND   4'b0111
`define ALU_PASS_B 4'b1111 // For LUI / JAL / JALR where imm or pc is passed

// Branch Types (funct3)
`define BR_BEQ  3'b000
`define BR_BNE  3'b001
`define BR_BLT  3'b100
`define BR_BGE  3'b101
`define BR_BLTU 3'b110
`define BR_BGEU 3'b111

// Memory Width / Sign Extension (funct3 for Load/Store)
`define MEM_BYTE   3'b000
`define MEM_HALF   3'b001
`define MEM_WORD   3'b010
`define MEM_DWORD  3'b011
`define MEM_UBYTE  3'b100
`define MEM_UHALF  3'b101
`define MEM_UWORD  3'b110

// Forwarding Multiplexer Selectors
`define FWD_NONE   2'b00
`define FWD_MEM    2'b01 // Forward from MEM/WB stage
`define FWD_EX     2'b10 // Forward from EX/MEM stage

`endif // RV64I_TYPES_VH
