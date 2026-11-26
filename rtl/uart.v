// 8N1 UART transmitter and receiver. DIV = clock cycles per bit (>= 8).
`timescale 1ns/1ps
module uart_tx #(parameter DIV = 16) (
    input  wire       clk, rst, start,
    input  wire [7:0] data,
    output wire       tx,
    output wire       busy
);
    reg [9:0]  shift;
    reg [3:0]  bits;
    reg [15:0] cnt;
    assign busy = (bits != 0);
    assign tx   = busy ? shift[0] : 1'b1;

    always @(posedge clk) begin
        if (rst) begin
            bits <= 0; cnt <= 0; shift <= 10'h3ff;
        end else if (!busy) begin
            if (start) begin
                shift <= {1'b1, data, 1'b0};   // stop, data (LSB first), start
                bits <= 10; cnt <= 0;
            end
        end else if (cnt == DIV - 1) begin
            cnt <= 0; shift <= {1'b1, shift[9:1]}; bits <= bits - 1;
        end else cnt <= cnt + 1;
    end
endmodule

module uart_rx #(parameter DIV = 16) (
    input  wire       clk, rst, rx,
    output reg  [7:0] data,
    output reg        valid,       // one-clock pulse: byte received
    output reg        frame_error  // one-clock pulse: stop bit was low
);
    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
    reg [1:0]  state;
    reg [15:0] cnt;
    reg [2:0]  bitn;
    reg        s1, s2;             // synchroniser for the asynchronous input

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; cnt <= 0; bitn <= 0; valid <= 0; frame_error <= 0;
            data <= 0; s1 <= 1; s2 <= 1;
        end else begin
            s1 <= rx; s2 <= s1;
            valid <= 0; frame_error <= 0;
            case (state)
                IDLE: if (!s2) begin state <= START; cnt <= 0; end
                START: if (cnt == DIV/2 - 1) begin       // middle of the start bit
                    cnt <= 0; bitn <= 0;
                    state <= s2 ? IDLE : DATA;           // reject short glitches
                end else cnt <= cnt + 1;
                DATA: if (cnt == DIV - 1) begin
                    cnt <= 0; data <= {s2, data[7:1]}; bitn <= bitn + 1;
                    if (bitn == 7) state <= STOP;
                end else cnt <= cnt + 1;
                STOP: if (cnt == DIV - 1) begin
                    state <= IDLE; cnt <= 0;
                    if (s2) valid <= 1; else frame_error <= 1;
                end else cnt <= cnt + 1;
            endcase
        end
    end
endmodule
