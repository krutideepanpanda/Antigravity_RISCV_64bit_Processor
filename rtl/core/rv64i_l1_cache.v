// ============================================================================
// RV64I High-Speed Configurable L1 Instruction/Data Cache
// Features:
// - Configurable capacity: 4 KB / 8 KB
// - Configurable associativity: Direct-Mapped (1) or 2-Way Set-Associative (2)
// - Synchronous read hit forwarding in 1 clock cycle (zero CPU stalls on hit)
// - Write-through buffer with configurable No-Write-Allocate / Write-Allocate
// ============================================================================
`default_nettype none
`include "rv64i_types.vh"

module rv64i_l1_cache #(
    parameter int CACHE_SIZE     = 4096, // 4096 bytes (4 KB) or 8192 bytes (8 KB)
    parameter int ASSOC          = 2,    // 1 for Direct-Mapped, 2 for 2-Way Set-Associative
    parameter int LINE_SIZE      = 8,    // Line size in bytes (8, 16, or 32)
    parameter int WRITE_ALLOCATE = 0     // 0 = No-Write-Allocate, 1 = Write-Allocate
) (
    input  wire        clk,
    input  wire        rst,
    // CPU Side Interface
    input  wire        cpu_req,
    input  wire [63:0] cpu_addr,
    input  wire [63:0] cpu_wdata,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_be,
    output reg  [63:0] cpu_rdata,
    output wire        cpu_hit,
    output wire        cpu_stall,
    // Memory Side Interface
    output reg         mem_req,
    output reg  [63:0] mem_addr,
    output reg  [63:0] mem_wdata,
    output reg         mem_we,
    output reg  [7:0]  mem_be,
    input  wire [63:0] mem_rdata,
    input  wire        mem_ready
);

    // ------------------------------------------------------------------------
    // Cache Parameter Calculations
    // ------------------------------------------------------------------------
    localparam int NUM_SETS       = CACHE_SIZE / (LINE_SIZE * ASSOC);
    localparam int OFFSET_BITS    = $clog2(LINE_SIZE);
    localparam int INDEX_BITS     = $clog2(NUM_SETS);
    localparam int TAG_BITS       = 64 - INDEX_BITS - OFFSET_BITS;
    localparam int WORDS_PER_LINE = LINE_SIZE / 8;
    localparam int REFILL_BITS    = (WORDS_PER_LINE > 1) ? $clog2(WORDS_PER_LINE) : 1;

    // ------------------------------------------------------------------------
    // Write Buffer Configuration
    // ------------------------------------------------------------------------
    parameter int WRITE_BUFFER_DEPTH = 4;
    localparam int WBUF_IDX_BITS = $clog2(WRITE_BUFFER_DEPTH);

    // ------------------------------------------------------------------------
    // Cache Line Arrays (Way 0 and Way 1)
    // ------------------------------------------------------------------------
    reg [TAG_BITS-1:0]    tag_way0   [0:NUM_SETS-1];
    reg                   valid_way0 [0:NUM_SETS-1];
    reg                   dirty_way0 [0:NUM_SETS-1];
    (* ram_style = "block" *) reg [LINE_SIZE*8-1:0] data_way0  [0:NUM_SETS-1];

    reg [TAG_BITS-1:0]    tag_way1   [0:NUM_SETS-1];
    reg                   valid_way1 [0:NUM_SETS-1];
    reg                   dirty_way1 [0:NUM_SETS-1];
    (* ram_style = "block" *) reg [LINE_SIZE*8-1:0] data_way1  [0:NUM_SETS-1];

    reg                   lru_array  [0:NUM_SETS-1]; // 0 -> way 0 LRU, 1 -> way 1 LRU

    // ------------------------------------------------------------------------
    // Address Decoding
    // ------------------------------------------------------------------------
    wire [INDEX_BITS-1:0] index = cpu_addr[OFFSET_BITS +: INDEX_BITS];
    wire [TAG_BITS-1:0]   tag   = cpu_addr[63 : OFFSET_BITS + INDEX_BITS];

    wire [10:0] word_bit_offset = (LINE_SIZE == 8)  ? 11'd0 :
                                  (LINE_SIZE == 16) ? (cpu_addr[3] ? 11'd64 : 11'd0) :
                                  (LINE_SIZE == 32) ? (cpu_addr[4:3] * 11'd64) : 11'd0;

    // ------------------------------------------------------------------------
    // Hit Detection & Synchronous 1-Cycle Read Hit Forwarding
    // ------------------------------------------------------------------------
    wire hit_w0 = valid_way0[index] && (tag_way0[index] == tag);
    wire hit_w1 = (ASSOC == 2) && valid_way1[index] && (tag_way1[index] == tag);
    wire hit    = cpu_req && (hit_w0 || hit_w1);

    assign cpu_hit = hit;

    wire [63:0] line_w0_word = (LINE_SIZE == 8)  ? data_way0[index][63:0] :
                               (LINE_SIZE == 16) ? (cpu_addr[3] ? data_way0[index][127:64] : data_way0[index][63:0]) :
                               (LINE_SIZE == 32) ? (data_way0[index][cpu_addr[4:3] * 64 +: 64]) :
                               data_way0[index][63:0];

    wire [63:0] line_w1_word = (LINE_SIZE == 8)  ? data_way1[index][63:0] :
                               (LINE_SIZE == 16) ? (cpu_addr[3] ? data_way1[index][127:64] : data_way1[index][63:0]) :
                               (LINE_SIZE == 32) ? (data_way1[index][cpu_addr[4:3] * 64 +: 64]) :
                               data_way1[index][63:0];

    always @(*) begin
        if (hit_w0)      cpu_rdata = line_w0_word;
        else if (hit_w1) cpu_rdata = line_w1_word;
        else             cpu_rdata = 64'h0;
    end

    // ------------------------------------------------------------------------
    // Cache Controller FSM States and Registers
    // ------------------------------------------------------------------------
    localparam [1:0] STATE_IDLE      = 2'd0;
    localparam [1:0] STATE_DRAIN_BUF = 2'd1;
    localparam [1:0] STATE_REFILL    = 2'd2;
    localparam [1:0] STATE_ALLOC_WR  = 2'd3;

    reg [1:0]               fsm_state;
    reg [REFILL_BITS-1:0]   refill_cnt;
    reg [63:0]              miss_addr;
    reg                     miss_we;
    reg [63:0]              miss_wdata;
    reg [7:0]               miss_be;

    wire [INDEX_BITS-1:0]   miss_idx = miss_addr[OFFSET_BITS +: INDEX_BITS];
    wire [TAG_BITS-1:0]     miss_tag = miss_addr[63 : OFFSET_BITS + INDEX_BITS];
    wire [63:0]             line_base_addr = {miss_tag, miss_idx, {OFFSET_BITS{1'b0}}};

    wire [10:0] miss_word_bit_offset = (LINE_SIZE == 8)  ? 11'd0 :
                                       (LINE_SIZE == 16) ? (miss_addr[3] ? 11'd64 : 11'd0) :
                                       (LINE_SIZE == 32) ? (miss_addr[4:3] * 11'd64) : 11'd0;

    wire victim_way = (ASSOC == 2) ? lru_array[miss_idx] : 1'b0;

    // ------------------------------------------------------------------------
    // Write Buffer FIFO Registers and Signals
    // ------------------------------------------------------------------------
    reg [63:0]              wbuf_addr [0:WRITE_BUFFER_DEPTH-1];
    reg [63:0]              wbuf_data [0:WRITE_BUFFER_DEPTH-1];
    reg [7:0]               wbuf_be   [0:WRITE_BUFFER_DEPTH-1];
    reg [WBUF_IDX_BITS:0]   wbuf_count;
    reg [WBUF_IDX_BITS-1:0] wbuf_head;
    reg [WBUF_IDX_BITS-1:0] wbuf_tail;

    wire wbuf_empty = (wbuf_count == 0);
    wire wbuf_full  = (wbuf_count == WRITE_BUFFER_DEPTH);

    // ------------------------------------------------------------------------
    // CPU Stall Logic
    // ------------------------------------------------------------------------
    wire read_miss  = cpu_req && !cpu_we && !hit;
    wire write_miss = cpu_req && cpu_we  && !hit && (WRITE_ALLOCATE == 1);
    wire cache_busy = (fsm_state != STATE_IDLE);

    assign cpu_stall = (read_miss || write_miss || cache_busy || (cpu_req && cpu_we && wbuf_full));

    wire start_miss = (fsm_state == STATE_IDLE) && (read_miss || write_miss);

    // ------------------------------------------------------------------------
    // Write Buffer Push and Pop Control
    // ------------------------------------------------------------------------
    wire normal_push = (fsm_state == STATE_IDLE) && cpu_req && cpu_we && !cpu_stall;
    wire alloc_push  = (fsm_state == STATE_ALLOC_WR);
    wire wbuf_push   = normal_push || alloc_push;

    wire [63:0] push_addr = alloc_push ? miss_addr  : cpu_addr;
    wire [63:0] push_data = alloc_push ? miss_wdata : cpu_wdata;
    wire [7:0]  push_be   = alloc_push ? miss_be    : cpu_be;

    wire serve_wbuf = (fsm_state == STATE_DRAIN_BUF) ? !wbuf_empty :
                      (fsm_state == STATE_IDLE)      ? (!wbuf_empty && !start_miss) : 1'b0;

    wire wbuf_pop   = serve_wbuf && mem_ready;

    // ------------------------------------------------------------------------
    // Memory Interface Output Arbitration
    // ------------------------------------------------------------------------
    always @(*) begin
        if (fsm_state == STATE_REFILL) begin
            mem_req   = 1'b1;
            mem_we    = 1'b0;
            mem_addr  = line_base_addr + (refill_cnt * 8);
            mem_wdata = 64'h0;
            mem_be    = 8'hFF;
        end else if (serve_wbuf) begin
            mem_req   = 1'b1;
            mem_we    = 1'b1;
            mem_addr  = wbuf_addr[wbuf_head];
            mem_wdata = wbuf_data[wbuf_head];
            mem_be    = wbuf_be[wbuf_head];
        end else begin
            mem_req   = 1'b0;
            mem_we    = 1'b0;
            mem_addr  = 64'h0;
            mem_wdata = 64'h0;
            mem_be    = 8'h0;
        end
    end

    // ------------------------------------------------------------------------
    // Sequential Control Logic
    // ------------------------------------------------------------------------
    integer idx, i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fsm_state  <= STATE_IDLE;
            refill_cnt <= 0;
            miss_addr  <= 64'h0;
            miss_we    <= 1'b0;
            miss_wdata <= 64'h0;
            miss_be    <= 8'h0;
            wbuf_count <= 0;
            wbuf_head  <= 0;
            wbuf_tail  <= 0;
            for (idx = 0; idx < NUM_SETS; idx = idx + 1) begin
                valid_way0[idx] <= 1'b0;
                valid_way1[idx] <= 1'b0;
                dirty_way0[idx] <= 1'b0;
                dirty_way1[idx] <= 1'b0;
                lru_array[idx]  <= 1'b0;
            end
        end else begin
            // Write Buffer Pointer and Counter Update
            if (wbuf_push && !wbuf_pop) begin
                wbuf_count <= wbuf_count + 1;
                wbuf_tail  <= (wbuf_tail == WRITE_BUFFER_DEPTH - 1) ? 0 : wbuf_tail + 1;
            end else if (!wbuf_push && wbuf_pop) begin
                wbuf_count <= wbuf_count - 1;
                wbuf_head  <= (wbuf_head == WRITE_BUFFER_DEPTH - 1) ? 0 : wbuf_head + 1;
            end else if (wbuf_push && wbuf_pop) begin
                wbuf_tail  <= (wbuf_tail == WRITE_BUFFER_DEPTH - 1) ? 0 : wbuf_tail + 1;
                wbuf_head  <= (wbuf_head == WRITE_BUFFER_DEPTH - 1) ? 0 : wbuf_head + 1;
            end

            // Write Buffer Push Storage
            if (wbuf_push) begin
                wbuf_addr[wbuf_tail] <= push_addr;
                wbuf_data[wbuf_tail] <= push_data;
                wbuf_be[wbuf_tail]   <= push_be;
            end

            // Cache Line Update on Store Hit or LRU Update on Read Hit
            if (fsm_state == STATE_IDLE && cpu_req && !cpu_stall && hit) begin
                if (cpu_we) begin
                    if (hit_w0) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            if (cpu_be[i]) data_way0[index][word_bit_offset + 8*i +: 8] <= cpu_wdata[8*i +: 8];
                        end
                        lru_array[index] <= 1'b1;
                    end else if (hit_w1) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            if (cpu_be[i]) data_way1[index][word_bit_offset + 8*i +: 8] <= cpu_wdata[8*i +: 8];
                        end
                        lru_array[index] <= 1'b0;
                    end
                end else begin
                    if (hit_w0)      lru_array[index] <= 1'b1;
                    else if (hit_w1) lru_array[index] <= 1'b0;
                end
            end

            // Main Cache Controller FSM
            case (fsm_state)
                STATE_IDLE: begin
                    if (start_miss) begin
                        miss_addr  <= cpu_addr;
                        miss_we    <= cpu_we;
                        miss_wdata <= cpu_wdata;
                        miss_be    <= cpu_be;
                        refill_cnt <= 0;
                        if (!wbuf_empty && !(wbuf_count == 1 && wbuf_pop)) begin
                            fsm_state <= STATE_DRAIN_BUF;
                        end else begin
                            fsm_state <= STATE_REFILL;
                        end
                    end
                end

                STATE_DRAIN_BUF: begin
                    if (wbuf_empty || (wbuf_count == 1 && wbuf_pop)) begin
                        fsm_state  <= STATE_REFILL;
                        refill_cnt <= 0;
                    end
                end

                STATE_REFILL: begin
                    if (mem_ready && !mem_we) begin
                        if (!victim_way) begin
                            if (LINE_SIZE == 8) begin
                                data_way0[miss_idx] <= mem_rdata;
                            end else if (LINE_SIZE == 16) begin
                                if (refill_cnt == 0) data_way0[miss_idx][63:0]   <= mem_rdata;
                                else                 data_way0[miss_idx][127:64] <= mem_rdata;
                            end else if (LINE_SIZE == 32) begin
                                if (refill_cnt == 0)      data_way0[miss_idx][63:0]    <= mem_rdata;
                                else if (refill_cnt == 1) data_way0[miss_idx][127:64]  <= mem_rdata;
                                else if (refill_cnt == 2) data_way0[miss_idx][191:128] <= mem_rdata;
                                else                      data_way0[miss_idx][255:192] <= mem_rdata;
                            end
                        end else begin
                            if (LINE_SIZE == 8) begin
                                data_way1[miss_idx] <= mem_rdata;
                            end else if (LINE_SIZE == 16) begin
                                if (refill_cnt == 0) data_way1[miss_idx][63:0]   <= mem_rdata;
                                else                 data_way1[miss_idx][127:64] <= mem_rdata;
                            end else if (LINE_SIZE == 32) begin
                                if (refill_cnt == 0)      data_way1[miss_idx][63:0]    <= mem_rdata;
                                else if (refill_cnt == 1) data_way1[miss_idx][127:64]  <= mem_rdata;
                                else if (refill_cnt == 2) data_way1[miss_idx][191:128] <= mem_rdata;
                                else                      data_way1[miss_idx][255:192] <= mem_rdata;
                            end
                        end

                        if (refill_cnt == WORDS_PER_LINE - 1) begin
                            if (!victim_way) begin
                                tag_way0[miss_idx]   <= miss_tag;
                                valid_way0[miss_idx] <= 1'b1;
                                dirty_way0[miss_idx] <= 1'b0;
                                lru_array[miss_idx]  <= 1'b1;
                            end else begin
                                tag_way1[miss_idx]   <= miss_tag;
                                valid_way1[miss_idx] <= 1'b1;
                                dirty_way1[miss_idx] <= 1'b0;
                                lru_array[miss_idx]  <= 1'b0;
                            end

                            if (miss_we && WRITE_ALLOCATE == 1) begin
                                fsm_state <= STATE_ALLOC_WR;
                            end else begin
                                fsm_state <= STATE_IDLE;
                            end
                        end else begin
                            refill_cnt <= refill_cnt + 1;
                        end
                    end
                end

                STATE_ALLOC_WR: begin
                    if (!victim_way) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            if (miss_be[i]) data_way0[miss_idx][miss_word_bit_offset + 8*i +: 8] <= miss_wdata[8*i +: 8];
                        end
                    end else begin
                        for (i = 0; i < 8; i = i + 1) begin
                            if (miss_be[i]) data_way1[miss_idx][miss_word_bit_offset + 8*i +: 8] <= miss_wdata[8*i +: 8];
                        end
                    end
                    fsm_state <= STATE_IDLE;
                end

                default: fsm_state <= STATE_IDLE;
            endcase
        end
    end

endmodule
