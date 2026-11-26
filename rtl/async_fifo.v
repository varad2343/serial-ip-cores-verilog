// Dual-clock FIFO: Gray-coded pointers crossed through two-flop synchronisers.
`timescale 1ns/1ps
module async_fifo #(parameter DW = 8, parameter AW = 4) (
    input  wire          wclk, wrst, winc,
    input  wire [DW-1:0] wdata,
    output reg           wfull,
    input  wire          rclk, rrst, rinc,
    output wire [DW-1:0] rdata,     // first-word fall-through: valid whenever !rempty
    output reg           rempty
);
    reg [DW-1:0] mem [0:(1<<AW)-1];
    reg [AW:0] wbin, wgray, rbin, rgray;       // one extra bit tells full from empty
    reg [AW:0] rgray_w1, rgray_w2, wgray_r1, wgray_r2;

    wire [AW:0] wbin_next  = wbin + {{AW{1'b0}}, winc & ~wfull};
    wire [AW:0] rbin_next  = rbin + {{AW{1'b0}}, rinc & ~rempty};
    wire [AW:0] wgray_next = (wbin_next >> 1) ^ wbin_next;
    wire [AW:0] rgray_next = (rbin_next >> 1) ^ rbin_next;

    assign rdata = mem[rbin[AW-1:0]];

    always @(posedge wclk) if (winc && !wfull) mem[wbin[AW-1:0]] <= wdata;

    always @(posedge wclk) begin
        if (wrst) begin
            wbin <= 0; wgray <= 0; wfull <= 0; rgray_w1 <= 0; rgray_w2 <= 0;
        end else begin
            wbin <= wbin_next; wgray <= wgray_next;
            rgray_w1 <= rgray; rgray_w2 <= rgray_w1;
            // full: pointers differ by exactly one wrap (top two Gray bits inverted)
            wfull <= (wgray_next == {~rgray_w2[AW:AW-1], rgray_w2[AW-2:0]});
        end
    end

    always @(posedge rclk) begin
        if (rrst) begin
            rbin <= 0; rgray <= 0; rempty <= 1; wgray_r1 <= 0; wgray_r2 <= 0;
        end else begin
            rbin <= rbin_next; rgray <= rgray_next;
            wgray_r1 <= wgray; wgray_r2 <= wgray_r1;
            rempty <= (rgray_next == wgray_r2);
        end
    end
endmodule
