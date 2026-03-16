//
// Author: Jim He
//
// Assignment: EE 271 Final Project: iWaaave Pro - Audio Signal Processing & Waveform Display
//
// Date Started: March 6, 2026
//
// Date Completed: March 10, 2026
//
// Description: This module is a FFT Magnitude and Display Column Heights Calculator
//

// FFT_mag_col_h_cal.sv


// 
// ============================================================
// FFT_mag_col_h_cal.sv — FFT Magnitude & Column Height Calculator
// ============================================================
// Takes complex FFT output and computes approximate magnitude for each frequency bin, 
//  then maps to column heights (0-16) for the LED display.
//
// Magnitude approximation:
//   |Z| ≈ max(|Re|, |Im|) + min(|Re|, |Im|) / 2
//   Max error: ~11.8%, perfectly fine for LED visualization.
//
// The column height mapping uses the top 5 bits of the magnitude, which may need tuning based on actual audio levels.
// ============================================================


// Module inputs: clk, reset, fft_done, fft_re, fft_im, column_heights, valid
// Module outputs: column_heights, valid_signal


module FFT_mag_col_h_cal (clk, reset, fft_done, fft_re, fft_im, column_heights, valid);
	input logic clk;
	input logic reset;
	input logic fft_done;
	input logic signed [15:0] fft_re [0:15];
	input logic signed [15:0] fft_im [0:15];
	output logic [4:0] column_heights [0:15];
	output logic valid;
	
	
	// Internal magnitude values
	logic [15:0] magnitudes [0:15];
	
	
	
	// Combinational magnitude approximation
	always_comb 
	begin
		for (int k = 0; k < 16; k++) 
		begin
			// Take absolute values of real and imaginary parts
			automatic logic [15:0] re_abs;
			automatic logic [15:0] im_abs;
			
			re_abs = (fft_re[k] < 0) ? (-fft_re[k]) : fft_re[k];
			im_abs = (fft_im[k] < 0) ? (-fft_im[k]) : fft_im[k];
			
			// Fast magnitude approximation
			if (re_abs > im_abs)
				magnitudes[k] = re_abs + (im_abs >> 1);
			else
				magnitudes[k] = im_abs + (re_abs >> 1);
		end
	end
    
	 
	 
	// Register output on fft_done
	always_ff @ (posedge clk) 
	begin
		if (reset) 
		begin
			valid <= '0;
			for (int i = 0; i < 16; i++)
				column_heights[i] <= '0;
		end
        
		else if (fft_done) 
		begin
			for (int i = 0; i < 16; i++) 
			begin
				// Map magnitude to column height (0-16)
				// Take top 5 bits — adjust the bit slice if display is
				// too sensitive or not sensitive enough
				// magnitudes are in Q1.14, so max representable is ~2.0
				// For typical audio, the FFT output magnitudes will vary.
				// Using bits [14:10] gives a good starting range.
				// If too dim:  shift window down (e.g., [13:9])
				// If too bright: shift window up (e.g., [15:11])
				
				automatic logic [4:0] raw_height;
				
				//raw_height = magnitudes[i][14:10];
				
				// ==========================================================
				// FIX: Shift the bit window down by 4 to compensate for the
				//      ÷16 input scaling.
				//
				//  BEFORE: magnitudes[i][14:10]  (needs very large values)
				//  AFTER:  magnitudes[i][10:6]   (matches scaled magnitudes)
				//
				//  Magnitude examples after fix:
				//    magnitude = 1000  → [10:6] = 15  → good visibility
				//    magnitude = 2048  → [10:6] = 32  → clamped to 16
				//    magnitude = 64    → [10:6] = 1   → barely visible
				// ==========================================================
				
				raw_height = magnitudes[i][10:6];
				
				

				if (magnitudes[i][15])  // bit 15 set means magnitude is very large
					column_heights[i] <= 5'd16;
				else if (raw_height > 5'd16)
					column_heights[i] <= 5'd16;
				else
					column_heights[i] <= raw_height;

			end
				
			valid <= '1;
		end
        
		else 	
		begin
			valid <= '0;
		end
		
	end // END OF always_ff

	 
	 
	 
endmodule