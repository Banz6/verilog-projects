# UART Verification Plan

## Objective
Verify that `uart_tx` and `uart_rx` correctly interoperate as a complete
asynchronous serial link: any byte transmitted by `uart_tx` must be
received correctly and identically by `uart_rx`.

## Design Under Test (DUT)
- `uart_tx.v` — transmitter (baud generator + FSM + shift register)
- `uart_rx.v` — receiver (baud generator + mid-bit sampling FSM + shift register)
- Connected in loopback: `uart_tx`'s `tx` output feeds directly into `uart_rx`'s `rx` input.

## Verification Strategy
A self-checking testbench (`uart_loopback_tb.v`) drives the transmitter,
waits for the receiver to capture a byte, and automatically compares the
sent and received values — no manual waveform inspection required to
determine pass/fail.

## Test Cases

### Directed tests (hand-picked edge cases)
| Byte | Why it matters |
|---|---|
| `0x00` | All-zero data — stresses the "no toggling" case |
| `0xFF` | All-one data — stresses the opposite extreme |
| `0x41` | A real ASCII character ('A'), representative of typical use |
| `0xAA` (10101010) | Maximum toggling — worst case for sampling-timing bugs |
| `0x55` (01010101) | Same as above, inverted phase |

### Randomized tests
20 pseudo-random bytes, generated with `$random`, to catch cases not
anticipated by directed testing.

### Timing stress test
One transmission is sent with a much shorter inter-byte gap than the
others, to confirm the receiver correctly returns to `IDLE` and is ready
for the next byte without a large recovery window.

## Functional Coverage
| Coverage point | Purpose |
|---|---|
| All-zeros byte hit | Confirms no false start-bit detection issues |
| All-ones byte hit | Confirms line stays idle-high correctly |
| Alternating 10101010 hit | Confirms sampling point is correctly centered (most likely to expose an off-by-one in bit timing) |
| Alternating 01010101 hit | Same, opposite phase |
| Bit 0 = 1 observed | Confirms LSB path works |
| Bit 7 = 1 observed | Confirms MSB path works |
| Back-to-back short-gap transfer | Confirms receiver FSM resets cleanly between bytes |

## Results
- **25/25 tests passed** (5 directed + 20 randomized)
- **7/7 functional coverage points hit (100%)**

## What This Does *Not* Cover (honest scope statement)
- Framing/parity errors are not injected — this testbench assumes an ideal
  channel with no noise or corrupted start/stop bits. A stretch goal would
  be to add fault injection (e.g. corrupting a bit mid-transmission) to
  verify error-handling behavior, which this design does not currently
  implement.
- Multiple baud rates are not swept; verification was performed at the
  design's fixed 9600 baud / 50 MHz configuration only.