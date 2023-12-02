/*
 * Copyright (C) 2023 nukeykt
 *
 * This file is part of LPC-Sound-Blaster.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 *  Sound Blaster over LPC
 *  Thanks:
 *      Tube Time:
 *          sound blaster firmware disassembly
 *      The DOSBox Team:
 *          useful info from sblaster.cpp
 *
 */
// lpc sound blaster
module sblaster
	(
	input CLK, // LPC Clock
	input reset,
	input LPC_FRM,
	inout [3:0] LPC_DATA,
	inout SERIRQ,
	output reg LPC_DREQ,

	output [15:0] audio_l,
	output [15:0] audio_r
	);
	
	wire ym_clk = CLK;
	
	reg [16:0] ym_cnt;
	
	wire ym_clk2 = ym_cnt[16];
	
	always @(posedge CLK)
	begin
		ym_cnt <= ym_cnt + 56301;
	end
		
	wire ym_ic = ~reset;
	
	reg [15:0] ym_left;
	reg [15:0] ym_right;
	reg [15:0] dac_shifter;
	reg o_sy;
	reg o_smpac;
	reg o_smpbd;
	reg sy;
	
	wire ym_sy;
	wire ym_doab;
	wire ym_smpac;
	wire ym_smpbd;
	
	reg ym_a0;
	reg ym_a1;
	reg ym_wr;
	reg ym_rd;
	reg ym_dir;
	
	always @(posedge ym_clk)
	begin
		if (~sy & o_sy)
		begin
		
			if (o_smpbd & ~ym_smpbd)
				ym_left <= dac_shifter ^ 16'h8000;
			if (o_smpac & ~ym_smpac)
				ym_right <= dac_shifter ^ 16'h8000;
			
			dac_shifter <= { ym_doab, dac_shifter[15:1] };
			o_smpac <= ym_smpac;
			o_smpbd <= ym_smpbd;
		end
		
		o_sy <= sy;
		
		sy <= ym_sy;
	end
	
	reg [7:0] lpc_cnt;
	reg io_write;
	reg io_read;
	reg io_dmaread;
	reg [15:0] io_address;
	reg [7:0] wr_data;
	reg lpc_state;
	reg [3:0] lpc_out;
	reg ym_dir2;
	
	wire [7:0] ym_data_o;
	wire ym_data_d;
	
	reg [7:0] rd_data;
	
	ymf262 opl3
	(
	.MCLK(ym_clk),
	.CLK(ym_clk2),
	.IC(ym_ic),
	.ADDRESS({ym_a1, ym_a0}),
	.DATA_i(wr_data),
	.DATA_o(ym_data_o),
	.DATA_d(ym_data_d),
	.WR(ym_wr),
	.RD(ym_rd),
	.CS(1'h0),
	.SY(ym_sy),
	.DOAB(ym_doab),
	.SMPAC(ym_smpac),
	.SMPBD(ym_smpbd)
	);
	
	assign LPC_DATA = lpc_state ? lpc_out : 'hz;
	
	//assign ym_data = ym_dir2 ? wr_data : 'hz;
	
	wire [15:0] sbbase = 16'h220;
	wire [2:0] sbdma = 1;
	wire [7:0] sbirq = 7;
	
	wire issbaddr = (io_address & 16'hfff0) == sbbase;
	
	wire sba_adlib = io_address[3:2] == 2'h0 | io_address[3:1] == 3'h4;
	wire sba_mixer_a = io_address[3:0] == 4'h4;
	wire sba_mixer_d = io_address[3:0] == 4'h5;
	wire sba_reset = io_address[3:0] == 4'h6;
	wire sba_read_data = io_address[3:0] == 4'ha;
	wire sba_read_status = io_address[3:0] == 4'he;
	wire sba_write_data = io_address[3:0] == 4'hc;
	wire sba_dsp_busy = io_address[3:0] == 4'hc;
	
	wire isadlib = (io_address & 16'hfffc) == 16'h388 | (issbaddr & sba_adlib);
	
	wire goodaddr = isadlib | issbaddr;
	
	reg dsp_busy;
	
	
	reg [7:0] dsp_write;
	reg [7:0] dsp_read;
	
	reg dsp_write_rdy;
	reg dsp_read_rdy;
	reg dsp_reset;
	
	reg [15:0] dsp_fsm;
	reg [15:0] dsp_fsm_shadow;
	
	reg [15:0] dsp_length;
	reg [15:0] dsp_length2;
	reg [15:0] dsp_length3;
	
	reg [15:0] dsp_blocksize;
	
	reg dsp_dma;
	reg dsp_dma2;
	reg dsp_autoinit;
	reg dsp_pause;
	reg dsp_stereosel;
	
	reg [7:0] mxr_address;
	reg [7:0] mxr_reg4;
	reg [7:0] mxr_rega;
	reg [7:0] mxr_regc;
	reg [7:0] mxr_rege;
	reg [7:0] mxr_reg22;
	reg [7:0] mxr_reg26;
	reg [7:0] mxr_reg28;
	reg [7:0] mxr_reg2e;
	
	wire mxr_stereo = mxr_rege[1];
	
	reg [7:0] dsp_tc;
	
	reg [16:0] dsp_prescaler;
	reg dsp_pof_o;
	wire dsp_pof = dsp_prescaler[16];
	reg [7:0] dsp_counter;
	
	reg [7:0] dsp_dma_req;
	
	reg [2:0] io_dma_chan;
	reg [1:0] io_dma_size;
	reg [15:0] io_dma_data;
	reg io_dma_rdy;
	
	reg dsp_irq_req;
	reg dsp_irq_val;
	
	
	reg irq_sleep;
	reg [7:0] irq_state;
	reg [7:0] irq_stopcnt;
	
	reg sr_state;
	reg sr_value;
	reg sr_clear;
	
	reg [15:0] dsp_left;
	reg [15:0] dsp_right;
	
	reg [16:0] dac_left;
	reg [16:0] dac_right;
	
	assign audio_l = dac_left[15:0];
	assign audio_r = dac_right[15:0];
	
	reg dsp_spk;
	
`define ADPCM_NONE 0
`define ADPCM_4b 1
`define ADPCM_3b 2
`define ADPCM_2b 3
	reg [1:0] dsp_adpcm;
	reg [1:0] dsp_adpcm_cnt;
	reg [7:0] dsp_adpcm_ref;
	reg [2:0] dsp_adpcm_shift;
	reg [7:0] dsp_adpcm_byte;
	reg dsp_adpcm_refbyte;
	reg dsp_adpcm_rdy;
	
	reg dsp_adpcm_sign;
	reg [2:0] dsp_adpcm_val;
	reg dsp_adpcm_of;
	reg dsp_adpcm_adju;
	reg dsp_adpcm_adjd;
	reg [2:0] dsp_adpcm_shiftmax;
	
	wire [7:0] dsp_adpcm_add1 = ({ 6'h0, dsp_adpcm_val } << dsp_adpcm_shift) + (dsp_adpcm_shift != 3'h0 ? 8'h1 << (dsp_adpcm_shift - 3'h1) : 8'h0);
	wire [7:0] dsp_adpcm_adds = dsp_adpcm_sign ? -dsp_adpcm_add1 : dsp_adpcm_add1;
	wire [7:0] dsp_adpcm_sum = dsp_adpcm_ref + dsp_adpcm_adds;
	wire dsp_adpcm_sum_of = dsp_adpcm_ref[7] & ~dsp_adpcm_adds[7] & ~dsp_adpcm_sum[7];
	wire dsp_adpcm_sum_uf = ~dsp_adpcm_ref[7] & dsp_adpcm_adds[7] & dsp_adpcm_sum[7];
	wire [7:0] dsp_adpcm_clip = dsp_adpcm_sum_of ? 8'hff : (dsp_adpcm_sum_uf ? 8'h00 : dsp_adpcm_sum);
	
	reg dsp_silence;
	
	reg [7:0] dsp_cmd;
	
	always @(*)
	begin
		case (dsp_adpcm)
			`ADPCM_NONE:
			begin
				dsp_adpcm_sign <= 1'h0;
				dsp_adpcm_val <= 3'h0;
				dsp_adpcm_of <= 1'h0;
				dsp_adpcm_adju <= 1'h0;
				dsp_adpcm_adjd <= 1'h0;
				dsp_adpcm_shiftmax <= 3'h0;
			end
			`ADPCM_4b:
			begin
				if (dsp_adpcm_cnt == 2'h0)
				begin
					dsp_adpcm_sign <= dsp_adpcm_byte[7];
					dsp_adpcm_val <= dsp_adpcm_byte[6:4];
				end
				else
				begin
					dsp_adpcm_sign <= dsp_adpcm_byte[3];
					dsp_adpcm_val <= dsp_adpcm_byte[2:0];
				end
				dsp_adpcm_of <= dsp_adpcm_cnt == 2'h1;
				dsp_adpcm_adjd <= dsp_adpcm_val == 3'h0;
				dsp_adpcm_adju <= dsp_adpcm_val >= 3'h5;
				dsp_adpcm_shiftmax <= 3'h3;
			end
			`ADPCM_3b:
			begin
				if (dsp_adpcm_cnt == 2'h0)
				begin
					dsp_adpcm_sign <= dsp_adpcm_byte[7];
					dsp_adpcm_val <= { 1'h0, dsp_adpcm_byte[6:5] };
				end
				else if (dsp_adpcm_cnt == 2'h1)
				begin
					dsp_adpcm_sign <= dsp_adpcm_byte[4];
					dsp_adpcm_val <= { 1'h0, dsp_adpcm_byte[3:2] };
				end
				else
				begin
					dsp_adpcm_sign <= dsp_adpcm_byte[1];
					dsp_adpcm_val <= { 2'h0, dsp_adpcm_byte[0] };
				end
				dsp_adpcm_of <= dsp_adpcm_cnt == 2'h2;
				dsp_adpcm_adjd <= dsp_adpcm_val == 3'h0;
				dsp_adpcm_adju <= dsp_adpcm_val == 3'h3;
				dsp_adpcm_shiftmax <= 3'h4;
			end
			`ADPCM_2b:
			begin
				if (dsp_adpcm_cnt == 2'h0)
				begin
					dsp_adpcm_sign <= dsp_adpcm_byte[7];
					dsp_adpcm_val <= { 2'h0, dsp_adpcm_byte[6] };
				end
				else if (dsp_adpcm_cnt == 2'h1)
				begin
					dsp_adpcm_sign <= dsp_adpcm_byte[5];
					dsp_adpcm_val <= { 2'h0, dsp_adpcm_byte[4] };
				end
				else if (dsp_adpcm_cnt == 2'h2)
				begin
					dsp_adpcm_sign <= dsp_adpcm_byte[3];
					dsp_adpcm_val <= { 2'h0, dsp_adpcm_byte[2] };
				end
				else
				begin
					dsp_adpcm_sign <= dsp_adpcm_byte[1];
					dsp_adpcm_val <= { 2'h0, dsp_adpcm_byte[0] };
				end
				dsp_adpcm_of <= dsp_adpcm_cnt == 2'h3;
				dsp_adpcm_adjd <= dsp_adpcm_val == 3'h0;
				dsp_adpcm_adju <= dsp_adpcm_val == 3'h1;
				dsp_adpcm_shiftmax <= 3'h5;
			end
		endcase
	end
	
	assign SERIRQ = sr_state ? sr_value : 'hz;
	
	always @(posedge CLK)
	begin
		if (reset)
		begin
			lpc_cnt <= 0;
			io_write <= 0;
			io_read <= 0;
			lpc_state <= 0;
			lpc_out <= 0;
			ym_a0 <= 0;
			ym_a1 <= 0;
			ym_wr <= 1;
			ym_rd <= 1;
			ym_dir <= 1;
			ym_dir2 <= 1;
			
			io_dma_rdy <= 0;
			
			irq_sleep <= 1;
			irq_state <= 0;
			sr_state <= 0;
			sr_value <= 0;
			sr_clear <= 0;
			
			dsp_busy <= 0;
			dsp_write <= 0;
			dsp_read <= 0;
			dsp_write_rdy <= 0;
			dsp_read_rdy <= 0;
			dsp_reset <= 0;
			dsp_fsm <= 0;
			dsp_dma <= 0;
			dsp_dma2 <= 0;
			dsp_blocksize <= 0;
			dsp_autoinit <= 0;
			dsp_tc <= 0;
			dsp_length <= 0;
			dsp_length2 <= 0;
			dsp_length3 <= 0;
			dsp_dma_req <= 0;
			dsp_irq_req <= 0;
			dsp_irq_val <= 0;
			dsp_left <= 0;
			dsp_right <= 0;
			dsp_spk <= 0;
			dsp_pause <= 0;
			dsp_stereosel <= 0;
			dsp_cmd <= 0;
			
			dsp_adpcm <= 0;
			dsp_adpcm_cnt <= 0;
			dsp_adpcm_ref <= 0;
			dsp_adpcm_shift <= 0;
			dsp_adpcm_byte <= 0;
			dsp_adpcm_refbyte <= 0;
			dsp_adpcm_rdy <= 0;
			
			dsp_silence <= 0;
			
			mxr_address <= 0;
			mxr_reg4 <= 0;
			mxr_rega <= 0;
			mxr_regc <= 0;
			mxr_rege <= 0;
			mxr_reg22 <= 0;
			mxr_reg26 <= 0;
			mxr_reg28 <= 0;
			mxr_reg2e <= 0;
	
			LPC_DREQ <= 1;
		end
		else
		begin
			if (~LPC_FRM & LPC_DATA == 4'h0)
			begin
				lpc_cnt <= 1;
			end
			else if (lpc_cnt == 1)
			begin
				io_write <= LPC_DATA == 4'h2;
				io_read <= LPC_DATA == 4'h0;
				io_dmaread <= LPC_DATA == 4'h8;
				lpc_cnt <= 2;
			end
			else if (io_write)
			begin
				if (lpc_cnt == 6 & ~goodaddr) // ignore
					lpc_cnt <= 0;
				else if (lpc_cnt == 15)
					lpc_cnt <= 0;
				else
					lpc_cnt <= lpc_cnt + 1;
				case (lpc_cnt)
					2: io_address[15:12] <= LPC_DATA;
					3: io_address[11:8] <= LPC_DATA;
					4: io_address[7:4] <= LPC_DATA;
					5: io_address[3:0] <= LPC_DATA;
					6: wr_data[3:0] <= LPC_DATA;
					7: wr_data[7:4] <= LPC_DATA;
					8: begin ym_a0 <= io_address[0]; ym_a1 <= io_address[1]; end
					// 8, 9 TAR
					9: begin lpc_state <= 1; lpc_out <= 4'h6; end
					13: lpc_out <= 4'h0;
					14: lpc_out <= 4'hf;
					15: begin lpc_state <= 0; end
				endcase
				if (isadlib)
				begin
					case (lpc_cnt)
						9: ym_wr <= 0;
						14: ym_wr <= 1;
					endcase
				end
				else if (issbaddr)
				begin
					if (lpc_cnt == 9)
					begin
						if (sba_reset) dsp_reset <= wr_data[0];
						if (sba_write_data) begin dsp_write <= wr_data; dsp_write_rdy <= 1; end
						if (sba_mixer_a) mxr_address <= wr_data;
						if (sba_mixer_d)
						begin
							case (mxr_address)
								8'h0:
								begin
									mxr_reg4 <= 8'h88;
									mxr_rega <= 8'h0;
									mxr_regc <= 8'h0;
									mxr_rege <= 8'h0;
									mxr_reg22 <= 8'h88;
									mxr_reg26 <= 8'h88;
									mxr_reg28 <= 8'h8;
									mxr_reg2e <= 8'h0;
								end
								8'h4: mxr_reg4 <= wr_data;
								8'ha: mxr_rega <= wr_data;
								8'hc: mxr_regc <= wr_data;
								8'he: mxr_rege <= wr_data;
								8'h22: mxr_reg22 <= wr_data;
								8'h26: mxr_reg26 <= wr_data;
								8'h28: mxr_reg28 <= wr_data;
								8'h2e: mxr_reg2e <= wr_data;
							endcase
						end
					end
				end
			end
			else if (io_read)
			begin
				if (lpc_cnt == 6 &  ~goodaddr) // ignore
					lpc_cnt <= 0;
				else if (lpc_cnt == 15)
					lpc_cnt <= 0;
				else
					lpc_cnt <= lpc_cnt + 1;
				case (lpc_cnt)
					2: io_address[15:12] <= LPC_DATA;
					3: io_address[11:8] <= LPC_DATA;
					4: io_address[7:4] <= LPC_DATA;
					5: io_address[3:0] <= LPC_DATA;
					6: begin ym_a0 <= io_address[0]; ym_a1 <= io_address[1]; end
					// 6, 7 TAR
					7: begin lpc_state <= 1; lpc_out <= 4'h6; end
					11: begin lpc_out <= 4'h0; end
					12: lpc_out <= rd_data[3:0];
					13: lpc_out <= rd_data[7:4];
					14: begin lpc_out <= 4'hf; end
					15: begin lpc_state <= 0; end
				endcase
				if (isadlib)
				begin
					case (lpc_cnt)
						6: ym_dir2 <= 0;
						7: begin ym_rd <= 0; ym_dir <= 0; end
						11: rd_data <= ym_data_d ? 8'hff : ym_data_o;
						14: begin ym_rd <= 1; ym_dir <= 1; end
						15: ym_dir2 <= 1;
					endcase
				end
				else if (issbaddr)
				begin
					if (lpc_cnt == 7)
					begin
						if (sba_read_data) begin rd_data <= dsp_read; dsp_read_rdy <= 0; end
						else if (sba_read_status) begin rd_data <= { dsp_read_rdy, 7'h7f }; if (dsp_irq_val) begin dsp_irq_val <= 0; dsp_irq_req <= 1; end end
						else if (sba_dsp_busy) rd_data <= { dsp_busy, 7'h7f };
						else if (sba_mixer_d)
						begin
							case (mxr_address)
								8'h4: rd_data <= mxr_reg4;
								8'ha: rd_data <= mxr_rega;
								8'hc: rd_data <= mxr_regc;
								8'he: rd_data <= mxr_rege;
								8'h22: rd_data <= mxr_reg22;
								8'h26: rd_data <= mxr_reg26;
								8'h28: rd_data <= mxr_reg28;
								8'h2e: rd_data <= mxr_reg2e;
								default: rd_data <= 8'h0;
							endcase
						end
						else rd_data <= 8'hff;
					end
				end
			end
			else if (io_dmaread)
			begin
				if (lpc_cnt == 4 & (io_dma_chan != sbdma | io_dma_size[1])) // ignore
					lpc_cnt <= 0;
				else if (lpc_cnt == 11)
					lpc_cnt <= 0;
				else if (lpc_cnt == 5 & ~io_dma_size[0])
					lpc_cnt <= 8;
				else
					lpc_cnt <= lpc_cnt + 1;
				case (lpc_cnt)
					2: io_dma_chan <= LPC_DATA[2:0];
					3: io_dma_size <= LPC_DATA[1:0];
					4: io_dma_data[3:0] <= LPC_DATA;
					5: io_dma_data[7:4] <= LPC_DATA;
					6: io_dma_data[11:8] <= LPC_DATA;
					7: io_dma_data[15:12] <= LPC_DATA;
					// 8, 9 TAR
					8: io_dma_rdy <= 1;
					9: begin lpc_state <= 1; lpc_out <= 4'h0; end
					10: lpc_out <= 4'hf;
					11: lpc_state <= 0;
				endcase
			end
			else
				lpc_cnt <= 0;
			
			// sb dsp emulation
		
`define DSP_IDLE 0
`define DSP_READY_STATUS 1
`define DSP_WAIT_READ 2
`define DSP_WAIT_WRITE 3
`define DSP_DSP_VERSION 16
`define DSP_TC 32
`define DSP_PLAYBACK 48
`define DSP_PLAYBACK2 64
`define DSP_BLOCKSIZE 80
`define DSP_PLAYBACKAUTO 96
`define DSP_SPKSTATUS 112
`define DSP_PLAYBACK_ADPCM 128
`define DSP_PLAYBACK_SILENCE 144
`define DSP_CHECK 160
			
			if (dsp_reset)
			begin
				dsp_write_rdy <= 0;
				dsp_read_rdy <= 0;
				dsp_busy <= 0;
				dsp_dma <= 0;
				dsp_tc <= 0;
				dsp_blocksize <= 0;
				dsp_autoinit <= 0;
				dsp_length <= 0;
				dsp_length2 <= 0;
				dsp_length3 <= 0;
				dsp_dma_req <= 0;
				dsp_irq_req <= 0;
				dsp_left <= 0;
				dsp_right <= 0;
				// dsp_spk <= 0; disable for DIGPAK
				dsp_pause <= 0;
				dsp_stereosel <= 0;
				dsp_cmd <= 0;
			
				dsp_adpcm <= 0;
				dsp_adpcm_cnt <= 0;
				dsp_adpcm_ref <= 0;
				dsp_adpcm_shift <= 0;
				dsp_adpcm_byte <= 0;
				dsp_adpcm_refbyte <= 0;
				dsp_adpcm_rdy <= 0;
			
				dsp_silence <= 0;
				
				dsp_fsm <= `DSP_READY_STATUS;
			end
			else if (dsp_fsm == `DSP_IDLE) // idle
			begin
				if (dsp_write_rdy)
				begin
					case (dsp_write)
						8'h14, 8'h91: begin if (dsp_dma & dsp_autoinit) dsp_fsm <= `DSP_PLAYBACK2; else dsp_fsm <= `DSP_PLAYBACK; dsp_stereosel <= 0; end
						8'h1c, 8'h90:
						begin
							dsp_dma <= 1;
							dsp_length <= dsp_blocksize;
							dsp_autoinit <= 1;
							dsp_pause <= 0;
							dsp_stereosel <= 0;
							dsp_adpcm <= 2'h0;
							dsp_silence <= 0;
						end
						8'h40: begin dsp_fsm <= `DSP_TC; end
						8'h48: begin dsp_fsm <= `DSP_BLOCKSIZE; end
						8'hd0: begin dsp_pause <= 1; end
						8'hd1: begin dsp_spk <= 1; end
						8'hd3: begin dsp_spk <= 0; end
						8'hd4: begin dsp_pause <= 0; end
						8'hd8: begin dsp_fsm <= `DSP_SPKSTATUS; end
						8'hda: begin dsp_autoinit <= 0; end
						8'he0: begin dsp_fsm <= `DSP_CHECK; end
						8'he1: begin dsp_fsm <= `DSP_DSP_VERSION; end
						8'h74,8'h75,8'h76,8'h77,8'h16,8'h17:
						begin
							dsp_fsm <= `DSP_PLAYBACK_ADPCM;
						end
						8'h7d, 8'h7f, 8'h1f:
						begin
							dsp_dma <= 1;
							dsp_length <= dsp_blocksize;
							dsp_autoinit <= 1;
							dsp_pause <= 0;
							dsp_adpcm_refbyte <= 1;
							if (dsp_write == 8'h7d)
								dsp_adpcm <= `ADPCM_4b;
							else if (dsp_write == 8'h7f)
								dsp_adpcm <= `ADPCM_3b;
							else if (dsp_write == 8'h1f)
								dsp_adpcm <= `ADPCM_2b;
							else
								dsp_adpcm <= 2'h0;
						end
						8'h80:
						begin
							dsp_fsm <= `DSP_PLAYBACK_SILENCE;
						end
						8'hf2:
						begin
							dsp_irq_req <= 1;
							dsp_irq_val <= 1;
						end
					endcase
					dsp_write_rdy <= 0;
					dsp_cmd <= dsp_write;
				end
			end
			else if (dsp_fsm == `DSP_READY_STATUS)
			begin
				dsp_read <= 8'haa;
				dsp_read_rdy <= 1;
				dsp_fsm <= `DSP_WAIT_READ;
				dsp_fsm_shadow <= `DSP_IDLE;
				dsp_irq_req <= 1; // pull IRQ low (wolf3d/duke2)
				dsp_irq_val <= 0;
			end
			else if (dsp_fsm == `DSP_WAIT_READ)
			begin
				if (~dsp_read_rdy)
					dsp_fsm <= dsp_fsm_shadow;
			end
			else if (dsp_fsm == `DSP_WAIT_WRITE)
			begin
				if (dsp_write_rdy)
					dsp_fsm <= dsp_fsm_shadow;
			end
			else if (dsp_fsm == `DSP_DSP_VERSION)
			begin
				dsp_read <= 8'h03;
				dsp_read_rdy <= 1;
				dsp_fsm <= `DSP_WAIT_READ;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_DSP_VERSION + 1)
			begin
				dsp_read <= 8'h00;
				dsp_read_rdy <= 1;
				dsp_fsm <= `DSP_WAIT_READ;
				dsp_fsm_shadow <= `DSP_IDLE;
			end
			else if (dsp_fsm == `DSP_TC)
			begin
				dsp_fsm <= `DSP_WAIT_WRITE;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_TC + 1)
			begin
				dsp_tc <= dsp_write;
				dsp_write_rdy <= 0;
				dsp_fsm <= `DSP_IDLE;
			end
			else if (dsp_fsm == `DSP_PLAYBACK)
			begin
				dsp_fsm <= `DSP_WAIT_WRITE;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_PLAYBACK + 1)
			begin
				dsp_length[7:0] <= dsp_write;
				dsp_write_rdy <= 0;
				dsp_fsm <= `DSP_WAIT_WRITE;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_PLAYBACK + 2)
			begin
				dsp_length[15:8] <= dsp_write;
				dsp_dma <= 1;
				dsp_silence <= 0;
				dsp_pause <= 0;
				dsp_adpcm <= 2'h0;
				dsp_write_rdy <= 0;
				dsp_fsm <= `DSP_IDLE;
			end
			else if (dsp_fsm == `DSP_PLAYBACK2)
			begin
				dsp_fsm <= `DSP_WAIT_WRITE;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_PLAYBACK2 + 1)
			begin
				dsp_length2[7:0] <= dsp_write;
				dsp_write_rdy <= 0;
				dsp_fsm <= `DSP_WAIT_WRITE;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_PLAYBACK2 + 2)
			begin
				dsp_length2[15:8] <= dsp_write;
				dsp_dma2 <= 1;
				dsp_write_rdy <= 0;
				dsp_fsm <= `DSP_IDLE;
			end
			else if (dsp_fsm == `DSP_BLOCKSIZE)
			begin
				dsp_fsm <= `DSP_WAIT_WRITE;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_BLOCKSIZE + 1)
			begin
				dsp_blocksize[7:0] <= dsp_write;
				dsp_write_rdy <= 0;
				dsp_fsm <= `DSP_WAIT_WRITE;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_BLOCKSIZE + 2)
			begin
				dsp_blocksize[15:8] <= dsp_write;
				dsp_write_rdy <= 0;
				dsp_fsm <= `DSP_IDLE;
			end
			else if (dsp_fsm == `DSP_SPKSTATUS)
			begin
				dsp_read <= {8{dsp_spk}};
				dsp_read_rdy <= 1;
				dsp_fsm <= `DSP_WAIT_READ;
				dsp_fsm_shadow <= `DSP_IDLE;
			end
			else if (dsp_fsm == `DSP_PLAYBACK_ADPCM)
			begin
				dsp_fsm <= `DSP_WAIT_WRITE;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_PLAYBACK_ADPCM + 1)
			begin
				dsp_length[7:0] <= dsp_write;
				dsp_write_rdy <= 0;
				dsp_fsm <= `DSP_WAIT_WRITE;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_PLAYBACK_ADPCM + 2)
			begin
				dsp_length[15:8] <= dsp_write;
				dsp_dma <= 1;
				dsp_silence <= 0;
				if (dsp_cmd[7:1] == 7'h3a) // 74
					dsp_adpcm <= `ADPCM_4b;
				else if (dsp_cmd[7:1] == 7'h3b) // 76
					dsp_adpcm <= `ADPCM_3b;
				else if (dsp_cmd[7:1] == 7'h0b) // 16
					dsp_adpcm <= `ADPCM_2b;
				else
					dsp_adpcm <= 2'h0;
				
				dsp_pause <= 0;
				dsp_adpcm_refbyte <= dsp_adpcm[0];
				dsp_write_rdy <= 0;
				dsp_fsm <= `DSP_IDLE;
			end
			else if (dsp_fsm == `DSP_PLAYBACK_SILENCE)
			begin
				dsp_fsm <= `DSP_WAIT_WRITE;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_PLAYBACK_SILENCE + 1)
			begin
				dsp_length3[7:0] <= dsp_write;
				dsp_write_rdy <= 0;
				dsp_fsm <= `DSP_WAIT_WRITE;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_PLAYBACK_SILENCE + 2)
			begin
				dsp_length3[15:8] <= dsp_write;
				dsp_pause <= 0;
				dsp_silence <= 1;
				dsp_write_rdy <= 0;
				dsp_fsm <= `DSP_IDLE;
			end
			else if (dsp_fsm == `DSP_CHECK)
			begin
				dsp_fsm <= `DSP_WAIT_WRITE;
				dsp_fsm_shadow <= dsp_fsm + 1;
			end
			else if (dsp_fsm == `DSP_CHECK+1)
			begin
				dsp_read <= ~dsp_write;
				dsp_read_rdy <= 1;
				dsp_fsm <= `DSP_WAIT_READ;
				dsp_fsm_shadow <= `DSP_IDLE;
			end
			else
				dsp_fsm <= `DSP_IDLE;
			
			dsp_busy <= dsp_fsm != `DSP_IDLE & dsp_fsm != `DSP_WAIT_WRITE;
			
			// dsp timer
			dsp_prescaler <= dsp_prescaler + 1966;
			dsp_pof_o <= dsp_pof;
			if (dsp_pof_o != dsp_pof)
			begin
				dsp_counter = dsp_counter + 1;
				if (dsp_counter == 0 & ~dsp_pause)
				begin
					dsp_counter = dsp_tc;
					if (dsp_silence)
					begin
						dsp_length3 <= dsp_length3 - 1;
						if (dsp_length3 == 0)
						begin
							dsp_irq_req <= 1;
							dsp_irq_val <= 1;
							dsp_silence <= 0;
						end
					end
					else if (dsp_dma)
					begin
						if (dsp_adpcm != 2'h0)
						begin
							if (dsp_adpcm_refbyte)
							begin
								// request first byte as-is
								dsp_dma_req <= 1;
								dsp_length <= dsp_length - 1;
							end
							else
							begin
								dsp_adpcm_ref <= dsp_adpcm_clip;
								dsp_adpcm_rdy <= 1;
								if (dsp_adpcm_adju)
								begin
									if (dsp_adpcm_shift != dsp_adpcm_shiftmax)
										dsp_adpcm_shift <= dsp_adpcm_shift + 3'h1;
								end
								else if (dsp_adpcm_adjd)
								begin
									if (dsp_adpcm_shift != 3'h0)
										dsp_adpcm_shift <= dsp_adpcm_shift - 3'h1;
								end
								if (dsp_adpcm_of)
								begin
									dsp_adpcm_cnt <= 2'h0;
									dsp_dma_req <= 1;
									dsp_length <= dsp_length - 1;
								end
								else
									dsp_adpcm_cnt <= dsp_adpcm_cnt + 2'h1;
							end
						end
						else
						begin
							dsp_dma_req <= 1;
							dsp_length <= dsp_length - 1;
						end
						if (dsp_length == 0 && (dsp_adpcm == 2'h0 || dsp_adpcm_of))
						begin
							if (dsp_autoinit)
							begin
								dsp_length <= dsp_blocksize;
							end
							else if (dsp_dma2)
							begin
								dsp_length <= dsp_length2;
								dsp_dma2 <= 0;
								dsp_dma <= 1;
								dsp_adpcm <= 2'h0;
							end
							else
								dsp_dma <= 0;
							dsp_irq_req <= 1;
							dsp_irq_val <= 1;
							dsp_silence <= 0;
						end
					end
				end
			end
			
			// dma ctrl
			if (dsp_dma_req == 1)
			begin
				LPC_DREQ <= 0;
				dsp_dma_req <= 2;
			end
			else if (dsp_dma_req == 2)
			begin
				LPC_DREQ <= sbdma[2];
				dsp_dma_req <= 3;
			end
			else if (dsp_dma_req == 3)
			begin
				LPC_DREQ <= sbdma[1];
				dsp_dma_req <= 4;
			end
			else if (dsp_dma_req == 4)
			begin
				LPC_DREQ <= sbdma[0];
				dsp_dma_req <= 5;
			end
			else if (dsp_dma_req == 5)
			begin
				LPC_DREQ <= 1;
				dsp_dma_req <= 6;
			end
			else if (dsp_dma_req == 6)
			begin
				LPC_DREQ <= 1;
				dsp_dma_req <= 0;
			end
			
			// dma cancel
			if (dsp_dma_req == 11)
			begin
				LPC_DREQ <= 0;
				dsp_dma_req <= 12;
			end
			else if (dsp_dma_req == 12)
			begin
				LPC_DREQ <= sbdma[2];
				dsp_dma_req <= 13;
			end
			else if (dsp_dma_req == 13)
			begin
				LPC_DREQ <= sbdma[1];
				dsp_dma_req <= 14;
			end
			else if (dsp_dma_req == 14)
			begin
				LPC_DREQ <= sbdma[0];
				dsp_dma_req <= 15;
			end
			else if (dsp_dma_req == 15)
			begin
				LPC_DREQ <= 0;
				dsp_dma_req <= 16;
			end
			else if (dsp_dma_req == 16)
			begin
				LPC_DREQ <= 1;
				dsp_dma_req <= 0;
			end
			
			if (irq_sleep & dsp_irq_req & irq_state == 0)
			begin
				sr_state <= 1;
				sr_value <= 0;
				sr_clear <= 1;
				irq_sleep <= 0;
				dsp_irq_req <= 0;
			end
			else if (sr_clear)
			begin
				sr_state <= 0;
				sr_clear <= 0;
			end
			
			if (irq_state == 0)
			begin
				if (~SERIRQ)
					irq_state <= 1;
			end
			else if (irq_state == 1)
			begin
				if (SERIRQ)
					irq_state <= 255;
			end
			else if (irq_state == 100)
			begin
				irq_state <= 101;
			end
			else if (irq_state == 101)
			begin
				irq_sleep <= SERIRQ;
				irq_state <= 102;
			end
			else if (irq_state == 102)
			begin
				irq_state <= 103;
			end
			else if (irq_state == 103)
			begin
				irq_state <= 0;
			end
			else if (irq_state == 255 - sbirq * 3)
			begin
				sr_state <= 1;
				sr_value <= dsp_irq_val;
				irq_state <= irq_state - 1;
			end
			else if (irq_state == 254 - sbirq * 3)
			begin
				sr_value <= 1;
				irq_state <= irq_state - 1;
			end
			else if (irq_state == 253 - sbirq * 3)
			begin
				sr_state <= 0;
				irq_state <= irq_state - 1;
			end
			else if (irq_state == 255 - 48)
			begin
				if (~SERIRQ)
					irq_state <= 100;
			end
			else
			begin
				irq_state <= irq_state - 1;
			end
			
			
			if (dsp_adpcm != 2'h0)
			begin
				if (io_dma_rdy & dsp_adpcm_refbyte)
				begin
					// reference byte
					dsp_adpcm_ref <= io_dma_data;
					dsp_left <= { {2{~io_dma_data[7]}}, io_dma_data[6:0], 7'h0 };
					dsp_right <= { {2{~io_dma_data[7]}}, io_dma_data[6:0], 7'h0 };
					dsp_adpcm_refbyte <= 1'h0;
					io_dma_rdy <= 0;
				end
				else
				begin
					if (dsp_adpcm_rdy)
					begin
						dsp_left <= { {2{~dsp_adpcm_ref[7]}}, dsp_adpcm_ref[6:0], 7'h0 };
						dsp_right <= { {2{~dsp_adpcm_ref[7]}}, dsp_adpcm_ref[6:0], 7'h0 };
						dsp_adpcm_rdy <= 1'h0;
					end
					if (io_dma_rdy)
					begin
						dsp_adpcm_byte <= io_dma_data;
						io_dma_rdy <= 0;
					end
				end
			end
			else if (io_dma_rdy)
			begin
				if (~mxr_stereo | dsp_stereosel == 1)
					dsp_left <= { {2{~io_dma_data[7]}}, io_dma_data[6:0], 7'h0 };
				if (~mxr_stereo | dsp_stereosel == 0)
					dsp_right <= { {2{~io_dma_data[7]}}, io_dma_data[6:0], 7'h0 };
			
				dsp_stereosel <= ~dsp_stereosel;
				io_dma_rdy <= 0;
			end
			
			if (dsp_silence)
			begin
				dsp_left <= 16'h0;
				dsp_right <= 16'h0;
			end
			
			dac_left = { ym_left[15], ym_left } + (dsp_spk ? { dsp_left[15], dsp_left } : 17'h0);
			dac_right = { ym_right[15], ym_right } + (dsp_spk ? { dsp_right[15], dsp_right } : 17'h0);
			
			if (dac_left[16:15] == 2'b01)
				dac_left = 17'h07fff;
			if (dac_left[16:15] == 2'b10)
				dac_left = 17'h18000;
				
			if (dac_right[16:15] == 2'b01)
				dac_right = 17'h07fff;
			if (dac_right[16:15] == 2'b10)
				dac_right = 17'h18000;
			
		end
	end
	
endmodule
