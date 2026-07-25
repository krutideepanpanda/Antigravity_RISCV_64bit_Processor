// ============================================================================
// 64-bit Arithmetic Logic Unit (ALU)
// Supports 64-bit integer ops and 32-bit W-type integer ops (sign-extended)
// ============================================================================
`default_nettype none
`include "rv64i_types.vh"

module rv64i_alu (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [3:0]  alu_op,
    input  wire        word_op,    // 1 for 32-bit W instructions
    output reg  [63:0] result,
    output wire        zero
);

    wire [5:0] shamt6 = b[5:0];
    wire [4:0] shamt5 = b[4:0];

    wire [31:0] a32 = a[31:0];
    wire [31:0] b32 = b[31:0];

    reg [31:0] res32;
    wire signed [63:0] signed_a = a;
    wire signed [63:0] signed_b = b;
    wire signed [31:0] signed_a32 = a[31:0];

    assign zero = (result == 64'd0);

    always @(*) begin
        res32 = 32'd0;
        result = 64'd0;
        if (word_op) begin
            // 32-bit Word Operations (sign-extend result from bit 31 to bit 63)
            case (alu_op)
                `ALU_ADD: res32 = a32 + b32;
                `ALU_SUB: res32 = a32 - b32;
                `ALU_SLL: res32 = a32 << shamt5;
                `ALU_SRL: res32 = a32 >> shamt5;
                `ALU_SRA: res32 = signed_a32 >>> shamt5;
                default:  res32 = a32 + b32;
            endcase
            result = {{32{res32[31]}}, res32};
        end else begin
            // 64-bit Operations
            case (alu_op)
                `ALU_ADD:    result = a + b;
                `ALU_SUB:    result = a - b;
                `ALU_SLL:    result = a << shamt6;
                `ALU_SLT:    result = (signed_a < signed_b) ? 64'd1 : 64'd0;
                `ALU_SLTU:   result = (a < b) ? 64'd1 : 64'd0;
                `ALU_XOR:    result = a ^ b;
                `ALU_SRL:    result = a >> shamt6;
                `ALU_SRA:    result = signed_a >>> shamt6;
                `ALU_OR:     result = a | b;
                `ALU_AND:    result = a & b;
                `ALU_PASS_B: result = b; // Pass operand B directly (for LUI/JAL/JALR)
                default:     result = a + b;
            endcase
        end
    end

endmodule
