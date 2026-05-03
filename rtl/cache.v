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
    // 16 sets * 4 ways per set * 16 bytes per way = 1K cache
    localparam O = 4;            // 4 bit offset => 16 byte cache line
    localparam S = 4;            // 4 bit set index => 16 sets
    localparam DEPTH = 16;       // 16 sets
    localparam W = 4;            // 4 way set associative, true LRU
    localparam T = 32 - O - S;   // 24 bit tag
    localparam integer D = 4;    // 16 bytes per line / 4 bytes per word = 4 words per line

    // The following memory arrays model the cache structure. As this is
    // an internal implementation detail, you are *free* to modify these
    // arrays as you please.

    // Backing memory, modeled as four separate ways.
    reg [   31:0] datas0 [DEPTH - 1:0][D - 1:0];
    reg [   31:0] datas1 [DEPTH - 1:0][D - 1:0];
    reg [   31:0] datas2 [DEPTH - 1:0][D - 1:0];
    reg [   31:0] datas3 [DEPTH - 1:0][D - 1:0];
    reg [T - 1:0] tags0  [DEPTH - 1:0];
    reg [T - 1:0] tags1  [DEPTH - 1:0];
    reg [T - 1:0] tags2  [DEPTH - 1:0];
    reg [T - 1:0] tags3  [DEPTH - 1:0];
    reg [DEPTH - 1:0] valid0;
    reg [DEPTH - 1:0] valid1;
    reg [DEPTH - 1:0] valid2;
    reg [DEPTH - 1:0] valid3;

    reg [1:0] age0 [DEPTH - 1:0];
    reg [1:0] age1 [DEPTH - 1:0];
    reg [1:0] age2 [DEPTH - 1:0];
    reg [1:0] age3 [DEPTH - 1:0];

    //decode incoming address and check for hits, current CPU request
    wire [O-1:0] offset = i_req_addr[O-1:0];
    wire [S-1:0] index  = i_req_addr[O+S-1:O];
    wire [T-1:0] tag    = i_req_addr[31:O+S];

    wire hit0 = valid0[index] && (tags0[index] == tag);
    wire hit1 = valid1[index] && (tags1[index] == tag);
    wire hit2 = valid2[index] && (tags2[index] == tag);
    wire hit3 = valid3[index] && (tags3[index] == tag);
    wire hit  = hit0 | hit1 | hit2 | hit3;

    wire [31:0] word0 = datas0[index][offset[3:2]];
    wire [31:0] word1 = datas1[index][offset[3:2]];
    wire [31:0] word2 = datas2[index][offset[3:2]];
    wire [31:0] word3 = datas3[index][offset[3:2]];

    wire [31:0] hit_word = hit0 ? word0 :
                           hit1 ? word1 :
                           hit2 ? word2 : word3;
    wire [1:0]  hit_way  = hit0 ? 2'd0 :
                           hit1 ? 2'd1 :
                           hit2 ? 2'd2 : 2'd3;

    wire [1:0] victim_way = (age0[index] == 2'd3) ? 2'd0 :
                            (age1[index] == 2'd3) ? 2'd1 :
                            (age2[index] == 2'd3) ? 2'd2 : 2'd3;
    wire [1:0] miss_victim_way = !valid0[index] ? 2'd0 :
                                  !valid1[index] ? 2'd1 :
                                  !valid2[index] ? 2'd2 :
                                  !valid3[index] ? 2'd3 :
                                                    victim_way;

    reg [2:0] state, next_state;
    localparam IDLE = 3'd0;
    localparam REFILL = 3'd1;
    localparam [1:0] LAST_REFILL_WORD = D - 1;

    //original request address
    reg [31:0] req_addr;
    //if original request was a write
    reg is_write;
    //word to be written to memory
    reg [31:0] req_wdata;
    //byte mask for write
    reg [3:0]  req_mask;
    // 2-bit victim way index
    reg [1:0] victim;
    //purpose of all this tracking is the 4 words per line thing
    //tracks which word address to send next during a miss refill
    reg [1:0]  refill_sent_word;
    //tracks which returned word we are currently writing back into the line.
    reg [1:0]  refill_recv_word;
    //how many requests asked for
    reg [2:0]  refill_sent_count;
    reg [31:0] refill_req_word;

    //for handling a miss, need to save the request address and data for the refill and write-through phases
    wire [S-1:0] req_index  = req_addr[O+S-1:O];
    wire [T-1:0] req_tag    = req_addr[31:O+S];
    wire [1:0]   req_word   = req_addr[3:2];
    //base address of the line being refilled
    wire [31:0] req_base_addr = {req_addr[31:O], {O{1'b0}}};
    //memory of current word getting fetched
    wire [31:0] refill_addr = req_base_addr + {28'b0, refill_sent_word, 2'b00};

    //address sent to memory
    reg [31:0] mem_addr;
    //read enable
    reg        mem_ren;
    //write enable
    reg        mem_wen;
    //data for memory writes
    reg [31:0] mem_wdata;
    reg        wt_pending;
    reg [31:0] wt_addr;
    reg [31:0] wt_wdata;
    //data to return to CPU
    reg [31:0] res_rdata;

    //drive the memory port combinationally so the cache can
    // stream requests out as soon as the memory accepts them.
    wire refill_mem_ren = (state == REFILL) && (refill_sent_count < 3'd4) && i_mem_ready;
    assign o_mem_addr = (state == REFILL) ? refill_addr : mem_addr;
    assign o_mem_ren = (state == REFILL) ? refill_mem_ren : mem_ren;
    assign o_mem_wen = mem_wen;
    assign o_mem_wdata = mem_wdata;
    assign o_res_rdata = (state == IDLE && i_req_ren && hit) ? hit_word : res_rdata;

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

    wire [1:0] idx_cur0 = age0[index];
    wire [1:0] idx_cur1 = age1[index];
    wire [1:0] idx_cur2 = age2[index];
    wire [1:0] idx_cur3 = age3[index];

    // next ages when way 0 is touched on set index
    wire [1:0] idx_nxt0_w0 = 2'd0;
    wire [1:0] idx_nxt1_w0 = (idx_cur1 < idx_cur0) ? idx_cur1 + 2'd1 : idx_cur1;
    wire [1:0] idx_nxt2_w0 = (idx_cur2 < idx_cur0) ? idx_cur2 + 2'd1 : idx_cur2;
    wire [1:0] idx_nxt3_w0 = (idx_cur3 < idx_cur0) ? idx_cur3 + 2'd1 : idx_cur3;
    // next ages when way 1 is touched on set index
    wire [1:0] idx_nxt0_w1 = (idx_cur0 < idx_cur1) ? idx_cur0 + 2'd1 : idx_cur0;
    wire [1:0] idx_nxt1_w1 = 2'd0;
    wire [1:0] idx_nxt2_w1 = (idx_cur2 < idx_cur1) ? idx_cur2 + 2'd1 : idx_cur2;
    wire [1:0] idx_nxt3_w1 = (idx_cur3 < idx_cur1) ? idx_cur3 + 2'd1 : idx_cur3;
    // next ages when way 2 is touched on set index
    wire [1:0] idx_nxt0_w2 = (idx_cur0 < idx_cur2) ? idx_cur0 + 2'd1 : idx_cur0;
    wire [1:0] idx_nxt1_w2 = (idx_cur1 < idx_cur2) ? idx_cur1 + 2'd1 : idx_cur1;
    wire [1:0] idx_nxt2_w2 = 2'd0;
    wire [1:0] idx_nxt3_w2 = (idx_cur3 < idx_cur2) ? idx_cur3 + 2'd1 : idx_cur3;
    // next ages when way 3 is touched on set index
    wire [1:0] idx_nxt0_w3 = (idx_cur0 < idx_cur3) ? idx_cur0 + 2'd1 : idx_cur0;
    wire [1:0] idx_nxt1_w3 = (idx_cur1 < idx_cur3) ? idx_cur1 + 2'd1 : idx_cur1;
    wire [1:0] idx_nxt2_w3 = (idx_cur2 < idx_cur3) ? idx_cur2 + 2'd1 : idx_cur2;
    wire [1:0] idx_nxt3_w3 = 2'd0;

    // Parallel next-age wires for req_index (used at refill completion)
    wire [1:0] req_cur0 = age0[req_index];
    wire [1:0] req_cur1 = age1[req_index];
    wire [1:0] req_cur2 = age2[req_index];
    wire [1:0] req_cur3 = age3[req_index];

    // next ages when way 0 is touched on set req_index
    wire [1:0] req_nxt0_w0 = 2'd0;
    wire [1:0] req_nxt1_w0 = (req_cur1 < req_cur0) ? req_cur1 + 2'd1 : req_cur1;
    wire [1:0] req_nxt2_w0 = (req_cur2 < req_cur0) ? req_cur2 + 2'd1 : req_cur2;
    wire [1:0] req_nxt3_w0 = (req_cur3 < req_cur0) ? req_cur3 + 2'd1 : req_cur3;
    // next ages when way 1 is touched on set req_index
    wire [1:0] req_nxt0_w1 = (req_cur0 < req_cur1) ? req_cur0 + 2'd1 : req_cur0;
    wire [1:0] req_nxt1_w1 = 2'd0;
    wire [1:0] req_nxt2_w1 = (req_cur2 < req_cur1) ? req_cur2 + 2'd1 : req_cur2;
    wire [1:0] req_nxt3_w1 = (req_cur3 < req_cur1) ? req_cur3 + 2'd1 : req_cur3;
    // next ages when way 2 is touched on set req_index
    wire [1:0] req_nxt0_w2 = (req_cur0 < req_cur2) ? req_cur0 + 2'd1 : req_cur0;
    wire [1:0] req_nxt1_w2 = (req_cur1 < req_cur2) ? req_cur1 + 2'd1 : req_cur1;
    wire [1:0] req_nxt2_w2 = 2'd0;
    wire [1:0] req_nxt3_w2 = (req_cur3 < req_cur2) ? req_cur3 + 2'd1 : req_cur3;
    // next ages when way 3 is touched on set req_index
    wire [1:0] req_nxt0_w3 = (req_cur0 < req_cur3) ? req_cur0 + 2'd1 : req_cur0;
    wire [1:0] req_nxt1_w3 = (req_cur1 < req_cur3) ? req_cur1 + 2'd1 : req_cur1;
    wire [1:0] req_nxt2_w3 = (req_cur2 < req_cur3) ? req_cur2 + 2'd1 : req_cur2;
    wire [1:0] req_nxt3_w3 = 2'd0;

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
                    1'b1: next_state = IDLE;
                    default: next_state = REFILL;
                endcase
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    assign o_busy = (state != IDLE) |
                    ((i_req_ren | i_req_wen) & !hit) |
                    (i_req_wen & hit & wt_pending & ~i_mem_ready);

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
            victim <= 2'b00;
            refill_sent_word <= 2'b00;
            refill_recv_word <= 2'b00;
            refill_sent_count <= 3'b000;
            refill_req_word <= 32'b0;
            res_rdata <= 32'b0;

            valid0 <= {DEPTH{1'b0}};
            valid1 <= {DEPTH{1'b0}};
            valid2 <= {DEPTH{1'b0}};
            valid3 <= {DEPTH{1'b0}};
            // initialise ages so way 0 is MRU, way 3 is LRU
            age0[0] <= 2'd0; age1[0] <= 2'd1; age2[0] <= 2'd2; age3[0] <= 2'd3;
            age0[1] <= 2'd0; age1[1] <= 2'd1; age2[1] <= 2'd2; age3[1] <= 2'd3;
            age0[2] <= 2'd0; age1[2] <= 2'd1; age2[2] <= 2'd2; age3[2] <= 2'd3;
            age0[3] <= 2'd0; age1[3] <= 2'd1; age2[3] <= 2'd2; age3[3] <= 2'd3;
            age0[4] <= 2'd0; age1[4] <= 2'd1; age2[4] <= 2'd2; age3[4] <= 2'd3;
            age0[5] <= 2'd0; age1[5] <= 2'd1; age2[5] <= 2'd2; age3[5] <= 2'd3;
            age0[6] <= 2'd0; age1[6] <= 2'd1; age2[6] <= 2'd2; age3[6] <= 2'd3;
            age0[7] <= 2'd0; age1[7] <= 2'd1; age2[7] <= 2'd2; age3[7] <= 2'd3;
            age0[8] <= 2'd0; age1[8] <= 2'd1; age2[8] <= 2'd2; age3[8] <= 2'd3;
            age0[9] <= 2'd0; age1[9] <= 2'd1; age2[9] <= 2'd2; age3[9] <= 2'd3;
            age0[10] <= 2'd0; age1[10] <= 2'd1; age2[10] <= 2'd2; age3[10] <= 2'd3;
            age0[11] <= 2'd0; age1[11] <= 2'd1; age2[11] <= 2'd2; age3[11] <= 2'd3;
            age0[12] <= 2'd0; age1[12] <= 2'd1; age2[12] <= 2'd2; age3[12] <= 2'd3;
            age0[13] <= 2'd0; age1[13] <= 2'd1; age2[13] <= 2'd2; age3[13] <= 2'd3;
            age0[14] <= 2'd0; age1[14] <= 2'd1; age2[14] <= 2'd2; age3[14] <= 2'd3;
            age0[15] <= 2'd0; age1[15] <= 2'd1; age2[15] <= 2'd2; age3[15] <= 2'd3;

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

                        //use invalid way first, otherwise true LRU victim (age==3)
                        victim <= miss_victim_way;

                        refill_sent_word <= 2'b00;
                        refill_recv_word <= 2'b00;
                        refill_sent_count <= 3'b000;
                        refill_req_word <= 32'b0;
                    end

                    //read hit
                    if (i_req_ren & hit) begin
                        res_rdata <= hit_word;
                        // update true LRU ages for the hit way on set index
                        case (hit_way)
                            2'd0: begin age0[index] <= idx_nxt0_w0; age1[index] <= idx_nxt1_w0; age2[index] <= idx_nxt2_w0; age3[index] <= idx_nxt3_w0; end
                            2'd1: begin age0[index] <= idx_nxt0_w1; age1[index] <= idx_nxt1_w1; age2[index] <= idx_nxt2_w1; age3[index] <= idx_nxt3_w1; end
                            2'd2: begin age0[index] <= idx_nxt0_w2; age1[index] <= idx_nxt1_w2; age2[index] <= idx_nxt2_w2; age3[index] <= idx_nxt3_w2; end
                            2'd3: begin age0[index] <= idx_nxt0_w3; age1[index] <= idx_nxt1_w3; age2[index] <= idx_nxt2_w3; age3[index] <= idx_nxt3_w3; end
                            default: ;
                        endcase
                    end

                    //write hit
                    if (i_req_wen & hit) begin
                        req_addr <= i_req_addr;
                        is_write <= 1'b1;
                        req_wdata <= merged_hit_word;
                        req_mask <= i_req_mask;

                        case (hit_way)
                            2'd0: datas0[index][offset[3:2]] <= merged_hit_word;
                            2'd1: datas1[index][offset[3:2]] <= merged_hit_word;
                            2'd2: datas2[index][offset[3:2]] <= merged_hit_word;
                            2'd3: datas3[index][offset[3:2]] <= merged_hit_word;
                            default: ;
                        endcase

                        // update true LRU ages for the hit way on set index
                        case (hit_way)
                            2'd0: begin age0[index] <= idx_nxt0_w0; age1[index] <= idx_nxt1_w0; age2[index] <= idx_nxt2_w0; age3[index] <= idx_nxt3_w0; end
                            2'd1: begin age0[index] <= idx_nxt0_w1; age1[index] <= idx_nxt1_w1; age2[index] <= idx_nxt2_w1; age3[index] <= idx_nxt3_w1; end
                            2'd2: begin age0[index] <= idx_nxt0_w2; age1[index] <= idx_nxt1_w2; age2[index] <= idx_nxt2_w2; age3[index] <= idx_nxt3_w2; end
                            2'd3: begin age0[index] <= idx_nxt0_w3; age1[index] <= idx_nxt1_w3; age2[index] <= idx_nxt2_w3; age3[index] <= idx_nxt3_w3; end
                            default: ;
                        endcase

                        if (wt_pending) begin
                            if (i_mem_ready) begin
                                mem_wen <= 1'b1;
                                mem_addr <= wt_addr;
                                mem_wdata <= wt_wdata;
                                wt_addr <= i_req_addr;
                                wt_wdata <= merged_hit_word;
                            end
                        end else if (i_mem_ready) begin
                            mem_wen <= 1'b1;
                            mem_addr <= i_req_addr;
                            mem_wdata <= merged_hit_word;
                        end else begin
                            wt_pending <= 1'b1;
                            wt_addr <= i_req_addr;
                            wt_wdata <= merged_hit_word;
                        end
                    end else if (wt_pending && i_mem_ready) begin
                        mem_wen <= 1'b1;
                        mem_addr <= wt_addr;
                        mem_wdata <= wt_wdata;
                        wt_pending <= 1'b0;
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
                        case (victim)
                            2'd0: datas0[req_index][refill_recv_word] <= i_mem_rdata;
                            2'd1: datas1[req_index][refill_recv_word] <= i_mem_rdata;
                            2'd2: datas2[req_index][refill_recv_word] <= i_mem_rdata;
                            2'd3: datas3[req_index][refill_recv_word] <= i_mem_rdata;
                            default: ;
                        endcase

                        //save the specific word we originally requested so we can return it to the CPU once the refill is done.
                        if (refill_recv_word == req_word)
                            refill_req_word <= i_mem_rdata;

                        if (refill_resp_last) begin
                            //mark the line valid only after all words have arrived
                            case (victim)
                                2'd0: begin tags0[req_index] <= req_tag; valid0[req_index] <= 1'b1; end
                                2'd1: begin tags1[req_index] <= req_tag; valid1[req_index] <= 1'b1; end
                                2'd2: begin tags2[req_index] <= req_tag; valid2[req_index] <= 1'b1; end
                                2'd3: begin tags3[req_index] <= req_tag; valid3[req_index] <= 1'b1; end
                                default: ;
                            endcase
                            //newly filled way is now MRU; update true LRU ages on req_index
                            case (victim)
                                2'd0: begin age0[req_index] <= req_nxt0_w0; age1[req_index] <= req_nxt1_w0; age2[req_index] <= req_nxt2_w0; age3[req_index] <= req_nxt3_w0; end
                                2'd1: begin age0[req_index] <= req_nxt0_w1; age1[req_index] <= req_nxt1_w1; age2[req_index] <= req_nxt2_w1; age3[req_index] <= req_nxt3_w1; end
                                2'd2: begin age0[req_index] <= req_nxt0_w2; age1[req_index] <= req_nxt1_w2; age2[req_index] <= req_nxt2_w2; age3[req_index] <= req_nxt3_w2; end
                                2'd3: begin age0[req_index] <= req_nxt0_w3; age1[req_index] <= req_nxt1_w3; age2[req_index] <= req_nxt2_w3; age3[req_index] <= req_nxt3_w3; end
                                default: ;
                            endcase
                            //case of a read miss so return requested word
                            if (!is_write) begin
                                res_rdata <= (req_word == refill_recv_word) ? i_mem_rdata : refill_req_word;
                            //write miss, so merge whatever bytes getting stored into refilled word and write back
                            end else begin
                                case (victim)
                                    2'd0: datas0[req_index][req_word] <= merged_refill_word;
                                    2'd1: datas1[req_index][req_word] <= merged_refill_word;
                                    2'd2: datas2[req_index][req_word] <= merged_refill_word;
                                    2'd3: datas3[req_index][req_word] <= merged_refill_word;
                                    default: ;
                                endcase
                                req_wdata <= merged_refill_word;
                                if (wt_pending) begin
                                    if (i_mem_ready) begin
                                        mem_wen <= 1'b1;
                                        mem_addr <= wt_addr;
                                        mem_wdata <= wt_wdata;
                                        wt_addr <= req_addr;
                                        wt_wdata <= merged_refill_word;
                                    end
                                end else if (i_mem_ready) begin
                                    mem_wen <= 1'b1;
                                    mem_addr <= req_addr;
                                    mem_wdata <= merged_refill_word;
                                end else begin
                                    wt_pending <= 1'b1;
                                    wt_addr <= req_addr;
                                    wt_wdata <= merged_refill_word;
                                end
                            end
                        end

                        refill_recv_word <= refill_recv_word + 2'd1;
                    end
                end

                default: begin
                end
            endcase
        end
    end

endmodule

`default_nettype wire