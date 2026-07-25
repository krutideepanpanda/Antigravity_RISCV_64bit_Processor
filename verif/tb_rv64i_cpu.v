// ============================================================================
// RV64I CPU Comprehensive Verification Testbench
// Instantiates processor, memory arrays, VCD dumping, and ISA checking
// ============================================================================
`default_nettype none
`timescale 1ns / 1ps

module tb_rv64i_cpu;

    // Clock and Reset
    reg clk;
    reg rst;

    // Processor Bus Signals
    wire [63:0] imem_addr;
    wire [31:0] imem_rdata;
    wire [63:0] dmem_addr;
    wire [63:0] dmem_wdata;
    wire        dmem_we;
    wire        dmem_re;
    wire [7:0]  dmem_be;
    wire [63:0] dmem_rdata;

    // Memory Arrays (4KB Instruction Mem, 8KB Data Mem)
    reg [31:0] imem [0:1023];
    reg [7:0]  dmem [0:8191];

    // Test Control Variables
    integer i;
    integer cycle_count;
    reg [255*8:1] test_hex_file;

    // Instantiate Top-Level CPU
    rv64i_cpu u_cpu (
        .clk        (clk),
        .rst        (rst),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_we    (dmem_we),
        .dmem_re    (dmem_re),
        .dmem_be    (dmem_be),
        .dmem_rdata (dmem_rdata)
    );

    // Clock Generation (100 MHz -> 10ns period)
    always #5 clk = ~clk;

    // Asynchronous Instruction Memory Read (Word aligned)
    wire [9:0] imem_idx = imem_addr[11:2];
    assign imem_rdata = (imem_addr < 64'h1000) ? imem[imem_idx] : 32'h0000_0013; // NOP if out of bounds

    // Asynchronous Data Memory Read (Byte-enable reconstructed)
    wire [12:0] dmem_idx = dmem_addr[12:0];
    assign dmem_rdata = (dmem_addr < 64'h2000) ? {
        dmem[dmem_idx+7], dmem[dmem_idx+6], dmem[dmem_idx+5], dmem[dmem_idx+4],
        dmem[dmem_idx+3], dmem[dmem_idx+2], dmem[dmem_idx+1], dmem[dmem_idx+0]
    } : 64'h0;

    // Synchronous Data Memory Write
    always @(posedge clk) begin
        if (dmem_we && (dmem_addr < 64'h2000)) begin
            if (dmem_be[0]) dmem[dmem_idx+0] <= dmem_wdata[7:0];
            if (dmem_be[1]) dmem[dmem_idx+1] <= dmem_wdata[15:8];
            if (dmem_be[2]) dmem[dmem_idx+2] <= dmem_wdata[23:16];
            if (dmem_be[3]) dmem[dmem_idx+3] <= dmem_wdata[31:24];
            if (dmem_be[4]) dmem[dmem_idx+4] <= dmem_wdata[39:32];
            if (dmem_be[5]) dmem[dmem_idx+5] <= dmem_wdata[47:40];
            if (dmem_be[6]) dmem[dmem_idx+6] <= dmem_wdata[55:48];
            if (dmem_be[7]) dmem[dmem_idx+7] <= dmem_wdata[63:56];
        end
    end

    // Testbench Initialization and Monitoring
    initial begin
        // Setup Waveform Dumping
        $dumpfile("verif/waves/cpu_sim.vcd");
        $dumpvars(0, tb_rv64i_cpu);

        clk = 0;
        rst = 1;
        cycle_count = 0;

        // Initialize memory arrays to 0
        for (i = 0; i < 1024; i = i + 1) imem[i] = 32'h0000_0013; // NOP
        for (i = 0; i < 8192; i = i + 1) dmem[i] = 8'h00;

        // Load hex test file specified via command line +test_file=<path>
        if ($value$plusargs("test_file=%s", test_hex_file)) begin
            $display("[TB] Loading instruction hex file: %0s", test_hex_file);
            $readmemh(test_hex_file, imem);
        end else begin
            $display("[TB] WARNING: No +test_file specified. Using default NOP instructions.");
        end

        // Release Reset after 5 clock cycles
        #50;
        rst = 0;
        $display("[TB] Reset released. Starting CPU simulation...");
    end

    // Cycle Counter and Pass/Fail Check
    always @(posedge clk) begin
        if (!rst) begin
            cycle_count <= cycle_count + 1;
            $display("[CYC %0d] ID_PC=%h Instr=%h | WB: we=%b rd=%0d wdata=%0d (%0h)", cycle_count, u_cpu.id_pc, u_cpu.id_instr, u_cpu.wb_reg_write, u_cpu.wb_rd_addr, u_cpu.wb_rd_data, u_cpu.wb_rd_data);
            if (dmem_we) $display("         DMEM WRITE: addr=%h wdata=%0d (%0h) be=%b", dmem_addr, dmem_wdata, dmem_wdata, dmem_be);

            // Monitor Special Memory-Mapped I/O Write for Compliance Checking
            // Address 64'h0000_0000_0000_1000 is used by test suites to signal status
            if (dmem_we && (dmem_addr == 64'h0000_0000_0000_1000)) begin
                if (dmem_wdata == 64'd1) begin
                    $display("[TB] === TEST PASSED === at cycle %0d (Status code: 1)", cycle_count);
                    $finish;
                end else begin
                    $display("[TB] === TEST FAILED === at cycle %0d (Error code: %0h)", cycle_count, dmem_wdata);
                    $finish(1);
                end
            end

            // Timeout check to prevent infinite loops in broken tests
            if (cycle_count > 5000) begin
                $display("[TB] === TEST FAILED === Timeout reached after 5000 cycles without completion signature.");
                $finish(2);
            end
        end
    end

endmodule
