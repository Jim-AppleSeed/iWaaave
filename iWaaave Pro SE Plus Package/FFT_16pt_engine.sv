//
// Author: Jim He
//
// Assignment: EE 271 Final Project: iWaaave Pro - Audio Signal Processing & Waveform Display
//
// Date Started: March 6, 2026
//
// Date Completed: March 6, 2026
//
// Description: This module implements the 16-point Cooley-Tukey (Radix-2) Decimation-in-Time (DIT) FFT Algorithm, using an iterative approach with a FSM.
//

// FFT_16pt_engine.sv



// 
// ============================================================
// FFT_16pt_engine.sv — 16-Point Radix-2 DIT FFT Engine
// ============================================================
// Algorithm: Cooley-Tukey Radix-2 DIT
// Stages: 4 (log2(16) = 4)
// Butterflies per stage: 8
// Arithmetic: Fixed-point Q1.14 (16-bit signed)
// Twiddle factors: Pre-computed, stored as constants
//
// State machine flow:
//   IDLE → LOAD → STAGE1 → STAGE2 → STAGE3 → STAGE4 → DONE → IDLE
//
// Each STAGE state iterates through 8 butterfly operations using a butterfly counter (bfly_cnt).
// ============================================================


// Module inputs: clk, reset, start, X_in
// Module outputs: X_re, X_im, done_signal


