module set_associative_cache #(
  parameter int NUM_SETS = 8,
  parameter int NUM_WAYS = 4,
  parameter int BLOCK_SIZE = 32,
  parameter int TAG_SIZE = 32 - $clog2(NUM_SETS)
)(
  input logic clk_i,
  input logic rst_ni,
  input logic en_i,
  input logic [31:0] addr_i,
  input logic [31:0] wdata_i,
  input logic we_i,
  output logic [31:0] rdata_o,
  output logic hit_o
);

// Cache memory
logic [BLOCK_SIZE-1:0] cache_mem [NUM_SETS-1:0][NUM_WAYS-1:0];
logic [TAG_SIZE-1:0] tag_mem [NUM_SETS-1:0][NUM_WAYS-1:0];
logic [$clog2(NUM_WAYS)-1:0] lru_cnt_s [NUM_SETS-1:0][NUM_WAYS-1:0];
// Address decoding
logic [$clog2(NUM_SETS)-1:0] set_index_s;
logic [TAG_SIZE-1:0] tag_s;

// Replacement FSM typedef
typedef enum logic [1:0] {
  IDLE,
  READ,
  WRITE,
  REPLACE
} cache_state_t;
cache_state_t state_s;

// LRU logic
logic [$clog2(NUM_WAYS)-1:0] lru_counter [NUM_SETS-1:0];

assign set_index_s = addr_i[$clog2(NUM_SETS)-1:0];
assign tag_s = addr_i[31:$clog2(NUM_SETS)];

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    // Reset cache memory and tags
    for (int i = 0; i < NUM_SETS; i++) begin
      for (int j = 0; j < NUM_WAYS; j++) begin
        cache_mem[i][j] <= '0;
        tag_mem[i][j] <= '0;
        lru_cnt_s[i][j] <= '0;
        lru_counter[i] <= '0;
      end
    end
  end else begin
    if(en_i) begin
      if (we_i) begin
        // Write operation: find a way to write to
        for (int j = 0; j < NUM_WAYS; j++) begin
          if (tag_mem[set_index_s][j] == tag_s || tag_mem[set_index_s][j] == '0) begin
            cache_mem[set_index_s][j] <= wdata_i;
            tag_mem[set_index_s][j] <= tag_s;
            // Update LRU counter
            lru_counter[set_index_s] <= (lru_counter[set_index_s] + 1);
            break;
          end
        end
      end else begin
        // Read operation: check for hit
        hit_o <= 1'b0;
        for (int j = 0; j < NUM_WAYS; j++) begin
          if (tag_mem[set_index_s][j] == tag_s) begin
            rdata_o <= cache_mem[set_index_s][j];
            hit_o <= 1'b1;
            // Update LRU counter
            lru_counter[set_index_s] <= (lru_counter[set_index_s] + 1);
            break;
          end
        end
      end
    end
  end
end

// Additional logic for cache replacement policy
// if hit_o is low, start a read to the next level of memory (e.g., main memory) and update the cache accordingly.
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    state_s <= IDLE;
    en_RAM_o <= 1'b0;
    data_replaced_s <= 1'b0;
  end else begin
    case (state_s)
      IDLE: begin
        data_replaced_s <= 1'b0;
        en_RAM_o <= 1'b0; // Enable read from main memory
        if (en_i && !hit_o) begin
          state_s <= READ;
        end
      end
      READ: begin
        en_RAM_o <= 1'b1;
        data_replaced_s <= 1'b0;
        if(rdata_RAM_i_valid) begin
          // Write the data from main memory into the cache
          for (int j = 0; j < NUM_WAYS; j++) begin
            if (tag_mem[set_index_s][j] == '0) begin
              cache_mem[set_index_s][j] <= rdata_RAM_i;
              tag_mem[set_index_s][j] <= rdata_RAM_i[31:$clog2(NUM_SETS)];
              data_replaced_s <= 1'b1;
              break;
            end
          end
          state_s <= REPLACE;
        end
      end
      REPLACE: begin
        // Replace a way in the cache with the new data from main memory
        // This is a placeholder for actual replacement logic
        if (data_replaced_s) begin
          state_s <= IDLE;
        end else begin
          // Implement replacement LRU policy (e.g., LRU, FIFO) here
          find_lru_way(set_index_s, lru_way);
          cache_mem[set_index_s][lru_way] <= rdata_RAM_i;
          tag_mem[set_index_s][lru_way] <= rdata_RAM_i[31:$clog2(NUM_SETS)];
          data_replaced_s <= 1'b1;
          state_s <= IDLE;
        end
      end
      default: begin
        state_s <= IDLE;
      end
    endcase
  end
end

task automatic find_lru_way(input logic [$clog2(NUM_SETS)-1:0] set_index, output logic [$clog2(NUM_WAYS)-1:0] lru_way);
  // TODO: implement algoritm to find LRU
  // the algoritm shall, starting from the lru_counter[set_index], find the way with lru_cnt_s[set_index][way] == lru_counter[set_index] +1
  // that because in a rolling counter, the older way is the "farest" from the actual lru_counter[set_index] value.
  // return the way index in lru_way
endtask