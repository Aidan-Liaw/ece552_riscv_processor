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
    // 32 sets * 2 ways per set * 16 bytes per way = 1K cache
    localparam O = 4;            // 4 bit offset => 16 byte cache line
    localparam S = 5;            // 5 bit set index => 32 sets
    localparam DEPTH = 2 ** S;   // 32 sets
    localparam W = 2;            // 2 way set associative, NMRU
    localparam T = 32 - O - S;   // 23 bit tag
    localparam D = 2 ** O / 4;   // 16 bytes per line / 4 bytes per word = 4 words per line

    // The following memory arrays model the cache structure. As this is
    // an internal implementation detail, you are *free* to modify these
    // arrays as you please.

    // Backing memory, modeled as two separate ways.
    reg [   31:0] datas0 [DEPTH - 1:0][D - 1:0];
    reg [   31:0] datas1 [DEPTH - 1:0][D - 1:0];
    reg [T - 1:0] tags0  [DEPTH - 1:0];
    reg [T - 1:0] tags1  [DEPTH - 1:0];
    reg [1:0] valid [DEPTH - 1:0];
    reg       lru   [DEPTH - 1:0];

    // Fill in your implementation here.
    // MODIFIED FSM: 
    // IDLE ──(miss)──> UPDATE_CACHE_REQ ──(mem_ready)──> UPDATE_CACHE_WAIT
    // ^                                                       │
    // │<──────────────(last word, read miss)──────────────────┤
    // │                                                       │
    // │<──(mem_ready)──── WRITE_THROUGH ◄──(last word, write)─┘

    //decode incoming address and check for hits, current CPU request
    wire [O-1:0] offset = i_req_addr[O-1:0];
    wire [S-1:0] index  = i_req_addr[O+S-1:O];
    wire [T-1:0] tag    = i_req_addr[31:O+S];
 
    wire hit0 = valid[index][0] && (tags0[index] == tag);
    wire hit1 = valid[index][1] && (tags1[index] == tag);
    wire hit  = hit0 || hit1;
 
    wire [31:0] word0 = datas0[index][offset[3:2]];
    wire [31:0] word1 = datas1[index][offset[3:2]];

    //for handling a miss, need to save the request address and data for the refill and write-through phases
    wire [S-1:0] req_index  = req_addr[O+S-1:O];
    wire [T-1:0] req_tag    = req_addr[31:O+S];
    wire [1:0]   req_word   = req_addr[3:2];
    //base address of the line being refilled
    wire [31:0] req_base_addr = {req_addr[31:O], {O{1'b0}}};
    //memory of current word getting fetched 
    wire [31:0] refill_addr = req_base_addr + {28'b0, refill_word, 2'b00};
    
    //eh on the numbers not sure if needed
    reg [2:0] state, next_state;
    localparam IDLE = 3'd0;
    localparam UPDATE_CACHE_REQ = 3'd1;
    localparam UPDATE_CACHE_WAIT = 3'd2;
    localparam WRITE_THROUGH = 3'd3;

    //original request address
    reg [31:0] req_addr;
    //if original request was a write
    reg is_write;
    //word to be written to memory
    reg [31:0] req_wdata;
    //byte mask for write
    reg [3:0]  req_mask;
    reg victim;
    reg [1:0]  refill_word;
    reg [31:0] refill_req_word;

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

    integer i;
    integer j;

    assign o_mem_addr = mem_addr;
    assign o_mem_ren = mem_ren;
    assign o_mem_wen = mem_wen;
    assign o_mem_wdata = mem_wdata;
    assign o_res_rdata = (state == IDLE && i_req_ren && hit) ? (hit0 ? word0 : word1) : res_rdata;

    function [31:0] apply_mask;
        input [31:0] old_word;
        input [31:0] new_word;
        input [3:0] mask;
        integer b;
        begin
            for (b = 0; b < 4; b = b + 1)
                apply_mask[b*8 +: 8] = mask[b] ? new_word[b*8 +: 8] : old_word[b*8 +: 8];
        end
    endfunction

    //next state logic, combinational
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
               next_state = ((i_req_ren | i_req_wen) & !hit) ? UPDATE_CACHE_REQ :
                             IDLE;
            end
            //update the cache when ready on a miss
            UPDATE_CACHE_REQ: begin
                next_state = i_mem_ready ? UPDATE_CACHE_WAIT : UPDATE_CACHE_REQ;
            end
            //consume the refill data, writing into the cache 
            UPDATE_CACHE_WAIT: begin
                next_state = i_mem_valid ?
                             ((refill_word == (D - 1)) ? (is_write ? WRITE_THROUGH : IDLE) : UPDATE_CACHE_REQ) :
                             UPDATE_CACHE_WAIT;
            end
            //write to memory
            WRITE_THROUGH: begin
                next_state = i_mem_ready ? IDLE : WRITE_THROUGH;
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
            refill_word <= 2'b00;
            refill_req_word <= 32'b0;
            res_rdata <= 32'b0;

            for (i = 0; i < DEPTH; i = i + 1) begin
                valid[i] <= 2'b00;
                lru[i] <= 1'b0;
                tags0[i] <= {T{1'b0}};
                tags1[i] <= {T{1'b0}};
                for (j = 0; j < D; j = j + 1) begin
                    datas0[i][j] <= 32'b0;
                    datas1[i][j] <= 32'b0;
                end
            end
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

                        //use invalid way first, otherwise NMRU bit
                        if (!valid[index][0])
                            victim <= 1'b0;
                        else if (!valid[index][1])
                            victim <= 1'b1;
                        else
                            victim <= lru[index];

                        refill_word <= 2'b00;
                        refill_req_word <= 32'b0;
                    end

                    //read hit
                    if (i_req_ren & hit) begin
                        res_rdata <= hit0 ? word0 : word1;
                        // update LRU
                        lru[index] <= hit0;
                    end

                    //write hit
                    if (i_req_wen & hit) begin
                        req_addr <= i_req_addr;
                        is_write <= 1'b1;
                        req_wdata <= apply_mask(hit0 ? word0 : word1, i_req_wdata, i_req_mask);
                        req_mask <= i_req_mask;

                        if (hit0) begin
                            datas0[index][offset[3:2]] <=
                                apply_mask(word0, i_req_wdata, i_req_mask);
                        end else begin
                            datas1[index][offset[3:2]] <=
                                apply_mask(word1, i_req_wdata, i_req_mask);
                        end

                        lru[index] <= hit0;

                        //if memory is busy, queue one pending write.
                        if (wt_pending) begin
                            if (i_mem_ready) begin
                                mem_wen <= 1'b1;
                                mem_addr <= wt_addr;
                                mem_wdata <= wt_wdata;
                                wt_pending <= 1'b1;
                                wt_addr <= i_req_addr;
                                wt_wdata <= apply_mask(hit0 ? word0 : word1, i_req_wdata, i_req_mask);
                            end
                        end else begin
                            if (i_mem_ready) begin
                                mem_wen <= 1'b1;
                                mem_addr <= i_req_addr;
                                mem_wdata <= apply_mask(hit0 ? word0 : word1, i_req_wdata, i_req_mask);
                            end else begin
                                wt_pending <= 1'b1;
                                wt_addr <= i_req_addr;
                                wt_wdata <= apply_mask(hit0 ? word0 : word1, i_req_wdata, i_req_mask);
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

                //send out memory request for the missed line, and wait for ready.
                UPDATE_CACHE_REQ: begin
                    mem_ren <= i_mem_ready;
                    mem_addr <= refill_addr;
                end

                UPDATE_CACHE_WAIT: begin
                    if (i_mem_valid) begin
                        //write each returned word into victim way
                        if (victim == 1'b0)
                            datas0[req_index][refill_word] <= i_mem_rdata;
                        else
                            datas1[req_index][refill_word] <= i_mem_rdata;
                        //save the requested word as it comes in to return for read miss, and for write allocate
                        if (refill_word == req_word)
                            refill_req_word <= i_mem_rdata;
                        //on final word: set valid, update LRU, and either return read data or write allocate
                        if (refill_word == (D - 1)) begin
                            if (victim == 1'b0) begin
                                tags0[req_index] <= req_tag;
                                valid[req_index][0] <= 1'b1;
                            end else begin
                                tags1[req_index] <= req_tag;
                                valid[req_index][1] <= 1'b1;
                            end

                            //filled way was MRU, so the other way is next victim
                            lru[req_index] <= ~victim;
                            //read miss so return requested word
                            if (!is_write) begin
                                res_rdata <= (req_word == refill_word) ? i_mem_rdata : refill_req_word;
                            end else begin
                                //write allocate
                                if (victim == 1'b0) begin
                                    datas0[req_index][req_word] <=
                                        apply_mask((req_word == refill_word) ? i_mem_rdata : refill_req_word,
                                                   req_wdata, req_mask);
                                end else begin
                                    datas1[req_index][req_word] <=
                                        apply_mask((req_word == refill_word) ? i_mem_rdata : refill_req_word,
                                                   req_wdata,
                                                   req_mask);
                                end
                                //sends the correct (old data + new bytes) value to memory
                                req_wdata <= apply_mask((req_word == refill_word) ? i_mem_rdata : refill_req_word,
                                                          req_wdata, req_mask);
                            end
                        end else begin
                            refill_word <= refill_word + 2'd1;
                        end
                    end
                end

                WRITE_THROUGH: begin
                    mem_wen <= i_mem_ready;
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
