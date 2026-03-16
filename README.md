iWaaave Pro SE
Digital Audio Visualizer — User Manual
Author: Jian "Jim" He  
Course: EE 271 Final Project · University of Washington  
Date Started: February 26, 2026 · Date Completed: March 8, 2026  
Revision: 2.0 · DE1-SoC FPGA Platform · VGA Extension
---
> © 2026 Jian "Jim" He. All rights reserved.
---
System Overview
Field	Value
Platform	Terasic DE1-SoC (Cyclone V FPGA)
System Clock	50 MHz (CLOCK_50)
Audio Sample Rate	48 kHz, 24-bit stereo (Wolfson WM8731)
LED Display	16×16 LED Matrix (Red + Green channels), GPIO_1
Visualization Modes	Amplitude Time-Domain (Green) / FFT Frequency-Domain (Red)
Audio Input	3.5mm Mic-In Port (AUD_ADCDAT, AUD_BCLK, AUD_ADCLRCK)
VGA Output	External monitor via 15-pin D-Sub · 640×480 @ 25.175 MHz
User Controls	SW[9]: Power · SW[0]: LED Mode · SW[7]: VGA On/Off · SW[6]: BG Color
Debug Output	LEDR[9:0] on-board LEDs (amplitude monitor)
iWaaave Pro SE is a real-time audio visualizer implemented on the Terasic DE1-SoC FPGA development board. The system captures audio from a standard 3.5mm Mic-In connection, processes it digitally in hardware, and renders the result simultaneously on an attached 16×16 dual-color LED matrix and an external VGA monitor.
Two visualization modes are available, selectable in real time using the SW[0] switch:
Amplitude Mode (SW[0] = 0) — displays a scrolling time-domain waveform using the Green LED channel. Each column represents the averaged absolute amplitude of 1024 consecutive audio samples, giving a smooth, rolling oscilloscope-like display at approximately 46 frames per second.
FFT Frequency Mode (SW[0] = 1) — displays a live frequency-domain spectrum using the Red LED channel. A 16-point Fast Fourier Transform (Cooley-Tukey algorithm) decomposes incoming audio into 16 frequency bins, with each bin driving one column of the LED matrix. Bin height reflects signal magnitude on a logarithmic scale.
Both modes are rendered on the LED matrix (one at a time, via SW[0]) and simultaneously on the VGA monitor (always both panels at once: Amplitude on top in green, FFT on bottom in red).
The system also performs simultaneous audio passthrough: audio received on the Mic-In port is forwarded to the DAC output in real time with no added latency, allowing the board to be used as an inline monitoring device.
---
1. Hardware Setup
1.1 Required Hardware
Terasic DE1-SoC FPGA development board
16×16 dual-color LED matrix panel (P10 format, Red + Green, connected to GPIO_1)
3.5mm stereo audio cable (TRS)
Audio source: microphone, headphone output, instrument, or any line-level device
VGA monitor with 15-pin D-Sub connector (optional, for VGA display feature)
VGA cable (15-pin D-Sub)
USB-Blaster cable for programming
1.2 Audio Connection
Locate the 3.5mm Mic-In jack on the DE1-SoC board (labeled MIC on the audio codec section).
Insert a standard 3.5mm audio cable into the Mic-In port.
Connect the other end to your audio source (e.g. headphone output of a phone, laptop, or audio interface).
Ensure the source is playing audio before observing the display.
> \*\*Note:\*\* The Mic-In port accepts both microphone-level and line-level signals. For best results, use a line-level source at moderate volume. Very loud signals may saturate the ADC and clip the visualization.
> \*\*Note:\*\* The system simultaneously outputs the same audio on the DAC (line-out) port via the DAC Passthrough block, which forwards `adc\_left` and `adc\_right` to `dac\_left` and `dac\_right` on every `audio\_advance` pulse.
1.3 LED Matrix Connection
Connect the 16×16 LED matrix to the GPIO_1 header (36 pins) on the DE1-SoC board. The LEDDriver module drives the matrix with a scan clock of approximately 1526 Hz derived by dividing CLOCK_50 by 2¹⁵.
Red pixels are active in FFT Frequency Mode (SW[0] = 1).
Green pixels are active in Amplitude Mode (SW[0] = 0).
1.4 VGA Monitor Connection
Connect a VGA cable from the DE1-SoC VGA connector (15-pin D-Sub) to your monitor.
Set your monitor to its VGA input if it has multiple sources.
Once the system is on (SW[9] = 1), flip SW[7] UP to enable the VGA output.
The monitor displays a fixed dual-panel view: Amplitude waveform on the top half (green), FFT spectrum on the bottom half (red).
> \*\*Note:\*\* The VGA output continues to generate valid sync signals even when SW\[7] = 0. The background is rendered but the graph overlay is suppressed, allowing the monitor to remain locked and display instantly when SW\[7] is toggled on.
---
2. User Controls
2.1 SW[9] — System Power / Reset
Switch Position	System Behavior
SW[9] = 0 (DOWN)	System OFF — `sys\_reset` is HIGH. All synchronous registers clear to zero. Audio driver is reset. LED matrix goes blank. Audio passthrough stops. VGA output is blanked.
SW[9] = 1 (UP)	System ON — `sys\_reset` is LOW. All modules running. Audio capture, processing, LED display, and VGA output are all active.
> ⚠️ \*\*Important:\*\* SW\[9] is the master power switch. Always ensure SW\[9] = 1 (UP) before expecting any output from the LED matrix or VGA monitor.
2.2 SW[0] — LED Matrix Visualization Mode
Switch Position	Visualization Mode
SW[0] = 0 (DOWN)	Amplitude Time-Domain Mode. Green LED channel active. Scrolling waveform. Each column = average of 1024 samples (~21 ms window). Columns scroll left as time advances.
SW[0] = 1 (UP)	FFT Frequency-Domain Mode. Red LED channel active. Live spectrum analyzer. 16 frequency bins. Bin 0 (leftmost) ≈ 0–3 kHz. Bin 7 (rightmost useful) ≈ 18–21 kHz.
Live switching: SW[0] can be toggled at any time while the system is running without resetting.
> \*\*Note:\*\* SW\[0] only affects the LED matrix. The VGA monitor always shows both amplitude (top) and FFT (bottom) simultaneously, regardless of SW\[0].
2.3 SW[4:0] — LEDR Debug Bit Selector
Switches SW[4:0] select which 10-bit window of the 34-bit amplitude accumulator is shown on the 10 on-board red LEDs (LEDR[9:0]).
```
LEDR\[9:0] = amplitude\_accumulator\[ SW\[4:0] +: 10 ]
```
Higher SW[4:0] values observe more significant bits.
Recommended: set SW[4:0] = 5–9 to observe mid-range amplitude.
LEDR is a diagnostic tool; it does not affect the display output.
2.4 SW[7] — VGA Display Enable
Switch Position	VGA Behavior
SW[7] = 0 (DOWN)	VGA overlay OFF. Sync signals remain active, but no graph bars are drawn. The screen shows only the background color (controlled by SW[6]).
SW[7] = 1 (UP)	VGA overlay ON. Full dual-panel view: Amplitude waveform (top half, green) + FFT spectrum (bottom half, red).
SW[7] can be toggled at runtime without resetting the system.
2.5 SW[6] — VGA Background Color
Switch Position	Background Color
SW[6] = 0 (DOWN)	White background — neutral canvas for both panels. Best for bright environments.
SW[6] = 1 (UP)	Colored tint — top (Amplitude) panel has a green-tinted background; bottom (FFT) panel has a red-tinted background.
SW[6] only affects the VGA background. The LED matrix is unaffected.
---
3. Operating the Visualizer
3.1 Quick Start
Connect the LED matrix to GPIO_1.
Connect an audio source to the 3.5mm Mic-In port.
(Optional) Connect a VGA monitor to the DE1-SoC VGA port.
Program the DE1-SoC with the iWaaave Pro SE bitstream via Quartus Programmer.
Flip SW[9] UP to power on the system.
Set SW[0] to choose LED matrix mode (0 = Amplitude, 1 = FFT).
Flip SW[7] UP to enable VGA output. Set SW[6] to choose background color.
Play audio — both the LED matrix and VGA monitor respond in real time.
3.2 Amplitude Time-Domain Mode (SW[0] = 0)
The system captures audio from the left ADC channel, accumulates 1024 samples per window, computes the average absolute magnitude, and maps it to a column height between 0 and 16.
The display scrolls left continuously — rightmost column is newest, leftmost is oldest (16 windows back).
Silent input → blank display. Loud sustained tone → tall columns.
Column height derived from the 5 MSBs of the 34-bit accumulator (bits [33:29]).
Update rate: ~46 FPS (1024 samples ÷ 48000 Hz ≈ 21 ms/frame).
3.3 FFT Frequency-Domain Mode (SW[0] = 1)
A 16-point FFT decomposes the audio into frequency bins. Each bin drives one column of the LED matrix.
Column (left → right)	Frequency Range (approx.)
Column 0	DC / 0 Hz (usually minimal)
Column 1	~0–3 kHz (bass / low-mid)
Column 2	~3–6 kHz
Column 3	~6–9 kHz
Column 4	~9–12 kHz
Column 5	~12–15 kHz
Column 6	~15–18 kHz
Column 7	~18–21 kHz (high frequency)
Columns 8–15	Mirror of bins 0–7 (conjugate symmetric — inherent in real-input FFT)
> \*\*Note:\*\* Frequency resolution = 48 kHz ÷ 16 = \*\*3 kHz/bin\*\*. Columns 1–7 are the musically relevant bins for typical audio content.
3.4 VGA Display (SW[7] = 1)
The VGA monitor shows a fixed dual-panel layout at all times:
```
┌─────────────────────────────────────┐
│  TOP HALF  (green bars)             │
│  Amplitude Time-Domain Waveform     │
│  Source: waveform\_history\[0:15]     │
├─────────────────────────────────────┤
│  BOTTOM HALF  (red bars)            │
│  FFT Frequency Spectrum             │
│  Source: fft\_column\_heights\[0:15]   │
└─────────────────────────────────────┘
```
Both panels are always active simultaneously — independent of SW[0].
16 columns per panel, each 40 pixels wide (640 ÷ 16 = 40 px/column).
Bar heights scale proportionally to the panel height (240 lines per half).
Background color controlled by SW[6] (white or green/red tint).
SW[7] = 0 hides bars but keeps sync active.
---
4. Signal Chain Description
```
3.5mm Mic-In
     │
     ▼
┌──────────────┐   adc\_left\[23:0]    ┌───────────────────┐
│ audio\_driver │──────────────────── │  Absolute Value   │ abs\_audio\_left\[22:0]
│  (I²C codec) │   audio\_advance     │  Logic (comb.)    │────────────┐
│  48kHz/24bit │─────────────────────└───────────────────┘            │
└──────────────┘         │                                            ▼
       │                 │                                  ┌───────────────────┐
       │ (adc\_left)      │                                  │ Sample Accumulator│
       │                 │ (audio\_advance)                  │  1024 samples     │──► new\_col\_height
       ▼                 ▼                                  │  \~21ms / \~46 FPS  │──► update\_signal
┌──────────────────────────────┐                            └────────┬──────────┘
│     FFT\_top                  │                                     │ update\_signal
│  ┌──────────────────────┐    │                                     ▼
│  │  FFT\_sample\_buffer   │    │                           ┌───────────────────┐
│  │  16 samples, Q1.14   │    │                           │  Waveform Shift   │ waveform\_history\[16]
│  └──────────┬───────────┘    │                           │  Register \[0:15]  │─────┬──────────────►  LED Pixel Mapper
│             │ samples\_ready  │                           └───────────────────┘     │              ►  VGA top panel
│  ┌──────────▼───────────┐    │                                                     │
│  │  FFT\_16pt\_engine     │    │                                                     │
│  │  Cooley-Tukey        │    │                                                     │
│  └──────────┬───────────┘    │                                                     │
│             │ re\[16], im\[16] │                                                     │
│  ┌──────────▼───────────┐    │                                                     │
│  │  FFT\_mag\_col\_h\_cal   │    │                                                     │
│  │  √(re²+im²), 5-bit  │    │                                                     │
│  └──────────┬───────────┘    │ fft\_column\_heights\[16] ──────────────────┬──────────►  LED Pixel Mapper
└─────────────┼────────────────┘                                          │          ►  VGA bottom panel
              │                                                            │
              ▼                                                            │
     fft\_column\_heights\[16]                                               │
                                                                           │
                                                                           │
         ┌─────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│  LED Pixel Mapper + Mode MUX    │     │  VGA\_display\_wrapper            │
│  (always\_comb)                  │     │  Apple\_Studio\_Display\_XDR       │
│  SW\[0]=0 → GrnPixels (amp)      │     │  Top:    Amplitude → green bars │
│  SW\[0]=1 → RedPixels (fft)      │     │  Bottom: FFT     → red bars     │
└────────────┬────────────────────┘     │  SW\[7]: enable/disable overlay  │
             │                          │  SW\[6]: bg color (white/tinted) │
             ▼                          └────────────┬────────────────────┘
┌────────────────────────┐                           │
│  LEDDriver             │                           ▼
│  \~1526 Hz scan clock   │──►  GPIO\_1\[35:0]    VGA\_R/G/B\[7:0]
│  samsung\_AMOLED\_driver │     16×16 Matrix    VGA\_HS, VGA\_VS
└────────────────────────┘     (P10 panel)     VGA\_CLK, VGA\_BLANK\_N
                                               VGA\_SYNC\_N
                                               → External Monitor (640×480)
```
4.1 Audio Capture
`audio\_driver` (audio_driver_BTTBD): The Wolfson WM8731 codec is managed over I²C (`FPGA\_I2C\_SCLK` / `FPGA\_I2C\_SDAT`). Audio is transferred via the serial audio interface (`AUD\_BCLK`, `AUD\_ADCLRCK`, `AUD\_ADCDAT`). On each `audio\_advance` pulse, a fresh stereo 24-bit sample is available on `adc\_left` and `adc\_right`.
4.2 Absolute Value Computation
Absolute Value Logic: Audio is bipolar signed (24-bit two's complement). The absolute magnitude is computed combinationally:
```systemverilog
abs\_audio\_left = adc\_left\[23] ? -adc\_left\[22:0] : adc\_left\[22:0];
```
The result is a 23-bit unsigned magnitude used by the Amplitude processing path only.
4.3 Amplitude Processing Path
Sample Accumulator: On every `audio\_advance`, the absolute magnitude is added to a 34-bit accumulator. After 1024 samples, bits [33:29] are extracted as `new\_col\_height` (0–16) and `update\_display\_signal` fires.
Waveform Shift Register: `waveform\_history\[0:15]` shifts left on each `update\_display\_signal`, inserting `new\_col\_height` at index 15 (newest, rightmost).
4.4 FFT Processing Path
`FFT\_sample\_buffer` (uncle_sams_buffer): Collects 16 samples, converts 24-bit → Q1.14 fixed-point, pulses `samples\_ready`.
`FFT\_16pt\_engine` (gentlemen_start_ur_FFT_engines): 16-point Cooley-Tukey FFT in fixed-point arithmetic. Outputs `fft\_out\_re\[16]`, `fft\_out\_im\[16]`, and `done\_signal`.
`FFT\_mag\_col\_h\_cal`: Computes magnitude √(re² + im²), applies log scaling, maps to 5-bit `fft\_column\_heights\[16]`. Asserts `fft\_valid` for one cycle.
4.5 LED Display Pipeline
Pixel Mapper + Mode MUX (`always\_comb`): SW[0]=0 → fills `GrnPixels` from `waveform\_history`; SW[0]=1 → fills `RedPixels` from `fft\_column\_heights`. Rule: `row < col\_height → pixel ON` (bottom-aligned bars).
`clock\_divider`: 32-bit ripple counter, `clk\_div\[14]` → ~1526 Hz LED scan clock (50 MHz ÷ 2¹⁵).
`LEDDriver` (samsung_AMOLED_driver): Drives `GPIO\_1\[35:0]` with multiplexed row-column scan signals.
4.6 VGA Display Pipeline
`VGA\_display\_wrapper` (Apple_Studio_Display_XDR): Receives `waveform\_history` and `fft\_column\_heights` directly from the top-level module — independent of the LED Pixel Mapper and SW[0]. The screen is permanently divided into two equal panels:
Top half (lines 0–239): Amplitude waveform as green vertical bars. Source: `waveform\_history\[0:15]`.
Bottom half (lines 240–479): FFT spectrum as red vertical bars. Source: `fft\_column\_heights\[0:15]`.
Both panels are rendered simultaneously at all times. `vga\_enable` (SW[7]) suppresses the bar graph overlay when LOW but keeps sync active. `bg\_color\_select` (SW[6]) selects white or color-tinted backgrounds.
---
5. Troubleshooting
Symptom	Likely Cause & Fix
LED matrix completely blank	SW[9] = 0. Flip SW[9] UP. Verify bitstream is programmed.
No response to audio input	Check 3.5mm cable is fully inserted. Ensure audio source is active. Verify SW[9] = 1.
Display always at maximum height	Input too loud (ADC saturation). Reduce source volume.
Display shows no response	Input too quiet. Increase source volume, or raise SW[4:0] to observe higher accumulator bits on LEDR.
Amplitude shows nothing in FFT mode	Verify SW[0] = 1 (UP). Red pixels only illuminate in FFT mode.
LED matrix flickering / wrong colors	Check GPIO_1 connection. Verify `clk\_div\[14]` is used as scan clock.
LEDR shows no activity	Set SW[4:0] = 5–8. SW[4:0]=0 monitors low-order bits that toggle too fast to see on LEDs.
FFT shows only DC component	No audio playing. Ensure audio source is active into Mic-In.
VGA monitor shows no image	Check VGA cable. Verify SW[9]=1 (system on). Flip SW[7] to 1 (UP) to enable VGA.
VGA shows background but no graphs	SW[7] = 0. Flip SW[7] UP to enable graph overlay.
VGA shows wrong background color	SW[6]=0 = white; SW[6]=1 = green/red tinted.
VGA shows only one panel	VGA always shows both panels simultaneously. Verify SW[7]=1.
---
6. Technical Specifications
Parameter	Value
FPGA	Intel Cyclone V (DE1-SoC)
System Clock	50 MHz (CLOCK_50)
Audio Codec	Wolfson WM8731 (on-board)
Sample Rate	48,000 Hz (48 kHz)
Bit Depth	24-bit signed (two's complement)
Amplitude Window	1024 samples per update window
Amplitude Update Rate	≈21.33 ms / frame (≈46.9 FPS)
FFT Points	16-point Cooley-Tukey FFT
FFT Freq Resolution	3000 Hz / bin (48 kHz ÷ 16)
Accumulator Width	34-bit (handles up to 1024 × 2²³)
Column Height Range	0 to 16 (5-bit unsigned)
LED Matrix	16×16, Red + Green channels, GPIO_1[35:0]
LED Scan Clock	≈1526 Hz (CLOCK_50 ÷ 2¹⁵)
Audio Input	3.5mm TRS Mic-In (AUD_ADCDAT, AUD_BCLK, AUD_ADCLRCK, AUD_DACLRCK)
Audio Passthrough	DAC output (AUD_DACDAT, AUD_DACLRCK)
I²C Codec Control	FPGA_I2C_SCLK / FPGA_I2C_SDAT (inout wire)
VGA Resolution	640×480 (standard VGA)
VGA Pixel Clock	≈25.175 MHz (generated from CLOCK_50)
VGA Color Depth	24-bit RGB (8-bit per channel via DE1-SoC VGA DAC)
VGA Connector	15-pin D-Sub (on-board)
VGA Top Panel	Amplitude waveform — green bars (waveform_history[0:15])
VGA Bottom Panel	FFT spectrum — red bars (fft_column_heights[0:15])
VGA Sync Outputs	VGA_HS, VGA_VS, VGA_CLK, VGA_BLANK_N, VGA_SYNC_N
User Switches	SW[9]: sys_reset · SW[0]: LED mode · SW[7]: VGA enable · SW[6]: VGA bg color · SW[4:0]: LEDR debug
Debug Outputs	LEDR[9:0] on-board LEDs
---
7. Developer Notes
7.1 FPGA_I2C_SDAT Wire Type
`FPGA\_I2C\_SDAT` is declared as `inout wire`, not `logic`. This is required because `inout` (bidirectional) ports must be connected to explicit `wire`-type signals — Quartus cannot infer bidirectional driver control from the `logic` type. The `audio\_driver` module manages the tristate control internally.
7.2 Signed Audio Samples in FFT
`FFT\_top` receives the raw signed 24-bit `adc\_left` sample — not the absolute value. The FFT requires the actual bipolar signal to correctly compute both positive and negative frequency components. `abs\_audio\_left` is used only in the Amplitude path.
7.3 Extending to 256-Point FFT
The design includes commented-out support for a 256-point FFT engine (`FFT\_256pt\_engine`) and a 256-element sample buffer. Switching to 256 points increases frequency resolution to 48000 ÷ 256 ≈ 188 Hz/bin at the cost of higher latency and resource utilization.
7.4 LED Color Extension
The Pixel Mapper populates only `GrnPixels` or `RedPixels` at a time. Both channels can be driven simultaneously by extending the `always\_comb` block, enabling yellow (R+G) as a third color.
7.5 Increment Notation
In the `always\_ff` accumulator block, `sample\_collected\_count` is incremented with `+ 1'b1` for explicit 1-bit literal typing. The expressions `+ '1` and `+ 1` also work in SystemVerilog but may require care with bit-width context in synthesis tools.
7.6 VGA Dual-Panel Architecture
`VGA\_display\_wrapper` receives `waveform\_history` and `fft\_column\_heights` directly from the top-level module, bypassing the LED Pixel Mapper entirely. The VGA layout is fixed: top half always renders Amplitude (green), bottom half always renders FFT (red), both simultaneously — this is independent of SW[0]. Column widths are 640 ÷ 16 = 40 pixels/column; bar heights scale to the 240-line panel height.
7.7 VGA Background Color Control (SW[6])
When SW[6] = 0, both panel backgrounds are white. When SW[6] = 1, the top Amplitude panel is tinted green and the bottom FFT panel is tinted red, reinforcing the color theme of each visualization. The bar graph colors (green for amplitude, red for FFT) remain constant regardless of SW[6].
---
iWaaave Pro SE · Digital Audio Visualizer · DE1-SoC FPGA Platform  
© 2026 Jian "Jim" He · End of User Manual · Rev 2.0 · VGA Extension
