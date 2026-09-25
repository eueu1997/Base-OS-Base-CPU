module cache_way #
  (
  parameter int NUM_SETS = 8,
  parameter int NUM_WAYS = 4,
  parameter int BLOCK_SIZE = 32,
  parameter int TAG_SIZE = 27
  )
  (
    input  logic clk_i,
    input  logic rst_n_i,
    input  logic we_i,
    input  logic [BLOCK_SIZE + TAG_SIZE-1:0] shift_i,
    input  logic en_i,
    input  logic prop_en_n_i,
    input  logic eq_i,
    input  logic dirty_i,         // dirty bit from upstream in shift chain
    input  logic clear_dirty_i,   // pulse to clear dirty bit after writeback
    output logic prop_en_o,
    output logic [BLOCK_SIZE + TAG_SIZE-1:0] data_o,
    output logic [BLOCK_SIZE + TAG_SIZE-1:0] shift_o,
    output logic dirty_o          // dirty bit of this way
  );

  logic [BLOCK_SIZE + TAG_SIZE-1:0] data_s;
  logic dirty_q;

  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)begin
      data_s  <= '0;
      dirty_q <= 1'b0;
    end else begin
      if (clear_dirty_i) begin
        dirty_q <= 1'b0;          // clean after writeback to RAM
      end else if(en_i && (!prop_en_n_i || we_i)) begin
        data_s  <= shift_i;
        dirty_q <= dirty_i;       // dirty bit shifts with data
      end
    end
  end

  assign prop_en_o = eq_i | prop_en_n_i;
  assign shift_o   = data_s;
  assign data_o    = data_s;
  assign dirty_o   = dirty_q;

endmodule