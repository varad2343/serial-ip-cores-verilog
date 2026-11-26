`timescale 1ns/1ps
module tb_spi;
    reg clk = 0, rst = 1, start = 0, cpol = 0, cpha = 0, miso = 0;
    reg [7:0] tx = 0, stx = 0, sshift = 0, srx = 0;
    wire sclk, cs_n, mosi, done, busy;
    wire [7:0] rx;
    integer errors = 0, mode, n, edges = 0, seed = 3;

    spi_master #(.HALF(4)) dut (.clk(clk), .rst(rst), .start(start), .cpol(cpol), .cpha(cpha), .tx_data(tx),
        .miso(miso), .sclk(sclk), .cs_n(cs_n), .mosi(mosi), .rx_data(rx), .done(done), .busy(busy));
    always #5 clk = ~clk;

    // behavioural slave, written from the SPI mode definition
    always @(negedge cs_n) begin
        sshift = stx; edges = 0;
        if (!cpha) begin miso = sshift[7]; sshift = sshift << 1; end
    end
    always @(sclk) if (!cs_n) begin : slave
        reg leading;
        leading = (sclk != cpol);
        if (leading != cpha) srx = {srx[6:0], mosi};          // sampling edge
        else begin miso = sshift[7]; sshift = sshift << 1; end // driving edge
        edges = edges + 1;
    end

    initial begin
        repeat (4) @(negedge clk); rst = 0;
        for (mode = 0; mode < 4; mode = mode + 1) begin
            cpol = mode[1]; cpha = mode[0];
            repeat (4) @(negedge clk);
            for (n = 0; n < 200; n = n + 1) begin
                tx = $random(seed); stx = $random(seed);
                @(negedge clk); start = 1;
                @(negedge clk); start = 0;
                @(posedge done); @(negedge clk);
                if (rx !== stx || srx !== tx || edges !== 16 || sclk !== cpol) begin
                    errors = errors + 1;
                    if (errors < 10) $display("mode %0d: master %h/%h slave %h/%h edges %0d",
                                              mode, rx, stx, srx, tx, edges);
                end
            end
        end
        if (errors == 0) $display("ALL TESTS PASSED (spi: 4 modes, 800 transfers)");
        else $display("FAILED spi: %0d errors", errors);
        $finish;
    end
    initial begin #2000000; $display("FAILED spi: timeout"); $finish; end
endmodule
