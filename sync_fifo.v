module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = 4   // log2(DEPTH) -- must match DEPTH manually
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  full,

    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire                  empty
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // pointers are 1 bit wider than needed to address DEPTH entries --
    // this extra MSB is the standard trick to distinguish "full" from
    // "empty" when both conditions would otherwise look identical
    // (read pointer == write pointer)
    reg [ADDR_WIDTH:0] wr_ptr = 0;
    reg [ADDR_WIDTH:0] rd_ptr = 0;

    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr[ADDR_WIDTH-1:0];

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

    // ---- Write logic ----
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_addr] <= wr_data;
            wr_ptr       <= wr_ptr + 1;
        end
    end

    // ---- Read logic ----
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rd_ptr  <= 0;
            rd_data <= 0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_addr];
            rd_ptr  <= rd_ptr + 1;
        end
    end

endmodule