`default_nettype none

module cache (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // External memory interface. See hart interface for details. This
    // interface is nearly identical to the phase 5 memory interface, with the
    // exception that the byte mask (`o_mem_mask`) has been removed. This is
    // no longer needed as the cache will only access the memory at word
    // granularity, and implement masking internally.
    input  wire        i_mem_ready,
    output wire [31:0] o_mem_addr,
    output wire        o_mem_ren,
    output wire        o_mem_wen,
    output wire [31:0] o_mem_wdata,
    input  wire [31:0] i_mem_rdata,
    input  wire        i_mem_valid,
    // Interface to CPU hart. This is nearly identical to the phase 5 hart memory
    // interface, but includes a stall signal (`o_busy`), and the input/output
    // polarities are swapped for obvious reasons.
    //
    // The CPU should use this as a stall signal for both instruction fetch
    // (IF) and memory (MEM) stages, from the instruction or data cache
    // respectively. If a memory request is made (`i_req_ren` for instruction
    // cache, or either `i_req_ren` or `i_req_wen` for data cache), this
    // should be asserted *combinationally* if the request results in a cache
    // miss.
    //
    // In case of a cache miss, the CPU must stall the respective pipeline
    // stage and deassert ren/wen on subsequent cycles, until the cache
    // deasserts `o_busy` to indicate it has serviced the cache miss. However,
    // the CPU must keep the other request lines constant. For example, the
    // CPU should not change the request address while stalling.
    output wire        o_busy,
    // 32-bit read/write address to access from the cache. This should be
    // 32-bit aligned (i.e. the two LSBs should be zero). See `i_req_mask` for
    // how to perform half-word and byte accesses to unaligned addresses.
    input  wire [31:0] i_req_addr,
    // When asserted, the cache should perform a read at the aligned address
    // specified by `i_req_addr` and return the 32-bit word at that address,
    // either immediately (i.e. combinationally) on a cache hit, or
    // synchronously on a cache miss. It is illegal to assert this and
    // `i_dmem_wen` on the same cycle.
    input  wire        i_req_ren,
    // When asserted, the cache should perform a write at the aligned address
    // specified by `i_req_addr` with the 32-bit word provided in
    // `o_req_wdata` (specified by the mask). This is necessarily synchronous,
    // but may either happen on the next clock edge (on a cache hit) or after
    // multiple cycles of latency (cache miss). As the cache is write-through
    // and write-allocate, writes must be applied to both the cache and
    // underlying memory.
    // It is illegal to assert this and `i_dmem_ren` on the same cycle.
    input  wire        i_req_wen,
    // The memory interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    input  wire [ 3:0] i_req_mask,
    // The 32-bit word to write to memory, if the request is a write
    // (i_req_wen is asserted). Only the bytes corresponding to set bits in
    // the mask should be written into the cache (and to backing memory).
    input  wire [31:0] i_req_wdata,
    // THe 32-bit data word read from memory on a read request.
    output wire [31:0] o_res_rdata
);
    // These parameters are equivalent to those provided in the project
    // 6 specification. Feel free to use them, but hardcoding these numbers
    // rather than using the localparams is also permitted, as long as the
    // same values are used (and consistent with the project specification).
    //
    // 64 ways * 16 bytes per way = 1K cache
    localparam O = 4;            // 4 bit offset => 16 byte cache line
    localparam W = 64;           // 64 way fully associative, true LRU
    localparam T = 32 - O;       // 28 bit tag
    localparam integer D = 4;    // 16 bytes per line / 4 bytes per word = 4 words per line
    localparam WBITS = 6;        // log2(64) = 6

    // The following memory arrays model the cache structure. As this is
    // an internal implementation detail, you are *free* to modify these
    // arrays as you please.

    // Backing memory, modeled as 64 fully associative ways.
    reg [   31:0] datas [W - 1:0][D - 1:0];
    reg [T - 1:0] tags  [W - 1:0];
    reg            valid [W - 1:0];
    reg [WBITS-1:0] lru [W - 1:0];

    // Fill in your implementation here.
    // MODIFIED FSM: 
    // IDLE ──(miss)──> UPDATE_CACHE_REQ ──(mem_ready)──> UPDATE_CACHE_WAIT
    // ^                                                       │
    // │<──────────────(last word, read miss)──────────────────┤
    // │                                                       │
    // │<──(mem_ready)──── WRITE_THROUGH ◄──(last word, write)─┘

    //decode incoming address and check for hits, current CPU request
    wire [O-1:0] offset = i_req_addr[O-1:0];
    wire [T-1:0] tag    = i_req_addr[31:O];

    wire hit0;
    wire hit1;
    wire [31:0] word0;
    wire [31:0] word1;

    wire            hit_vec  [W - 1:0];
    wire [31:0]     data_vec [W - 1:0];
    wire [W - 1:0]  hit_bits;

    genvar g;
    generate
        for (g = 0; g < W; g = g + 1) begin : gen_hit
            assign hit_vec[g] = valid[g] && (tags[g] == tag);
            assign data_vec[g] = datas[g][offset[3:2]];
            assign hit_bits[g] = hit_vec[g];
        end
    endgenerate

    wire hit = |hit_bits;

    wire [WBITS - 1:0] hit_way_chain [W - 1:0];
    wire [WBITS - 1:0] hit_way;
    assign hit_way_chain[0] = {WBITS{1'b0}};
    generate
        for (g = 1; g < W; g = g + 1) begin : gen_hit_way
            assign hit_way_chain[g] = hit_vec[g] ? g[WBITS - 1:0] :
                                      hit_way_chain[g - 1];
        end
    endgenerate
    assign hit_way = hit_way_chain[W - 1];

    wire [31:0] hit_masked [W - 1:0];
    generate
        for (g = 0; g < W; g = g + 1) begin : gen_mask
            assign hit_masked[g] = {32{hit_vec[g]}} & data_vec[g];
        end
    endgenerate

    wire [31:0] hit_data_chain [W - 1:0];
    wire [31:0] hit_data;
    assign hit_data_chain[0] = hit_masked[0];
    generate
        for (g = 1; g < W; g = g + 1) begin : gen_hit_data
            assign hit_data_chain[g] = hit_data_chain[g - 1] | hit_masked[g];
        end
    endgenerate
    assign hit_data = hit_data_chain[W - 1];

    assign hit0 = hit;
    assign hit1 = 1'b0;
    assign word0 = hit_data;
    assign word1 = 32'b0;

    reg [2:0] state, next_state;
    localparam IDLE = 3'd0;
    localparam REFILL = 3'd1;
    localparam WRITE_THROUGH = 3'd3;
    localparam [1:0] LAST_REFILL_WORD = D - 1;

    //original request address
    reg [31:0] req_addr;
    //if original request was a write
    reg is_write;
    //word to be written to memory
    reg [31:0] req_wdata;
    //byte mask for write
    reg [3:0]  req_mask;
    reg [WBITS - 1:0] victim;
    //purpose of all this tracking is the 4 words per line thing
    //tracks which word address to send next during a miss refill
    reg [1:0]  refill_sent_word;
    //tracks which returned word we are currently writing back into the line.
    reg [1:0]  refill_recv_word;
    //how many requests asked for
    reg [2:0]  refill_sent_count;
    reg [31:0] refill_req_word;

    //for handling a miss, need to save the request address and data for the refill and write-through phases
    wire [T-1:0] req_tag    = req_addr[31:O];
    wire [1:0]   req_word   = req_addr[3:2];
    //base address of the line being refilled
    wire [31:0] req_base_addr = {req_addr[31:O], {O{1'b0}}};
    //memory of current word getting fetched
    wire [31:0] refill_addr = req_base_addr + {28'b0, refill_sent_word, 2'b00};

    //does there exist invalid lines
    wire [W-1:0] inv;
    wire has_invalid;
    assign has_invalid = |inv;
    wire [WBITS-1:0] invalid_way_chain [W - 1:0];
    wire [WBITS-1:0] invalid_way;

    wire [WBITS-1:0] lru_candidate [W-1:0];
    wire [WBITS-1:0] age [W-1:0];
    wire [WBITS-1:0] lru_way;
    wire [WBITS-1:0] victim_way;

    generate
        for (g = 0; g < W; g = g + 1) begin : gen_inv
            assign inv[g] = ~valid[g];
        end
    endgenerate

    assign invalid_way_chain[0] = {WBITS{1'b0}};
    generate
        for (g = 1; g < W; g = g + 1) begin : gen_invalid_way
            assign invalid_way_chain[g] = inv[g] ? g[WBITS - 1:0] :
                                          invalid_way_chain[g - 1];
        end
    endgenerate
    assign invalid_way = invalid_way_chain[W - 1];

    assign lru_candidate[0] = {WBITS{1'b0}};
    assign age[0] = lru[0];
    generate
        for (g = 1; g < W; g = g + 1) begin : gen_max_age
            assign lru_candidate[g] = (lru[g] > age[g - 1]) ? g[WBITS - 1:0] :
                                      lru_candidate[g - 1];
            assign age[g] = (lru[g] > age[g - 1]) ? lru[g] :
                                      age[g - 1];
        end
    endgenerate

    assign lru_way = lru_candidate[W - 1];
    assign victim_way = has_invalid ? invalid_way : lru_way;

    //address sent to memory
    reg [31:0] mem_addr;
    //read enable
    reg        mem_ren;
    //write enable
    reg        mem_wen;
    //data for write though
    reg [31:0] mem_wdata;
    //pending write-through queue for write hits when memory is not ready
    reg        wt_pending;
    reg [31:0] wt_addr;
    reg [31:0] wt_wdata;
    //data to return to CPU
    reg [31:0] res_rdata;

    //drive the memory port combinationally so the cache can
    // stream requests out as soon as the memory accepts them.
    wire refill_mem_ren = (state == REFILL) && (refill_sent_count < 3'd4) && i_mem_ready;
    wire write_through_mem_wen = (state == WRITE_THROUGH) && i_mem_ready;

    assign o_mem_addr = (state == REFILL) ? refill_addr :
                        (state == WRITE_THROUGH) ? req_addr :
                        mem_addr;
    assign o_mem_ren = (state == REFILL) ? refill_mem_ren : mem_ren;
    assign o_mem_wen = (state == WRITE_THROUGH) ? write_through_mem_wen : mem_wen;
    assign o_mem_wdata = (state == WRITE_THROUGH) ? req_wdata : mem_wdata;
    assign o_res_rdata = (state == IDLE && i_req_ren && hit) ? (hit0 ? word0 : word1) : res_rdata;

    wire [31:0] hit_word = hit0 ? word0 : word1;
    wire [31:0] merged_hit_word = {
        i_req_mask[3] ? i_req_wdata[31:24] : hit_word[31:24],
        i_req_mask[2] ? i_req_wdata[23:16] : hit_word[23:16],
        i_req_mask[1] ? i_req_wdata[15:8]  : hit_word[15:8],
        i_req_mask[0] ? i_req_wdata[7:0]   : hit_word[7:0]
    };
    wire [31:0] refill_base_word = (req_word == refill_recv_word) ? i_mem_rdata : refill_req_word;
    wire [31:0] merged_refill_word = {
        req_mask[3] ? req_wdata[31:24] : refill_base_word[31:24],
        req_mask[2] ? req_wdata[23:16] : refill_base_word[23:16],
        req_mask[1] ? req_wdata[15:8]  : refill_base_word[15:8],
        req_mask[0] ? req_wdata[7:0]   : refill_base_word[7:0]
    };

    //requeset is sent out to memory
    wire refill_req_fire = refill_mem_ren;
    //response back from memory
    wire refill_resp_fire = (state == REFILL) && i_mem_valid;
    //received last word of the cache line being refilled
    wire refill_resp_last = refill_resp_fire && (refill_recv_word == LAST_REFILL_WORD);

    generate
        for (g = 0; g < W; g = g + 1) begin : gen_way_reg
            always @(posedge i_clk) begin
                if (i_rst) begin
                    valid[g] <= 1'b0;
                    lru[g] <= g[WBITS - 1:0];
                end else begin
                    if ((state == IDLE) && i_req_wen && hit && (g[WBITS - 1:0] == hit_way))
                        datas[g][offset[3:2]] <= merged_hit_word;
                    if ((state == REFILL) && refill_resp_fire && (g[WBITS - 1:0] == victim)) begin
                        datas[g][refill_recv_word] <=
                            (refill_resp_last && is_write && (req_word == refill_recv_word)) ?
                            merged_refill_word : i_mem_rdata;
                        if (refill_resp_last && is_write && (req_word != refill_recv_word))
                            datas[g][req_word] <= merged_refill_word;
                    end
                    if ((state == REFILL) && refill_resp_last && (g[WBITS - 1:0] == victim)) begin
                        tags[g] <= req_tag;
                        valid[g] <= 1'b1;
                    end
                    if (((state == IDLE) && ((i_req_ren | i_req_wen) & hit)) ||
                        ((state == REFILL) && refill_resp_last)) begin
                        lru[g] <= (((state == IDLE) && (g[WBITS - 1:0] == hit_way)) ||
                                   ((state == REFILL) && (g[WBITS - 1:0] == victim))) ? {WBITS{1'b0}} :
                                  (valid[g] ? (lru[g] + {{(WBITS - 1){1'b0}}, 1'b1}) : lru[g]);
                    end
                end
            end
        end
    endgenerate

    //next state logic, combinational
    always @* begin
        next_state = state;
        case (state)
            IDLE: begin
                case (((i_req_ren | i_req_wen) & !hit))
                    1'b1: next_state = REFILL;
                    default: next_state = IDLE;
                endcase
            end
            REFILL: begin
                case (refill_resp_last)
                    1'b1: begin
                        case (is_write)
                            1'b1: next_state = WRITE_THROUGH;
                            default: next_state = IDLE;
                        endcase
                    end
                    default: next_state = REFILL;
                endcase
            end
            //write to memory
            WRITE_THROUGH: begin
                case (i_mem_ready)
                    1'b1: next_state = IDLE;
                    default: next_state = WRITE_THROUGH;
                endcase
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    assign o_busy = (state != IDLE) | ((i_req_ren | i_req_wen) & !hit);

    //sequential logic
    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= IDLE;
            mem_ren <= 1'b0;
            mem_wen <= 1'b0;
            mem_addr <= 32'b0;
            mem_wdata <= 32'b0;
            wt_pending <= 1'b0;
            wt_addr <= 32'b0;
            wt_wdata <= 32'b0;
            req_addr <= 32'b0;
            is_write <= 1'b0;
            req_wdata <= 32'b0;
            req_mask <= 4'b0;
            victim <= 1'b0;
            refill_sent_word <= 2'b00;
            refill_recv_word <= 2'b00;
            refill_sent_count <= 3'b000;
            refill_req_word <= 32'b0;
            res_rdata <= 32'b0;

        end else begin
            state <= next_state;
            mem_ren <= 1'b0;
            mem_wen <= 1'b0;

            case (state)
                IDLE: begin
                    if ((i_req_ren | i_req_wen) & !hit) begin
                        req_addr <= i_req_addr;
                        is_write <= i_req_wen;
                        req_wdata <= i_req_wdata;
                        req_mask <= i_req_mask;

                        //use invalid way first, otherwise true LRU
                        victim <= victim_way;

                        refill_sent_word <= 2'b00;
                        refill_recv_word <= 2'b00;
                        refill_sent_count <= 3'b000;
                        refill_req_word <= 32'b0;
                    end

                    //read hit
                    if (i_req_ren & hit) begin
                        res_rdata <= hit0 ? word0 : word1;
                        // update LRU
                    end

                    //write hit
                    if (i_req_wen & hit) begin
                        req_addr <= i_req_addr;
                        is_write <= 1'b1;
                        req_wdata <= merged_hit_word;
                        req_mask <= i_req_mask;

                        //if memory is busy, queue one pending write.
                        if (wt_pending) begin
                            if (i_mem_ready) begin
                                mem_wen <= 1'b1;
                                mem_addr <= wt_addr;
                                mem_wdata <= wt_wdata;
                                wt_pending <= 1'b1;
                                wt_addr <= i_req_addr;
                                wt_wdata <= merged_hit_word;
                            end
                        end else begin
                            if (i_mem_ready) begin
                                mem_wen <= 1'b1;
                                mem_addr <= i_req_addr;
                                mem_wdata <= merged_hit_word;
                            end else begin
                                wt_pending <= 1'b1;
                                wt_addr <= i_req_addr;
                                wt_wdata <= merged_hit_word;
                            end
                        end
                    end else begin
                        //consume pending write-through when memory can accept it.
                        if (!((i_req_ren | i_req_wen) & !hit) && wt_pending && i_mem_ready) begin
                            mem_wen <= 1'b1;
                            mem_addr <= wt_addr;
                            mem_wdata <= wt_wdata;
                            wt_pending <= 1'b0;
                        end
                    end
                end

                REFILL: begin
                    if (refill_req_fire) begin
                        //send the next word request without waiting for the previous word's response to come back first
                        refill_sent_word <= refill_sent_word + 2'd1;
                        refill_sent_count <= refill_sent_count + 3'd1;
                    end

                    if (refill_resp_fire) begin
                        //write each returning word into the victim way as it arrives
                        //save the specific word we originally requested so we can return it to the CPU once the refill is done.
                        if (refill_recv_word == req_word)
                            refill_req_word <= i_mem_rdata;

                        if (refill_resp_last) begin
                            //mark the line valid only after all words have arrived
                            //other way is now LRU
                            //case of a read miss so return requested word 
                            if (!is_write) begin
                                res_rdata <= (req_word == refill_recv_word) ? i_mem_rdata : refill_req_word;
                            //write miss, so merge whatever bytes getting stored into refilled word and write back
                            end else begin
                                req_wdata <= merged_refill_word;
                            end
                        end

                        refill_recv_word <= refill_recv_word + 2'd1;
                    end
                end

                WRITE_THROUGH: begin
                    mem_addr <= req_addr;
                    mem_wdata <= req_wdata;
                end
                default: begin
                end
            endcase
        end
    end

endmodule

`default_nettype wire