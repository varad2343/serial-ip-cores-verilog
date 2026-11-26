`timescale 1ns/1ps
module tb_uart;
    localparam DIV = 32;
    reg clk = 0, rst = 1, start = 0, use_ext = 0, ext = 1;
    reg [7:0] txd = 0;
    wire tx, busy, valid, ferr;
    wire [7:0] rxd;
    integer errors = 0, good = 0, bad = 0, i;
    reg [7:0] last;

    uart_tx #(.DIV(DIV)) t (.clk(clk), .rst(rst), .start(start), .data(txd), .tx(tx), .busy(busy));
    uart_rx #(.DIV(DIV)) r (.clk(clk), .rst(rst), .rx(use_ext ? ext : tx), .data(rxd),
                            .valid(valid), .frame_error(ferr));
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (valid) begin good = good + 1; last = rxd; end
        if (ferr) bad = bad + 1;
    end

    // drive a frame from the testbench with its own bit time (in ns)
    task send(input [7:0] b, input real bit_ns, input stop);
        integer k;
        begin
            ext = 0; #(bit_ns);
            for (k = 0; k < 8; k = k + 1) begin ext = b[k]; #(bit_ns); end
            ext = stop; #(bit_ns);
            ext = 1; #(2 * bit_ns);
        end
    endtask

    task expect_byte(input [7:0] b, input integer count);
        begin
            if (good !== count || last !== b) begin
                errors = errors + 1;
                if (errors < 10) $display("byte %h: got %h (count %0d, want %0d)", b, last, good, count);
            end
        end
    endtask

    initial begin
        repeat (4) @(negedge clk); rst = 0;
        for (i = 0; i < 256; i = i + 1) begin           // loopback of every byte
            @(negedge clk); txd = i; start = 1;
            @(negedge clk); start = 0;
            wait (!busy); repeat (DIV) @(negedge clk);
            expect_byte(i, i + 1);
        end
        use_ext = 1; #1000;
        for (i = 0; i < 256; i = i + 1) begin           // sender 3 % slow, then 3 % fast
            send(i, DIV * 10 * 1.03, 1); expect_byte(i, 257 + 2*i);
            send(~i, DIV * 10 * 0.97, 1); expect_byte(~i, 258 + 2*i);
        end
        send(8'h55, DIV * 10, 0);                       // missing stop bit
        #(DIV * 200);
        if (bad < 1) begin errors = errors + 1; $display("framing error not flagged"); end
        i = good; ext = 0; #(DIV * 2); ext = 1; #(DIV * 200);   // short glitch is ignored
        if (good !== i) begin errors = errors + 1; $display("glitch accepted"); end
        if (errors == 0) $display("ALL TESTS PASSED (uart: %0d bytes)", good);
        else $display("FAILED uart: %0d errors", errors);
        $finish;
    end
endmodule
