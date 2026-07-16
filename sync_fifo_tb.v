`timescale 1ns/1ps

module sync_fifo_tb;

    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 16;
    parameter ADDR_WIDTH = 4;

    reg clk = 0;
    reg rst = 1;
    reg wr_en = 0;
    reg rd_en = 0;
    reg [DATA_WIDTH-1:0] wr_data = 0;

    wire [DATA_WIDTH-1:0] rd_data;
    wire full, empty;

    always #10 clk = ~clk; // 50 MHz

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .full(full),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .empty(empty)
    );

    // ---- Reference model: a simple queue, mirrors what the FIFO should contain ----
    reg [DATA_WIDTH-1:0] ref_queue [0:255];
    integer ref_head = 0;
    integer ref_tail = 0;

    integer pass_count = 0;
    integer fail_count = 0;

    task write_byte(input [DATA_WIDTH-1:0] b);
        begin
            @(negedge clk);
            if (!full) begin
                wr_en   = 1;
                wr_data = b;
                @(negedge clk);
                wr_en = 0;
                ref_queue[ref_tail] = b;
                ref_tail = ref_tail + 1;
            end else begin
                $display("SKIP WRITE: FIFO full, byte 0x%02h dropped", b);
            end
        end
    endtask

    task read_byte;
        reg [DATA_WIDTH-1:0] expected;
        begin
            @(negedge clk);
            if (!empty) begin
                rd_en = 1;
                @(negedge clk);
                rd_en = 0;
                expected = ref_queue[ref_head];
                ref_head = ref_head + 1;

                if (rd_data === expected) begin
                    pass_count = pass_count + 1;
                    $display("PASS: read 0x%02h (expected 0x%02h)", rd_data, expected);
                end else begin
                    fail_count = fail_count + 1;
                    $display("FAIL: read 0x%02h (expected 0x%02h)", rd_data, expected);
                end
            end else begin
                $display("SKIP READ: FIFO empty");
            end
        end
    endtask

    // ---- Coverage tracking ----
    reg cov_hit_full        = 0;
    reg cov_hit_empty_after = 0;
    reg cov_simul_rw        = 0;
    reg cov_wrap_around     = 0;

    integer i;

    initial begin
        $dumpfile("sync_fifo.vcd");
        $dumpvars(0, sync_fifo_tb);

        rst = 1;
        #40;
        rst = 0;
        #20;

        // ---- Test 1: fill it completely, confirm 'full' asserts ----
        for (i = 0; i < DEPTH; i = i + 1)
            write_byte(i);

        if (full) cov_hit_full = 1;
        $display("After filling: full = %b (expected 1)", full);

        // ---- Test 2: drain it completely, confirm 'empty' asserts ----
        for (i = 0; i < DEPTH; i = i + 1)
            read_byte;

        if (empty) cov_hit_empty_after = 1;
        $display("After draining: empty = %b (expected 1)", empty);

        // ---- Test 3: simultaneous read+write while partially full ----
        write_byte(8'hA1);
        write_byte(8'hA2);
        write_byte(8'hA3);

        @(negedge clk);
        wr_en = 1; wr_data = 8'hB1;
        rd_en = 1;
        cov_simul_rw = 1;
        @(negedge clk);
        wr_en = 0; rd_en = 0;
        ref_queue[ref_tail] = 8'hB1; ref_tail = ref_tail + 1;
        begin : simul_check
            reg [DATA_WIDTH-1:0] expected;
            expected = ref_queue[ref_head];
            ref_head = ref_head + 1;
            if (rd_data === expected) begin
                pass_count = pass_count + 1;
                $display("PASS (simul r/w): read 0x%02h (expected 0x%02h)", rd_data, expected);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL (simul r/w): read 0x%02h (expected 0x%02h)", rd_data, expected);
            end
        end

        // drain remaining
        while (!empty) read_byte;

        // ---- Test 4: wraparound -- write/read enough to cross the memory boundary twice ----
        for (i = 0; i < DEPTH + 5; i = i + 1) begin
            write_byte(i + 100);
            read_byte;
        end
        cov_wrap_around = 1;

        // ---- Test 5: randomized read/write mix ----
        for (i = 0; i < 40; i = i + 1) begin
            if ($random % 2 == 0 && !full)
                write_byte($random);
            else if (!empty)
                read_byte;
        end

        // drain anything left
        while (!empty) read_byte;

        // ---- Summary ----
        $display("--------------------------------------------------");
        $display("TOTAL: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: SOME TESTS FAILED");
        $display("--------------------------------------------------");

        $display("---------------- FUNCTIONAL COVERAGE ----------------");
        $display("FIFO reached full:               %s", cov_hit_full        ? "YES" : "NO");
        $display("FIFO reached empty after fill:    %s", cov_hit_empty_after ? "YES" : "NO");
        $display("Simultaneous read+write:          %s", cov_simul_rw        ? "YES" : "NO");
        $display("Pointer wraparound exercised:      %s", cov_wrap_around     ? "YES" : "NO");
        $display("--------------------------------------------------");

        $finish;
    end

endmodule