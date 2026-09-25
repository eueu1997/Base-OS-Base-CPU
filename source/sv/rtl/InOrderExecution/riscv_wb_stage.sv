// -----------------------------------------------------------------------------
// Module      : riscv_wb_stage
// File        : riscv_wb_stage.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Implements the Write-Back (WB) stage for the RISC-V core.
// - Converts pipeline WB control/data into register-file write interface signals.
// - Blocks writes to x0 to preserve architectural zero-register behavior.
// - Contains the data cache controller (riscv_dcache_ctrl) for load/store operations,
//   which may take multiple cycles per access (cache miss / dirty write-back).
// - Handles load result writeback by muxing between ALU and load data.
// - Exposes mem_stall_o so the rest of the pipeline (ID/EX, IF) can freeze while a
//   multi-cycle memory access is in flight.
//
// Integration Notes
// - WB outputs are sampled in stage-local registers before driving regfile.
// - Data cache read data is used as source for load writeback.
// - riscv_dcache_ctrl's own AHB-Lite master port is passed straight through to this
//   stage's ports (this stage does not touch the bus signals itself).
// -----
// -----------------------------------------------------------------------------
module riscv_wb_stage #(
  parameter int LINE_WORDS  = 8,
  parameter int LINE_LENGHT = 2**LINE_WORDS
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // ALU writeback from ID/EX stage.
  input  logic [4:0]  wb_rd_i,
  input  logic [31:0] wb_data_i,
  input  logic        wb_we_i,

  // Memory access signals from ID/EX stage.
  input  logic        mem_req_i,
  input  logic [31:0] mem_addr_i,
  input  logic        mem_we_i,
  input  logic [1:0]  mem_width_i,
  input  logic        mem_sign_ext_i,
  input  logic [31:0] mem_wdata_i,
  input  logic        load_valid_i,
  input  logic [4:0]  load_rd_i,

  output logic        rf_we_o,
  output logic [4:0]  rf_waddr_o,
  output logic [31:0] rf_wdata_o,

  // Stalls the pipeline (ID/EX output registers and, through it, IF) while the
  // data cache controller is servicing a multi-cycle access.
  output logic        mem_stall_o,

  // Read/write AHB-Lite master port toward the system bus (D-side).
  output logic [31:0] ahb_haddr_o,
  output logic [1:0]  ahb_htrans_o,
  output logic        ahb_hwrite_o,
  output logic [2:0]  ahb_hsize_o,
  output logic [LINE_LENGHT-1:0] ahb_hwdata_o,
  input  logic [LINE_LENGHT-1:0] ahb_hrdata_i,
  input  logic        ahb_hready_i,
  input  logic        ahb_hresp_i
);

  // Data cache read interface.
  logic [31:0] dcache_rdata;
  logic        dcache_rvalid;

  // Combinational WB mux results before output registers.
  logic        rf_we_d;
  logic [4:0]  rf_waddr_d;
  logic [31:0] rf_wdata_d;

  // Data cache controller: wraps set_associative_cache with width/sign-extension,
  // read-modify-write for partial stores, and an AHB-Lite master for refills and
  // dirty-line write-back. Receives already-latched signals from ID/EX (no extra
  // register stage here).
  riscv_dcache_ctrl #(
    .LINE_WORDS  (LINE_WORDS),
    .LINE_LENGHT (LINE_LENGHT)
  ) u_dcache_ctrl (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .req_i         (mem_req_i),
    .addr_i        (mem_addr_i),
    .we_i          (mem_we_i),
    .width_i       (mem_width_i),
    .sign_ext_i    (mem_sign_ext_i),
    .wdata_i       (mem_wdata_i),
    .rdata_o       (dcache_rdata),
    .rvalid_o      (dcache_rvalid),
    .stall_o       (mem_stall_o),
    .ahb_haddr_o   (ahb_haddr_o),
    .ahb_htrans_o  (ahb_htrans_o),
    .ahb_hwrite_o  (ahb_hwrite_o),
    .ahb_hsize_o   (ahb_hsize_o),
    .ahb_hwdata_o  (ahb_hwdata_o),
    .ahb_hrdata_i  (ahb_hrdata_i),
    .ahb_hready_i  (ahb_hready_i),
    .ahb_hresp_i   (ahb_hresp_i)
  );

  // Convert pipeline writeback info into register-file write controls.
  // Mux between ALU result (wb_data_i) and load result (dcache_rdata).
  always_comb begin
    // Select writeback data: load data if load_valid_i, else ALU data.
    logic [31:0] wb_data_mux;
    logic [4:0]  wb_rd_mux;
    logic        wb_we_mux;

    if (load_valid_i & dcache_rvalid) begin
      // Load result: write load_rd_i with dcache_rdata.
      wb_data_mux = dcache_rdata;
      wb_rd_mux   = load_rd_i;
      wb_we_mux   = 1'b1;  // Load always writes to rd (unless rd=x0).
    end else begin
      // ALU result: use wb_data_i, wb_rd_i, wb_we_i as-is.
      // Note: wb_we_i is already 0 for load/store instructions (see
      // riscv_id_ex_stage), so this branch never spuriously writes the regfile
      // while a memory access is still stalling (mem_stall_o asserted).
      wb_data_mux = wb_data_i;
      wb_rd_mux   = wb_rd_i;
      wb_we_mux   = wb_we_i;
    end

    // x0 is hardwired to zero and must never be written.
    rf_we_d    = wb_we_mux & (wb_rd_mux != 5'd0);
    rf_waddr_d = wb_rd_mux;
    rf_wdata_d = wb_data_mux;
  end

  // Stage output registers.
  // No hold logic needed here even during mem_stall_o: wb_we_mux is guaranteed 0 on
  // every stall cycle (load_valid_i & dcache_rvalid is false until the exact settle
  // cycle), so rf_we_o naturally stays deasserted until the correct data is ready.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rf_we_o    <= 1'b0;
      rf_waddr_o <= 5'd0;
      rf_wdata_o <= 32'h0000_0000;
    end else begin
      rf_we_o    <= rf_we_d;
      rf_waddr_o <= rf_waddr_d;
      rf_wdata_o <= rf_wdata_d;
    end
  end

endmodule
