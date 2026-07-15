`timescale 1ns/1ps

module uart_loopback_tb;

    reg clk = 0;
    reg rst = 1;
    reg tx_start = 0;
    reg [7:0] data_in = 8'h00;

    wire tx_line;
    wire tx_busy;
    wire [7:0] rx_data;
    wire rx_valid;

    // 50 MHz clock
    always #10 clk = ~clk;

    // Transmitter
    uart_tx #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(9600)
    ) tx_inst (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .data_in(data_in),
        .tx(tx_line),
        .tx_busy(tx_busy)
    );

    // Receiver — its rx input is directly wired to the tx output
    uart_rx #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(9600)
    ) rx_inst (
        .clk(clk),
        .rst(rst),
        .rx(tx_line),
        .data_out(rx_data),
        .data_valid(rx_valid)
    );

    // ---- Scoreboard: self-checking pass/fail ----
    integer pass_count = 0;
    integer fail_count = 0;

    // ---- Functional coverage tracking ----
    reg cov_all_zeros    = 0;  // hit 0x00
    reg cov_all_ones     = 0;  // hit 0xFF
    reg cov_alt_10       = 0;  // hit 0xAA (10101010)
    reg cov_alt_01       = 0;  // hit 0x55 (01010101)
    reg cov_bit0_set     = 0;  // some byte had bit 0 = 1
    reg cov_bit7_set     = 0;  // some byte had bit 7 = 1
    reg cov_back_to_back = 0;  // sent two bytes with minimal gap

    task record_coverage(input [7:0] b);
        begin
            if (b == 8'h00) cov_all_zeros = 1;
            if (b == 8'hFF) cov_all_ones  = 1;
            if (b == 8'hAA) cov_alt_10    = 1;
            if (b == 8'h55) cov_alt_01    = 1;
            if (b[0] == 1)  cov_bit0_set  = 1;
            if (b[7] == 1)  cov_bit7_set  = 1;
        end
    endtask

    task send_byte(input [7:0] byte_to_send, input integer index);
        begin
            @(posedge clk);
            data_in  = byte_to_send;
            record_coverage(byte_to_send);
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;

            // wait for RX to actually capture a byte
            wait (rx_valid == 1);

            if (rx_data === byte_to_send) begin
                pass_count = pass_count + 1;
                $display("PASS: sent 0x%02h, received 0x%02h", byte_to_send, rx_data);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: sent 0x%02h, received 0x%02h", byte_to_send, rx_data);
            end

            wait (tx_busy == 0);

            if (index == 5) begin
                cov_back_to_back = 1;
                #200;  // very short gap — stresses back-to-back timing
            end else begin
                #2000; // normal gap between bytes
            end
        end
    endtask

    integer i;
    reg [7:0] rand_byte;

    initial begin
        $dumpfile("uart_loopback.vcd");
        $dumpvars(0, uart_loopback_tb);

        rst = 1;
        #200;
        rst = 0;
        #200;

        // ---- Directed tests: known edge-case bytes ----
        send_byte(8'h00, 0); // all zeros
        send_byte(8'hFF, 1); // all ones
        send_byte(8'h41, 2); // ASCII 'A'
        send_byte(8'hAA, 3); // alternating 10101010
        send_byte(8'h55, 4); // alternating 01010101

        // ---- Randomized tests ----
        for (i = 0; i < 20; i = i + 1) begin
            rand_byte = $random;
            send_byte(rand_byte, 5 + i);
        end

        // ---- Summary ----
        $display("--------------------------------------------------");
        $display("TOTAL: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: SOME TESTS FAILED");
        $display("--------------------------------------------------");

        $display("---------------- FUNCTIONAL COVERAGE ----------------");
        $display("All-zeros byte (0x00) hit:          %s", cov_all_zeros    ? "YES" : "NO");
        $display("All-ones byte (0xFF) hit:            %s", cov_all_ones     ? "YES" : "NO");
        $display("Alternating 10101010 hit:            %s", cov_alt_10       ? "YES" : "NO");
        $display("Alternating 01010101 hit:            %s", cov_alt_01       ? "YES" : "NO");
        $display("Bit 0 = 1 seen at least once:        %s", cov_bit0_set     ? "YES" : "NO");
        $display("Bit 7 = 1 seen at least once:        %s", cov_bit7_set     ? "YES" : "NO");
        $display("Back-to-back short-gap transfer:     %s", cov_back_to_back ? "YES" : "NO");
        $display("--------------------------------------------------");

        $finish;
    end

endmodule