module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire       clk,
    input  wire       rst,
    input  wire        tx_start,
    input  wire [7:0]  data_in,
    output reg        tx,
    output reg        tx_busy
);

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

    // ---- Baud rate generator ----
    reg [15:0] baud_cnt = 0;
    reg        baud_tick = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            baud_cnt  <= 0;
            baud_tick <= 0;
        end else if (baud_cnt == BAUD_DIV - 1) begin
            baud_cnt  <= 0;
            baud_tick <= 1;
        end else begin
            baud_cnt  <= baud_cnt + 1;
            baud_tick <= 0;
        end
    end

    // ---- FSM states ----
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state = IDLE;
    reg [2:0] bit_index = 0;
    reg [7:0] shift_reg = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            tx        <= 1'b1;   // idle line is HIGH
            tx_busy   <= 1'b0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (tx_start) begin
                        shift_reg <= data_in;
                        tx_busy   <= 1'b1;
                        state     <= START;
                    end
                end

                START: begin
                    if (baud_tick) begin
                        tx    <= 1'b0;   // start bit
                        state <= DATA;
                        bit_index <= 0;
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        tx <= shift_reg[bit_index];
                        if (bit_index == 7)
                            state <= STOP;
                        else
                            bit_index <= bit_index + 1;
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        tx      <= 1'b1;   // stop bit
                        tx_busy <= 1'b0;
                        state   <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule