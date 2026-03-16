//
// Author: Jim He
//
// Assignment: EE 271 Final Project: iWaaave Pro - Audio Signal Processing & Waveform Display
//
// Date Started: February 26, 2026
//
// Date Completed: March 13, 2026
//
// Description: This system is based on the iWaaave Pro SE project, with additional extension on external computer monitor display.
//
	
	
// System inputs: SW[9], SW[7],  SW[6], SW[0], Audio-Plug-In (Mic-In Port)
// System outputs: LEDR, GPIO_1, VGA
// Clock Domain: The system runs on the built-in 50mHz clock, except that the LED display will run on a divided clock.


module DE1_SoC (CLOCK_50, SW, LEDR, GPIO_1, 
                AUD_ADCDAT, AUD_DACDAT, AUD_BCLK, AUD_ADCLRCK, AUD_DACLRCK, AUD_XCK, FPGA_I2C_SCLK, FPGA_I2C_SDAT,
                VGA_R, VGA_G, VGA_B, VGA_BLANK_N, VGA_CLK, VGA_HS, VGA_SYNC_N, VGA_VS);
	// Basic IO
	input  logic CLOCK_50;
	input  logic [9:0] SW;
	output logic [9:0] LEDR; 
	
	// 16x16 LED matrix
	output logic [35:0] GPIO_1;
    
	// Audio codec physical pins
	input  logic  AUD_ADCDAT;
	output logic  AUD_DACDAT;
	input  logic  AUD_BCLK;
	input  logic  AUD_ADCLRCK;
	input  logic  AUD_DACLRCK;
	output logic  AUD_XCK;
	output logic  FPGA_I2C_SCLK;
	inout  wire  FPGA_I2C_SDAT;	
	
	// VGA output pins
	output logic [7:0] VGA_R;
	output logic [7:0] VGA_G;
	output logic [7:0] VGA_B;
	output logic       VGA_BLANK_N;
	output logic       VGA_CLK;
	output logic       VGA_HS;
	output logic       VGA_SYNC_N;
	output logic       VGA_VS;
	
	
	
	
	// ============================================================
	// SYSTEM CONTROL
	// ============================================================
	
	// Turn off all LEDs 
	//assign LEDR = 10'd0;
	
	// System ON/OFF: SW[9]==0 means system turned off (Reset is High)
	logic sys_reset;
	assign sys_reset = ~SW[9]; 
	
	// Mode Selection Amplitude/FFT: SW[0]==0 is Amplitude mode; SW[0]==1 is FFT Frequency Mode
	logic select_mode;
	assign select_mode = SW[0];
	
	// VGA Enable ON/OFF: SW[7]==0 OFF, SW[7]==1 ON
	logic VGA_enable;
	assign VGA_enable = SW[7];
	
	// VGA Background Color Select: SW[6]==0 White, SW[6]==1 Green/Red
	logic VGA_bg_color;
	assign VGA_bg_color = SW[6];
	
	
	// ============================================================
	// AUDIO INPUT
	// ============================================================
	
	logic audio_advance;
	logic [23:0] adc_left;
	logic [23:0] adc_right;
	logic [23:0] dac_left; 
	logic [23:0] dac_right;
	logic [22:0] abs_audio_left;	 // NOTE // We only need 23-bit since "A signed value of n bit only need n-1 bit to represent magnitude (absolute value)
	logic [22:0] abs_audio_right;
	
	// Instantiate provided Audio Driver
	audio_driver audio_driver_BTTBD (  						// BTTBD: Better Than The Bus Drivers (referring to King County Metro specifically)
			.CLOCK_50      (CLOCK_50), 
			.reset         (sys_reset),
			.dac_left      (dac_left), 	// module input
			.dac_right     (dac_right),	// module input
			.adc_left      (adc_left),		// module output
			.adc_right     (adc_right),	// module output
			.advance       (audio_advance), // module output
			.FPGA_I2C_SCLK (FPGA_I2C_SCLK),
			.FPGA_I2C_SDAT (FPGA_I2C_SDAT),
			.AUD_XCK       (AUD_XCK),
			.AUD_DACLRCK   (AUD_DACLRCK),
			.AUD_ADCLRCK   (AUD_ADCLRCK),
			.AUD_BCLK      (AUD_BCLK),
			.AUD_ADCDAT    (AUD_ADCDAT),
			.AUD_DACDAT    (AUD_DACDAT)
	);
	
	
	// Audio Pass-through & Advance Signal
	always_ff @ (posedge CLOCK_50) 
	begin
		if (sys_reset) // When system reset is high, feed 0 to audio driver input
		begin
			dac_left  <= '0;
			dac_right <= '0;
		end 
		
		else if (audio_advance) // When audio driver gives advance signal, proceed
		begin
			dac_left  <= adc_left;
			dac_right <= adc_right;
		end
	end
	
	 
	// Description // We need to take the absolute value of the volumne since the amplitude from the audio driver will goes to negative.
	
	// Calculate Absolute Magnitude (2's complement)
	assign abs_audio_left = adc_left[23] ? -adc_left[22:0] : adc_left[22:0];
	//assign abs_audio_right = adc_right[23] ? (~adc_right[22:0] + 1'b1) : adc_right[22:0];
	
	// NOTE // This (~adc_left[22:0] + 1'b1) is the same as (-adc_left[22:0])
	
	
	
	 
	// ============================================================
	// AUDIO Processing:  TIME AVERAGING & DOWNSAMPLING LOGIC (AMPLITUDE MODE ONLY)
	// ============================================================

	// Parameters for timing - number of samples to accumulate before averaging them
	// 1024 samples @ 48kHz = ~21ms update rate (~46 FPS) -- Calculated by Claude
	localparam num_samples_to_avg = 1024; 
	
	logic [10:0] sample_collected_count;	// Number of samples collected so far, up to 1024
	logic [33:0] amplitude_accumulator;		// Large register to hold sum of amplitudes from the 1024 samples -- bitwidth required for accumulat (worst cast scenario) 1024 (10-bit to rep.) * largest 24-bit audio (1111...) = 34-bit. Thus we need 34 bit reg
	logic [4:0] new_column_height;	// The calculated height for the column from 0-16; use 5 bit to represent it
	logic update_display_signal;	// Flag signal to shift the display columns left
   
	

	
	always_ff @ (posedge CLOCK_50) 
	begin
	
		if (sys_reset) 
		begin
			sample_collected_count <= '0;
			amplitude_accumulator <= '0;
			update_display_signal <='0;
			new_column_height <= 5'b0;
		end 
      
		
		else if (audio_advance) 
		begin
			// 1. Accumulate audio data, until we have gotten enough of them
			if (sample_collected_count < num_samples_to_avg) 
			begin
				amplitude_accumulator <= amplitude_accumulator + abs_audio_left;
				sample_collected_count <= sample_collected_count + 1'b1;		// ? // Do I need to specifically state "+ 1'b1" here or i can just state "+ '1" or even "+1"
				update_display_signal <= '0;
			end 
				
			// 2. Calculate Average and Trigger display update flag (left shift signal)
			else 
			begin
				//LEDR
				LEDR <= amplitude_accumulator[SW[4:0] +: 10];
	 
				// Take the most significant 5 bits for column height mapping. 
				new_column_height <= amplitude_accumulator[33:29];	 
					 
				// Reset variables for next cycle
				sample_collected_count <= '0;
				amplitude_accumulator <= '0;
				update_display_signal <= '1;
				
			end // END OF else statement block
			
		end // END OF else if (audio_advance) block
		
		
		else // No audio coming in
		begin
			update_display_signal <= '0;
		end
		
	end // END OF always_ff
	
	
	
	
	// ============================================================
	// WAVEFORM SHIFT REGISTER (AMPLITUDE MODE ONLY)
	// ============================================================
	
	// Array to store the height of all 16 columns (4 bit logic to rep. all 16 )
	logic [4:0] waveform_history [0:15];
	
	always_ff @ (posedge CLOCK_50) 
	begin
		if (sys_reset) 
		begin
			for(int i = 0; i < 16; i++) 
				waveform_history[i] <= 5'd0;
		end
      
		else if (update_display_signal) 
		begin
			// Shift all columns to the left (Index 0 is Oldest, Index 15 is Newest)
			for (int i = 0; i < 15; i++) 
				waveform_history[i] <= waveform_history[i+1];
			
			// Insert new column at the "end" (Right side)
			waveform_history[15] <= new_column_height;
		end
		
	end // END OF always_ff
	
	
	
	
	// ============================================================
	// FFT FREQUENCY Processing
	// ============================================================
	
	logic [4:0] fft_column_heights [0:15];
	logic fft_valid;
	
	FFT_top fft_mode_processor (
			.clk                (CLOCK_50),
			.reset              (sys_reset),
			.audio_advance      (audio_advance),
			.audio_sample       (adc_left),         // use the original left channel audio_in (signed 24-bit), not the absolute value here
			.fft_column_heights (fft_column_heights),
			.fft_valid          (fft_valid)
	);
	
	
	
	 
	// ============================================================
	// LED MATRIX DRIVER
	// ============================================================
    
	// Clock Divider for LED Driver (required ~1526 Hz)
	logic [31:0] clk_div;
	
	clock_divider clk_divider (
			.clock(CLOCK_50), 
			.reset(sys_reset), 
			.divided_clocks(clk_div)
	);
	
	logic select_div_clk;	// selected divided clock signal
	assign select_div_clk = clk_div[14]; 

	
	// 2D Green & Red Pixel Arrays
	logic [15:0][15:0] RedPixels;
	logic [15:0][15:0] GrnPixels;
	
	
	// Instantiate LED Driver
	LEDDriver samsung_AMOLED_driver (
			.GPIO_1(GPIO_1),
			.RedPixels(RedPixels), 
			.GrnPixels(GrnPixels),
			.EnableCount('1),
			.CLK(select_div_clk), 
			.RST(sys_reset) 
	);
	
	
	// Map Waveform History to Pixels - with mode selection for iWaaave Pro
	always_comb 
	begin
		// Red always off. Only use green display. (Potential Add-on - allow user to choose colors)
		RedPixels = '0;
		GrnPixels = '0;
	
		for (int col = 0; col < 16; col++) 
		begin
		
			for (int row = 0; row < 16; row++) 
			begin
				
				
				if (!select_mode) // (SW[0]==1'b0) Amplitude Time-Domain Mode, Green Display
				begin
					if (row < waveform_history[col]) 
					begin
						GrnPixels[15 - row][15 - col] = '1;
					end
				end
				
				else // (SW[0]==1'b1) FFT Frequency-Domain Mode, Red Display
				begin
					// The 16 columns are mapped from 128 bins
               if (row < fft_column_heights[col])
						RedPixels[15 - row][15 - col] = '1;
				end
				
				
			end // END OF row for loop
			
		end // END OF col for loop
		
	end // END OF always_comb
	
	
	
	
	// ============================================================
	// VGA DISPLAY (Top Green, Bottom Red)
	// ============================================================
	
	VGA_display_wrapper Apple_Studio_Display_XDR (
			.CLOCK_50          	(CLOCK_50),
			.reset             	(sys_reset),
			.vga_enable        	(VGA_enable),           // SW[7]: HIGH = show graphs, LOW = background only
			.bg_color_select   	(VGA_bg_color),         // SW[6]: LOW = white bg, HIGH = green/red tinted bg
			.amp_column_heights	(waveform_history),
			.fft_column_heights	(fft_column_heights),
			.VGA_R             	(VGA_R),
			.VGA_G             	(VGA_G),
			.VGA_B             	(VGA_B),
			.VGA_BLANK_N       	(VGA_BLANK_N),
			.VGA_CLK           	(VGA_CLK),
			.VGA_HS            	(VGA_HS),
			.VGA_SYNC_N        	(VGA_SYNC_N),
			.VGA_VS            	(VGA_VS)
	);
	
	
	
	
endmodule





