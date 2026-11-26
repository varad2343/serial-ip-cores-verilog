// 8-bit SPI master, all four modes (CPOL, CPHA), MSB first. HALF = clocks per half SCLK period.
`timescale 1ns/1ps
module spi_master #(parameter HALF = 4) (
    input  wire       clk, rst, start, cpol, cpha,
    input  wire [7:0] tx_data,
    input  wire       miso,
    output reg        sclk, cs_n,
    output wire       mosi,
    output reg  [7:0] rx_data,
    output reg        done,
    output wire       busy
);
    reg [7:0]  sh;
    reg [4:0]  edges;     // SCLK edges produced so far (16 per byte)
    reg [15:0] cnt;
    reg        running;
    assign busy = running;
    assign mosi = sh[7];

    wire leading = ~edges[0];                 // edges 0,2,4.. are leading edges
    wire sample  = cpha ? ~leading : leading; // CPHA picks which edge samples

    always @(posedge clk) begin
        if (rst) begin
            running <= 0; cs_n <= 1; sclk <= 0; done <= 0; edges <= 0; cnt <= 0; sh <= 0; rx_data <= 0;
        end else begin
            done <= 0;
            if (!running) begin
                sclk <= cpol;
                if (start) begin running <= 1; cs_n <= 0; sh <= tx_data; edges <= 0; cnt <= 0; end
            end else if (cnt != HALF - 1) cnt <= cnt + 1;
            else begin
                cnt <= 0;
                if (edges == 16) begin
                    running <= 0; cs_n <= 1; done <= 1;
                end else begin
                    sclk <= ~sclk; edges <= edges + 1;
                    if (sample) rx_data <= {rx_data[6:0], miso};
                    // shift on the other edge; with CPHA=1 the first bit is already on MOSI
                    else if (!(cpha && edges == 0) && !(!cpha && edges == 15)) sh <= {sh[6:0], 1'b0};
                end
            end
        end
    end
endmodule
