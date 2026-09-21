module ahb_slave #(
  parameter logic [31:0] BASE_ADDR = 32'h0001_0000,
  parameter int ADDRESS_WIDTH = 32,
  parameter int DATA_WIDTH    = 32,
  parameter int SLAVE_WORDS   = 1024
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic [ADDRESS_WIDTH-1:0] haddr_i,
  input  logic [1:0]               htrans_i,
  input  logic                     hwrite_i,
  input  logic [2:0]               hsize_i,
  input  logic [DATA_WIDTH-1:0]    hwdata_i,
  output logic [DATA_WIDTH-1:0]    hrdata_o,
  output logic                     hready_o,
  output logic                     hresp_o
);

logic [2:0] cnt;
logic [31:0] haddr_q;
logic [31:0] data_mem_s [31:0];
logic valid_add_s;
typedef enum logic [1:0] {
                        IDLE = 2'b00,
                        BUSY = 2'b01,
                        NONSEQ = 2'b10,
                        SEQ = 2'b11
} ahb_state_e;
ahb_state_e slave_state_s;

assign valid_add_s = (haddr_i & 32'hFFFF_0000) == BASE_ADDR;

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    cnt <= 3'b0;
    slave_state_s <= IDLE;
    hrdata <= 32'b0;
    hready <= 1'b1;
    hresp <= 1'b0;
  end else begin
    case (slave_state_s)
      IDLE: begin
        if(htrans == IDLE) begin
          slave_state_s <= IDLE;
        end else if (htrans == BUSY) begin
          slave_state_s <= BUSY;
        end else if (htrans == NONSEQ) begin
          if(valid_add_s) begin
            slave_state_s <= NONSEQ;
            haddr_q <= haddr;
          end else begin
            slave_state_s <= IDLE;
            hresp <= 1'b1;
          end
        end else if (htrans == SEQ) begin
          slave_state_s <= IDLE;
        end
      end
      BUSY: begin
        if(htrans == IDLE) begin
          slave_state_s <= IDLE;
        end
      end
      NONSEQ: begin
        if(hwrite) begin
          data_mem_s[haddr_q[31:2]] <= hwdata;
        end else
          hrdata <= data_mem_s[haddr_q[31:2]];

        if(htrans == IDLE) begin
          slave_state_s <= IDLE;
        end else if (htrans == BUSY) begin
          slave_state_s <= BUSY;
        end else if (htrans == NONSEQ) begin
          slave_state_s <= NONSEQ;
          haddr_q <= haddr;
        end else if (htrans == SEQ) begin
          slave_state_s <= SEQ;
          haddr_q <= haddr;
        end
      end
      SEQ: begin
        if(hwrite) begin
          data_mem_s[haddr_q[31:2]] <= hwdata;
        end else
          hrdata <= data_mem_s[haddr_q[31:2]];

        if(htrans == IDLE) begin
          slave_state_s <= IDLE;
        end else if (htrans == BUSY) begin
          slave_state_s <= BUSY;
        end else if (htrans == NONSEQ) begin
          slave_state_s <= NONSEQ;
          haddr_q <= haddr;
        end else if (htrans == SEQ) begin
          slave_state_s <= SEQ;
          haddr_q <= haddr;
        end
      end
    endcase
    // Implement your state machine or counter logic here
  end
end

endmodule