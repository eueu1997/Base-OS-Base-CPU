module tomasulo_RF #(
  parameter int ROB_SIZE = 8
)
(
  input logic                   clk_i,
  input logic                   rst_ni,
  input logic [4:0]             rsource1_issue_i,  // Register source 1 during issue phase
  input logic [4:0]             rsource2_issue_i,  // Register source 2 during issue phase
  input logic [4:0]             rdest_issue_i,     // Register destination to be saved in RAT with rob_inst
  input logic [$clog2(ROB_SIZE)-1 : 0]  rob_inst_issue_i,       // ROB position of register destination of issuing instruction
  input logic [4:0]             rdest_commit_i,    // Register destination of committing instruction
  input logic [31:0]            value_commit_i,    // Register value of committing instruction
  input logic [$clog2(ROB_SIZE)-1 : 0]  rob_inst_commit_i, // ROB position of committing instruction
  input logic                   we_commit_i,       // Write enable of committing instruction
  output logic [31:0]           rsource1_value_o,
  output logic [31:0]           rsource2_value_o,
  output logic [4:0]            rsource1_rob_o,
  output logic [4:0]            rsource2_rob_o,
  output logic                  rsource1_en_o,
  output logic                  rsource2_en_o
);

  // Integer register file storage (x0..x31).
  logic [31:0]                           rat_en_s;
  logic [31:0][$clog2(ROB_SIZE)-1 : 0]   rat_q ;
  logic [31:0][31:0]                     rf_q ;
  integer i;


  // Synchronous write port and reset initialization.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (i = 0; i < 32; i = i + 1) begin
        rf_q[i] <= 32'h0000_0000;
      end
      rat_q <= '{default: '0};
      rat_en_s <= '0;
      rsource1_rob_o <= '0;
      rsource2_rob_o <= '0;
      rsource1_value_o <= '0;
      rsource2_value_o <= '0;
      rsource1_en_o <= 1'b0;
      rsource2_en_o <= 1'b0;
    end else begin
      // RAT filling
      rat_q[rdest_issue_i] <= rob_inst_issue_i;
      rat_en_s[rdest_issue_i] <= 1'b1;
      rsource1_en_o <= 1'b0;
      rsource2_en_o <= 1'b0;
      rsource1_rob_o <= '0;
      rsource2_rob_o <= '0;
      rsource1_value_o <= '0;
      rsource2_value_o <= '0;
      if (we_commit_i) begin
        // If there is a commit from ROB, Write in RF value_commit at rdest_commit
        if (rdest_commit_i != 5'd0) begin
          rf_q[rdest_commit_i] <= value_commit_i;
          // In case of a commit of a register, and if the #ROB of committing register destination is equal to the #ROB in the RAT,
          // that means the last instruction writing that register has been committed, so the RAT is no more needed
          if(rat_q[rdest_commit_i] == rob_inst_commit_i)
            rat_en_s[rdest_commit_i] <= 1'b0;
        end else
          rf_q[rdest_commit_i] <= '0;
      end else begin
        if (!rat_en_s[rsource1_issue_i]) begin
          // If the source1 do not risk war and waw, get from RF
          rsource1_value_o = (rsource1_issue_i == 5'd0) ? 32'h0000_0000 : rf_q[rsource1_issue_i];
          rsource1_en_o <= 1'b1;
        end else begin
          // Otherwise, get the ROB position
          rsource1_rob_o <= rat_q[rsource1_issue_i];
          rsource1_en_o <= 1'b0;
        end
        if (!rat_en_s[rsource2_issue_i]) begin
          rsource2_value_o = (rsource2_issue_i == 5'd0) ? 32'h0000_0000 : rf_q[rsource2_issue_i];
          rsource2_en_o <= 1'b1;
        end else begin
          rsource2_rob_o <= rat_q[rsource2_issue_i];
          rsource2_en_o <= 1'b0;
        end
      end
    end
  end



endmodule