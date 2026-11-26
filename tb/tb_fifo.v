`timescale 1ns/1ps
module tb_fifo;
    localparam N = 20000, DEPTH = 16;
    reg wclk = 0, rclk = 0, wrst = 1, rrst = 1, winc = 0, rinc = 0;
    reg [7:0] wdata = 0;
    wire [7:0] rdata;
    wire wfull, rempty;
    reg [7:0] model [0:N-1];
    integer written = 0, read = 0, errors = 0, seed = 7, wbias = 90, rbias = 10;
    integer saw_full = 0, saw_empty_again = 0;

    async_fifo #(.DW(8), .AW(4)) dut (.wclk(wclk), .wrst(wrst), .winc(winc), .wdata(wdata), .wfull(wfull),
        .rclk(rclk), .rrst(rrst), .rinc(rinc), .rdata(rdata), .rempty(rempty));

    always #3.5 wclk = ~wclk;   // 7 ns
    always #6.5 rclk = ~rclk;   // 13 ns, unrelated to wclk

    always @(negedge wclk) begin
        winc <= !wrst && written < N && ({$random(seed)} % 100) < wbias;
        wdata <= $random(seed);
    end
    always @(posedge wclk) if (!wrst) begin
        if (winc && !wfull) begin model[written] = wdata; written = written + 1; end
        if (wfull) saw_full = saw_full + 1;
        if (written - read > DEPTH) begin errors = errors + 1; $display("overflow"); end
    end

    always @(negedge rclk) rinc <= !rrst && ({$random(seed)} % 100) < rbias;
    always @(posedge rclk) if (!rrst) begin
        if (rinc && !rempty) begin
            if (read >= written || rdata !== model[read]) begin
                errors = errors + 1;
                if (errors < 10) $display("read %0d: got %h expected %h", read, rdata, model[read]);
            end
            read = read + 1;
        end
        if (rempty && read > 100) saw_empty_again = saw_empty_again + 1;
    end

    initial begin
        repeat (4) @(negedge rclk);
        wrst = 0; rrst = 0;
        wait (written >= N/3);   wbias = 20; rbias = 90;   // reader faster: hits empty
        wait (written >= 2*N/3); wbias = 90; rbias = 40;   // writer faster: hits full
        wait (written >= N);     rbias = 100;
        wait (read >= N);
        repeat (10) @(posedge rclk);
        if (errors == 0 && rempty && saw_full > 0 && saw_empty_again > 0)
            $display("ALL TESTS PASSED (fifo: %0d words)", read);
        else $display("FAILED fifo: errors=%0d full=%0d empty=%0d", errors, saw_full, saw_empty_again);
        $finish;
    end
    initial begin #2000000; $display("FAILED fifo: timeout"); $finish; end
endmodule