module FFT_16pt_engine (clk, reset, start, X_in, X_re, X_im, done_signal);
	input logic clk; 
	input logic reset;
	input logic start;
	input logic signed [15:0] X_in [0:15];    // 16 input samples (Q1.14)
	output logic signed [15:0] X_re [0:15];   // FFT output real parts
	output logic signed [15:0] X_im [0:15];   // FFT output imaginary parts
	output logic done_signal;
	

	// Define State Variables
	typedef enum logic [2:0] 
	{
		S_IDLE   = 3'd0,
		S_LOAD   = 3'd1,
		S_STAGE1 = 3'd2,
		S_STAGE2 = 3'd3,
		S_STAGE3 = 3'd4,
		S_STAGE4 = 3'd5,
		S_DONE   = 3'd6
	} state_t;
   
	state_t present_state, next_state;
    
    
	
	 
	// -------------------------------------------------------
	// Working data arrays (real and imaginary)
	// -------------------------------------------------------
	logic signed [15:0] data_re [0:15];
	logic signed [15:0] data_im [0:15];
    
    
	 
	 
   // -------------------------------------------------------
   // Butterfly counter (0-7, 8 butterflies per stage)
   // -------------------------------------------------------
   logic [2:0] bfly_cnt;
	
	
	// NOTE //
	// -------------------------------------------------------
	// Twiddle Factor ROM (Q1.14 format)
	// -------------------------------------------------------
	// W_16^k = cos(2*pi*k/16) - j*sin(2*pi*k/16)
   // Stored as: tw_re[k] = round(cos(2*pi*k/16) * 16384)
   //            tw_im[k] = round(-sin(2*pi*k/16) * 16384)
   // Note: tw_im has NEGATIVE sign because W = cos - j*sin
   //
   // k=0: cos=1.0000  sin=0.0000  → re=16384, im=0
   // k=1: cos=0.9239  sin=0.3827  → re=15137, im=-6270
	// k=2: cos=0.7071  sin=0.7071  → re=11585, im=-11585
   // k=3: cos=0.3827  sin=0.9239  → re=6270,  im=-15137
   // k=4: cos=0.0000  sin=1.0000  → re=0,     im=-16384
   // k=5: cos=-0.3827 sin=0.9239  → re=-6270, im=-15137
   // k=6: cos=-0.7071 sin=0.7071  → re=-11585,im=-11585
   // k=7: cos=-0.9239 sin=0.3827  → re=-15137,im=-6270
   // -------------------------------------------------------
	
	logic signed [15:0] tw_re [0:7];
	logic signed [15:0] tw_im [0:7];
	
	assign tw_re[0] = 16'sd16384;   assign tw_im[0] = 16'sd0;
	assign tw_re[1] = 16'sd15137;   assign tw_im[1] = -16'sd6270;
	assign tw_re[2] = 16'sd11585;   assign tw_im[2] = -16'sd11585;
	assign tw_re[3] = 16'sd6270;    assign tw_im[3] = -16'sd15137;
	assign tw_re[4] = 16'sd0;       assign tw_im[4] = -16'sd16384;
	assign tw_re[5] = -16'sd6270;   assign tw_im[5] = -16'sd15137;
	assign tw_re[6] = -16'sd11585;  assign tw_im[6] = -16'sd11585;
	assign tw_re[7] = -16'sd15137;  assign tw_im[7] = -16'sd6270;
	
	
	
	
	// -------------------------------------------------------
	// Bit-Reversal Function (4-bit)
	// -------------------------------------------------------
	function automatic [3:0] bit_reverse_4(input [3:0] idx);			// ? // What is this "function" doing in system verilog?	
		bit_reverse_4 = {idx[0], idx[1], idx[2], idx[3]};
	endfunction
	
	
	
	
	// -------------------------------------------------------
	// Butterfly Index Calculation
	// -------------------------------------------------------
	// For each stage s (1-4), given butterfly count bfly_cnt (0-7):
	//   block_size = 2^s
	//   half       = 2^(s-1)
	//   block_num  = bfly_cnt / half  (which block this butterfly is in)
	//   bfly_in_blk = bfly_cnt % half (position within the block)
	//   top_idx    = block_num * block_size + bfly_in_blk
	//   bot_idx    = top_idx + half
	//   tw_idx     = bfly_in_blk * (8 / half) = bfly_in_blk * (N/2 / 2^(s-1))
	//              = bfly_in_blk << (4 - s)  ... but we need to keep it 0-7
	//
	// Let's compute these as combinational signals based on present state.
	// -------------------------------------------------------
	
	logic [3:0] top_idx, bot_idx;
	logic [2:0] tw_idx;
    
	always_comb 
	begin
		top_idx = 4'd0;
		bot_idx = 4'd0;
		tw_idx  = 3'd0;
        
		case (present_state)
			S_STAGE1: 
			begin
				// block_size=2, half=1
				// top = bfly_cnt*2, bot = top+1
            // tw = 0 (all butterflies use W^0 in stage 1)
				top_idx = {bfly_cnt, 1'b0};    // bfly_cnt * 2
				bot_idx = {bfly_cnt, 1'b1};    // bfly_cnt * 2 + 1
				tw_idx  = 3'd0;
			end
            
			S_STAGE2: 
			begin
				// block_size=4, half=2
				// block_num = bfly_cnt / 2 = bfly_cnt[2:1]
				// bfly_in_blk = bfly_cnt % 2 = bfly_cnt[0]
				// top = block_num*4 + bfly_in_blk
				// bot = top + 2
				// tw = bfly_in_blk * 4
				top_idx = {bfly_cnt[2:1], 1'b0, bfly_cnt[0]};   // block_num*4 + bfly_in_blk
				bot_idx = top_idx + 4'd2;
				tw_idx  = {bfly_cnt[0], 2'b00};  // bfly_in_blk * 4
			end
            
			S_STAGE3: 
			begin
				// block_size=8, half=4
				// block_num = bfly_cnt / 4 = bfly_cnt[2]
				// bfly_in_blk = bfly_cnt % 4 = bfly_cnt[1:0]
				// top = block_num*8 + bfly_in_blk
				// bot = top + 4
				// tw = bfly_in_blk * 2
				top_idx = {bfly_cnt[2], 1'b0, bfly_cnt[1:0]};   // block_num*8 + bfly_in_blk
				bot_idx = top_idx + 4'd4;
				tw_idx  = {bfly_cnt[1:0], 1'b0};  // bfly_in_blk * 2
			end
            
			S_STAGE4: 
			begin
				// block_size=16, half=8
				// Only 1 block, all 8 butterflies
				// top = bfly_cnt
				// bot = bfly_cnt + 8
				// tw = bfly_cnt
				top_idx = {1'b0, bfly_cnt};
				bot_idx = {1'b1, bfly_cnt};
				tw_idx  = bfly_cnt;
			end
            
			default: 
			begin
				top_idx = 4'd0;
				bot_idx = 4'd0;
				tw_idx  = 3'd0;
			end
		endcase
		
	end // END OF always_comb
    
	 
	 
    
	// -------------------------------------------------------
	// Butterfly Computation (combinational)
	// -------------------------------------------------------
	logic signed [15:0] a_re, a_im, b_re, b_im;
	logic signed [15:0] w_re, w_im;
	logic signed [31:0] prod1, prod2, prod3, prod4;
	logic signed [15:0] t_re, t_im;
	logic signed [15:0] a_out_re, a_out_im, b_out_re, b_out_im;
	
	always_comb 
	begin
		// Read inputs
		a_re = data_re[top_idx];
		a_im = data_im[top_idx];
		b_re = data_re[bot_idx];
		b_im = data_im[bot_idx];
		w_re = tw_re[tw_idx];
		w_im = tw_im[tw_idx];
		
		// Complex multiply: t = b * w
		prod1 = b_re * w_re;   // Q1.14 * Q1.14 = Q2.28
		prod2 = b_im * w_im;
		prod3 = b_re * w_im;
		prod4 = b_im * w_re;
		
		t_re = (prod1 - prod2) >>> 14;  // Back to Q1.14
		t_im = (prod3 + prod4) >>> 14;
		
		// Butterfly: add and subtract
		a_out_re = a_re + t_re;
		a_out_im = a_im + t_im;
		b_out_re = a_re - t_re;
		b_out_im = a_im - t_im;
	end
	
	
	
	
	// -------------------------------------------------------
	// State Flip Flop - Data Path
	// -------------------------------------------------------
	always_ff @ (posedge clk) 
	begin
		if (reset) 
		begin
			present_state <= S_IDLE;
			done_signal <= '0;
			bfly_cnt <= '0;
			
			for (int i = 0; i < 16; i++) 
			begin
                data_re[i] <= 16'sd0;
                data_im[i] <= 16'sd0;
                X_re[i]    <= 16'sd0;
                X_im[i]    <= 16'sd0;
			end
		end // END OF if
        
		else 
		begin
			done_signal <= '0;  // default: done is a pulse
            
			case (present_state)  
				S_IDLE: 
				begin
					if (start) 
					begin
						present_state <= S_LOAD;
						bfly_cnt <= 3'd0;
					end
				end
                
				S_LOAD: 
				begin
					// Apply bit-reversal permutation and load data
					for (int i = 0; i < 16; i++) 
					begin
						data_re[bit_reverse_4(i[3:0])] <= X_in[i];
						data_im[bit_reverse_4(i[3:0])] <= 16'sd0;
					end
					
					present_state <= S_STAGE1;
					bfly_cnt <= '0;
				end
                
				S_STAGE1, S_STAGE2, S_STAGE3, S_STAGE4: 
				begin
					// Perform butterfly operation
					data_re[top_idx] <= a_out_re;
					data_im[top_idx] <= a_out_im;
					data_re[bot_idx] <= b_out_re;
					data_im[bot_idx] <= b_out_im;
                    
					if (bfly_cnt == 3'd7) 
					begin
						// All 8 butterflies in this stage done
						bfly_cnt <= '0;
						case (present_state)
							S_STAGE1: present_state <= S_STAGE2;
							S_STAGE2: present_state <= S_STAGE3;
							S_STAGE3: present_state <= S_STAGE4;
							S_STAGE4: present_state <= S_DONE;
							default:  present_state <= S_DONE;
						endcase
					end
                    
					else 
					begin
						bfly_cnt <= bfly_cnt + 3'd1;
               end
				end
                
				S_DONE: 
				begin
					// Copy results to output
					for (int i = 0; i < 16; i++) 
					begin
						X_re[i] <= data_re[i];
						X_im[i] <= data_im[i];
					end
					
					done_signal <= 1'b1;
					present_state <= S_IDLE;
				end
                
				default: present_state <= S_IDLE;
                
			endcase
			
		end // END OF else
		
	end // END OF always_ff

	
	
	
	
endmodule