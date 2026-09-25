`timescale 1ns/1ps

module tomasulo_top_tb;
  localparam time CLK_PERIOD = 10ns;
  localparam int INSTRUCTION_COUNT = 50;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic [31:0] instr = '0;
  logic [31:0] pc = 32'h00001000;
  int instruction_index;

  logic [31:0] instruction_stream [0:INSTRUCTION_COUNT-1] = '{
    32'hfff08193,
    32'h0020c1b3,
    32'hffc0a183,
    32'h402081b3,
    32'h00208463,
    32'h01f09193,
    32'hfffff1b7,
    32'hfe208e23,
    32'h0020b1b3,
    32'h008001ef,
    32'h002081b3,
    32'hfff0e193,
    32'h0020d1b3,
    32'hffc09183,
    32'h00209463,
    32'hfff0a193,
    32'hffc081e7,
    32'h0020f1b3,
    32'hfe20ae23,
    32'hfffff197,
    32'h4020d1b3,
    32'hffc0c183,
    32'h0020c463,
    32'hfff0c193,
    32'h002091b3,
    32'hfff0b193,
    32'hfe209e23,
    32'h0020e1b3,
    32'hffc0d183,
    32'h0020d463,
    32'h01f0d193,
    32'hfff0f193,
    32'h0020a1b3,
    32'hffc08183,
    32'h0020e463,
    32'h41f0d193,
    32'h0020f463,
    32'h00500093,
    32'h00300113,
    32'h001101b3,
    32'h40110233,
    32'h00111293,
    32'h00116333,
    32'h001123b3,
    32'h00408463,
    32'h010002ef,
    32'h00012303,
    32'h00312223,
    32'h000023b7,
    32'h00002417
  };

  tomasulo_top u_dut (
    .clk_i(clk),
    .rst_i(rst_n),
    .intr_i(instr),
    .pc_i(pc),
    .source_value1_o(),
    .source_value2_o(),
    .destination_o(),
    .fu_en_o(),
    .instr_o(),
    .pc_o(),
    .commit_valid_o(),
    .commit_rd_o(),
    .commit_value_o(),
    .illegal_instr_o(),
    .result_value_i('0),
    .result_dest_i('0),
    .result_en_i('0)
  );

  always #(CLK_PERIOD / 2) clk = ~clk;

  initial begin
    $dumpfile("tomasulo_top_tb.vcd");
    $dumpvars(0, tomasulo_top_tb);
  end

  initial begin
    repeat (5) @(negedge clk);
    rst_n = 1'b1;
    for (instruction_index = 0; instruction_index < INSTRUCTION_COUNT; instruction_index++) begin
      instr = instruction_stream[instruction_index];
      pc = 32'h00001000 + 32'(instruction_index * 4);
      @(negedge clk);
    end
    $finish;
  end
endmodule