// -----------------------------------------------------------------------------
// Module      : riscv_dmem
// File        : riscv_dmem.sv
// Author      : spt9pad
// Date        : 2026-06-15
// Version     : v1.0
//
// Functionality
// - Data memory model for RISC-V core load/store operations.
// - Supports word (32-bit), halfword (16-bit), and byte (8-bit) accesses.
// - Handles sign-extension for signed loads (LB, LH).
// - Zero-extension for unsigned loads (LBU, LHU).
// - Combinational response modeled as zero-wait-state.
//
// Memory Organization
// - DMEM_WORDS: total addressable 32-bit words
// - address indexed as [addr[31:2]] for word-aligned access
//
// Integration Notes
// - Intended for simulation/prototyping; replace with SRAM in ASIC flow.
// - mem_width_o[1:0]: 00=byte, 01=halfword, 10=word
// - mem_sign_ext_o: 1=sign-extend, 0=zero-extend (for loads)
// - mem_we_o: 1=write (store), 0=read (load)
// - Response is always ready (rvalid_o = req_i)
// -----------------------------------------------------------------------------
module riscv_dmem #(
  parameter int DMEM_WORDS = 1024
) (
  input  logic        clk_i,
  input  logic        req_i,        // Request valid.
  input  logic [31:0] addr_i,       // Memory address.
  input  logic        we_i,         // Write enable (1=store, 0=load).
  input  logic [1:0]  width_i,      // Width: 00=byte, 01=halfword, 10=word.
  input  logic        sign_ext_i,   // Sign-extend for loads (1=signed, 0=unsigned).
  input  logic [31:0] wdata_i,      // Write data (for stores).

  output logic [31:0] rdata_o,      // Read data (for loads).
  output logic        rvalid_o      // Response valid.
);

  // Data memory storage.
  logic [31:0] dmem [0:DMEM_WORDS-1];

  // Address alignment and range checks.
  logic dmem_addr_aligned;
  logic dmem_addr_in_range;
  logic [31:2] word_addr;

  // Extract word address (ignore lower 2 bits for byte offset within word).
  assign word_addr = addr_i[31:2];
  assign dmem_addr_aligned = (addr_i[1:0] == 2'b00);  // TODO: allow misaligned in future.
  assign dmem_addr_in_range = (addr_i[31:2] < DMEM_WORDS);

  // Synchronous write on store operations.
  always_ff @(posedge clk_i) begin
    if (req_i & we_i & dmem_addr_in_range) begin
      case (width_i)
        2'b00: begin // Byte write
          case (addr_i[1:0])
            2'b00: dmem[word_addr][7:0]   <= wdata_i[7:0];
            2'b01: dmem[word_addr][15:8]  <= wdata_i[7:0];
            2'b10: dmem[word_addr][23:16] <= wdata_i[7:0];
            2'b11: dmem[word_addr][31:24] <= wdata_i[7:0];
          endcase
        end
        2'b01: begin // Halfword write
          case (addr_i[1])
            1'b0: dmem[word_addr][15:0]  <= wdata_i[15:0];
            1'b1: dmem[word_addr][31:16] <= wdata_i[15:0];
          endcase
        end
        2'b10: begin // Word write
          dmem[word_addr] <= wdata_i;
        end
        default: begin
          // Unsupported width; no write.
        end
      endcase
    end
  end

  // Combinational read path for load operations.
  always_comb begin
    rvalid_o = req_i;

    // Default response: zero (no data).
    rdata_o = 32'h0000_0000;

    if (dmem_addr_aligned & dmem_addr_in_range) begin
      case (width_i)
        2'b00: begin // Byte read
          case (addr_i[1:0])
            2'b00: begin
              if (sign_ext_i) begin
                rdata_o = {{24{dmem[word_addr][7]}}, dmem[word_addr][7:0]};
              end else begin
                rdata_o = {24'h0, dmem[word_addr][7:0]};
              end
            end
            2'b01: begin
              if (sign_ext_i) begin
                rdata_o = {{24{dmem[word_addr][15]}}, dmem[word_addr][15:8]};
              end else begin
                rdata_o = {24'h0, dmem[word_addr][15:8]};
              end
            end
            2'b10: begin
              if (sign_ext_i) begin
                rdata_o = {{24{dmem[word_addr][23]}}, dmem[word_addr][23:16]};
              end else begin
                rdata_o = {24'h0, dmem[word_addr][23:16]};
              end
            end
            2'b11: begin
              if (sign_ext_i) begin
                rdata_o = {{24{dmem[word_addr][31]}}, dmem[word_addr][31:24]};
              end else begin
                rdata_o = {24'h0, dmem[word_addr][31:24]};
              end
            end
          endcase
        end
        2'b01: begin // Halfword read
          case (addr_i[1])
            1'b0: begin
              if (sign_ext_i) begin
                rdata_o = {{16{dmem[word_addr][15]}}, dmem[word_addr][15:0]};
              end else begin
                rdata_o = {16'h0, dmem[word_addr][15:0]};
              end
            end
            1'b1: begin
              if (sign_ext_i) begin
                rdata_o = {{16{dmem[word_addr][31]}}, dmem[word_addr][31:16]};
              end else begin
                rdata_o = {16'h0, dmem[word_addr][31:16]};
              end
            end
          endcase
        end
        2'b10: begin // Word read
          rdata_o = dmem[word_addr];
        end
        default: begin
          rdata_o = 32'h0000_0000;
        end
      endcase
    end else if (!dmem_addr_aligned || !dmem_addr_in_range) begin
      // Misaligned or out-of-range access: return zero for now.
      // TODO: Generate exception on invalid access.
      rdata_o = 32'h0000_0000;
    end
  end

  // Initialize data memory to zero.
  initial begin
    integer i;
    for (i = 0; i < DMEM_WORDS; i = i + 1) begin
      dmem[i] = 32'h0000_0000;
    end
  end

endmodule
