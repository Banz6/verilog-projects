# UART Transmitter — Digital ASIC Flow

A complete digital ASIC design flow for a UART transmitter, built from RTL through to a manufacturable chip layout.

## What is a UART?

A UART (Universal Asynchronous Receiver/Transmitter) sends data one bit at a time over a single wire. Each byte is wrapped in a start bit, 8 data bits, and a stop bit, so the receiver can tell where each byte begins and ends without needing a shared clock signal.

## Design

- `uart_tx.v` — the transmitter: a baud rate generator (clock divider) plus a finite state machine (IDLE → START → DATA → STOP) that shifts out one byte at a time.
- `uart_tx_tb.v` — testbench that sends the byte `0x41` ('A') and dumps a waveform for verification.

Clock: 50 MHz | Baud rate: 9600

## Flow

1. **RTL** — written in Verilog, modeling the FSM and shift register logic.
2. **Simulation** — compiled and run with Icarus Verilog (`iverilog` + `vvp`), waveform inspected to confirm correct start/data/stop bit sequencing.
3. **Synthesis** — converted to a gate-level netlist using Yosys (151 cells).
4. **Physical Design** — floorplanning, placement, clock tree synthesis, and routing performed using OpenLane, producing a GDSII layout. Zero setup/hold timing violations.
5. **Layout Inspection** — final GDS reviewed visually in KLayout.

## What I learned

- How UART protocol timing works and how to implement it as an FSM in Verilog.
- The full RTL-to-GDSII flow: simulation, synthesis, and physical design.
- Troubleshooting a real toolchain (WSL, Docker, OpenLane) from scratch.