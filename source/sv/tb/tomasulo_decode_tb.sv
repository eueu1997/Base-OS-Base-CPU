`timescale 1ns/1ps

module tomasulo_decode_tb;
  logic [31:0] instr;
  logic illegal_instr;
  wire [7:0] rs_load;
  int check_count = 0;

  tomasulo_top dut (
    .clk_i(1'b0),
    .rst_i(1'b1),
    .intr_i(instr),
    .source_value1_o(),
    .source_value2_o(),
    .destination_o(),
    .fu_en_o(),
    .illegal_instr_o(illegal_instr),
    .result_value_i('0),
    .result_dest_i('0),
    .result_en_i('0)
  );

  for (genvar rs_index = 0; rs_index < 8; rs_index++) begin : gen_observe
    assign rs_load[rs_index] = dut.gen_rs[rs_index].rs_i.instr_load_i;
  end

  task automatic check(input logic [31:0] instruction, input logic [7:0] expected);
    instr = instruction;
    #1;
    if ((rs_load !== expected) || (illegal_instr !== (expected == 8'h00)))
      $fatal(1, "instr=%h RS loads=%h expected=%h illegal=%b",
             instruction, rs_load, expected, illegal_instr);
    check_count++;
  endtask

  initial begin
    check(32'h002081b3, 8'h01);
    check(32'h402081b3, 8'h02);
    check(32'h002091b3, 8'h04);
    check(32'h0020a1b3, 8'h10);
    check(32'h0020b1b3, 8'h10);
    check(32'h0020c1b3, 8'h08);
    check(32'h0020d1b3, 8'h04);
    check(32'h4020d1b3, 8'h04);
    check(32'h0020e1b3, 8'h08);
    check(32'h0020f1b3, 8'h08);

    check(32'hfff08193, 8'h01);
    check(32'hfff0a193, 8'h10);
    check(32'hfff0b193, 8'h10);
    check(32'hfff0c193, 8'h08);
    check(32'hfff0e193, 8'h08);
    check(32'hfff0f193, 8'h08);
    check(32'h01f09193, 8'h04);
    check(32'h01f0d193, 8'h04);
    check(32'h41f0d193, 8'h04);

    check(32'hfffff1b7, 8'h01);
    check(32'hfffff197, 8'h01);
    check(32'h008001ef, 8'h40);
    check(32'hffc081e7, 8'h40);

    check(32'h00208463, 8'h20);
    check(32'h00209463, 8'h20);
    check(32'h0020c463, 8'h20);
    check(32'h0020d463, 8'h20);
    check(32'h0020e463, 8'h20);
    check(32'h0020f463, 8'h20);

    check(32'hffc08183, 8'h80);
    check(32'hffc09183, 8'h80);
    check(32'hffc0a183, 8'h80);
    check(32'hffc0c183, 8'h80);
    check(32'hffc0d183, 8'h80);
    check(32'hfe208e23, 8'h80);
    check(32'hfe209e23, 8'h80);
    check(32'hfe20ae23, 8'h80);

    for (int upper_bits = 0; upper_bits < 128; upper_bits++) begin
      for (int subop = 0; subop < 8; subop++) begin
        if ((upper_bits != 0) &&
            !((upper_bits == 32) && ((subop == 0) || (subop == 5))))
          check({7'(upper_bits), 5'd2, 5'd1, 3'(subop), 5'd3, 7'b0110011}, 8'h00);
      end
      if (upper_bits != 0)
        check({7'(upper_bits), 5'd31, 5'd1, 3'b001, 5'd3, 7'b0010011}, 8'h00);
      if ((upper_bits != 0) && (upper_bits != 32))
        check({7'(upper_bits), 5'd31, 5'd1, 3'b101, 5'd3, 7'b0010011}, 8'h00);
    end

    check(32'h0020a463, 8'h00);
    check(32'h0020b463, 8'h00);
    check(32'h000091e7, 8'h00);
    check(32'h0000b183, 8'h00);
    check(32'h0000e183, 8'h00);
    check(32'h0000f183, 8'h00);
    check(32'h0020b023, 8'h00);
    check(32'h0020c023, 8'h00);
    check(32'h0020d023, 8'h00);
    check(32'h0020e023, 8'h00);
    check(32'h0020f023, 8'h00);
    check(32'h00000073, 8'h00);
    check(32'h0000000f, 8'h00);
    check(32'h00000000, 8'h00);
    check(32'hxxxxxxxx, 8'h00);
    check(32'h002081b3, 8'h01);

    $display("PASS: %0d Tomasulo dispatch checks", check_count);
    $finish;
  end
endmodule