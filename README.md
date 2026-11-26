# Serial IP Cores: Async FIFO, UART, SPI

Reusable Verilog-2001 peripheral blocks, each with a self-checking testbench.

| Core | Features | Testbench |
|---|---|---|
| `async_fifo.v` | Two clock domains, Gray-coded pointers, two-flop synchronisers, full/empty flags, first-word fall-through | 20,000 words with 7 ns and 13 ns clocks, random traffic, both full and empty reached |
| `uart.v` | 8N1 TX and RX, mid-bit sampling, input synchroniser, start-glitch rejection, framing-error flag | All 256 bytes looped back, sender 3 % slow and 3 % fast, bad stop bit, glitch |
| `spi_master.v` | Modes 0-3, MSB first, parameterised clock divider | 200 random full-duplex transfers per mode against a behavioural slave |

## Run
Needs Icarus Verilog and Python.
```bash
python run.py
```
Status: simulated RTL, not yet synthesized. RTL simulation does not model metastability, so it cannot prove the clock-domain crossing; that relies on the Gray-code and synchroniser structure.
