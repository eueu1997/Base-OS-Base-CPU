module cache_set
  (
    input  logic clk_i,
    input  logic rst_n_i,
    input  logic [31:0] data_i,
    input  logic en_i,
    input  logic we_i,
    output logic [31:0] data_o
  );
  logic [31:0] data_s;
  logic [31:0] data_to_comp[3:0];
  logic [31:0] shift_s[3:0];
  logic [3:0] prop_en_s;
  logic [3:0] eq_s;
  // decode of way_sel_i into one-hot enable signals for each cache_way
  assign #1ns shift_s[0] = we_i ? data_i : data_o;
  // Instantiation of 4 cache_way modules
  cache_way way0 (
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
  cache_way way1 (
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
  cache_way way2 (
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
  cache_way way3 (
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

  // Equality check logic for each way
  assign eq_s[0] = en_i && (data_to_comp[0] == data_i);
  assign eq_s[1] = en_i && (data_to_comp[1] == data_i);
  assign eq_s[2] = en_i && (data_to_comp[2] == data_i);
  assign eq_s[3] = en_i && (data_to_comp[3] == data_i);

  // Output data selection logic
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
      data_s = 32'h0000_0000; // Default value if no match
    end
  end
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      data_o <= 32'h0000_0000;
    end else begin
      data_o <= data_s;
    end
  end

endmodule