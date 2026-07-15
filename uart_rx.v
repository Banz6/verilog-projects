module uart_rx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg  [7:0] data_out,
    output reg        data_valid
);

    localparam BAUD_DIV      = CLK_FREQ / BAUD_RATE;
    localparam HALF_BAUD_DIV = BAUD_DIV / 2;

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]  state = IDLE;
    reg [15:0] clk_cnt = 0;
    reg [2:0]  bit_index = 0;
    reg [7:0]  shift_reg = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            clk_cnt    <= 0;
            bit_index  <= 0;
            data_valid <= 0;
        end else begin
            data_valid <= 0; // pulses high for exactly 1 cycle when a byte completes

            case (state)
                IDLE: begin
                    clk_cnt <= 0;
                    if (rx == 1'b0) begin      // falling edge = possible start bit
                        state <= START;
                    end
                end

                START: begin
                    // wait to the MIDDLE of the start bit to confirm it's real,
                    // not just line noise
                    if (clk_cnt == HALF_BAUD_DIV - 1) begin
                        if (rx == 1'b0) begin  // still low -> genuine start bit
                            clk_cnt   <= 0;
                            bit_index <= 0;
                            state     <= DATA;
                        end else begin
                            state <= IDLE;     // was a glitch, abort
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                DATA: begin
                    if (clk_cnt == BAUD_DIV - 1) begin
                        clk_cnt <= 0;
                        shift_reg[bit_index] <= rx;  // sample mid-bit
                        if (bit_index == 7)
                            state <= STOP;
                        else
                            bit_index <= bit_index + 1;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                STOP: begin
                    if (clk_cnt == BAUD_DIV - 1) begin
                        data_out   <= shift_reg;
                        data_valid <= 1'b1;
                        state      <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
            endcase
        end
    end

endmodule