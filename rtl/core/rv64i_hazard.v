// ============================================================================
// Hazard Detection Unit
// Detects load-use stalls (ID/EX mem_read matching IF/ID rs1 or rs2)
// Asserts pipeline stall and branch/jump control flushes
// ============================================================================
`default_nettype none

module rv64i_hazard (
    input  wire [4:0] id_rs1_addr,
    input  wire [4:0] id_rs2_addr,
    input  wire       ex_mem_read,
    input  wire [4:0] ex_rd_addr,
    input  wire       ex_mispredict,
    output reg        stall,       // Freezes PC and IF/ID reg; inserts bubble in ID/EX
    output reg        if_id_flush, // Flushes IF/ID reg when branch taken
    output reg        id_ex_flush  // Flushes ID/EX reg when branch taken or stall occurs
);

    always @(*) begin
        stall       = 1'b0;
        if_id_flush = 1'b0;
        id_ex_flush = 1'b0;

        // Load-Use Data Hazard Detection
        if (ex_mem_read && (ex_rd_addr != 5'd0) && ((ex_rd_addr == id_rs1_addr) || (ex_rd_addr == id_rs2_addr))) begin
            stall       = 1'b1;
            id_ex_flush = 1'b1; // Insert NOP bubble into ID/EX
        end

        // Control Hazard Flush on Branch Misprediction
        if (ex_mispredict) begin
            if_id_flush = 1'b1;
            id_ex_flush = 1'b1;
        end
    end

endmodule
