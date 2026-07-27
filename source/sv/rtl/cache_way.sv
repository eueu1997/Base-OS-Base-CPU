module cache_way #
  (
  parameter int NUM_SETS = 8,
  parameter int NUM_WAYS = 4,
  parameter int BLOCK_SIZE = 32,
  parameter int TAG_SIZE = BLOCK_SIZE - $clog2(NUM_SETS)
  )
  (
    input  logic clk_i,
    input  logic rst_n_i,
    input  logic we_i,
    input  logic [BLOCK_SIZE + TAG_SIZE-1:0] shift_i,
    input  logic en_i,
    input  logic prop_en_n_i,
    input  logic eq_i,
    output logic prop_en_o,
    output logic [BLOCK_SIZE + TAG_SIZE-1:0] data_o,
    output logic [BLOCK_SIZE + TAG_SIZE-1:0] shift_o
  );

  logic [BLOCK_SIZE + TAG_SIZE-1:0] data_s;

  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)begin
      data_s <= '0;
    end else begin
      if(en_i && (!prop_en_n_i || we_i))
        data_s <= shift_i;
    end
  end

  assign prop_en_o = eq_i | prop_en_n_i;
  assign shift_o = data_s;
  assign data_o = data_s;

endmodule