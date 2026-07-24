// -----------------------------------------------------------------------------
// Module      : riscv_regfile
// File        : riscv_regfile.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Implements the integer register file for the RISC-V core.
// - Provides two asynchronous read ports and one synchronous write port.
// - Keeps x0 hardwired to zero.
// -----------------------------------------------------------------------------
module riscv_regfile (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [4:0]  rs1_addr_i,
  input  logic [4:0]  rs2_addr_i,
  output logic [31:0] rs1_data_o,
  output logic [31:0] rs2_data_o,
  input  logic        we_i,
  input  logic [4:0]  waddr_i,
  input  logic [31:0] wdata_i
);

  // Integer register file storage (x0..x31).
  logic [31:0] rf_q [31:0];
  integer i;

  // Asynchronous read ports.
  always_comb begin
    rs1_data_o = (rs1_addr_i == 5'd0) ? 32'h0000_0000 : rf_q[rs1_addr_i];
    rs2_data_o = (rs2_addr_i == 5'd0) ? 32'h0000_0000 : rf_q[rs2_addr_i];
  end

  // Synchronous write port and reset initialization.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (i = 0; i < 32; i = i + 1) begin
        rf_q[i] <= 32'h0000_0000;
      end
    end else begin
      if (we_i && (waddr_i != 5'd0)) begin
        rf_q[waddr_i] <= wdata_i;
      end

      // Keep x0 hardwired to zero regardless of write attempts.
      rf_q[0] <= 32'h0000_0000;
    end
  end

endmodule
