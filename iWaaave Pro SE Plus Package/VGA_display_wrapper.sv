//
// Author: Jim He
//
// Assignment: EE 271 Final Project: iWaaave Pro - Audio Signal Processing & Waveform Display
//
// Date Started: March 13, 2026
//
// Date Completed: March 13, 2026
//
// Description: This module is the top level wrapper for the VGA external monitor control.  
//
	

// ============================================================
// VGA Display Wrapper Module
// ============================================================
// Displays both amplitude and FFT bar graphs simultaneously
// on a 640x480 VGA display.
//
// Layout:
//   Top half    (y: 0..238)   = Amplitude waveform (green bars)
//   Divider     (y: 239..240) = Gray separator line
//   Bottom half (y: 241..479) = FFT frequency spectrum (red bars)
//
// Bar graph:
//   16 columns, each 40 pixels wide (640/16)
//   Each half is 240 pixels tall, 16 height levels -> 15 px per unit
//   Bars grow upward from the baseline of each half
//
// Controls:
//   vga_enable     (SW[7]): LOW  = background only (no bars drawn)
//                           HIGH = draw bar graphs over background
//   bg_color_select (SW[6]): LOW  = white background
//                            HIGH = tinted background (dark green top, dark red bottom)
// ============================================================


module VGA_display_wrapper (
	// System inputs
	input  logic        CLOCK_50,
	input  logic        reset,
	input  logic        vga_enable,        // SW[7]: HIGH = show graphs, LOW = background only
	input  logic        bg_color_select,   // SW[6]: LOW = white bg, HIGH = green/red tinted bg
	
	// Data inputs: column heights for both modes (16 columns x 5-bit height each)
	input  logic [4:0]  amp_column_heights [0:15],
	input  logic [4:0]  fft_column_heights [0:15],
	
	// VGA physical output pins
	output logic [7:0]  VGA_R,
	output logic [7:0]  VGA_G,
	output logic [7:0]  VGA_B,
	output logic        VGA_BLANK_N,
	output logic        VGA_CLK,
	output logic        VGA_HS,
	output logic        VGA_SYNC_N,
	output logic        VGA_VS
);



	// --------------------------------------------------------
	// VGA Driver Interface Signals
	// --------------------------------------------------------
	logic [9:0] vga_x;
	logic [8:0] vga_y;
	logic [7:0] vga_r, vga_g, vga_b;
	
	video_driver #(.WIDTH(640), .HEIGHT(480)) vga_driver_inst (
		.CLOCK_50    (CLOCK_50),
		.reset       (reset),
		.x           (vga_x),
		.y           (vga_y),
		.r           (vga_r),
		.g           (vga_g),
		.b           (vga_b),
		.VGA_R       (VGA_R),
		.VGA_G       (VGA_G),
		.VGA_B       (VGA_B),
		.VGA_BLANK_N (VGA_BLANK_N),
		.VGA_CLK     (VGA_CLK),
		.VGA_HS      (VGA_HS),
		.VGA_SYNC_N  (VGA_SYNC_N),
		.VGA_VS      (VGA_VS)
	);
	
	
	
	// --------------------------------------------------------
	// Snapshot Registers
	// --------------------------------------------------------
	logic [4:0] amp_snap [0:15];
	logic [4:0] fft_snap [0:15];
	
	always_ff @(posedge CLOCK_50) 
	begin
		if (reset) 
		begin
			for (int i = 0; i < 16; i++) 
			begin
				amp_snap[i] <= 5'd0;
				fft_snap[i] <= 5'd0;
			end
		end 
		else 
		begin
			for (int i = 0; i < 16; i++) 
			begin
				amp_snap[i] <= amp_column_heights[i];
				fft_snap[i] <= fft_column_heights[i];
			end
		end
	end
	
	
	
	// --------------------------------------------------------
	// Display Layout Parameters
	// --------------------------------------------------------
	localparam COL_WIDTH      = 40;
	localparam HALF_HEIGHT    = 240;
	localparam BAR_UNIT       = 15;
	localparam COL_GAP        = 1;
	localparam DIVIDER_Y_TOP  = 239;
	localparam DIVIDER_Y_BOT  = 240;



	// --------------------------------------------------------
	// Background Color Constants
	// --------------------------------------------------------

	// White background (SW[6] == 0)
	localparam BG_WHITE_R     = 8'd255;
	localparam BG_WHITE_G     = 8'd255;
	localparam BG_WHITE_B     = 8'd255;

	// Tinted backgrounds (SW[6] == 1)
	localparam BG_GREEN_R     = 8'd0;
	localparam BG_GREEN_G     = 8'd30;
	localparam BG_GREEN_B     = 8'd5;

	localparam BG_RED_R       = 8'd30;
	localparam BG_RED_G       = 8'd0;
	localparam BG_RED_B       = 8'd5;

	// Divider color (same for both background modes)
	localparam DIVIDER_R      = 8'd120;
	localparam DIVIDER_G      = 8'd120;
	localparam DIVIDER_B      = 8'd120;

	// Bar colors (same regardless of background mode)
	localparam BAR_AMP_R      = 8'd30;
	localparam BAR_AMP_G      = 8'd255;
	localparam BAR_AMP_B      = 8'd30;

	localparam BAR_FFT_R      = 8'd255;
	localparam BAR_FFT_G      = 8'd30;
	localparam BAR_FFT_B      = 8'd30;
	
	
	
	// --------------------------------------------------------
	// Combinational signals declared OUTSIDE always_comb
	// --------------------------------------------------------
	logic [9:0]  col_idx;
	logic [9:0]  pos_in_col;
	logic        in_bar_region;
	logic [9:0]  bar_px_h;
	logic [9:0]  bar_top_y;
	logic [9:0]  local_y;
	logic [9:0]  bar_px_h_f;
	logic [9:0]  bar_top_y_f;

	
	
	// --------------------------------------------------------
	// Pixel Color Generation (combinational)
	// --------------------------------------------------------
	always_comb 
	begin
		// --- Default: black (overwritten below) ---
		vga_r = 8'd0;
		vga_g = 8'd0;
		vga_b = 8'd0;
		
		// --- Compute column geometry ---
		col_idx       = vga_x / COL_WIDTH;
		pos_in_col    = vga_x % COL_WIDTH;
		in_bar_region = (col_idx < 10'd16) &&
		                (pos_in_col >= COL_GAP) &&
		                (pos_in_col < (COL_WIDTH - COL_GAP));
		
		// --- Pre-compute bar heights (default to 0) ---
		bar_px_h    = 10'd0;
		bar_top_y   = 10'd0;
		local_y     = 10'd0;
		bar_px_h_f  = 10'd0;
		bar_top_y_f = 10'd0;

		if (col_idx < 10'd16) 
		begin
			bar_px_h    = {5'd0, amp_snap[col_idx[3:0]]} * BAR_UNIT;
			bar_top_y   = (HALF_HEIGHT - 1) - bar_px_h;
			local_y     = {1'b0, vga_y} - HALF_HEIGHT;
			bar_px_h_f  = {5'd0, fft_snap[col_idx[3:0]]} * BAR_UNIT;
			bar_top_y_f = (HALF_HEIGHT - 1) - bar_px_h_f;
		end

		
		
		// --------------------------------------------------
		// Step 1: Draw background layer
		//         Always drawn first, bars are overlaid on top
		// --------------------------------------------------
		if (vga_y == DIVIDER_Y_TOP || vga_y == DIVIDER_Y_BOT) 
		begin
			// Divider line: same color regardless of SW[6]
			vga_r = DIVIDER_R;
			vga_g = DIVIDER_G;
			vga_b = DIVIDER_B;
		end
		else if (vga_y < HALF_HEIGHT) 
		begin
			// Top half background
			if (bg_color_select) 
			begin
				// SW[6] == 1: deep green tint
				vga_r = BG_GREEN_R;
				vga_g = BG_GREEN_G;
				vga_b = BG_GREEN_B;
			end
			else 
			begin
				// SW[6] == 0: white
				vga_r = BG_WHITE_R;
				vga_g = BG_WHITE_G;
				vga_b = BG_WHITE_B;
			end
		end
		else 
		begin
			// Bottom half background
			if (bg_color_select) 
			begin
				// SW[6] == 1: deep red tint
				vga_r = BG_RED_R;
				vga_g = BG_RED_G;
				vga_b = BG_RED_B;
			end
			else 
			begin
				// SW[6] == 0: white
				vga_r = BG_WHITE_R;
				vga_g = BG_WHITE_G;
				vga_b = BG_WHITE_B;
			end
		end

		
		
		// --------------------------------------------------
		// Step 2: Overlay bar graphs (only when VGA enabled)
		// --------------------------------------------------
		if (vga_enable) 
		begin
		
			// Top half: Amplitude bars (y = 0 to 238)
			if (vga_y < HALF_HEIGHT && vga_y != DIVIDER_Y_TOP) 
			begin
				if (in_bar_region) 
				begin
					if ({1'b0, vga_y} > bar_top_y && vga_y < (HALF_HEIGHT - 1)) 
					begin
						// Bright vivid green bar
						vga_r = BAR_AMP_R;
						vga_g = BAR_AMP_G;
						vga_b = BAR_AMP_B;
					end 
					// else: background shows through
				end
			end
			
			// Bottom half: FFT bars (y = 241 to 479)
			else if (vga_y > DIVIDER_Y_BOT) 
			begin
				if (in_bar_region) 
				begin
					if (local_y > bar_top_y_f && local_y <= (HALF_HEIGHT - 1)) 
					begin
						// Bright vivid red bar
						vga_r = BAR_FFT_R;
						vga_g = BAR_FFT_G;
						vga_b = BAR_FFT_B;
					end 
					// else: background shows through
				end
			end
			
		end // END OF if (vga_enable)
		
		// else: vga_enable == 0, only background colors are shown
		
		
	end // END OF always_comb

	
	

endmodule