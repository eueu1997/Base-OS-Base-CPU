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
// - Fetch requests go through riscv_icache; PC is held while a cache miss
//   refill is in progress (instr_rvalid low).
// - The icache's AHB-Lite master port is passed through unchanged to the
//   top of this stage: riscv_if_stage owns no bus logic of its own.
// -----------------------------------------------------------------------------
module riscv_if_stage #(
    parameter int LINE_WORDS = 8,
    parameter int LINE_LENGHT = 2**LINE_WORDS
  ) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        pc_redirect_valid_i,
  input  logic [31:0] pc_redirect_addr_i,
  input  logic        stall_i,
  input  logic        flush_i,
  output logic        if_valid_o,
  output logic [31:0] if_pc_o,
  output logic [31:0] if_instr_o,

  // Read-only AHB-Lite master port, passed through from riscv_icache.
  output logic [31:0] ahb_haddr_o,
  output logic [1:0]  ahb_htrans_o,
  output logic        ahb_hwrite_o,
  output logic [2:0]  ahb_hsize_o,
  input  logic [LINE_LENGHT-1:0] ahb_hrdata_i,
  input  logic        ahb_hready_i,
  input  logic        ahb_hresp_i
);

  // Architectural PC state owned by IF stage.
  logic [31:0] pc_q;

  // Internal instruction cache interface.
  logic        instr_req;
  logic [31:0] instr_addr;
  logic [31:0] instr_rdata;
  logic        instr_rvalid;

  // Direct-mapped instruction cache instance; refills over the AHB-Lite
  // master port passed through to the top of this stage.
  riscv_icache #(
    .LINE_WORDS   (LINE_WORDS),
    .LINE_LENGHT  (LINE_LENGHT)
  ) u_icache (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .req_i        (instr_req),
    .addr_i       (instr_addr),
    .rdata_o      (instr_rdata),
    .rvalid_o     (instr_rvalid),
    .ahb_haddr_o  (ahb_haddr_o),
    .ahb_htrans_o (ahb_htrans_o),
    .ahb_hwrite_o (ahb_hwrite_o),
    .ahb_hsize_o  (ahb_hsize_o),
    .ahb_hrdata_i (ahb_hrdata_i),
    .ahb_hready_i (ahb_hready_i),
    .ahb_hresp_i  (ahb_hresp_i)
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
      // PC also holds while an icache miss refill is in progress (instr_rvalid low),
      // otherwise the core would race ahead of the not-yet-completed fetch.
      if (pc_redirect_valid_i) begin
        pc_q <= pc_redirect_addr_i;
      end else if (stall_i || !instr_rvalid) begin
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
