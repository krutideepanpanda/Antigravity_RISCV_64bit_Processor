// ============================================================================
// Immediate Generator for RV64I Instruction Formats
// Extracts and sign-extends 32-bit instruction immediates to 64-bit
// ============================================================================
`default_nettype none
`include "rv64i_types.vh"

module rv64i_imm_gen (
    input  wire [31:0] instr,
    output reg  [63:0] imm
);

    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            `OPCODE_IMM, `OPCODE_IMM_W, `OPCODE_LOAD, `OPCODE_JALR: begin
                // I-Type: 12-bit signed immediate
                imm = {{52{instr[31]}}, instr[31:20]};
            end
            `OPCODE_STORE: begin
                // S-Type: 12-bit signed immediate
                imm = {{52{instr[31]}}, instr[31:25], instr[11:7]};
            end
            `OPCODE_BRANCH: begin
                // B-Type: 13-bit signed branch offset (multiple of 2)
                imm = {{52{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            end
            `OPCODE_LUI, `OPCODE_AUIPC: begin
                // U-Type: 20-bit upper immediate shifted by 12, sign-extended
                imm = {{32{instr[31]}}, instr[31:12], 12'b0};
            end
            `OPCODE_JAL: begin
                // J-Type: 21-bit signed jump offset (multiple of 2)
                imm = {{44{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            end
            default: begin
                imm = 64'h0;
            end
        endcase
    end

endmodule
