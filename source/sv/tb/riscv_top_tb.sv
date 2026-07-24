`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Module      : riscv_top_tb
// File        : riscv_top_tb.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Testbench for riscv_top using the IMEM HEX test program.
// - Generates clock/reset and performs end-of-test register checks.
// -----------------------------------------------------------------------------
module riscv_top_tb;

  localparam time CLK_PERIOD = 10ns;
  localparam int  IMEM_WORDS = 1024;
  // Update this path if your simulator working directory differs.
  localparam string IMEM_HEX_FILE = "/home/spt9pad/sv-training/nodm/default/units/ressa2/source/sv/rtl/imem_hex_file.hex";

  logic clk;
  logic rst_n;
  logic illegal_instr;

  int error_count;

  // DUT instance.
  riscv_top #(
    .IMEM_WORDS    (IMEM_WORDS),
    .IMEM_HEX_FILE (IMEM_HEX_FILE)
  ) u_dut (
    .clk_i           (clk),
    .rst_ni          (rst_n),
    .illegal_instr_o (illegal_instr)
  );

  // Clock generator.
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // Reset sequence.
  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  // Register check helper.
  task automatic check_reg(input int idx, input logic [31:0] expected);
    logic [31:0] actual;
    begin
      actual = u_dut.u_riscv.u_regfile.rf_q[idx];
      if (actual !== expected) begin
        $display("[TB][ERROR] x%0d mismatch: expected=0x%08h actual=0x%08h", idx, expected, actual);
        error_count++;
      end else begin
        $display("[TB][OK]    x%0d = 0x%08h", idx, actual);
      end
    end
  endtask

  // DMEM check helper.
  task automatic check_dmem(input int addr, input logic [31:0] expected);
    logic [31:0] actual;
    begin
      actual = u_dut.u_riscv.u_wb_stage.u_dmem.dmem[addr >> 2];  // Convert byte addr to word addr
      if (actual !== expected) begin
        $display("[TB][ERROR] DMEM[0x%03h] mismatch: expected=0x%08h actual=0x%08h", addr, expected, actual);
        error_count++;
      end else begin
        $display("[TB][OK]    DMEM[0x%03h] = 0x%08h", addr, actual);
      end
    end
  endtask

  // Test sequence and checks.
  initial begin
    error_count = 0;

    // Wait reset deassertion.
    @(posedge rst_n);

    // Allow the extended test program to execute.
    repeat (220) @(posedge clk);

    // Check illegal instruction flag.
    if (illegal_instr !== 1'b0) begin
      $display("[TB][ERROR] illegal_instr_o asserted unexpectedly");
      error_count++;
    end

    $display("\n=== ALU & Control Flow Test Results ===");
    // Expected values from imem_test_sequence.md (first 32 instructions).
    check_reg(0,  32'h0000_0000);
    check_reg(1,  32'h0000_0050);
    check_reg(2,  32'h0000_0004);
    check_reg(3,  32'h0000_000c);
    check_reg(4,  32'h0000_0046);
    check_reg(5,  32'h0000_0046);
    check_reg(6,  32'h0000_0000);
    check_reg(7,  32'h0000_0003);
    check_reg(8,  32'h0000_0003);
    check_reg(9,  32'h0000_0002);
    check_reg(10, 32'hffff_ffff);
    check_reg(11, 32'h0000_0001);
    check_reg(12, 32'h0000_0000);
    check_reg(13, 32'h0000_0000);
    check_reg(14, 32'h0000_0009);
    check_reg(15, 32'h0000_0046);
    check_reg(16, 32'h0000_0005);
    check_reg(17, 32'h0000_0008);
    check_reg(18, 32'h0000_000a);
    check_reg(19, 32'h0000_0009);
    check_reg(20, 32'h0000_000a);
    check_reg(21, 32'h0000_0078);
    check_reg(22, 32'h0000_0008);
    check_reg(23, 32'h0000_0078);
    check_reg(24, 32'h0000_0079);
    check_reg(25, 32'h0000_0078);
    check_reg(26, 32'h0000_0079);

    $display("\n=== DMEM State Verification ===");
    // Expected DMEM values after store instructions.
    check_dmem(0,  32'h0000_0042);  // SW x1,0(x2) at instr 35 with x2=0
    check_dmem(4,  32'h0000_0046);  // SW x1,0(x2) at instr 39 with x2=4
    check_dmem(8,  32'h0000_0078);  // SW x21,0(x22) at instr 54 with x22=8

    if (error_count == 0) begin
      $display("\n[TB][PASS] All register and memory checks passed.");
    end else begin
      $display("\n[TB][FAIL] Total mismatches: %0d", error_count);
    end

    $finish;
  end

endmodule
