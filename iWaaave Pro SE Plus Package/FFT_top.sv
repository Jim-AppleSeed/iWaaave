//
// Author: Jim He
//
// Assignment: EE 271 Final Project: iWaaave Pro - Audio Signal Processing & Waveform Display
//
// Date Started: March 6, 2026
//
// Date Completed: March 7, 2026
//
// Description: This module is the top-level wrapper for frequency-domain waveform - FFT implementation, which collects audio samples, runs 16-point FFT, then outputs column heights.
//

// FFT_top.sv
	
// Module inputs: clk, reset, audio_advance, audio_sample
// Module outputs: fft_column_heights, fft_valid


// Inputs:
//   clk           - System clock (CLOCK_50)
//   reset         - System reset
//   audio_advance - Pulse from audio driver when new sample is ready
//   audio_sample  - 24-bit signed audio sample from ADC
//
// Outputs:
//   fft_column_heights - Array of 16 column heights (0-16) for the 16x16 LED display
//   fft_valid          - Pulse high for one cycle when new FFT results are ready


module FFT_top (clk, reset, audio_advance, audio_sample, fft_column_heights, fft_valid);
	input logic clk;
	input logic reset;
	input logic audio_advance;
	input logic signed [23:0] audio_sample;				// ? // What is the point of explicitly state "signed" vs not writing it explicitly? 
	output logic [4:0] fft_column_heights [0:15];
	output logic fft_valid;

	
	// Internal Signals
	logic signed [15:0] sample_buffer [0:15];  // 16 samples in Q1.14
//	logic signed [15:0] sample_buffer [0:255];   // 256 samples in Q1.14
	
	logic samples_ready;					
	
	logic signed [15:0] fft_out_re [0:15];     // FFT output real parts
	logic signed [15:0] fft_out_im [0:15];     // FFT output imaginary parts
//	logic signed [15:0] fft_out_re [0:255];   	// FFT output real parts
//	logic signed [15:0] fft_out_im [0:255];      // FFT output imaginary parts
	
	logic fft_done;
	
	
	
	// -------------------------------------------------------
	// Sample Buffer: collect 256 audio samples
	// -------------------------------------------------------
	FFT_sample_buffer uncle_sams_buffer (
			.clk            (clk),
			.reset          (reset),
			.audio_advance  (audio_advance),
			.audio_sample   (audio_sample),
			.sample_buffer  (sample_buffer),
			.samples_ready  (samples_ready)
	);
    
	
    
	// -------------------------------------------------------
	// 16-Point FFT Engine
	// -------------------------------------------------------
	FFT_16pt_engine gentlemen_start_ur_FFT_engines (
			.clk            (clk),
			.reset          (reset),
			.start          (samples_ready),
			.X_in           (sample_buffer),
			.X_re           (fft_out_re),
			.X_im           (fft_out_im),
			.done_signal    (fft_done)
	);



//	// -------------------------------------------------------
//	// 256-Point FFT Engine
//	// -------------------------------------------------------
//	FFT_256pt_engine fft_engine (
//			.clk         (clk),
//			.reset       (reset),
//			.start       (samples_ready),
//			.X_in        (sample_buffer),
//			.X_re        (fft_out_re),
//			.X_im        (fft_out_im),
//			.done_signal (fft_done)
//	);
    
    
	
	// -------------------------------------------------------
	// Magnitude Calculator & Column Height Mapping
	// -------------------------------------------------------
	FFT_mag_col_h_cal our_fft_mag_col_height_calculator (
			.clk                (clk),
			.reset              (reset),
			.fft_done           (fft_done),
			.fft_re             (fft_out_re),
			.fft_im             (fft_out_im),
			.column_heights     (fft_column_heights),
			.valid              (fft_valid)
	);
	
	
	 
endmodule