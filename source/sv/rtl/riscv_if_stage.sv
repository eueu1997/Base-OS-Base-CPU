// -----------------------------------------------------------------------------
// Module      : riscv_if_stage
// File        : riscv_if_stage.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Implements the Instruction Fetch (IF) stage for the RISC-V pipeline.
// - Generates instruction request/address from the current program counter.
// - Owns and updates the architectural PC register.
// - Samples IF outputs into stage-local registers for IF/ID handoff.
//
// Integration Notes
// - IF/ID registers are internal to this stage.
// - Flush clears the registered instruction/valid outputs to a NOP state.
// -----------------------------------------------------------------------------
module riscv_if_stage #(
  parameter int    IMEM_WORDS    = 1024,
  parameter string IMEM_HEX_FILE = ""
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        pc_redirect_valid_i,
  input  logic [31:0] pc_redirect_addr_i,
  input  logic        stall_i,
  input  logic        flush_i,
  output logic        if_valid_o,
  output logic [31:0] if_pc_o,
  output logic [31:0] if_instr_o
);

  // Architectural PC state owned by IF stage.
  logic [31:0] pc_q;

  // Internal instruction memory interface.
  logic        instr_req;
  logic [31:0] instr_addr;
  logic [31:0] instr_rdata;
  logic        instr_rvalid;

  // Instruction memory instance.
  riscv_imem #(
    .IMEM_WORDS    (IMEM_WORDS),
    .IMEM_HEX_FILE (IMEM_HEX_FILE)
  ) u_imem (
    .req_i    (instr_req),
    .addr_i   (instr_addr),
    .rdata_o  (instr_rdata),
    .rvalid_o (instr_rvalid)
  );

  // Combinational fetch interface.
  always_comb begin
    instr_req  = 1'b1;
    instr_addr = pc_q;
  end

  // IF stage state update: PC register and IF/ID register stage.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_q       <= 32'h0000_0000;
      if_valid_o <= 1'b0;
      if_pc_o    <= 32'h0000_0000;
      if_instr_o <= 32'h0000_0013;
    end else begin
      // Redirect has priority over sequential PC increment.
      if (pc_redirect_valid_i) begin
        pc_q <= pc_redirect_addr_i;
      end else if (stall_i) begin
        pc_q <= pc_q;
      end else begin
        pc_q <= pc_q + 32'd4;
      end

      if (flush_i) begin
        if_valid_o <= 1'b0;
        if_pc_o    <= 32'h0000_0000;
        if_instr_o <= 32'h0000_0013;
      end else if (stall_i) begin
        if_valid_o <= if_valid_o;
        if_pc_o    <= if_pc_o;
        if_instr_o <= if_instr_o;
      end else if (instr_rvalid) begin
        if_valid_o <= 1'b1;
        if_pc_o    <= pc_q;
        if_instr_o <= instr_rdata;
      end
    end
  end

endmodule
