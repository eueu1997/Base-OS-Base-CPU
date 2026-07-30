// -----------------------------------------------------------------------------
// Module      : riscv_top
// File        : riscv_top.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Top-level wrapper that instantiates the RISC-V core and a single shared
//   AHB-Lite RAM backing store.
// - The core exposes two AHB masters (I-side and D-side). This top arbitrates
//   them onto one shared slave bus, allowing one transaction at a time.
// - When the RAM path is already serving one side, the other side sees
//   HREADY low (busy/back-pressure) until the current transaction completes.
//
// Integration Notes
// - This is a bring-up oriented top for early simulation/debug.
// - Shared RAM address space is 4 GB (32-bit byte addresses).
// - Arbitration policy is fixed priority to D-side over I-side when both
//   request in the same cycle. This avoids D-side starvation while IF is
//   very active.
// -----------------------------------------------------------------------------
module riscv_top #(
  parameter int IMEM_WORDS = 1024,
  parameter string IMEM_HEX_FILE = "",
  parameter int LINE_WORDS = 8,
  parameter int LINE_LENGHT = 2**LINE_WORDS
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  output logic        illegal_instr_o
);

  localparam logic [1:0] HTRANS_IDLE = 2'b00;

  // I-side master signals from core.
  logic [31:0] i_haddr;
  logic [1:0]  i_htrans;
  logic        i_hwrite;
  logic [2:0]  i_hsize;
  logic [LINE_LENGHT-1:0] i_hrdata;
  logic        i_hready;
  logic        i_hresp;

  // D-side master signals from core.
  logic [31:0] d_haddr;
  logic [1:0]  d_htrans;
  logic        d_hwrite;
  logic [2:0]  d_hsize;
  logic [LINE_LENGHT-1:0] d_hwdata;
  logic [LINE_LENGHT-1:0] d_hrdata;
  logic        d_hready;
  logic        d_hresp;

  // Shared slave bus toward unified RAM.
  logic [31:0] s_haddr;
  logic [1:0]  s_htrans;
  logic        s_hwrite;
  logic [2:0]  s_hsize;
  logic [LINE_LENGHT-1:0] s_hwdata;
  logic [LINE_LENGHT-1:0] s_hrdata;
  logic        s_hready;
  logic        s_hresp;

  // Simple single-outstanding arbitration state.
  logic busy_q;
  logic owner_d_q;
  logic req_i;
  logic req_d;
  logic issue_i;
  logic issue_d;

  assign req_i = i_htrans[1];
  assign req_d = d_htrans[1];

  // Request selection: while idle, serve D-side first if both request.
  always_comb begin
    issue_i = 1'b0;
    issue_d = 1'b0;
    if (!busy_q) begin
      if (req_d) begin
        issue_d = 1'b1;
      end else if (req_i) begin
        issue_i = 1'b1;
      end
    end
  end

  // Address/control mux toward shared RAM slave.
  always_comb begin
    s_haddr  = 32'h0000_0000;
    s_htrans = HTRANS_IDLE;
    s_hwrite = 1'b0;
    s_hsize  = 3'b010;
    s_hwdata = {LINE_LENGHT{1'b0}};

    if (issue_d) begin
      s_haddr  = d_haddr;
      s_htrans = d_htrans;
      s_hwrite = d_hwrite;
      s_hsize  = d_hsize;
      s_hwdata = d_hwdata;
    end else if (issue_i) begin
      s_haddr  = i_haddr;
      s_htrans = i_htrans;
      s_hwrite = i_hwrite;
      s_hsize  = i_hsize;
      s_hwdata = {LINE_LENGHT{1'b0}};
    end
  end

  // Response routing + busy/back-pressure behavior.
  always_comb begin
    i_hrdata = {LINE_LENGHT{1'b0}};
    i_hresp  = 1'b0;
    i_hready = 1'b1;
    d_hrdata = {LINE_LENGHT{1'b0}};
    d_hresp  = 1'b0;
    d_hready = 1'b1;

    if (!busy_q) begin
      // Request accepted this cycle: requester waits for response next cycle.
      if (issue_i) begin
        i_hready = 1'b0;
        if (req_d) begin
          d_hready = 1'b0;
        end
      end else if (issue_d) begin
        d_hready = 1'b0;
        if (req_i) begin
          i_hready = 1'b0;
        end
      end
    end else begin
      // One outstanding transaction: return response to owner, hold other side busy.
      i_hready = 1'b0;
      d_hready = 1'b0;
      if (owner_d_q) begin
        d_hrdata = s_hrdata;
        d_hresp  = s_hresp;
        d_hready = s_hready;
      end else begin
        i_hrdata = s_hrdata;
        i_hresp  = s_hresp;
        i_hready = s_hready;
      end
    end
  end

  // Track one outstanding transaction at a time.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      busy_q    <= 1'b0;
      owner_d_q <= 1'b0;
    end else if (!busy_q) begin
      if (issue_d) begin
        busy_q    <= 1'b1;
        owner_d_q <= 1'b1;
      end else if (issue_i) begin
        busy_q    <= 1'b1;
        owner_d_q <= 1'b0;
      end
    end else if (s_hready) begin
      busy_q <= 1'b0;
    end
  end

  // Core instance.
  riscv u_riscv #(
    .LINE_WORDS    (LINE_WORDS),
    .LINE_LENGHT   (LINE_LENGHT)
  )
  (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .illegal_instr_o(illegal_instr_o),
    .ahb_haddr_o    (i_haddr),
    .ahb_htrans_o   (i_htrans),
    .ahb_hwrite_o   (i_hwrite),
    .ahb_hsize_o    (i_hsize),
    .ahb_hrdata_i   (i_hrdata),
    .ahb_hready_i   (i_hready),
    .ahb_hresp_i    (i_hresp),
    .dahb_haddr_o   (d_haddr),
    .dahb_htrans_o  (d_htrans),
    .dahb_hwrite_o  (d_hwrite),
    .dahb_hsize_o   (d_hsize),
    .dahb_hwdata_o  (d_hwdata),
    .dahb_hrdata_i  (d_hrdata),
    .dahb_hready_i  (d_hready),
    .dahb_hresp_i   (d_hresp)
  );

  // Shared unified RAM AHB-Lite slave (4 GB address space).
  riscv_ahb_ram_slave #(
    .BOOT_WORDS    (IMEM_WORDS),
    .BOOT_HEX_FILE (IMEM_HEX_FILE),
    .LINE_WORDS    (LINE_WORDS),
    .LINE_LENGHT   (LINE_LENGHT)
  ) u_ahb_ram_slave (
    .clk_i    (clk_i),
    .rst_ni   (rst_ni),
    .haddr_i  (s_haddr),
    .htrans_i (s_htrans),
    .hwrite_i (s_hwrite),
    .hsize_i  (s_hsize),
    .hwdata_i (s_hwdata),
    .hrdata_o (s_hrdata),
    .hready_o (s_hready),
    .hresp_o  (s_hresp)
  );

endmodule
