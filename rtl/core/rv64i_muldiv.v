// ============================================================================
// RISC-V 64-bit M-Extension (RV64M) Hardware Multiplier and Divider
// Implements 64-bit and 32-bit integer multiplication and division:
// MUL, MULH, MULHSU, MULHU, MULW, DIV, DIVU, REM, REMU, DIVW, REMW
// ============================================================================
`default_nettype none
`include "rv64i_types.vh"

module rv64i_muldiv (
    input  wire        clk,
    input  wire        rst,
    input  wire        valid_in,
    input  wire [63:0] operand_a,
    input  wire [63:0] operand_b,
    input  wire [2:0]  funct3,
    input  wire        word_op,
    output wire [63:0] result_out,
    output wire        ready,
    output wire        busy
);

    // Instruction decoding
    wire is_div_instr  = funct3[2]; // 1 for division/remainder (100, 101, 110, 111), 0 for multiplication
    wire is_signed_div = (funct3 == `M_DIV) || (funct3 == `M_REM);
    wire is_rem_instr  = funct3[1]; // 1 for REM/REMU (110, 111), 0 for DIV/DIVU (100, 101)

    // Operand preparation for division (sign/zero extend 32-bit inputs if W-type)
    wire [63:0] div_op_a = word_op ? ( (is_signed_div && operand_a[31]) ? {{32{1'b1}}, operand_a[31:0]} : {32'd0, operand_a[31:0]} ) : operand_a;
    wire [63:0] div_op_b = word_op ? ( (is_signed_div && operand_b[31]) ? {{32{1'b1}}, operand_b[31:0]} : {32'd0, operand_b[31:0]} ) : operand_b;

    wire div_by_zero  = (div_op_b == 64'd0);
    wire div_overflow = is_signed_div && (
        (!word_op && (div_op_a == 64'h8000_0000_0000_0000) && (div_op_b == 64'hFFFF_FFFF_FFFF_FFFF)) ||
        ( word_op && (div_op_a == 64'hFFFF_FFFF_8000_0000) && (div_op_b == 64'hFFFF_FFFF_FFFF_FFFF))
    );

    wire sign_a = is_signed_div && div_op_a[63];
    wire sign_b = is_signed_div && div_op_b[63];
    wire [63:0] abs_a = sign_a ? (~div_op_a + 64'd1) : div_op_a;
    wire [63:0] abs_b = sign_b ? (~div_op_b + 64'd1) : div_op_b;

    // Special case division results
    reg [63:0] div_special_result;
    always @(*) begin
        if (div_by_zero) begin
            if (is_rem_instr) begin
                div_special_result = div_op_a;
            end else begin
                div_special_result = 64'hFFFF_FFFF_FFFF_FFFF;
            end
        end else begin // div_overflow
            if (is_rem_instr) begin
                div_special_result = 64'd0;
            end else begin
                div_special_result = div_op_a;
            end
        end
    end

    // Multiplication logic (Pipelined for 1GHz optimization)
    wire is_mul_signed_a = (funct3 == `M_MULH) || (funct3 == `M_MULHSU);
    wire is_mul_signed_b = (funct3 == `M_MULH);

    reg signed [64:0] reg_mul_op_a;
    reg signed [64:0] reg_mul_op_b;
    reg               reg_mul_word_op;
    reg [2:0]         reg_mul_funct3;
    
    // Stage 1 to 2 combinational multiply
    wire signed [129:0] mul_full_res = reg_mul_op_a * reg_mul_op_b;
    
    reg signed [129:0] reg_mul_full_res;
    reg [31:0]         reg_mulw_res32;
    reg [2:0]          reg_mul_funct3_stage2;
    reg                reg_mul_word_op_stage2;

    reg [63:0] mul_result;
    always @(*) begin
        if (reg_mul_word_op_stage2) begin
            mul_result = {{32{reg_mulw_res32[31]}}, reg_mulw_res32[31:0]};
        end else begin
            case (reg_mul_funct3_stage2)
                `M_MUL:    mul_result = reg_mul_full_res[63:0];
                `M_MULH:   mul_result = reg_mul_full_res[127:64];
                `M_MULHSU: mul_result = reg_mul_full_res[127:64];
                `M_MULHU:  mul_result = reg_mul_full_res[127:64];
                default:   mul_result = reg_mul_full_res[63:0];
            endcase
        end
    end

    // Division State Machine & Multiplier Pipelining
    localparam STATE_IDLE        = 3'b000;
    localparam STATE_DIVIDING    = 3'b001;
    localparam STATE_MULTIPLY_1  = 3'b010;
    localparam STATE_MULTIPLY_2  = 3'b011;
    localparam STATE_DONE        = 3'b100;

    reg [2:0]   state;
    reg [5:0]   count;
    reg [127:0] PA;
    reg [63:0]  reg_b;
    reg         reg_sign_q;
    reg         reg_sign_r;
    reg         reg_is_rem;

    wire [127:0] PA_sh   = {PA[126:0], 1'b0};
    wire [64:0]  sub_val = {1'b0, PA_sh[127:64]} - {1'b0, reg_b};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= STATE_IDLE;
            count      <= 6'd0;
            PA         <= 128'd0;
            reg_b      <= 64'd0;
            reg_sign_q <= 1'b0;
            reg_sign_r <= 1'b0;
            reg_is_rem <= 1'b0;
            reg_mul_op_a <= 65'd0;
            reg_mul_op_b <= 65'd0;
            reg_mul_word_op <= 1'b0;
            reg_mul_funct3 <= 3'd0;
            reg_mul_full_res <= 130'd0;
            reg_mulw_res32 <= 32'd0;
            reg_mul_funct3_stage2 <= 3'd0;
            reg_mul_word_op_stage2 <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (valid_in) begin
                        if (is_div_instr && !div_by_zero && !div_overflow) begin
                            state      <= STATE_DIVIDING;
                            count      <= 6'd63;
                            PA         <= {64'd0, abs_a};
                            reg_b      <= abs_b;
                            reg_sign_q <= sign_a ^ sign_b;
                            reg_sign_r <= sign_a;
                            reg_is_rem <= is_rem_instr;
                        end else if (!is_div_instr) begin
                            // Start Multiplier Pipeline
                            state <= STATE_MULTIPLY_1;
                            reg_mul_op_a <= {is_mul_signed_a & operand_a[63], operand_a};
                            reg_mul_op_b <= {is_mul_signed_b & operand_b[63], operand_b};
                            reg_mul_word_op <= word_op;
                            reg_mul_funct3 <= funct3;
                        end
                    end
                end

                STATE_DIVIDING: begin
                    if (!sub_val[64]) begin
                        PA <= {sub_val[63:0], PA_sh[63:1], 1'b1};
                    end else begin
                        PA <= PA_sh;
                    end

                    if (count == 6'd0) begin
                        state <= STATE_DONE;
                    end else begin
                        count <= count - 6'd1;
                    end
                end
                
                STATE_MULTIPLY_1: begin
                    state <= STATE_MULTIPLY_2;
                    reg_mul_full_res <= mul_full_res;
                    reg_mulw_res32 <= reg_mul_op_a[31:0] * reg_mul_op_b[31:0];
                    reg_mul_funct3_stage2 <= reg_mul_funct3;
                    reg_mul_word_op_stage2 <= reg_mul_word_op;
                end
                
                STATE_MULTIPLY_2: begin
                    state <= STATE_DONE;
                end

                STATE_DONE: begin
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

    // Result computation for division in DONE state
    wire [63:0] raw_quotient  = reg_sign_q ? (~PA[63:0]  + 64'd1) : PA[63:0];
    wire [63:0] raw_remainder = reg_sign_r ? (~PA[127:64] + 64'd1) : PA[127:64];
    wire [63:0] div_normal_result = reg_is_rem ? raw_remainder : raw_quotient;

    // Output selection
    wire [63:0] raw_result_out;
    assign raw_result_out = (!is_div_instr) ? mul_result :
                            (div_by_zero || div_overflow) ? div_special_result :
                            div_normal_result;

    // Word operation sign extension (W instructions sign-extend lower 32 bits to 64 bits)
    assign result_out = (is_div_instr && word_op) ? {{32{raw_result_out[31]}}, raw_result_out[31:0]} : raw_result_out;

    // Handshake and Hazard control flags
    assign busy  = (state != STATE_IDLE && state != STATE_DONE) || (state == STATE_IDLE && valid_in && (!is_div_instr || (!div_by_zero && !div_overflow)));
    assign ready = (state == STATE_DONE) || (state == STATE_IDLE && valid_in && is_div_instr && (div_by_zero || div_overflow));

endmodule
