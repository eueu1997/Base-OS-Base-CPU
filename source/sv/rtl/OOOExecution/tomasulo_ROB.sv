module tomasulo_ROB #
  (
    parameter int ROB_SIZE = 8,
    parameter int FUNC_UNIT_N = 8
  ) (
    input logic                           clk_i,
    input logic                           rst_i,
    input logic [4:0]                     reg_dest_i,
    output logic [$clog2(ROB_SIZE)-1 : 0] rob_pos_o,
    output logic [4:0]                    rdest_commit_o,
    output logic [31:0]                   rvalue_commit_o,
    output logic [$clog2(ROB_SIZE)-1 : 0] robpos_commit_o,
    output logic                          ren_commit_o,
    // Touple {ROB destination,value} from all the FU
    input logic  [FUNC_UNIT_N -1 : 0][$clog2(ROB_SIZE) -1 : 0]           rdest_i,
    input logic  [FUNC_UNIT_N -1 : 0][31:0]                              rvalue_i,
    input logic  [FUNC_UNIT_N -1 : 0]                                    ren_i


  );
  logic [ROB_SIZE-1:0] [4:0]   dest_rob_s;
  logic [ROB_SIZE-1:0] [31:0]  value_rob_s;
  logic [ROB_SIZE-1:0]         spec_rob_s;
  logic [ROB_SIZE-1:0]         commit_rob_s;
  logic                      rob_full_s;


  logic [$clog2(ROB_SIZE)-1 : 0] first_p_s, last_p_s;

  // new entry from instruction fetch
  always_ff @(posedge clk_i or negedge rst_i)begin

    if (!rst_i)begin
      dest_rob_s <= '0;
      value_rob_s <= '0;
      spec_rob_s <= '0;
      commit_rob_s <= '0;
      last_p_s <= '0;
      rob_full_s <= 1'b0;
    end else begin
      if(!rob_full_s) begin
        dest_rob_s[last_p_s] <= reg_dest_i;
        commit_rob_s[last_p_s] <= 1'b0;
        last_p_s <= last_p_s + 1 ;
        if (last_p_s + 1 == first_p_s)
          rob_full_s <= 1'b1;
        else
          rob_full_s <= 1'b0;
        for ( int i = 0; i< FUNC_UNIT_N ; i++)begin
          if(ren_i[i])begin
            value_rob_s[rdest_i[i]] <=rvalue_i[i];
            commit_rob_s[rdest_i[i]] <= 1'b1;
          end
        end
      end
    end
  end
  assign rob_pos_o = last_p_s;

  // Data valid to commit
  always_ff @(posedge clk_i or negedge rst_i)begin
    if (!rst_i) begin
      first_p_s <= '0;
      rdest_commit_o <= '0;
      rvalue_commit_o <= '0;
      ren_commit_o <= 1'b0;
    end else begin
      if(commit_rob_s[first_p_s]) begin
        rdest_commit_o <= dest_rob_s[first_p_s];
        rvalue_commit_o <= value_rob_s[first_p_s];
        robpos_commit_o <= first_p_s;
        ren_commit_o <= 1'b1;
        first_p_s <= first_p_s + 1'b1;
      end else
        ren_commit_o <= 1'b0;
    end
  end

  // data coming from FUs

endmodule