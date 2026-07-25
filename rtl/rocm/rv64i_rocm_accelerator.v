// ============================================================================
// RV64I ROCm Hardware Co-Processor Accelerator
// Implements a memory-mapped HSA/ROCm Architectural Queue Language (AQL)
// kernel dispatch queue and simulated SIMD vector execution unit for RV64I.
// Physical Address Mapping: 0x8000_0000 - 0x8000_00FF
// ============================================================================
`default_nettype none
`timescale 1ns / 1ps

`include "rocm_dispatch_pkt.vh"

module rv64i_rocm_accelerator (
    input  wire        clk,
    input  wire        rst,
    // Wishbone / RISC-V Memory Bus Slave Interface
    input  wire [63:0] addr,
    input  wire [63:0] wdata,
    input  wire        we,
    input  wire        re,
    input  wire [7:0]  be,
    output reg  [63:0] rdata,
    // Co-Processor Status and Interrupt Lines
    output reg         rocm_kernel_active,
    output reg         rocm_irq
);

    // Address Matching for 0x8000_0000 - 0x8000_00FF
    wire addr_match = ((addr[63:32] == 32'h0000_0000) || (addr[63:32] == 32'hFFFF_FFFF)) &&
                      (addr[31:8]  == 24'h800000);

    wire [7:0] offset = addr[7:0];

    // Internal 64-Byte AQL Kernel Dispatch Packet Storage (8 x 64-bit words)
    reg [63:0] aql_pkt [0:7];

    // Doorbell, Status, and Vector Accumulator Registers
    reg [31:0] doorbell_reg;
    reg [63:0] cycle_counter;
    reg [63:0] sim_vector_acc [0:3];
    reg [31:0] work_remaining;

    // Co-Processor State Machine
    localparam STATE_IDLE     = 2'd0;
    localparam STATE_COMPUTE  = 2'd1;
    localparam STATE_COMPLETE = 2'd2;

    reg [1:0] state;

    integer i;

    // Synchronous Write Logic and Co-Processor State Machine
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1) begin
                aql_pkt[i] <= 64'h0;
            end
            doorbell_reg       <= 32'h0;
            cycle_counter      <= 64'h0;
            sim_vector_acc[0]  <= 64'h0;
            sim_vector_acc[1]  <= 64'h0;
            sim_vector_acc[2]  <= 64'h0;
            sim_vector_acc[3]  <= 64'h0;
            work_remaining     <= 32'h0;
            state              <= STATE_IDLE;
            rocm_kernel_active <= 1'b0;
            rocm_irq           <= 1'b0;
        end else begin
            // Handle Memory-Mapped Slave Writes for Register Storage
            if (we && addr_match) begin
                if (offset < 8'h40) begin
                    // Write to 64-byte AQL Dispatch Packet with Byte Enables
                    if (be[0]) aql_pkt[offset[5:3]][7:0]   <= wdata[7:0];
                    if (be[1]) aql_pkt[offset[5:3]][15:8]  <= wdata[15:8];
                    if (be[2]) aql_pkt[offset[5:3]][23:16] <= wdata[23:16];
                    if (be[3]) aql_pkt[offset[5:3]][31:24] <= wdata[31:24];
                    if (be[4]) aql_pkt[offset[5:3]][39:32] <= wdata[39:32];
                    if (be[5]) aql_pkt[offset[5:3]][47:40] <= wdata[47:40];
                    if (be[6]) aql_pkt[offset[5:3]][55:48] <= wdata[55:48];
                    if (be[7]) aql_pkt[offset[5:3]][63:56] <= wdata[63:56];
                end else if (offset == `ROCM_REG_DOORBELL) begin
                    doorbell_reg <= wdata[31:0];
                end
            end

            // High Priority Reset Command Check
            if (we && addr_match && (offset == `ROCM_REG_CTRL) && wdata[1]) begin
                state              <= STATE_IDLE;
                rocm_kernel_active <= 1'b0;
                rocm_irq           <= 1'b0;
            end else begin
                // Co-Processor SIMD Execution State Machine
                case (state)
                    STATE_IDLE: begin
                        if (we && addr_match && (offset == `ROCM_REG_DOORBELL)) begin
                            state              <= STATE_COMPUTE;
                            rocm_kernel_active <= 1'b1;
                            rocm_irq           <= 1'b0;
                            // Set compute latency based on grid_size_x (default to 16 cycles)
                            if (aql_pkt[1][63:32] > 0) begin
                                work_remaining <= (aql_pkt[1][63:32] > 64) ? 32'd64 : aql_pkt[1][63:32];
                            end else begin
                                work_remaining <= 32'd16;
                            end
                        end else begin
                            rocm_kernel_active <= 1'b0;
                            rocm_irq           <= 1'b0;
                        end
                    end

                    STATE_COMPUTE: begin
                        rocm_kernel_active <= 1'b1;
                        rocm_irq           <= 1'b0;
                        cycle_counter      <= cycle_counter + 64'd1;

                        // Execute Simulated SIMD Vector Arithmetic using AQL parameters
                        sim_vector_acc[0]  <= sim_vector_acc[0] + {16'h0, aql_pkt[0][47:32]} + 64'd1;
                        sim_vector_acc[1]  <= sim_vector_acc[1] + {16'h0, aql_pkt[0][63:48]} + 64'd2;
                        sim_vector_acc[2]  <= sim_vector_acc[2] + {16'h0, aql_pkt[1][15:0]}  + 64'd3;
                        sim_vector_acc[3]  <= sim_vector_acc[3] + aql_pkt[1][63:32]         + 64'd4;

                        if (work_remaining <= 32'd1) begin
                            state              <= STATE_COMPLETE;
                            rocm_kernel_active <= 1'b0;
                            rocm_irq           <= 1'b1;
                        end else begin
                            work_remaining <= work_remaining - 32'd1;
                        end
                    end

                    STATE_COMPLETE: begin
                        rocm_kernel_active <= 1'b0;
                        if (we && addr_match && (offset == `ROCM_REG_IRQ_ACK || offset == `ROCM_REG_DOORBELL)) begin
                            rocm_irq <= 1'b0;
                            if (offset == `ROCM_REG_DOORBELL) begin
                                state              <= STATE_COMPUTE;
                                rocm_kernel_active <= 1'b1;
                                if (aql_pkt[1][63:32] > 0) begin
                                    work_remaining <= (aql_pkt[1][63:32] > 64) ? 32'd64 : aql_pkt[1][63:32];
                                end else begin
                                    work_remaining <= 32'd16;
                                end
                            end else begin
                                state <= STATE_IDLE;
                            end
                        end else begin
                            rocm_irq <= 1'b1;
                        end
                    end

                    default: begin
                        state              <= STATE_IDLE;
                        rocm_kernel_active <= 1'b0;
                        rocm_irq           <= 1'b0;
                    end
                endcase
            end
        end
    end

    // Combinational Read Interface for Low-Latency Peripheral Access
    always @(*) begin
        rdata = 64'h0;
        if (re && addr_match) begin
            if (offset < 8'h40) begin
                rdata = aql_pkt[offset[5:3]];
            end else begin
                case (offset)
                    `ROCM_REG_DOORBELL:    rdata = {32'h0, doorbell_reg};
                    `ROCM_REG_STATUS:      rdata = {cycle_counter[31:0], 29'h0, (state == STATE_COMPLETE), rocm_irq, rocm_kernel_active};
                    `ROCM_REG_IRQ_ACK:     rdata = {63'h0, rocm_irq};
                    `ROCM_REG_VECTOR_ACC0: rdata = sim_vector_acc[0];
                    `ROCM_REG_VECTOR_ACC1: rdata = sim_vector_acc[1];
                    `ROCM_REG_VECTOR_ACC2: rdata = sim_vector_acc[2];
                    `ROCM_REG_VECTOR_ACC3: rdata = sim_vector_acc[3];
                    default:               rdata = 64'h0;
                endcase
            end
        end
    end

endmodule
