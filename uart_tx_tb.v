`timescale 1ns/1ps

module uart_tx_tb;

    reg clk = 0;
    reg rst = 1;
    reg tx_start = 0;
    reg [7:0] data_in = 8'h00;
    wire tx;
    wire tx_busy;

    // 50 MHz clock -> 20ns period
    always #10 clk = ~clk;

    uart_tx #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(9600)
    ) dut (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .data_in(data_in),
        .tx(tx),
        .tx_busy(tx_busy)
    );

    initial begin
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, uart_tx_tb);

        rst = 1;
        #100;
        rst = 0;
        #100;

        data_in = 8'h41;   // send ASCII 'A'
        tx_start = 1;
        #20;
        tx_start = 0;

        wait (tx_busy == 0);
        #1000;

        $finish;
    end

endmodule