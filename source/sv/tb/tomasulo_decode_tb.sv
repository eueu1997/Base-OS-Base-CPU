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
    .pc_i('0),
    .instr_o(),
    .pc_o(),
    .commit_valid_o(),
    .commit_rd_o(),
    .commit_value_o(),
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

module tomasulo_fu_tb;
  logic rst_n = 1'b0;
  logic [7:0][31:0] dispatch_instr = '0;
  logic [7:0][31:0] dispatch_pc = '0;
  logic [7:0][31:0] dispatch_source1 = '0;
  logic [7:0][31:0] dispatch_source2 = '0;
  logic [7:0][2:0] dispatch_dest = '0;
  logic [7:0] dispatch_enable = '0;
  int check_count = 0;

  riscv_id_ex_stage dut (
    .clk_i(1'b0),
    .rst_ni(rst_n),
    .valid_i(1'b1),
    .hold_i(1'b0),
    .pc_i(32'hdead0000),
    .instr_i(32'hffffffff),
    .wb_rf_we_i(1'b0),
    .wb_rf_waddr_i(1'b0),
    .wb_rf_wdata_i(1'b0),
    .wb_valid_o(), .wb_rd_o(), .wb_data_o(), .wb_we_o(),
    .pc_redirect_valid_o(), .pc_redirect_addr_o(), .illegal_instr_o(),
    .mem_req_o(), .mem_addr_o(), .mem_we_o(), .mem_width_o(),
    .mem_sign_ext_o(), .mem_wdata_o(), .load_valid_o(), .load_rd_o()
  );

  task automatic check_alu(
    input int slot,
    input logic [31:0] instruction,
    input logic [31:0] source1,
    input logic [31:0] source2,
    input logic [31:0] expected
  );
    dispatch_instr[slot] = instruction;
    dispatch_source1[slot] = source1;
    dispatch_source2[slot] = source2;
    dispatch_enable = 8'b1 << slot;
    #1;
    if (dut.u_tomasulo.result_en_i !== dispatch_enable)
      $fatal(1, "FU valid mismatch for slot %0d", slot);
    if (dut.u_tomasulo.result_value_i[slot] !== expected)
      $fatal(1, "FU %0d instr=%h result=%h expected=%h", slot,
             instruction, dut.u_tomasulo.result_value_i[slot], expected);
    if (dut.u_tomasulo.result_dest_i[slot] !== dispatch_dest[slot])
      $fatal(1, "FU tag mismatch for slot %0d", slot);
    check_count++;
  endtask

  initial begin
    force dut.fu_instr = dispatch_instr;
    force dut.fu_pc = dispatch_pc;
    force dut.fu_source1 = dispatch_source1;
    force dut.fu_source2 = dispatch_source2;
    force dut.fu_dest = dispatch_dest;
    force dut.fu_enable = dispatch_enable;
    for (int slot = 0; slot < 8; slot++) begin
      dispatch_dest[slot] = 3'(7 - slot);
      dispatch_pc[slot] = 32'h1000;
    end
    #1;
    rst_n = 1'b1;

    check_alu(0, 32'h002081b3, 32'd7, 32'd5, 32'd12);
    check_alu(1, 32'h402081b3, 32'd7, 32'd9, 32'hfffffffe);
    check_alu(2, 32'h002091b3, 32'd1, 32'd35, 32'd8);
    check_alu(2, 32'h0020d1b3, 32'h80000000, 32'd4, 32'h08000000);
    check_alu(2, 32'h4020d1b3, 32'h80000000, 32'd4, 32'hf8000000);
    check_alu(3, 32'h0020c1b3, 32'h55, 32'h0f, 32'h5a);
    check_alu(3, 32'h0020e1b3, 32'h55, 32'h0f, 32'h5f);
    check_alu(3, 32'h0020f1b3, 32'h55, 32'h0f, 32'h05);
    check_alu(4, 32'h0020a1b3, 32'hffffffff, 32'd1, 32'd1);
    check_alu(4, 32'h0020b1b3, 32'hffffffff, 32'd1, 32'd0);
    check_alu(0, 32'hfff08193, 32'd7, 32'h1234, 32'd6);
    check_alu(0, 32'hfffff1b7, 32'h1234, 32'h5678, 32'hfffff000);
    check_alu(0, 32'h00002197, 32'h1234, 32'h5678, 32'h3000);
    check_alu(2, 32'h01f09193, 32'd1, 32'd2, 32'h80000000);
    check_alu(2, 32'h01f0d193, 32'h80000000, 32'd2, 32'd1);
    check_alu(2, 32'h41f0d193, 32'h80000000, 32'd2, 32'hffffffff);
    check_alu(3, 32'hfff0c193, 32'h55, 32'h1234, 32'hffffffaa);
    check_alu(3, 32'hfff0e193, 32'h55, 32'h1234, 32'hffffffff);
    check_alu(3, 32'hfff0f193, 32'h55, 32'h1234, 32'h55);
    check_alu(4, 32'hfff0a193, 32'd0, 32'h1234, 32'd0);
    check_alu(4, 32'hfff0b193, 32'd0, 32'h1234, 32'd1);

    dispatch_enable = '1;
    #1;
    if (dut.u_tomasulo.result_en_i !== 8'h1f)
      $fatal(1, "Simultaneous ALU completion or placeholder valid mismatch");
    if (dut.u_tomasulo.result_dest_i !== dispatch_dest)
      $fatal(1, "Simultaneous result tags mismatch");
    if (dut.u_tomasulo.result_value_i[7:5] !== '0)
      $fatal(1, "Placeholder results must be zero");
    if ({dut.pc_redirect_valid_o, dut.mem_req_o, dut.mem_we_o,
         dut.load_valid_o} !== '0)
      $fatal(1, "Placeholder side effects must remain inactive");

    rst_n = 1'b0;
    #1;
    if (dut.u_tomasulo.result_en_i !== '0)
      $fatal(1, "Results must be invalid during reset");
    rst_n = 1'b1;
    dispatch_enable = '0;
    #1;
    if (dut.u_tomasulo.result_en_i !== '0)
      $fatal(1, "Disabled FUs must not complete");
    $display("PASS: %0d ALU checks plus concurrent/placeholder/reset checks", check_count);
    $finish;
  end
endmodule