#!/usr/bin/env python3
"""
This python script is written by Claude
generate_twiddle_hex.py
Generates twiddle factor .hex files for a 256-point FFT in Q1.14 format.

W_256^k = cos(2*pi*k/256) - j*sin(2*pi*k/256)
tw_re[k] = round(cos(2*pi*k/256) * 16384)
tw_im[k] = round(-sin(2*pi*k/256) * 16384)

For k = 0 to 127 (N/2 - 1)

Output:
  twiddle_re_256.hex  — real parts, one 16-bit hex value per line
  twiddle_im_256.hex  — imaginary parts, one 16-bit hex value per line

Values are 16-bit signed in two's complement, written as 4-digit hex.
"""

import math

N = 256
SCALE = 16384  # 2^14 for Q1.14 format

def to_twos_complement_hex(value, bits=16):
    """Convert a signed integer to two's complement hex string."""
    if value < 0:
        value = (1 << bits) + value
    return f"{value:04X}"

def main():
    re_values = []
    im_values = []

    for k in range(N // 2):  # k = 0 to 127
        angle = 2.0 * math.pi * k / N
        cos_val = math.cos(angle)
        sin_val = math.sin(angle)

        # Q1.14 representation
        tw_re = round(cos_val * SCALE)
        tw_im = round(-sin_val * SCALE)  # negative sign: W = cos - j*sin

        # Clamp to 16-bit signed range
        tw_re = max(-32768, min(32767, tw_re))
        tw_im = max(-32768, min(32767, tw_im))

        re_values.append(tw_re)
        im_values.append(tw_im)

    # Write hex files
    with open("twiddle_re_256.hex", "w") as f:
        for val in re_values:
            f.write(to_twos_complement_hex(val) + "\n")

    with open("twiddle_im_256.hex", "w") as f:
        for val in im_values:
            f.write(to_twos_complement_hex(val) + "\n")

    # Also print for verification
    print("Twiddle factors for 256-point FFT (Q1.14):")
    print(f"{'k':>4} {'cos':>10} {'tw_re':>7} {'tw_re_hex':>10} "
          f"{'sin':>10} {'tw_im':>7} {'tw_im_hex':>10}")
    print("-" * 75)
    for k in range(min(16, N // 2)):  # Print first 16 for verification
        angle = 2.0 * math.pi * k / N
        print(f"{k:4d} {math.cos(angle):10.6f} {re_values[k]:7d} "
              f"{to_twos_complement_hex(re_values[k]):>10} "
              f"{math.sin(angle):10.6f} {im_values[k]:7d} "
              f"{to_twos_complement_hex(im_values[k]):>10}")
    if N // 2 > 16:
        print(f"  ... ({N//2 - 16} more entries)")

    print(f"\nFiles written: twiddle_re_256.hex, twiddle_im_256.hex")
    print(f"Each file contains {N//2} lines of 4-digit hex values.")

if __name__ == "__main__":
    main()
    input("Press Enter to exit...")