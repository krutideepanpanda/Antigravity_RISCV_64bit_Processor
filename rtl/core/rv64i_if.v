// ============================================================================
// Stage 1: Instruction Fetch (IF)
// Program Counter (PC), PC+4 Adder, Branch/Jump Muxing, and IF/ID Register
// ============================================================================
`default_nettype none

module rv64i_if (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,          // From hazard unit: freeze PC and IF/ID reg
    input  wire        flush,          // From hazard unit: clear IF/ID reg to NOP
    input  wire        branch_taken,   // From EX stage: branch or jump taken
    input  wire [63:0] branch_target,  // From EX stage: target address
    input  wire [31:0] imem_rdata,     // Instruction read from instruction memory
    output wire [63:0] imem_addr,      // PC address to instruction memory
    output reg  [63:0] id_pc,          // PC passed to ID stage
    output reg  [63:0] id_pc_plus4,    // PC+4 passed to ID stage
    output reg  [31:0] id_instr        // Instruction passed to ID stage
);

    reg [63:0] pc_reg;
    wire [63:0] pc_next;
    wire [63:0] pc_plus4;

    assign pc_plus4  = pc_reg + 64'h4;
    assign pc_next   = branch_taken ? branch_target : pc_plus4;
    assign imem_addr = pc_reg;

    // Synchronous PC Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_reg <= 64'h0000_0000_0000_0000;
        end else if (!stall) begin
            pc_reg <= pc_next;
        end
    end

    // IF/ID Synchronous Pipeline Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_pc       <= 64'h0;
            id_pc_plus4 <= 64'h0;
            id_instr    <= 32'h0000_0013; // NOP (addi x0, x0, 0)
        end else if (flush) begin
            id_pc       <= 64'h0;
            id_pc_plus4 <= 64'h0;
            id_instr    <= 32'h0000_0013; // NOP
        end else if (!stall) begin
            id_pc       <= pc_reg;
            id_pc_plus4 <= pc_plus4;
            id_instr    <= imem_rdata;
        end
    end

endmodule
