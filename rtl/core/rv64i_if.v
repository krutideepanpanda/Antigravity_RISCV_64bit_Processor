// ============================================================================
// Stage 1: Instruction Fetch (IF)
// Program Counter (PC), PC+4 Adder, Branch Prediction (BHT+BTB), and IF/ID Reg
// ============================================================================
`default_nettype none

module rv64i_if (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,          // From hazard unit: freeze PC and IF/ID reg
    input  wire        flush,          // From hazard unit: clear IF/ID reg to NOP
    input  wire        ex_mispredict,  // From EX stage: prediction was wrong
    input  wire [63:0] ex_correct_pc,  // From EX stage: correct recovery PC
    
    // Branch Predictor Training (from EX)
    input  wire        ex_branch_valid, // 1 if EX instruction is a branch/jump
    input  wire [63:0] ex_branch_pc,    // PC of branch in EX
    input  wire        ex_branch_taken, // 1 if branch was actually taken
    input  wire [63:0] ex_branch_target,// Actual computed target

    // Instruction Memory
    input  wire [31:0] imem_rdata,
    output wire [63:0] imem_addr,
    
    // ID pipeline signals
    output reg  [63:0] id_pc,
    output reg  [63:0] id_pc_plus4,
    output reg  [31:0] id_instr,
    output reg         id_predicted_taken,
    output reg  [63:0] id_predicted_target
);

    reg [63:0] pc_reg;
    wire [63:0] pc_next;
    wire [63:0] pc_plus4;

    assign pc_plus4  = pc_reg + 64'h4;
    assign imem_addr = pc_reg;

    // ------------------------------------------------------------------------
    // Dynamic Branch Predictor (64-entry BHT + BTB)
    // ------------------------------------------------------------------------
    localparam BTB_ENTRIES = 256;
    localparam BTB_INDEX_BITS = 8; // log2(256)
    
    // Arrays for predictor
    reg [61:0] btb_tag    [0:BTB_ENTRIES-1];
    reg [63:0] btb_target [0:BTB_ENTRIES-1];
    reg [1:0]  bht_state  [0:BTB_ENTRIES-1]; // 2-bit saturating counter
    reg        btb_valid  [0:BTB_ENTRIES-1];

    // Predictor Read (Fetch)
    wire [BTB_INDEX_BITS-1:0] fetch_idx = pc_reg[BTB_INDEX_BITS+1:2];
    wire [61:0]               fetch_tag = pc_reg[63:2];
    
    wire hit = btb_valid[fetch_idx] && (btb_tag[fetch_idx] == fetch_tag);
    wire pred_taken = hit && (bht_state[fetch_idx][1] == 1'b1); // State 10 or 11 = Taken
    wire [63:0] pred_target = btb_target[fetch_idx];

    // PC Next Logic
    assign pc_next = ex_mispredict ? ex_correct_pc :
                     pred_taken    ? pred_target   : pc_plus4;

    // Predictor Write (Training from EX)
    wire [BTB_INDEX_BITS-1:0] train_idx = ex_branch_pc[BTB_INDEX_BITS+1:2];
    wire [61:0]               train_tag = ex_branch_pc[63:2];
    
    always @(posedge clk) begin
        if (rst) begin
            integer i;
            for (i = 0; i < BTB_ENTRIES; i = i + 1) begin
                btb_valid[i] <= 1'b0;
                bht_state[i] <= 2'b10; // Weakly Taken default
            end
        end else if (ex_branch_valid) begin
            // Update BTB Tag and Target
            btb_valid[train_idx] <= 1'b1;
            btb_tag[train_idx]   <= train_tag;
            btb_target[train_idx]<= ex_branch_target;
            
            // Update 2-bit Saturating Counter
            if (ex_branch_taken) begin
                if (bht_state[train_idx] != 2'b11) bht_state[train_idx] <= bht_state[train_idx] + 2'd1;
            end else begin
                if (bht_state[train_idx] != 2'b00) bht_state[train_idx] <= bht_state[train_idx] - 2'd1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Synchronous PC Register
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_reg <= 64'h0000_0000_0000_0000;
        end else if (ex_mispredict) begin
            pc_reg <= ex_correct_pc;
        end else if (!stall) begin
            pc_reg <= pc_next;
        end
    end

    // ------------------------------------------------------------------------
    // IF/ID Synchronous Pipeline Register
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_pc              <= 64'h0;
            id_pc_plus4        <= 64'h0;
            id_instr           <= 32'h0000_0013; // NOP
            id_predicted_taken <= 1'b0;
            id_predicted_target<= 64'h0;
        end else if (flush || ex_mispredict) begin
            id_pc              <= 64'h0;
            id_pc_plus4        <= 64'h0;
            id_instr           <= 32'h0000_0013; // NOP
            id_predicted_taken <= 1'b0;
            id_predicted_target<= 64'h0;
        end else if (!stall) begin
            id_pc              <= pc_reg;
            id_pc_plus4        <= pc_plus4;
            id_instr           <= imem_rdata;
            id_predicted_taken <= pred_taken;
            id_predicted_target<= pred_target;
        end
    end

endmodule
