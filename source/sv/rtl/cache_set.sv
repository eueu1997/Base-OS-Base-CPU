module cache_set #
  (
  parameter int NUM_SETS = 8,
  parameter int NUM_WAYS = 4,
  parameter int BLOCK_SIZE = 32,
  parameter int TAG_SIZE = 27  // 32-bit addr, 8 sets, 2 offset bits: 32-3-2=27
  )
  (
    input  logic clk_i,
    input  logic rst_n_i,
    input  logic en_i,
    input  logic we_i,
    input  logic [BLOCK_SIZE + TAG_SIZE-1:0] data_i,
    output logic [BLOCK_SIZE + TAG_SIZE-1:0] data_o,
    output logic miss_o,
    output logic hit_o
  );
  logic [BLOCK_SIZE + TAG_SIZE-1:0] data_s;
  logic [BLOCK_SIZE + TAG_SIZE-1:0] data_to_comp[NUM_WAYS-1:0];
  logic [BLOCK_SIZE + TAG_SIZE-1:0] shift_s[NUM_WAYS-1:0];
  logic [NUM_WAYS-1:0] prop_en_s;
  logic [NUM_WAYS-1:0] eq_s;
  // decode of way_sel_i into one-hot enable signals for each cache_way
  assign #1ns shift_s[0] = we_i ? data_i : data_o;
  // Instantiation of 4 cache_way modules
  cache_way #(
    .BLOCK_SIZE(BLOCK_SIZE),
    .TAG_SIZE  (TAG_SIZE)
  ) way0 (
    .clk_i(clk_i),
    .rst_n_i(rst_n_i),
    .shift_i(shift_s[0]),
    .we_i(we_i),
    .en_i(en_i),
    .prop_en_n_i(1'b0), // No previous prop_en_s for the first way
    .eq_i(eq_s[0]),
    .prop_en_o(prop_en_s[1]),
    .data_o(data_to_comp[0]),
    .shift_o(shift_s[1])
  );
  cache_way #(
    .BLOCK_SIZE(BLOCK_SIZE),
    .TAG_SIZE  (TAG_SIZE)
  ) way1 (
    .clk_i(clk_i),
    .rst_n_i(rst_n_i),
    .shift_i(shift_s[1]),
    .we_i(we_i),
    .en_i(en_i),
    .prop_en_n_i(prop_en_s[1]),
    .eq_i(eq_s[1]),
    .prop_en_o(prop_en_s[2]),
    .data_o(data_to_comp[1]),
    .shift_o(shift_s[2])
  );
  cache_way #(
    .BLOCK_SIZE(BLOCK_SIZE),
    .TAG_SIZE  (TAG_SIZE)
  ) way2 (
    .clk_i(clk_i),
    .rst_n_i(rst_n_i),
    .shift_i(shift_s[2]),
    .we_i(we_i),
    .en_i(en_i),
    .prop_en_n_i(prop_en_s[2]),
    .eq_i(eq_s[2]),
    .prop_en_o(prop_en_s[3]),
    .data_o(data_to_comp[2]),
    .shift_o(shift_s[3])
  );
  cache_way #(
    .BLOCK_SIZE(BLOCK_SIZE),
    .TAG_SIZE  (TAG_SIZE)
  ) way3 (
    .clk_i(clk_i),
    .rst_n_i(rst_n_i),
    .shift_i(shift_s[3]),
    .we_i(we_i),
    .en_i(en_i),
    .prop_en_n_i(prop_en_s[3]),
    .eq_i(eq_s[3]),
    .prop_en_o(), // No next prop_en_s
    .data_o(data_to_comp[3]),
    .shift_o() // No next shift_s
  );

  // TAG CHECK LOGIC: Compare the TAG portion of the input data with each way's stored TAG.
  assign eq_s[0] = en_i & (data_to_comp[0][BLOCK_SIZE + TAG_SIZE-1:BLOCK_SIZE] == data_i[BLOCK_SIZE + TAG_SIZE-1:BLOCK_SIZE]);
  assign eq_s[1] = en_i & (data_to_comp[1][BLOCK_SIZE + TAG_SIZE-1:BLOCK_SIZE] == data_i[BLOCK_SIZE + TAG_SIZE-1:BLOCK_SIZE]);
  assign eq_s[2] = en_i & (data_to_comp[2][BLOCK_SIZE + TAG_SIZE-1:BLOCK_SIZE] == data_i[BLOCK_SIZE + TAG_SIZE-1:BLOCK_SIZE]);
  assign eq_s[3] = en_i & (data_to_comp[3][BLOCK_SIZE + TAG_SIZE-1:BLOCK_SIZE] == data_i[BLOCK_SIZE + TAG_SIZE-1:BLOCK_SIZE]);

  // If all eq are 0 while reading we have a miss.
  assign hit_o = en_i & (|eq_s);
  assign miss_o = en_i & !(|eq_s);

  // Output the data of the correct tag.
  always_comb begin
    if (eq_s[0]) begin
      data_s = data_to_comp[0];
    end else if (eq_s[1]) begin
      data_s = data_to_comp[1];
    end else if (eq_s[2]) begin
      data_s = data_to_comp[2];
    end else if (eq_s[3]) begin
      data_s = data_to_comp[3];
    end else begin
      data_s = {BLOCK_SIZE + TAG_SIZE{1'b0}}; // Default value if no match
    end
  end
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      data_o <= {BLOCK_SIZE + TAG_SIZE{1'b0}};
    end else begin
      data_o <= data_s;
    end
  end

endmodule