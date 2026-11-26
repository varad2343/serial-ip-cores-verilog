"""Compile and run every self-checking testbench with Icarus Verilog."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / "build"
BUILD.mkdir(exist_ok=True)
failed = []
for name, source in (("fifo", "async_fifo.v"), ("uart", "uart.v"), ("spi", "spi_master.v")):
    sim = BUILD / f"{name}.vvp"
    subprocess.run(["iverilog", "-g2001", "-Wall", "-o", sim, ROOT / "rtl" / source,
                    ROOT / "tb" / f"tb_{name}.v"], check=True)
    out = subprocess.run(["vvp", sim], check=True, capture_output=True, text=True).stdout
    print(out)
    if "ALL TESTS PASSED" not in out:
        failed.append(name)
sys.exit(f"failed: {failed}" if failed else 0)
