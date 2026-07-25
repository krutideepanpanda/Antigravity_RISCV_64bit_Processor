// ============================================================================
// ROCm / HSA AQL Kernel Dispatch Hardware Verification Testbench
// Instantiates rv64i_rocm_accelerator, simulates a RISC-V host CPU writing an
// AQL dispatch packet and ringing the doorbell, verifies simulated SIMD
// vector execution, completion interrupt assertion, and IRQ acknowledgement.
// ============================================================================
`default_nettype none
`timescale 1ns / 1ps

`include "rocm_dispatch_pkt.vh"

module tb_rocm_dispatch;

    // Clock and Reset Signals
    reg         clk;
    reg         rst;

    // Memory-Mapped Bus Interface
    reg  [63:0] addr;
    reg  [63:0] wdata;
    reg         we;
    reg         re;
    reg  [7:0]  be;
    wire [63:0] rdata;

    // Co-Processor Status & Interrupt Signals
    wire        rocm_kernel_active;
    wire        rocm_irq;

    // Test Bench Monitoring Variables
    reg [63:0]  read_val;
    integer     cycle_count;
    reg [63:0]  vec_res0, vec_res1, vec_res2, vec_res3;

    // Instantiate RV64I ROCm Hardware Accelerator
    rv64i_rocm_accelerator u_accel (
        .clk                (clk),
        .rst                (rst),
        .addr               (addr),
        .wdata              (wdata),
        .we                 (we),
        .re                 (re),
        .be                 (be),
        .rdata              (rdata),
        .rocm_kernel_active (rocm_kernel_active),
        .rocm_irq           (rocm_irq)
    );

    // Clock Generation (100 MHz -> 10ns period)
    always #5 clk = ~clk;

    // Cycle Counter for Logging
    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
        end
    end

    // Host Memory Write Task (Simulates RISC-V CPU store instruction)
    task host_write(input [63:0] write_addr, input [63:0] write_data);
    begin
        @(posedge clk);
        addr  <= write_addr;
        wdata <= write_data;
        we    <= 1'b1;
        re    <= 1'b0;
        be    <= 8'hFF;
        @(posedge clk);
        we    <= 1'b0;
        addr  <= 64'h0;
        wdata <= 64'h0;
    end
    endtask

    // Host Memory Read Task (Simulates RISC-V CPU load instruction)
    task host_read(input [63:0] read_addr, output [63:0] read_data);
    begin
        @(posedge clk);
        addr <= read_addr;
        re   <= 1'b1;
        we   <= 1'b0;
        @(negedge clk);
        read_data = rdata;
        @(posedge clk);
        re   <= 1'b0;
        addr <= 64'h0;
    end
    endtask

    // Verification Test Sequence
    initial begin
        // Setup Waveform Dumping
        $dumpfile("verif/sim_rocm.vcd");
        $dumpvars(0, tb_rocm_dispatch);

        $display("================================================================================");
        $display("[TB_ROCM] Starting Verification of RISC-V ROCm/HSA Co-Processor Accelerator...");
        $display("================================================================================");

        // 1. Initialize Bus and Assert Reset
        clk   = 0;
        rst   = 1;
        addr  = 64'h0;
        wdata = 64'h0;
        we    = 1'b0;
        re    = 1'b0;
        be    = 8'h0;

        #30;
        rst = 0;
        $display("[TB_ROCM] [Cycle %0d] Reset released. Co-Processor IDLE.", cycle_count);

        // Verify initial state
        if (rocm_kernel_active !== 1'b0 || rocm_irq !== 1'b0) begin
            $display("[TB_ROCM] ERROR: Initial state check failed! active=%b, irq=%b", rocm_kernel_active, rocm_irq);
            $finish(1);
        end

        // 2. Host CPU Writes 64-Byte AQL Kernel Dispatch Packet (8 x 64-bit words)
        $display("[TB_ROCM] [Cycle %0d] Host CPU writing AQL Kernel Dispatch Packet to 0x8000_0000...", cycle_count);
        
        // Word 0 (0x00): header=KERNEL_DISPATCH(0x2), setup=3D(0x3), wg_x=16, wg_y=16
        host_write(64'h8000_0000, 64'h0010_0010_0003_0002);
        
        // Word 1 (0x08): wg_z=1, res0=0, grid_x=20 (Compute will run for 20 clock cycles)
        host_write(64'h8000_0008, 64'h0000_0014_0000_0001);
        
        // Word 2 (0x10): grid_y=16, grid_z=1
        host_write(64'h8000_0010, 64'h0000_0001_0000_0010);
        
        // Word 3 (0x18): private_seg_size=0, group_seg_size=1024
        host_write(64'h8000_0018, 64'h0000_0400_0000_0000);
        
        // Word 4 (0x20): kernel_object (Simulated kernel instruction pointer)
        host_write(64'h8000_0020, 64'h0000_0000_1000_4000);
        
        // Word 5 (0x28): kernarg_address (Simulated kernel argument payload pointer)
        host_write(64'h8000_0028, 64'h0000_0000_2000_8000);
        
        // Word 6 (0x30): reserved2=0
        host_write(64'h8000_0030, 64'h0000_0000_0000_0000);
        
        // Word 7 (0x38): completion_signal handle
        host_write(64'h8000_0038, 64'h0000_0000_8000_9000);

        $display("[TB_ROCM] [Cycle %0d] AQL Packet written successfully.", cycle_count);

        // Verify status register before doorbell write
        host_read(64'h8000_0048, read_val);
        $display("[TB_ROCM] [Cycle %0d] Pre-doorbell Status Register: 0x%016x", cycle_count, read_val);

        // 3. Host CPU Rings Hardware Doorbell to Launch Kernel
        $display("[TB_ROCM] [Cycle %0d] Host CPU ringing ROCm Doorbell Register (0x8000_0040) with Queue ID 1...", cycle_count);
        host_write(64'h8000_0040, 64'h0000_0000_0000_0001);

        // 4. Verify Co-Processor Transitions to ACTIVE state
        @(negedge clk);
        if (rocm_kernel_active !== 1'b1) begin
            $display("[TB_ROCM] ERROR: rocm_kernel_active failed to assert after doorbell write!");
            $finish(1);
        end
        $display("[TB_ROCM] [Cycle %0d] SUCCESS: rocm_kernel_active asserted! Simulated SIMD execution in progress...", cycle_count);

        // 5. Monitor Vector Computation and Wait for Completion Interrupt (rocm_irq)
        while (rocm_irq === 1'b0) begin
            @(negedge clk);
            if (cycle_count > 500) begin
                $display("[TB_ROCM] ERROR: Simulation TIMEOUT waiting for rocm_irq!");
                $finish(2);
            end
        end

        $display("[TB_ROCM] [Cycle %0d] SUCCESS: rocm_irq asserted! Kernel computation finished.", cycle_count);

        // Verify rocm_kernel_active deasserted when completion IRQ fired
        if (rocm_kernel_active !== 1'b0) begin
            $display("[TB_ROCM] ERROR: rocm_kernel_active should be deasserted when kernel completes!");
            $finish(1);
        end

        // 6. Read and Verify Simulated SIMD Vector Accumulators
        host_read(64'h8000_0060, vec_res0);
        host_read(64'h8000_0068, vec_res1);
        host_read(64'h8000_0070, vec_res2);
        host_read(64'h8000_0078, vec_res3);

        $display("[TB_ROCM] SIMD Vector Execution Results:");
        $display("          VEC_ACC0 (0x60) = 0x%016x", vec_res0);
        $display("          VEC_ACC1 (0x68) = 0x%016x", vec_res1);
        $display("          VEC_ACC2 (0x70) = 0x%016x", vec_res2);
        $display("          VEC_ACC3 (0x78) = 0x%016x", vec_res3);

        if (vec_res0 == 0 || vec_res1 == 0 || vec_res2 == 0 || vec_res3 == 0) begin
            $display("[TB_ROCM] ERROR: SIMD vector accumulators returned zero!");
            $finish(1);
        end

        // 7. Host CPU Acknowledges and Clears Completion Interrupt
        $display("[TB_ROCM] [Cycle %0d] Host CPU writing IRQ_ACK Register (0x8000_0050) to clear interrupt...", cycle_count);
        host_write(64'h8000_0050, 64'h0000_0000_0000_0001);

        @(negedge clk);
        if (rocm_irq !== 1'b0) begin
            $display("[TB_ROCM] ERROR: rocm_irq failed to deassert after IRQ acknowledgement!");
            $finish(1);
        end

        $display("[TB_ROCM] [Cycle %0d] SUCCESS: rocm_irq cleared and co-processor returned to IDLE.", cycle_count);
        $display("================================================================================");
        $display("[TB_ROCM] === ALL VERIFICATION TESTS PASSED SUCCESSFULLY ===");
        $display("================================================================================");

        #20;
        $finish;
    end

endmodule
