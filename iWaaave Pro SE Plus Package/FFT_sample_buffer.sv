//
// Author: Jim He
//
// Assignment: EE 271 Final Project: iWaaave Pro - Audio Signal Processing & Waveform Display
//
// Date Started: March 6, 2026
//
// Date Completed: March 6, 2026
//
// Description: This module collects 16 consecutive audio samples from the audio driver, converts them to Q1.14 fixed-point format, and signals out when a full buffer is ready for FFT processing.
//

// FFT_sample_buffer.sv
	
	
// Explanation // Conversion strategy:
//   The audio ADC outputs 24-bit signed values. We take the upper bits for our Q1.14 representation.
//   Specifically, we use bits [23:8] which gives us a 16-bit signed value. 
//   This is effectively the audio sample divided by 256 (shifted right by 8), fitting nicely into our Q1.14 range of [-2, +2).
	
	
	
// Module inputs: clk, reset, audio_advance, audio_sample
// Module outputs: sample_buffer, samples_ready


// Audio sample format: 24-bit signed (from audio_driver)
// Output format: 16-bit signed Q1.14 fixed-point


module FFT_sample_buffer (clk, reset, audio_advance, audio_sample, sample_buffer, samples_ready);
	input logic clk;
	input logic reset;
	input logic audio_advance;
	input logic signed [23:0] audio_sample;
	output logic signed [15:0] sample_buffer [0:15];
	output logic samples_ready;
	
	
	logic [3:0] sample_count;  // Counts 0 to 15 (16 samples in total)
	
	
	always_ff @ (posedge clk) 
	begin
		if (reset) 
		begin
			sample_count  <= '0;
			samples_ready <= '0;
			
			for (int i = 0; i < 16; i++)
				sample_buffer[i] <= 16'sd0; // ? // What is sd? and why are we using it here?
		end
		  
        
		else if (audio_advance) 
		begin
			// Store the sample (take upper 16 bits of 24-bit audio)
			// This maps the 24-bit range to Q1.14 range
			
			//sample_buffer[sample_count] <= audio_sample[23:8];
			
			// The statement above causes overflow bug: (full range, overflows after Stage 1)
			
			// FIX: Take bits [23:12] instead of [23:8], sign-extend to 16.
			//      This divides the input amplitude by 16, giving 4 stages
			//      of butterfly headroom (2^4 = 16x growth fits in 16-bit).
			
			// AFTER FIX (÷16, max FFT output ≈ ±32,752 — fits 16-bit signed):
			
			sample_buffer[sample_count] <= {{4{audio_sample[23]}}, audio_sample[23:12]};
			
			
			if (sample_count == 4'd15) 
			begin
				// All 16 samples collected
				sample_count  <= '0; // reset it to ready for next round
				samples_ready <= '1; // flag it for ready to be be sent out
			end
				
			else 
			begin
				sample_count  <= sample_count + 1;
				samples_ready <= '0;
			end
		end // END OF else if 
      
		  
		else 
		begin
			samples_ready <= '0;
		end
		
	end // END OF always_ff

	 
	 
endmodule