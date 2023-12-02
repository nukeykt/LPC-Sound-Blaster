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
 *  YMF262 emulator
 *  Thanks:
 *      John McMaster (siliconpr0n.org):
 *          YMF262 decap and die shot
 *
 */
module ymf262
	(
	input MCLK,
	input CLK,
	input IC,
	input [1:0] ADDRESS,
	input [7:0] DATA_i,
	output [7:0] DATA_o,
	output DATA_d,
	input WR,
	input RD,
	input CS,
	output TEST,
	output SY,
	output DOCD,
	output DOAB,
	output SMPAC,
	output SMPBD,
	output IRQ_pull
	);
	
	wire mclk1 = ~CLK;
	wire mclk2 = CLK;
	
	wire io_rd = ~RD;
	wire io_wr = ~WR;
	wire io_cs = ~CS;
	wire io_a0 = ADDRESS[0];
	wire io_a1 = ADDRESS[1];
	
	wire reset0;
	ym_sr_bit #(.SR_LENGTH(2)) l_ic_latch(.MCLK(MCLK), .c1(mclk1), .c2(mclk2), .inp(~IC), .val(reset0));
	
	wire io_read = ~reset0 & io_cs & io_rd & ~io_a0 & ~io_a1;
	wire io_write = ~reset0 & io_cs & io_wr;
	wire io_write0 = ~reset0 & io_cs & io_wr & ~io_a0;
	wire io_write1 = ~reset0 & io_cs & io_wr & io_a0;
	
	wire [7:0] data_latch;
	ym_slatch_r #(.DATA_WIDTH(8)) l_data_latch(.MCLK(MCLK), .en(io_write), .rst(reset0), .inp(DATA_i), .val(data_latch));
	wire bank_latch;
	ym_slatch_r l_bank_latch(.MCLK(MCLK), .en(io_write), .rst(reset0), .inp(io_a1), .val(bank_latch));
	
	wire [7:0]reg_test1;
	wire reset1 = reset0 | reg_test1[7:6] == 2'h3;
	
	wire prescaler1_reset;
	ym_sr_bit #(.SR_LENGTH(2)) l_prescaler1_reset(.MCLK(MCLK), .c1(mclk1), .c2(mclk2), .inp(reset1), .val(prescaler1_reset));
	
	wire [1:0] prescaler1_cnt;
	ym_cnt_bit #(.DATA_WIDTH(2)) l_prescaler1_cnt(.MCLK(MCLK), .c1(mclk1), .c2(mclk2), .c_in(1'h1), .rst(~prescaler1_reset & reset1), .val(prescaler1_cnt));
	
	wire prescaler1_clk = reg_test1[6] ? CLK : ~prescaler1_cnt[1];
	
	wire aclk1 = ~prescaler1_clk;
	wire aclk2 = prescaler1_clk;
	
	wire prescaler2_reset_l;
	ym_sr_bit #(.SR_LENGTH(2)) l_prescaler2_reset(.MCLK(MCLK), .c1(aclk1), .c2(aclk2), .inp(reset1), .val(prescaler2_reset_l));
	
	wire prescaler2_reset = ~prescaler2_reset_l & reset1;
	
	wire [1:0] prescaler2_cnt;
	ym_cnt_bit #(.DATA_WIDTH(2)) l_prescaler2_cnt(.MCLK(MCLK), .c1(aclk1), .c2(aclk2), .c_in(1'h1), .rst(prescaler2_reset), .val(prescaler2_cnt));
	
	wire prescaler2_l1;
	ym_sr_bit l_prescaler2_l1(.MCLK(MCLK), .c1(aclk1), .c2(aclk2), .inp(~prescaler2_reset & ~prescaler2_cnt[0]), .val(prescaler2_l1));
	
	wire clk1;
	ym_edge_detect l_clk1(.MCLK(MCLK), .c1(aclk1), .inp(prescaler2_l1), .val(clk1));
	
	wire prescaler2_l3;
	ym_sr_bit l_prescaler2_l3(.MCLK(MCLK), .c1(aclk1), .c2(aclk2), .inp(~prescaler2_reset & prescaler2_cnt[0]), .val(prescaler2_l3));
	
	wire clk2;
	ym_edge_detect l_clk2(.MCLK(MCLK), .c1(aclk1), .inp(prescaler2_l3), .val(clk2));
	
	wire rclk2;
	ym_sr_bit l_prescaler2_l5(.MCLK(MCLK), .c1(aclk1), .c2(aclk2), .inp(~prescaler2_reset & prescaler2_cnt == 2'h3), .val(rclk2));
	
	wire rclk1;
	ym_sr_bit l_prescaler2_l6(.MCLK(MCLK), .c1(aclk1), .c2(aclk2), .inp(~prescaler2_reset & prescaler2_cnt == 2'h1), .val(rclk1));
	
	wire prescaler2_l7;
	ym_dlatch l_prescaler2_l7(.MCLK(MCLK), .en(aclk1), .inp(~prescaler2_cnt[0]), .val(prescaler2_l7));
	
	wire bclk = ~prescaler2_reset & prescaler2_l7 & ~prescaler2_cnt[0];
	
	wire reg_sel1;
	ym_slatch_r l_reg_sel1(.MCLK(MCLK), .en(write0), .rst(reset0), .inp(data_latch == 8'h1), .val(reg_sel1));
	wire reg_sel2;
	ym_slatch_r l_reg_sel2(.MCLK(MCLK), .en(write0), .rst(reset0), .inp(data_latch == 8'h2), .val(reg_sel2));
	wire reg_sel3;
	ym_slatch_r l_reg_sel3(.MCLK(MCLK), .en(write0), .rst(reset0), .inp(data_latch == 8'h3), .val(reg_sel3));
	wire reg_sel4;
	ym_slatch_r l_reg_sel4(.MCLK(MCLK), .en(write0), .rst(reset0), .inp(data_latch == 8'h4), .val(reg_sel4));
	wire reg_sel5;
	ym_slatch_r l_reg_sel5(.MCLK(MCLK), .en(write0), .rst(reset0), .inp(data_latch == 8'h5), .val(reg_sel5));
	wire reg_sel8;
	ym_slatch_r l_reg_sel8(.MCLK(MCLK), .en(write0), .rst(reset0), .inp(data_latch == 8'h8), .val(reg_sel8));
	wire reg_selbd;
	ym_slatch_r l_reg_selbd(.MCLK(MCLK), .en(write0), .rst(reset0), .inp(data_latch == 8'hbd), .val(reg_selbd));
	
	wire write0_l;
	wire write1_l;
	
	reg write0_sr;
	reg write1_sr;
	always @(posedge MCLK)
	begin
		if (io_write0)
			write0_sr <= 1'h1;
		else if (reset0 | write0_l)
			write0_sr <= 1'h0;
		if (io_write1)
			write1_sr <= 1'h1;
		else if (reset0 | write1_l)
			write1_sr <= 1'h0;
	end
	
	ym_sr_bit l_write0_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(write0_sr), .val(write0_l));
	ym_sr_bit l_write1_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(write1_sr), .val(write1_l));
	wire write0_l2;
	ym_sr_bit l_write0_l2(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(write0_l), .val(write0_l2));
	wire write1_l2;
	ym_sr_bit l_write1_l2(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(write1_l), .val(write1_l2));
	
	wire write0 = write0_l2 & ~write0_l;
	wire write1 = write1_l2 & ~write1_l;
	
	wire reg_new;
	ym_slatch_r l_reg_new(.MCLK(MCLK), .en(write1 & bank_latch & reg_sel5), .rst(reset0), .inp(data_latch[0]), .val(reg_new));
	
	wire bank_masked = reg_new & bank_latch;
	
	wire [7:0] reg_test0;
	ym_slatch_r #(.DATA_WIDTH(8)) l_reg_test0(.MCLK(MCLK), .en(write1 & ~bank_masked & reg_sel1), .rst(reset0), .inp(data_latch), .val(reg_test0));

	wire [7:0] reg_timer1;
	ym_slatch_r #(.DATA_WIDTH(8)) l_reg_timer1(.MCLK(MCLK), .en(write1 & ~bank_masked & reg_sel2), .rst(reset0), .inp(data_latch), .val(reg_timer1));

	wire [7:0] reg_timer2;
	ym_slatch_r #(.DATA_WIDTH(8)) l_reg_timer2(.MCLK(MCLK), .en(write1 & ~bank_masked & reg_sel3), .rst(reset0), .inp(data_latch), .val(reg_timer2));
	
	wire reg_notesel;
	ym_slatch_r l_reg_notesel(.MCLK(MCLK), .en(write1 & ~bank_masked & reg_sel8), .rst(reset0), .inp(data_latch[6]), .val(reg_notesel));
	
	wire [4:0] reg_rh_kon;
	ym_slatch_r #(.DATA_WIDTH(5)) l_reg_rh_kon(.MCLK(MCLK), .en(write1 & ~bank_masked & reg_selbd), .rst(reset0), .inp(data_latch[4:0]), .val(reg_rh_kon));
	wire rhythm;
	ym_slatch_r l_rhythm(.MCLK(MCLK), .en(write1 & ~bank_masked & reg_selbd), .rst(reset0), .inp(data_latch[5]), .val(rhythm));
	wire reg_dv;
	ym_slatch_r l_reg_dv(.MCLK(MCLK), .en(write1 & ~bank_masked & reg_selbd), .rst(reset0), .inp(data_latch[6]), .val(reg_dv));
	wire reg_da;
	ym_slatch_r l_reg_da(.MCLK(MCLK), .en(write1 & ~bank_masked & reg_selbd), .rst(reset0), .inp(data_latch[7]), .val(reg_da));
	
	ym_slatch_r #(.DATA_WIDTH(8)) l_reg_test1(.MCLK(MCLK), .en(write1 & bank_masked & reg_sel1), .rst(reset0), .inp(data_latch), .val(reg_test1));
	wire [5:0] reg_4op;
	ym_slatch_r #(.DATA_WIDTH(6)) l_reg_4op(.MCLK(MCLK), .en(write1 & bank_masked & reg_sel4), .rst(reset0), .inp(data_latch[5:0]), .val(reg_4op));
	
	wire reg_sel4_wr = write1 & reg_sel4 & ~bank_masked & ~data_latch[7];
	wire reg_sel4_rst = (write1 & reg_sel4 & ~bank_masked & data_latch[7]) | reset0;
	
	wire reg_t1_mask;
	ym_slatch_r l_reg_t1_mask(.MCLK(MCLK), .en(reg_sel4_wr), .rst(reset0), .inp(data_latch[6]), .val(reg_t1_mask));
	wire reg_t2_mask;
	ym_slatch_r l_reg_t2_mask(.MCLK(MCLK), .en(reg_sel4_wr), .rst(reset0), .inp(data_latch[5]), .val(reg_t2_mask));
	wire reg_t1_start;
	ym_slatch_r l_reg_t1_start(.MCLK(MCLK), .en(reg_sel4_wr), .rst(reset0), .inp(data_latch[0]), .val(reg_t1_start));
	wire reg_t2_start;
	ym_slatch_r l_reg_t2_start(.MCLK(MCLK), .en(reg_sel4_wr), .rst(reset0), .inp(data_latch[1]), .val(reg_t2_start));
	
	wire fsm_out[17];

	wire ga = data_latch[7:5] != 3'h0;
	
	wire [8:0] ra_address_latch;
	ym_slatch_r #(.DATA_WIDTH(9)) l_ra_address_latch(.MCLK(MCLK), .en(write0 & ga), .rst(reset1), .inp({bank_masked, data_latch}), .val(ra_address_latch));
	
	wire ra_address_good;
	ym_slatch_r l_ra_address_good(.MCLK(MCLK), .en(write0), .rst(reset1), .inp(ga), .val(ra_address_good));
	
	wire [7:0] ra_data_latch;
	ym_slatch_r #(.DATA_WIDTH(8)) l_ra_data_latch(.MCLK(MCLK), .en(write1 & ra_address_good), .rst(reset1), .inp(data_latch), .val(ra_data_latch));
	
	wire ra_write0 = ga & write0 & reg_test1[4];
	wire ra_write_comb = write1 | ra_write0;
	
	wire ra_write_comb_ed1;
	ym_edge_detect l_ra_write_comb_ed1(.MCLK(MCLK), .c1(aclk1), .inp(ra_write_comb), .val(ra_write_comb_ed1));

	
	wire ra_write = ra_write_comb_ed1 | (reset1 & clk2);
	
	wire ra_write_comb_ed2;
	ym_edge_detect l_ra_write_comb_ed2(.MCLK(MCLK), .c1(clk1), .inp(ra_write_comb), .val(ra_write_comb_ed2));
	
	wire ra_write_a = ra_write_comb_ed2;
	
	wire ra_rst_l;
	ym_sr_bit l_ra_rst_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(reset1), .val(ra_rst_l));
	
	wire [2:0] ra_cnt1;
	wire [1:0] ra_cnt2;
	wire ra_cnt3;
	wire [1:0] ra_cnt4;
	
	wire ra_cnt_rst = (reset1 & ~ra_rst_l) | fsm_out[5];
	
	wire ra_cnt_of1 = ra_cnt1[2] & ra_cnt1[0];
	wire ra_cnt_of2 = ra_cnt2[1] & ra_cnt_of1;
	wire ra_cnt_of4 = ra_cnt4[1];
	
	ym_cnt_bit #(.DATA_WIDTH(3)) l_ra_cnt1(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(1'h1), .rst(ra_cnt_rst | ra_cnt_of1), .val(ra_cnt1));
	ym_cnt_bit #(.DATA_WIDTH(2)) l_ra_cnt2(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(ra_cnt_of1), .rst(ra_cnt_rst | ra_cnt_of2), .val(ra_cnt2));
	ym_cnt_bit l_ra_cnt3(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(ra_cnt_of2), .rst(ra_cnt_rst), .val(ra_cnt3));
	ym_cnt_bit #(.DATA_WIDTH(2)) l_ra_cnt4(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(1'h1), .rst(ra_cnt_rst | ra_cnt_of4 | ra_cnt_of1), .val(ra_cnt4));
	
	wire [5:0] ra_cnt = { ra_cnt3, ra_cnt2, ra_cnt1 };
	
	function [4:0] ch_map;
		input [4:0] index;
		begin
			case (index)
				5'h0: ch_map = 5'h0;
				5'h1: ch_map = 5'h1;
				5'h2: ch_map = 5'h2;
				
				5'h4: ch_map = 5'h3;
				5'h5: ch_map = 5'h4;
				5'h6: ch_map = 5'h5;
				
				5'h8: ch_map = 5'h6;
				5'h9: ch_map = 5'h7;
				5'ha: ch_map = 5'h8;
				
				5'h10: ch_map = 5'h9;
				5'h11: ch_map = 5'ha;
				5'h12: ch_map = 5'hb;
				
				5'h14: ch_map = 5'hc;
				5'h15: ch_map = 5'hd;
				5'h16: ch_map = 5'he;
				
				5'h18: ch_map = 5'hf;
				5'h19: ch_map = 5'h10;
				5'h1a: ch_map = 5'h11;
				
				default: ch_map = 5'h1f;
			endcase
		end
	endfunction
	
	function [5:0] op_map;
		input [5:0] index;
		begin
			case (index)
				6'h0: op_map = 6'h0;
				6'h1: op_map = 6'h1;
				6'h2: op_map = 6'h2;
				6'h3: op_map = 6'h3;
				6'h4: op_map = 6'h4;
				6'h5: op_map = 6'h5;
				
				6'h8: op_map = 6'h6;
				6'h9: op_map = 6'h7;
				6'ha: op_map = 6'h8;
				6'hb: op_map = 6'h9;
				6'hc: op_map = 6'ha;
				6'hd: op_map = 6'hb;
				
				6'h10: op_map = 6'hc;
				6'h11: op_map = 6'hd;
				6'h12: op_map = 6'he;
				6'h13: op_map = 6'hf;
				6'h14: op_map = 6'h10;
				6'h15: op_map = 6'h11;
				
				6'h20: op_map = 6'h12;
				6'h21: op_map = 6'h13;
				6'h22: op_map = 6'h14;
				6'h23: op_map = 6'h15;
				6'h24: op_map = 6'h16;
				6'h25: op_map = 6'h17;
				
				6'h28: op_map = 6'h18;
				6'h29: op_map = 6'h19;
				6'h2a: op_map = 6'h1a;
				6'h2b: op_map = 6'h1b;
				6'h2c: op_map = 6'h1c;
				6'h2d: op_map = 6'h1d;
				
				6'h30: op_map = 6'h1e;
				6'h31: op_map = 6'h1f;
				6'h32: op_map = 6'h20;
				6'h33: op_map = 6'h21;
				6'h34: op_map = 6'h22;
				6'h35: op_map = 6'h23;
				
				default: op_map = 6'h3f;
			endcase
		end
	endfunction
	
	wire [5:0] op_address = ra_write_a ? { ra_address_latch[8], ra_address_latch[4:0] } : ra_cnt;
	wire [5:0] op_idx = op_map(op_address);
	
	wire [3:0] ch_address_write = ra_address_latch[3:0];
	
	wire [1:0] ch_address_add;
	
	assign ch_address_add[0] = ch_address_write == 4'h3 | ch_address_write == 4'h4 | ch_address_write == 4'h5;
	assign ch_address_add[1] = ch_address_write == 4'h6 | ch_address_write == 4'h7 | ch_address_write == 4'h8;
	
	wire [1:0] ch_address_sum1 = { 1'h0, ch_address_write[0] } + { 1'h0, ch_address_add[0] };
	wire [2:0] ch_address_sum2 = ch_address_write[3:1] + { 2'h0, ch_address_sum1[1] | ch_address_add[1] };
	
	wire [4:0] ch_address_mapped = { ra_address_latch[8], ch_address_sum2, ch_address_sum1[0] };
	wire [4:0] ch_address_mapped2;
	
	assign ch_address_mapped2[1:0] = ch_address_mapped[1:0];
	assign ch_address_mapped2[2] = ch_address_mapped[3:2] == 2'h2;
	assign ch_address_mapped2[3] = ch_address_mapped[3:2] == 2'h0;
	assign ch_address_mapped2[4] = ch_address_mapped[4:2] == 3'h0 | ch_address_mapped[4:2] == 3'h5 | ch_address_mapped[4:2] == 3'h6;
	
	wire [4:0] ch_address_read = { ra_cnt3, ra_cnt2, ra_cnt4 };
	wire [4:0] ch_address = ra_write_a ? ch_address_mapped : ch_address_read;
	
	wire [4:0] ch_address_read_4op;
	
	assign ch_address_read_4op[1:0] = ch_address_read[1:0];
	assign ch_address_read_4op[4:3] = ch_address_read[4:3];
	
	assign ch_address_read_4op[2] = ch_address_read[2] & ~(~ra_cnt2[1] & (
		(reg_4op[0] & ra_cnt3 == 1'h0 & ra_cnt4 == 2'h0) |
		(reg_4op[1] & ra_cnt3 == 1'h0 & ra_cnt4 == 2'h1) |
		(reg_4op[2] & ra_cnt3 == 1'h0 & ra_cnt4 == 2'h2) |
		(reg_4op[3] & ra_cnt3 == 1'h1 & ra_cnt4 == 2'h0) |
		(reg_4op[4] & ra_cnt3 == 1'h1 & ra_cnt4 == 2'h1) |
		(reg_4op[5] & ra_cnt3 == 1'h1 & ra_cnt4 == 2'h2)));
	
	wire [4:0] ch_address_4op = ra_write_a ? ch_address_mapped : ch_address_read_4op;
	wire [4:0] ch_address_fb = ra_write_a ? ch_address_mapped2 : ch_address_read;
	
	wire [4:0] ch_idx1 = ch_map(ch_address);
	wire [4:0] ch_idx2 = ch_map(ch_address_4op);
	wire [4:0] ch_idx3 = ch_map(ch_address_fb);
	
	reg [3:0] ra_multi[36];
	reg ra_ksr[36];
	reg ra_egt[36];
	reg ra_vib[36];
	reg ra_am[36];
	reg [5:0] ra_tl[36];
	reg [1:0] ra_ksl[36];
	reg [3:0] ra_dr[36];
	reg [3:0] ra_ar[36];
	reg [3:0] ra_rr[36];
	reg [3:0] ra_sl[36];
	reg [2:0] ra_wf[36];
	
	reg [3:0] ra_multi_o;
	reg ra_ksr_o;
	reg ra_egt_o;
	reg ra_vib_o;
	reg ra_am_o;
	reg [5:0] ra_tl_o;
	reg [1:0] ra_ksl_o;
	reg [3:0] ra_dr_o;
	reg [3:0] ra_ar_o;
	reg [3:0] ra_rr_o;
	reg [3:0] ra_sl_o;
	reg [2:0] ra_wf_o;
	
	reg ra_connect[18];
	reg [3:0] ra_pan[18];
	reg [9:0] ra_fnum[18];
	reg [2:0] ra_block[18];
	reg ra_keyon[18];
	reg ra_connect_pair[18];
	reg [2:0] ra_fb[18];
	
	reg ra_connect_o;
	reg [3:0] ra_pan_o;
	reg [9:0] ra_fnum_o;
	reg [2:0] ra_block_o;
	reg ra_keyon_o;
	reg ra_connect_pair_o;
	reg [2:0] ra_fb_o;
	
	always @(posedge MCLK)
	begin
		if (op_idx < 6'd36)
		begin
			if (ra_write)
			begin
				if (ra_address_latch[7:5] == 3'h1 | ra_write0 | reset1)
				begin
					ra_multi[op_idx] <= ra_data_latch[3:0];
					ra_ksr[op_idx] <= ra_data_latch[4];
					ra_egt[op_idx] <= ra_data_latch[5];
					ra_vib[op_idx] <= ra_data_latch[6];
					ra_am[op_idx] <= ra_data_latch[7];
				end
				if (ra_address_latch[7:5] == 3'h2 | ra_write0 | reset1)
				begin
					ra_tl[op_idx] <= ra_data_latch[5:0];
					ra_ksl[op_idx] <= ra_data_latch[7:6];
				end
				if (ra_address_latch[7:5] == 3'h3 | ra_write0 | reset1)
				begin
					ra_dr[op_idx] <= ra_data_latch[3:0];
					ra_ar[op_idx] <= ra_data_latch[7:4];
				end
				if (ra_address_latch[7:5] == 3'h4 | ra_write0 | reset1)
				begin
					ra_rr[op_idx] <= ra_data_latch[3:0];
					ra_sl[op_idx] <= ra_data_latch[7:4];
				end
				if (ra_address_latch[7:5] == 3'h7 | ra_write0 | reset1)
				begin
					ra_wf[op_idx][1:0] <= ra_data_latch[1:0];
					ra_wf[op_idx][2] <= ra_data_latch[2] & reg_new;
				end
			end
			if (clk1)
			begin
				ra_multi_o <= ra_multi[op_idx];
				ra_ksr_o <= ra_ksr[op_idx];
				ra_egt_o <= ra_egt[op_idx];
				ra_vib_o <= ra_vib[op_idx];
				ra_am_o <= ra_am[op_idx];
				ra_tl_o <= ra_tl[op_idx];
				ra_ksl_o <= ra_ksl[op_idx];
				ra_dr_o <= ra_dr[op_idx];
				ra_ar_o <= ra_ar[op_idx];
				ra_rr_o <= ra_rr[op_idx];
				ra_sl_o <= ra_sl[op_idx];
				ra_wf_o <= ra_wf[op_idx];
			end
		end
		if (ch_idx1 < 5'd18)
		begin
			if (ra_write)
			begin
				if (ra_address_latch[7:4] == 4'hc | ra_write0 | reset1)
				begin
					ra_connect[ch_idx1] <= ra_data_latch[0];
					ra_pan[ch_idx1] <= ((~reg_new | reset1) ? 4'h3 : 4'h0) | (reg_new ? ra_data_latch[7:4] : 4'h0);
				end
			end
			if (clk1)
			begin
				ra_connect_o <= ra_connect[ch_idx1];
				ra_pan_o <= ra_pan[ch_idx1];
			end
		end
		if (ch_idx2 < 5'd18)
		begin
			if (ra_write)
			begin
				if (ra_address_latch[7:4] == 4'ha | ra_write0 | reset1)
				begin
					ra_fnum[ch_idx2][7:0] <= ra_data_latch;
				end
				if (ra_address_latch[7:4] == 4'hb | ra_write0 | reset1)
				begin
					ra_fnum[ch_idx2][9:8] <= ra_data_latch[1:0];
					ra_block[ch_idx2] <= ra_data_latch[4:2];
					ra_keyon[ch_idx2] <= ra_data_latch[5];
				end
			end
			if (clk1)
			begin
				ra_fnum_o <= ra_fnum[ch_idx2];
				ra_block_o <= ra_block[ch_idx2];
				ra_keyon_o <= ra_keyon[ch_idx2];
			end
		end
		if (ch_idx3 < 5'd18)
		begin
			if (ra_write)
			begin
				if (ra_address_latch[7:4] == 4'hc | ra_write0 | reset1)
				begin
					ra_connect_pair[ch_idx3] <= ra_data_latch[0];
					ra_fb[ch_idx3] <= ra_data_latch[3:1];
				end
			end
			if (clk1)
			begin
				ra_connect_pair_o <= ra_connect_pair[ch_idx3];
				ra_fb_o <= ra_fb[ch_idx3];
			end
		end
	end
	
	wire [3:0] multi;
	wire ksr;
	wire egt;
	wire vib;
	wire am;
	wire [5:0] tl;
	wire [1:0] ksl;
	wire [3:0] dr;
	wire [3:0] ar;
	wire [3:0] rr;
	wire [3:0] sl;
	wire [2:0] wf;
	wire connect;
	wire [3:0] pan;
	wire [9:0] fnum;
	wire [2:0] blk;
	wire keyon;
	wire connect_pair;
	wire [2:0] fb;
	
	ym_sr_bit_array #(.DATA_WIDTH(4)) l_multi(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_multi_o), .val(multi));
	ym_sr_bit l_ksr(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_ksr_o), .val(ksr));
	ym_sr_bit l_egt(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_egt_o), .val(egt));
	ym_sr_bit l_vib(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_vib_o), .val(vib));
	ym_sr_bit l_am(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_am_o), .val(am));
	ym_sr_bit_array #(.DATA_WIDTH(6)) l_tl(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_tl_o), .val(tl));
	ym_sr_bit_array #(.DATA_WIDTH(2)) l_ksl(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_ksl_o), .val(ksl));
	ym_sr_bit_array #(.DATA_WIDTH(4)) l_dr(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_dr_o), .val(dr));
	ym_sr_bit_array #(.DATA_WIDTH(4)) l_ar(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_ar_o), .val(ar));
	ym_sr_bit_array #(.DATA_WIDTH(4)) l_rr(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_rr_o), .val(rr));
	ym_sr_bit_array #(.DATA_WIDTH(4)) l_sl(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_sl_o), .val(sl));
	ym_sr_bit_array #(.DATA_WIDTH(3)) l_wf(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_wf_o), .val(wf));
	ym_sr_bit l_connect(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_connect_o), .val(connect));
	ym_sr_bit_array #(.DATA_WIDTH(4)) l_pan(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_pan_o), .val(pan));
	ym_sr_bit_array #(.DATA_WIDTH(10)) l_fnum(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_fnum_o), .val(fnum));
	ym_sr_bit_array #(.DATA_WIDTH(3)) l_block(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_block_o), .val(blk));
	ym_sr_bit l_keyon(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_keyon_o), .val(keyon));
	ym_sr_bit l_connect_pair(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_connect_pair_o), .val(connect_pair));
	ym_sr_bit_array #(.DATA_WIDTH(3)) l_fb(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(ra_fb_o), .val(fb));
	
	
	wire connect_l;
	wire connect_pair_l;
	wire [2:0] fb_l;
	wire [3:0] pan_l;
	ym_sr_bit #(.SR_LENGTH(2)) l_connect_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(connect), .val(connect_l));
	ym_sr_bit #(.SR_LENGTH(2)) l_connect_pair_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(connect_pair), .val(connect_pair_l));
	ym_sr_bit_array #(.DATA_WIDTH(3), .SR_LENGTH(2)) l_fb_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(fb), .val(fb_l));
	ym_sr_bit_array #(.DATA_WIDTH(4), .SR_LENGTH(2)) l_pan_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(pan), .val(pan_l));
	
	
	
	wire [2:0] fsm_cnt1;
	wire [1:0] fsm_cnt2;
	wire fsm_cnt3;
	
	wire fsm_reset_l;
	ym_sr_bit #(.SR_LENGTH(2)) l_fsm_reset_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(reset1), .val(fsm_reset_l));
	
	wire fsm_reset = ~fsm_reset_l & reset1;
	
	wire fsm_of1 = fsm_cnt1[2] & fsm_cnt1[0];
	wire fsm_of2 = fsm_cnt2[1] & fsm_of1;
	
	ym_cnt_bit #(.DATA_WIDTH(3)) l_fsm_cnt1(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(1'h1), .rst(fsm_reset | fsm_of1), .val(fsm_cnt1));
	ym_cnt_bit #(.DATA_WIDTH(2)) l_fsm_cnt2(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(fsm_of1), .rst(fsm_reset | fsm_of2), .val(fsm_cnt2));
	ym_cnt_bit l_fsm_cnt3(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(fsm_of2), .rst(fsm_reset), .val(fsm_cnt3));
	
	wire [5:0] fsm_cnt = { fsm_cnt3, fsm_cnt2, fsm_cnt1 };
	
	wire fsm_4op =
		(fsm_cnt == 6'd5 & reg_4op[0]) |
		(fsm_cnt == 6'd8 & reg_4op[1]) |
		(fsm_cnt == 6'd9 & reg_4op[2]) |
		(fsm_cnt == 6'd37 & reg_4op[3]) |
		(fsm_cnt == 6'd40 & reg_4op[4]) |
		(fsm_cnt == 6'd41 & reg_4op[5]);
	
	wire fsm_l1;
	wire fsm_l2;
	wire fsm_l3;
	wire fsm_l4;
	wire fsm_l5;
	wire fsm_l6;
	wire fsm_l7;
	wire fsm_l8;
	wire fsm_l9;
	wire fsm_l10;
	
	wire con_4op = fsm_4op & fsm_l10;
	
	ym_sr_bit l_fsm_l1(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(fsm_cnt == 6'd53), .val(fsm_l1));
	ym_sr_bit l_fsm_l2(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(fsm_cnt == 6'd16), .val(fsm_l2));
	ym_sr_bit l_fsm_l3(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(fsm_cnt == 6'd20), .val(fsm_l3));
	ym_sr_bit l_fsm_l4(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(fsm_cnt == 6'd52), .val(fsm_l4));
	ym_sr_bit #(.SR_LENGTH(3)) l_fsm_l5(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp((fsm_cnt & 6'd56) == 6'd0), .val(fsm_l5));
	ym_sr_bit #(.SR_LENGTH(2)) l_fsm_l6(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp((fsm_cnt & 6'd56) == 6'd8 | (fsm_cnt & 6'd62) == 6'd16), .val(fsm_l6));
	ym_sr_bit #(.SR_LENGTH(2)) l_fsm_l7(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp((fsm_cnt & 6'd56) == 6'd40 | (fsm_cnt & 6'd62) == 6'd48), .val(fsm_l7));
	ym_sr_bit #(.SR_LENGTH(2)) l_fsm_l8(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp((fsm_cnt & 6'd48) == 6'd16), .val(fsm_l8));
	ym_sr_bit #(.SR_LENGTH(3)) l_fsm_l9(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(con_4op), .val(fsm_l9));
	ym_sr_bit #(.SR_LENGTH(3)) l_fsm_l10(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(~connect_l & connect_pair_l), .val(fsm_l10));
	
	assign fsm_out[0] = fsm_l1;
	assign fsm_out[1] = fsm_cnt == 6'd16;
	assign fsm_out[2] = fsm_l2;
	assign fsm_out[3] = fsm_cnt == 6'd20;
	assign fsm_out[4] = fsm_l3;
	assign fsm_out[5] = fsm_cnt == 6'd52;
	assign fsm_out[6] = fsm_l4;
	assign fsm_out[7] = fsm_l5 | ((fsm_cnt & 6'd56) == 6'd0);
	assign fsm_out[8] = (fsm_cnt & 6'd32) == 6'd0;
	assign fsm_out[9] = fsm_l6;
	assign fsm_out[10] = fsm_l7;
	assign fsm_out[11] = rhythm & fsm_l8;
	
	wire fsm_mc = ~((fsm_cnt & 6'd5) == 6'd4 | (fsm_cnt & 6'd2) != 6'd0);
	wire fsm_mc_4op = fsm_mc & ~fsm_4op;
	wire rhy_19_20 = rhythm & (fsm_cnt == 6'd19 | fsm_cnt == 6'd20);
	
	assign fsm_out[12] = fsm_mc_4op & ~(rhythm & (fsm_cnt == 6'd16 | fsm_cnt == 6'd17));
	assign fsm_out[14] = con_4op | (~fsm_4op & ~fsm_l9 & connect_l);
	assign fsm_out[13] = ~(rhythm & fsm_cnt == 6'd18) & (fsm_mc_4op | rhy_19_20 | fsm_out[14]);
	assign fsm_out[15] = ~fsm_mc & ~rhy_19_20;
	assign fsm_out[16] = ~fsm_mc_4op & ~rhy_19_20;
	
	wire [9:0] lfo_cnt;
	wire lfo_reset = reg_test0[1] | reset1;
	
	wire lfo_cnt_c1;
	wire lfo_cnt_c2;
	wire lfo_cnt_c3;
	wire lfo_cnt_c4;
	
	ym_cnt_bit #(.DATA_WIDTH(2)) l_lfo_cnt1(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(fsm_out[6]), .rst(lfo_reset), .val(lfo_cnt[1:0]), .c_out(lfo_cnt_c1));
	ym_cnt_bit #(.DATA_WIDTH(2)) l_lfo_cnt2(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(lfo_cnt_c1), .rst(lfo_reset), .val(lfo_cnt[3:2]), .c_out(lfo_cnt_c2));
	ym_cnt_bit #(.DATA_WIDTH(2)) l_lfo_cnt3(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(lfo_cnt_c2), .rst(lfo_reset), .val(lfo_cnt[5:4]), .c_out(lfo_cnt_c3));
	ym_cnt_bit #(.DATA_WIDTH(4)) l_lfo_cnt4(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(lfo_cnt_c3), .rst(lfo_reset), .val(lfo_cnt[9:6]), .c_out(lfo_cnt_c4));
	
	wire timer_st_load;
	ym_edge_detect l_timer_st_load(.MCLK(MCLK), .c1(clk1), .inp(fsm_out[6]), .val(timer_st_load));
	
	wire t1_start;
	ym_slatch l_t1_start(.MCLK(MCLK), .en(timer_st_load), .inp(reg_t1_start), .val(t1_start));
	wire t2_start;
	ym_slatch l_t2_start(.MCLK(MCLK), .en(timer_st_load), .inp(reg_t2_start), .val(t2_start));
	
	
	wire t1_step = lfo_cnt_c1;
	wire t2_step = lfo_cnt_c2;
	
	wire t1_start_l;
	wire t1_start_l2;
	wire t1_of;
	wire [7:0] t1_cnt;
	wire t1_cnt_c;
	ym_cnt_bit_load #(.DATA_WIDTH(8)) l_t1_cnt(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in((t1_start_l & t1_step) | reg_test1[3]), .rst(~t1_start_l),
		.load(t1_of | (~t1_start_l2 & t1_start_l)), .load_val(reg_timer1), .val(t1_cnt), .c_out(t1_cnt_c));
	ym_sr_bit l_t1_of(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(t1_cnt_c), .val(t1_of));
	ym_sr_bit l_t1_start_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(t1_start), .val(t1_start_l));
	ym_sr_bit l_t1_start_l2(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(t1_start_l), .val(t1_start_l2));
	
	wire t2_start_l;
	wire t2_start_l2;
	wire t2_of;
	wire [7:0] t2_cnt;
	wire t2_cnt_c;
	ym_cnt_bit_load #(.DATA_WIDTH(8)) l_t2_cnt(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in((t2_start_l & t2_step) | reg_test1[3]), .rst(~t2_start_l),
		.load(t2_of | (~t2_start_l2 & t2_start_l)), .load_val(reg_timer2), .val(t2_cnt), .c_out(t2_cnt_c));
	ym_sr_bit l_t2_of(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(t2_cnt_c), .val(t2_of));
	ym_sr_bit l_t2_start_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(t2_start), .val(t2_start_l));
	ym_sr_bit l_t2_start_l2(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(t2_start_l), .val(t2_start_l2));
	
	wire t1_status;
	ym_rs_trig l_t1_status(.MCLK(MCLK), .rst(reg_sel4_rst | reg_t1_mask), .set(t1_of), .q(t1_status));
	wire t2_status;
	ym_rs_trig l_t2_status(.MCLK(MCLK), .rst(reg_sel4_rst | reg_t2_mask), .set(t2_of), .q(t2_status));
	
	wire rh_sel0 = rhythm & fsm_out[1];
	wire rh_sel1;
	wire rh_sel2;
	wire rh_sel3;
	wire rh_sel4;
	wire rh_sel5;
	
	ym_sr_bit l_rh_sel1(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(rh_sel0), .val(rh_sel1));
	ym_sr_bit l_rh_sel2(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(rh_sel1), .val(rh_sel2));
	ym_sr_bit l_rh_sel3(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(rh_sel2), .val(rh_sel3));
	ym_sr_bit l_rh_sel4(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(rh_sel3), .val(rh_sel4));
	ym_sr_bit l_rh_sel5(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(rh_sel4), .val(rh_sel5));
	
	wire keyon_comb = keyon |
		(rh_sel0 & reg_rh_kon[4]) |
		(rh_sel1 & reg_rh_kon[0]) |
		(rh_sel2 & reg_rh_kon[2]) |
		(rh_sel3 & reg_rh_kon[4]) |
		(rh_sel4 & reg_rh_kon[3]) |
		(rh_sel5 & reg_rh_kon[1]);
	
	reg [11:0] eg_cells0[18];
	reg [11:0] eg_cells1[18];
	
	reg [4:0] eg_index[2];
	wire [4:0] eg_index1 = eg_index[1];
	wire [4:0] eg_index2 = eg_index1 == 5'd0 ? 5'd17 : (eg_index1 - 5'd1);
	
	wire [11:0] eg_cells_i;
	reg [1:0] eg_state_o[4];
	reg [8:0] eg_level_o[4];
	reg eg_timer_o[4];
	
	always @(posedge MCLK)
	begin
		if (clk1)
		begin
			if (fsm_out[4] | fsm_out[6])
				eg_index[0] <= 5'h0;
			else if (eg_index[1] == 5'h1f)
				eg_index[0] <= 5'h1f;
			else
				eg_index[0] <= eg_index[1] + 5'h1;
			
			if (eg_index[1] < 5'd18)
			begin
				eg_cells0[eg_index2] <= eg_cells_i;
				eg_cells1[eg_index2] <= eg_cells0[eg_index1];
				eg_state_o[0] <= eg_cells1[eg_index1][1:0];
				eg_level_o[0] <= eg_cells1[eg_index1][10:2];
				eg_timer_o[0] <= eg_cells1[eg_index1][11];
			end
			eg_state_o[2] <= eg_state_o[1];
			eg_level_o[2] <= eg_level_o[1];
			eg_timer_o[2] <= eg_timer_o[1];
		end
		if (clk2)
		begin
			eg_index[1] <= eg_index[0];
			eg_state_o[1] <= eg_state_o[0];
			eg_state_o[3] <= eg_state_o[2];
			eg_level_o[1] <= eg_level_o[0];
			eg_level_o[3] <= eg_level_o[2];
			eg_timer_o[1] <= eg_timer_o[0];
			eg_timer_o[3] <= eg_timer_o[2];
		end
	end
	
	wire trem_load;
	ym_edge_detect l_trem_load(.MCLK(MCLK), .c1(clk1), .inp(fsm_out[0]), .val(trem_load));
	wire trem_st_load;
	ym_edge_detect l_trem_st_load(.MCLK(MCLK), .c1(clk1), .inp(fsm_out[6]), .val(trem_st_load));
	
	wire am_step = lfo_cnt_c3;
	wire trem_step;
	ym_slatch l_trem_step(.MCLK(MCLK), .en(trem_st_load), .inp(am_step), .val(trem_step));
	
	wire [8:0] trem_value;
	wire trem_value_bit;
	ym_sr_bit_array #(.DATA_WIDTH(9)) l_trem_value(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp({ trem_value_bit, trem_value[8:1]}), .val(trem_value));
	
	wire [6:0] trem_out;
	ym_slatch #(.DATA_WIDTH(7)) l_trem_out(.MCLK(MCLK), .en(trem_load), .inp(trem_value[6:0]), .val(trem_out));
	
	wire trem_bit = trem_value[0];
	wire trem_reset = reset1 | reg_test0[1];
	
	wire trem_dir;
	wire trem_carry;
	
	wire trem_step_add = ((trem_step | reg_test0[4]) & (fsm_out[0] | trem_dir)) & fsm_out[7];
	wire trem_carry_add = fsm_out[7] & trem_carry;
	
	wire [1:0] trem_sum = { 1'h0, trem_bit } + { 1'h0, trem_step_add } + { 1'h0, trem_carry_add };
	
	assign trem_value_bit = ~trem_reset & trem_sum[0];
	
	ym_sr_bit l_trem_carry(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(trem_sum[1]), .val(trem_carry));
	
	wire trem_of = trem_out == 7'd0 | (trem_out & 7'd105) == 7'd105;
	wire trem_of_l;
	ym_sr_bit l_trem_of_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(trem_of), .val(trem_of_l));
	
	ym_sr_bit l_trem_dir(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(trem_reset ? 1'h0 : (trem_dir ^ (trem_of & ~trem_of_l))), .val(trem_dir));
	
	wire eg_carry;
	wire eg_subcnt;
	wire eg_sync_l;
	
	wire eg_timer_bit = eg_timer_o[3];
	wire eg_timer_carry = eg_carry | (eg_subcnt & eg_sync_l);
	wire [1:0] eg_timer_sum = { 1'h0, eg_timer_bit } + { 1'h0, eg_timer_carry };
	wire eg_timer_rst = reset1 | reg_test1[3];
	
	wire eg_timer_bit2 = eg_timer_sum[0] & ~eg_timer_rst;
	
	assign eg_cells_i[11] = eg_timer_bit2;
	
	ym_sr_bit l_eg_carry(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(eg_timer_sum[1]), .val(eg_carry));
	ym_sr_bit l_eg_sync_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(fsm_out[6]), .val(eg_sync_l));
	
	wire eg_mask;
	ym_sr_bit l_eg_mask(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp((eg_mask | eg_timer_bit2) & ~(eg_timer_rst | fsm_out[6])), .val(eg_mask));
	
	wire eg_timer_dbg;
	wire [35:0] eg_timer_masked;
	ym_sr_bit_array #(.DATA_WIDTH(36)) l_eg_timer_masked(.MCLK(MCLK), .c1(clk1), .c2(clk2),
		.inp( { (~eg_mask & eg_timer_bit2) | (~eg_timer_dbg & reg_test0[6]), eg_timer_masked[35:1] } ), .val(eg_timer_masked));
	
	ym_sr_bit l_eg_timer_dbg(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(reg_test0[6]), .val(eg_timer_dbg));
	
	ym_cnt_bit l_eg_subcnt(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(fsm_out[6]), .rst(reset1), .val(eg_subcnt));
	
	wire eg_load_l1;
	ym_sr_bit l_eg_load_l1(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(eg_subcnt & fsm_out[6]), .val(eg_load_l1));
	
	wire eg_load;
	ym_edge_detect l_eg_load(.MCLK(MCLK), .c1(clk1), .inp(eg_load_l1), .val(eg_load));
	
	wire [1:0] eg_timer_low;
	ym_slatch_r #(.DATA_WIDTH(2)) l_eg_timer_low(.MCLK(MCLK), .en(eg_load), .inp({ eg_timer_o[1], eg_timer_o[3] }), .rst(reset1), .val(eg_timer_low));
	wire [3:0] eg_shift;
	wire [3:0] eg_shift_i;
	assign eg_shift_i[0] = (eg_timer_masked & 36'h1555) != 36'h0;
	assign eg_shift_i[1] = (eg_timer_masked & 36'h666) != 36'h0;
	assign eg_shift_i[2] = (eg_timer_masked & 36'h1878) != 36'h0;
	assign eg_shift_i[3] = (eg_timer_masked & 36'h1f80) != 36'h0;
	ym_slatch_r #(.DATA_WIDTH(4)) l_eg_shift(.MCLK(MCLK), .en(eg_load), .inp(eg_shift_i), .rst(reset1), .val(eg_shift));
	
	
	wire eg_rst = reset1 | reg_test1[5];
	
	wire [1:0] state = eg_state_o[3];
	wire dokon = state == 2'h3 & keyon_comb;
	wire [1:0] rate_sel = dokon ? 2'h0 : state;
	
	wire [3:0] rate = (rate_sel == 2'h0 ? ar : 4'h0) |
					(rate_sel == 2'h1 ? dr : 4'h0) |
					((rate_sel == 2'h3 | (rate_sel == 2'h2 & ~egt)) ? rr : 4'h0);
	
	wire [4:0] sl2 = { sl == 4'hf, sl };

	wire ns = reg_notesel ? fnum[8] : fnum[9];
	
	wire [3:0] ksrv = ksr ? { blk, ns } : { 2'h0, blk[2:1] };
	
	wire [4:0] rate_sum = { 1'h0, rate } + { 3'h0, ksrv[3:2] };
	
	wire [3:0] rate_hi = rate_sum[4] ? 4'hf : rate_sum[3:0];
	
	wire rate12 = rate_hi == 4'hc;
	wire rate13 = rate_hi == 4'hd;
	wire rate14 = rate_hi == 4'he;
	wire rate15 = rate_hi == 4'hf;
	
	wire [3:0] shift_sum = rate_hi + eg_shift;
	
	wire rate_ls12 = rate_hi[3:2] != 2'h3;
	wire rate_nz = rate != 4'h0;
	
	wire inclow = rate_ls12 & rate_nz & eg_subcnt & shift_sum[3:2] == 2'h3 &
		(shift_sum[1:0] == 2'h0 | (shift_sum[1:0] == 2'h1 & ksrv[1]) | (shift_sum[1:0] == 2'h2 & ksrv[0]));
	
	wire stephi = (eg_timer_low == 2'h1 & ksrv[1:0] == 2'h3) |
			(eg_timer_low == 2'h0 & ksrv[0]) |
			(~eg_timer_low[0] & ksrv[1]);
	
	wire step1 = (rate12 & (stephi | eg_subcnt)) | (rate13 & ~stephi) | inclow;
	wire step2 = (rate13 & stephi) | (rate14 & ~stephi);
	wire step3 = (rate14 & stephi) | rate15;
	
	wire [8:0] level = eg_level_o[3];
	wire slreach = level[8:4] == sl2;
	wire zeroreach = level == 9'h0;
	wire silent = level[8:3] == 6'h3f;
	
	wire [1:0] nextstate;
	assign eg_cells_i[1:0] = nextstate;
	
	assign nextstate = (eg_rst ? 2'h3 : 2'h0) |
		((~dokon & ~keyon_comb) ? 2'h3 : 2'h0) |
		((~dokon & state == 2'h0 & zeroreach) ? 2'h1 : 2'h0) |
		((~dokon & state == 2'h1 & ~slreach) ? 2'h1 : 2'h0) |
		((~dokon & state == 2'h1 & slreach) ? 2'h2 : 2'h0) |
		((~dokon & state == 2'h2) ? 2'h2 : 2'h0) |
		((~dokon & state == 2'h3) ? 2'h3 : 2'h0);
	
	wire linear = ~dokon & ~silent & (state[1] | (state == 2'h1 & ~slreach));
	wire exponent = state == 2'h0 & keyon_comb & ~rate15 & ~zeroreach;
	wire instantattack = (dokon & rate15) | reg_test0[4];
	wire mute = eg_rst | (state != 2'h0 & silent & ~dokon & ~reg_test0[4]);
	
	wire [8:0] level2 = mute ? 9'h1ff : (instantattack ? 9'h0 : level);
	
	wire [7:0] eg_add = (exponent ? ~level[8:1] : 8'h0) |
		(linear ? 8'h4 : 8'h0);
	
	wire [8:0] eg_addshift = ((exponent & (step1 | step2 | step3)) ? 9'h100 : 9'h0) |
		(step1 ? { 1'h0, exponent, exponent, eg_add[7:3], eg_add[2] | linear } : 9'h0) |
		(step2 ? { 1'h0, exponent, eg_add[7:3], eg_add[2] | linear, eg_add[1] } : 9'h0) |
		(step3 ? { 1'h0, eg_add[7:3], eg_add[2] | linear, eg_add[1:0] } : 9'h0);
	
	wire [8:0] levelnext = level2 + eg_addshift;
	assign eg_cells_i[10:2] = levelnext;
	
	reg [6:0] ksltable;
	
	always @(*)
	begin
		case (fnum[9:6])
			4'h0: ksltable <= 7'd0;
			4'h1: ksltable <= 7'd32;
			4'h2: ksltable <= 7'd40;
			4'h3: ksltable <= 7'd45;
			4'h4: ksltable <= 7'd48;
			4'h5: ksltable <= 7'd51;
			4'h6: ksltable <= 7'd53;
			4'h7: ksltable <= 7'd55;
			4'h8: ksltable <= 7'd56;
			4'h9: ksltable <= 7'd58;
			4'ha: ksltable <= 7'd59;
			4'hb: ksltable <= 7'd60;
			4'hc: ksltable <= 7'd61;
			4'hd: ksltable <= 7'd62;
			4'he: ksltable <= 7'd63;
			4'hf: ksltable <= 7'd64;
		endcase
	end
	
	wire [6:0] ksl_sum = { 1'h0, ksltable[5:0] } + { 1'h0, blk, 3'h0 };
	wire [5:0] ksl_clamp = (ksltable[6] | ksl_sum[6]) ? ksl_sum[5:0] : 6'h0;
	
	wire [7:0] ksl_shift = ((ksl == 2'h1) ? { 1'h0, ksl_clamp, 1'h0 } : 8'h0) |
									((ksl == 2'h2) ? { 2'h0, ksl_clamp } : 8'h0) |
									((ksl == 2'h3) ? { ksl_clamp, 2'h0 } : 8'h0);
	
	wire [8:0] ksltl = {1'h0, ksl_shift } + {1'h0, tl, 2'h0};
	
	wire [4:0] tremolo = ((reg_da & am) ? trem_out[6:2] : 5'h0) |
								((~reg_da & am) ? { 2'h0, trem_out[6:4] } : 5'h0);
	
	wire [9:0] ksltltrem = { 1'h0, ksltl } + { 5'h0, tremolo };
	
	wire [9:0] totallevel = { 1'h0, ksltltrem[8:0] } + { 1'h0, level };
	
	wire [8:0] totallevelclamp = reg_test0[0] ? 9'h0 : ((ksltltrem[9] | totallevel[9]) ? 9'h1ff : totallevel[8:0]);
	
	wire [8:0] eg_out;
	ym_sr_bit_array #(.DATA_WIDTH(9)) l_eg_out(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(totallevelclamp), .val(eg_out));
	
	wire eg_dbg_load_l;
	ym_sr_bit l_eg_dbg_load_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(reg_test0[5]), .val(eg_dbg_load_l));
	wire eg_dbg;
	ym_dbg_read #(.DATA_WIDTH(9)) l_eg_ebg(.MCLK(MCLK), .c1(clk1), .c2(clk2), .prev(1'h0), .load(reg_test0[5] & ~eg_dbg_load_l), .load_val(eg_out),
		.next(eg_dbg));
	
	
	reg [18:0] pg_cells0[18];
	reg [18:0] pg_cells1[18];
	
	reg [4:0] pg_index[2];
	wire [4:0] pg_index1 = pg_index[1];
	wire [4:0] pg_index2 = pg_index1 == 5'd0 ? 5'd17 : (pg_index1 - 5'd1);
	
	wire [18:0] pg_cells_i;
	reg [18:0] pg_phase_o[4];
	
	always @(posedge MCLK)
	begin
		if (clk1)
		begin
			if (fsm_out[4] | fsm_out[6])
				pg_index[0] <= 5'h0;
			else if (pg_index[1] == 5'h1f)
				pg_index[0] <= 5'h1f;
			else
				pg_index[0] <= pg_index[1] + 5'h1;
			
			if (pg_index[1] < 5'd18)
			begin
				pg_cells0[pg_index2] <= pg_cells_i;
				pg_cells1[pg_index2] <= pg_cells0[pg_index1];
				pg_phase_o[0] <= pg_cells1[pg_index1];
			end
			pg_phase_o[2] <= pg_phase_o[1];
		end
		if (clk2)
		begin
			pg_index[1] <= pg_index[0];
			pg_phase_o[1] <= pg_phase_o[0];
			pg_phase_o[3] <= pg_phase_o[2];
		end
	end
	
	
	
	wire vib_step = lfo_cnt_c4 | (reg_test0[4] & fsm_out[6]);
	wire [2:0] vib_cnt;
	ym_cnt_bit #(.DATA_WIDTH(3)) l_vib_cnt(.MCLK(MCLK), .c1(clk1), .c2(clk2), .c_in(vib_step), .rst(lfo_reset), .val(vib_cnt));
	
	wire vib_sel1 = vib_cnt[1:0] == 2'h2;
	wire vib_sel2 = vib_cnt[0];
	wire vib_sh0 = reg_dv & vib & vib_sel1;
	wire vib_sh1 = (reg_dv & vib & vib_sel2) | (~reg_dv & vib & vib_sel1);
	wire vib_sh2 = ~reg_dv & vib & vib_sel2;
	wire vib_sign = vib_cnt[2] & vib;
	
	wire [2:0] vib_add = (vib_sh0 ? fnum[9:7] : 3'h0) | (vib_sh1 ? { 1'h0, fnum[9:8] } : 3'h0) | (vib_sh2 ? { 2'h0, fnum[9] } : 3'h0);
	
	wire [10:0] fnum_vib1;
	
	assign fnum_vib1 = { 1'h0, fnum } + { 1'h0, {7{vib_sign}}, vib_sign ? ~vib_add : vib_add } + { 9'h0, vib_sign };
	
	wire [10:0] fnum_vib;
	assign fnum_vib[9:0] = fnum_vib1[9:0];
	assign fnum_vib[10] = fnum_vib1[10] & ~vib_sign;
	
	wire [13:0] fnum_sh0 = (blk[1:0] == 2'h0 ? { 3'h0, fnum_vib } : 14'h0) |
							(blk[1:0] == 2'h1 ? { 2'h0, fnum_vib, 1'h0 } : 14'h0) |
							(blk[1:0] == 2'h2 ? { 1'h0, fnum_vib, 2'h0 } : 14'h0) |
							(blk[1:0] == 2'h3 ? { fnum_vib, 3'h0 } : 14'h0);
	
	wire [16:0] fnum_blk = blk[2] ? { fnum_sh0, 3'h0 } : { 4'h0, fnum_sh0[13:1] };
	
	wire multi_sel[13];
	assign multi_sel[0] = multi == 4'h0;
	assign multi_sel[1] = multi == 4'h1;
	assign multi_sel[2] = multi == 4'h2;
	assign multi_sel[3] = multi == 4'h3;
	assign multi_sel[4] = multi == 4'h4;
	assign multi_sel[5] = multi == 4'h5;
	assign multi_sel[6] = multi == 4'h6;
	assign multi_sel[7] = multi == 4'h7;
	assign multi_sel[8] = multi == 4'h8;
	assign multi_sel[9] = multi == 4'h9;
	assign multi_sel[10] = multi[3:1] == 3'h5;
	assign multi_sel[11] = multi[3:1] == 3'h6;
	assign multi_sel[12] = multi[3:1] == 3'h7;
	
	wire multi_ctrl[8];
	assign multi_ctrl[0] = multi_sel[11]; // 12, 13
	assign multi_ctrl[1] = multi_sel[1] | multi_sel[5] | multi_sel[9]; // 1, 5, 9
	assign multi_ctrl[2] = multi_sel[2] | multi_sel[6] | multi_sel[10]; // 2, 6, 10, 11
	assign multi_ctrl[3] = multi_sel[3] | multi_sel[7] | multi_sel[12]; // 3, 7, 14, 15
	assign multi_ctrl[4] = multi_sel[0]; // 0
	
	assign multi_ctrl[5] = multi_sel[12]; // 14, 15
	assign multi_ctrl[6] = multi_sel[7] | multi_sel[8] | multi_sel[9] | multi_sel[10] | multi_sel[11];
	assign multi_ctrl[7] = multi_sel[3] | multi_sel[4] | multi_sel[5] | multi_sel[6];
	
	wire [16:0] fnum_m1 = multi_ctrl[7] ? fnum_blk :
							(multi_ctrl[6] ? { fnum_blk[15:0], 1'h0 } :
								(multi_ctrl[5] ? { fnum_blk[14:0], 2'h0 } : 17'h0));
	
	wire [18:0] fnum_m2 = multi_ctrl[4] ? { 3'h0, fnum_blk[16:1] } :
							(multi_ctrl[3] ? { 2'h3, ~fnum_blk } :
								(multi_ctrl[2] ? { 1'h0, fnum_blk, 1'h0 } :
									(multi_ctrl[1] ? { 2'h0, fnum_blk } :
										(multi_ctrl[0] ? { fnum_blk, 2'h0 } : 19'h0))));
	
	
	wire [18:0] fnum_multi = { fnum_m1, 2'h0 } + fnum_m2 + { 18'h0, multi_ctrl[3] };
	
	
	wire [18:0] phase = ((dokon | reg_test0[2] | reset1) ? 19'h0 : pg_phase_o[3]) + fnum_multi;
	assign pg_cells_i = phase;
	
	wire [22:0] noise_lfsr;
	wire noise_bit = ~reset1 & ((noise_lfsr[22] ^ noise_lfsr[8]) | reg_test0[1] | noise_lfsr == 23'h0);
	ym_sr_bit_array #(.DATA_WIDTH(23)) l_noise_lfsr(.MCLK(MCLK), .c1(rclk1), .c2(rclk2), .inp({noise_lfsr[21:0], noise_bit}), .val(noise_lfsr));
	
	wire [9:0] pg_out = pg_phase_o[3][18:9];
	
	wire hh = fsm_out[2] & rhythm;
	wire sd = fsm_out[3] & rhythm;
	wire tc = fsm_out[4] & rhythm;
	wire rhy = (fsm_out[2] | fsm_out[3] | fsm_out[4]) & rhythm;
	
	wire hh_load;
	ym_edge_detect l_hh_load(.MCLK(MCLK), .c1(clk1), .inp(fsm_out[2]), .val(hh_load));
	wire hh_bit2, hh_bit3, hh_bit7, hh_bit8;
	ym_slatch l_hh_bit2(.MCLK(MCLK), .en(hh_load), .inp(pg_out[2]), .val(hh_bit2));
	ym_slatch l_hh_bit3(.MCLK(MCLK), .en(hh_load), .inp(pg_out[3]), .val(hh_bit3));
	ym_slatch l_hh_bit7(.MCLK(MCLK), .en(hh_load), .inp(pg_out[7]), .val(hh_bit7));
	ym_slatch l_hh_bit8(.MCLK(MCLK), .en(hh_load), .inp(pg_out[8]), .val(hh_bit8));
	wire tc_load;
	ym_edge_detect l_tc_load(.MCLK(MCLK), .c1(clk1), .inp(tc), .val(tc_load));
	wire tc_bit3, tc_bit5;
	ym_slatch l_tc_bit3(.MCLK(MCLK), .en(tc_load), .inp(pg_out[3]), .val(tc_bit3));
	ym_slatch l_tc_bit5(.MCLK(MCLK), .en(tc_load), .inp(pg_out[5]), .val(tc_bit5));
	
	wire noise = noise_lfsr[22];
	
	wire rm_bit = (hh_bit2 ^ hh_bit7) | (tc_bit5 ^ hh_bit3) | (tc_bit5 ^ tc_bit3);
	
	wire hh_xor = noise ^ rm_bit;
	
	wire [9:0] pg_out_rhy = (~rhy ? pg_out : 10'h0) |
		(hh ? { rm_bit, 1'h0, hh_xor, hh_xor, ~hh_xor, hh_xor | ~hh_xor, 1'h0, ~hh_xor, 1'h0, 1'h0 } : 10'h0) |
		(sd ? { hh_bit8, noise ^ hh_bit8, 8'h0 } : 10'h0) |
		(tc ? { rm_bit, 9'h80 } : 10'h0);
	
	wire pg_dbg_load_l;
	ym_sr_bit l_pg_dbg_load_l(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(reg_test0[3]), .val(pg_dbg_load_l));
	wire pg_dbg;
	ym_dbg_read #(.DATA_WIDTH(19)) l_pg_ebg(.MCLK(MCLK), .c1(clk1), .c2(clk2), .prev(1'h0), .load(reg_test0[3] & ~pg_dbg_load_l),
		.load_val({ pg_out_rhy, pg_phase_o[3][8:0] }), .next(pg_dbg));
	
	wire [9:0] op_mod;
	wire [9:0] op_phase = pg_out_rhy + op_mod;
	wire sawtooth = wf == 3'h7;
	
	wire [9:0] op_phase2 = (wf == 3'h4 | wf == 3'h5) ? { op_phase[8:0], 1'h0 } : op_phase;
	
	wire [8:0] op_phase3;
	
	assign op_phase3 = (sawtooth ? op_phase2[9] : op_phase2[8]) ? ~op_phase2[8:0] : op_phase2[8:0];
	
	
	wire wf_mute = (op_phase[9] & (wf == 3'h1 | wf == 3'h4 | wf == 3'h5)) | (op_phase[8] & wf == 3'h3);
	wire wf_sign = (wf == 3'h2 | wf == 3'h3 | wf == 3'h5) ? 1'h0 : op_phase2[9];
	
	wire op_mute;
	wire op_sign;
	ym_sr_bit #(.SR_LENGTH(2)) l_op_mute(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(wf_mute), .val(op_mute));
	ym_sr_bit #(.SR_LENGTH(2)) l_op_sign(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(wf_sign), .val(op_sign));
	
	wire [7:0] sin_index = (wf == 3'h6) ? 8'hff : op_phase3[7:0];
	
	wire [4:0] sin_lut_index = sin_index[5:1];
	
	reg [45:0] sine_lut_out;
	
	always @(sin_lut_index)
	begin
		case (sin_lut_index)
			5'h1f: sine_lut_out = 46'b0001100001000100100001000010101010101000100101;
			5'h1e: sine_lut_out = 46'b0001100001010100001000000001001001001100010100;
			5'h1d: sine_lut_out = 46'b0001100001010100001000110000101011001100000110;
			5'h1c: sine_lut_out = 46'b0001110000010000000000110011001001001100100111;
			5'h1b: sine_lut_out = 46'b0001110000010000011000000011101010001110010110;
			5'h1a: sine_lut_out = 46'b0001110000010100010001100000001000101110100111;
			5'h19: sine_lut_out = 46'b0001110000010100011001100001001011001110100101;
			5'h18: sine_lut_out = 46'b0001110000011100001001010011101000101111001111;
			5'h17: sine_lut_out = 46'b0001110001011000000001110010101110001101110111;
			5'h16: sine_lut_out = 46'b0001110001011000101000111001100101011001101010;
			5'h15: sine_lut_out = 46'b0001110001011100110000011011100100001010100111;
			5'h14: sine_lut_out = 46'b0001110001011100111000111110100011001001110111;
			5'h13: sine_lut_out = 46'b0100100010010000100001011100100000111001111011;
			5'h12: sine_lut_out = 46'b0100100010010100100001001111000001111110100010;
			5'h11: sine_lut_out = 46'b0100100010010100101001101111110110100101100100;
			5'h10: sine_lut_out = 46'b0100100111000000010000011101000110101110010111;
			5'h0f: sine_lut_out = 46'b0100100111000100010000101110001101001011111110;
			5'h0e: sine_lut_out = 46'b0100100111001100001011011000001001011000011011;
			5'h0d: sine_lut_out = 46'b0100110110001000001011101000001010111011111011;
			5'h0c: sine_lut_out = 46'b0100110110001100010011011010111110110100011000;
			5'h0b: sine_lut_out = 46'b0100110111001000110010111100101010001100010111;
			5'h0a: sine_lut_out = 46'b0100110111001100110110110111110001010111110000;
			5'h09: sine_lut_out = 46'b0111000100000000101111000101010101010101111001;
			5'h08: sine_lut_out = 46'b0111000100000100101111110111011101010010111011;
			5'h07: sine_lut_out = 46'b0111000101010101010100101000110000010010010001;
			5'h06: sine_lut_out = 46'b0111010100011001001100011010011100010000101001;
			5'h05: sine_lut_out = 46'b0111010101011011001001100100010000110100110010;
			5'h04: sine_lut_out = 46'b1010000100011011011001011110010001110010101001;
			5'h03: sine_lut_out = 46'b1010000101011111111100100101011100010010010011;
			5'h02: sine_lut_out = 46'b1010010111110101100010001011110001010100001010;
			5'h01: sine_lut_out = 46'b1011010110110011110111011000011100110000011010;
			5'h00: sine_lut_out = 46'b1110011111010001110111100110011001110101111010;
		endcase
	end
	
	wire sin_index_top_sel[4];
	assign sin_index_top_sel[0] = sin_index[7:6] == 2'h0;
	assign sin_index_top_sel[1] = sin_index[7:6] == 2'h1;
	assign sin_index_top_sel[2] = sin_index[7:6] == 2'h2;
	assign sin_index_top_sel[3] = sin_index[7:6] == 2'h3;
	
	wire [18:0] sin_lut_mux;
	
	assign sin_lut_mux[0] = (sine_lut_out[0] & sin_index_top_sel[0]) | (sine_lut_out[1] & sin_index_top_sel[1])
		| (sine_lut_out[2] & sin_index_top_sel[2]) | (sine_lut_out[3] & sin_index_top_sel[3]);
	assign sin_lut_mux[1] = (sine_lut_out[4] & sin_index_top_sel[0]) | (sine_lut_out[5] & sin_index_top_sel[1])
		| (sine_lut_out[6] & sin_index_top_sel[2]) | (sine_lut_out[7] & sin_index_top_sel[3]);
	assign sin_lut_mux[2] = (sine_lut_out[8] & sin_index_top_sel[0]) | (sine_lut_out[9] & sin_index_top_sel[1])
		| (sine_lut_out[10] & sin_index_top_sel[2]);
	assign sin_lut_mux[3] = (sine_lut_out[11] & sin_index_top_sel[0]) | (sine_lut_out[12] & sin_index_top_sel[1])
		| (sine_lut_out[13] & sin_index_top_sel[2]) | (sine_lut_out[14] & sin_index_top_sel[3]);
	assign sin_lut_mux[4] = (sine_lut_out[15] & sin_index_top_sel[0]) | (sine_lut_out[16] & sin_index_top_sel[1]);
	assign sin_lut_mux[5] = (sine_lut_out[17] & sin_index_top_sel[0]) | (sine_lut_out[18] & sin_index_top_sel[1])
		| (sine_lut_out[19] & sin_index_top_sel[2]) | (sine_lut_out[20] & sin_index_top_sel[3]);
	assign sin_lut_mux[6] = sine_lut_out[21] & sin_index_top_sel[0];
	assign sin_lut_mux[7] = (sine_lut_out[22] & sin_index_top_sel[0]) | (sine_lut_out[23] & sin_index_top_sel[1])
		| (sine_lut_out[24] & sin_index_top_sel[2]) | (sine_lut_out[25] & sin_index_top_sel[3]);
	assign sin_lut_mux[8] = sine_lut_out[26] & sin_index_top_sel[0];
	assign sin_lut_mux[9] = (sine_lut_out[27] & sin_index_top_sel[0]) | (sine_lut_out[28] & sin_index_top_sel[1])
		| (sine_lut_out[29] & sin_index_top_sel[2]) | (sine_lut_out[30] & sin_index_top_sel[3]);
	assign sin_lut_mux[10] = sine_lut_out[31] & sin_index_top_sel[0];
	assign sin_lut_mux[11] = (sine_lut_out[32] & sin_index_top_sel[0]) | (sine_lut_out[33] & sin_index_top_sel[1])
		| (sine_lut_out[34] & sin_index_top_sel[2]);
	assign sin_lut_mux[12] = sine_lut_out[35] & sin_index_top_sel[0];
	assign sin_lut_mux[13] = (sine_lut_out[36] & sin_index_top_sel[0]) | (sine_lut_out[37] & sin_index_top_sel[1])
		| (sine_lut_out[38] & sin_index_top_sel[2]);
	assign sin_lut_mux[14] = sine_lut_out[39] & sin_index_top_sel[0];
	assign sin_lut_mux[15] = (sine_lut_out[40] & sin_index_top_sel[0]) | (sine_lut_out[41] & sin_index_top_sel[1]);
	assign sin_lut_mux[16] = (sine_lut_out[42] & sin_index_top_sel[0]) | (sine_lut_out[43] & sin_index_top_sel[1]);
	assign sin_lut_mux[17] = sine_lut_out[44] & sin_index_top_sel[0];
	assign sin_lut_mux[18] = sine_lut_out[45] & sin_index_top_sel[0];
	
	wire [10:0] sin_base = { sin_lut_mux[18:15], sin_lut_mux[13], sin_lut_mux[11], sin_lut_mux[9], sin_lut_mux[7], sin_lut_mux[5], sin_lut_mux[3], sin_lut_mux[1] };
	
	wire [7:0] sin_delta = sin_index[0] ? 8'h0 : { sin_lut_mux[14], sin_lut_mux[12], sin_lut_mux[10], sin_lut_mux[8], sin_lut_mux[6], sin_lut_mux[4], sin_lut_mux[2], sin_lut_mux[0] };
	
	wire [11:0] sin_sum = sin_base + { sin_delta[7], sin_delta };
	
	wire [11:0] op_logsin;
	
	ym_sr_bit_array #(.DATA_WIDTH(12)) l_op_logsin(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(sin_sum), .val(op_logsin));
	
	wire op_saw;
	ym_sr_bit l_op_saw(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(sawtooth), .val(op_saw));
	wire [8:0] op_saw_phase;
	ym_sr_bit_array #(.DATA_WIDTH(9)) l_op_saw_phase(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(op_phase3), .val(op_saw_phase));
	
	wire [12:0] att = {1'h0, op_saw ? { op_saw_phase, 3'h0 } : op_logsin } + { 1'h0, eg_out, 3'h0 };
	
	wire [11:0] att_clamp = ~(att[12] ? 12'hfff : att[11:0]);
	
	wire [7:0] pow_index = att_clamp[7:0];
	
	wire [4:0] pow_lut_index = pow_index[5:1];
	
	reg [47:0] pow_lut_out;
	
	always @(pow_lut_index)
	begin
		case (pow_lut_index)
			5'h1f: pow_lut_out = 48'b111011111100011111101000111101000001000110011101;
			5'h1e: pow_lut_out = 48'b111011111100011010011111011000001011100010110011;
			5'h1d: pow_lut_out = 48'b111011111100000011110110111101101001110111011010;
			5'h1c: pow_lut_out = 48'b111011111100000011100001111101100101000001010110;
			5'h1b: pow_lut_out = 48'b111011111100000010000110011100100101000001011011;
			5'h1a: pow_lut_out = 48'b111011101001010101011101111101000001111111011101;
			5'h19: pow_lut_out = 48'b111011001011011101111010011111001000011011000000;
			5'h18: pow_lut_out = 48'b111011001011011100100101111100001001001111011110;
			5'h17: pow_lut_out = 48'b111011001011001101000110111101000001101011011010;
			5'h16: pow_lut_out = 48'b111011001011000001110011011101110001010111010100;
			5'h15: pow_lut_out = 48'b111011000011100010111100111100110001110110010101;
			5'h14: pow_lut_out = 48'b111010000111110011001111011101111001110010011011;
			5'h13: pow_lut_out = 48'b111010000111110011000000111001111011001110111101;
			5'h12: pow_lut_out = 48'b111010000100111110110111111100110101101001010001;
			5'h11: pow_lut_out = 48'b111010000100111110110000011100110001001110010011;
			5'h10: pow_lut_out = 48'b111010000100101101011010111101001001110011010101;
			5'h0f: pow_lut_out = 48'b111010000100101100001101011001001011010110110111;
			5'h0e: pow_lut_out = 48'b111010000100100100101010011000000011111010110001;
			5'h0d: pow_lut_out = 48'b111010000000110001110101111000000011011110110011;
			5'h0c: pow_lut_out = 48'b111010000000110000010110011001011011100011110101;
			5'h0b: pow_lut_out = 48'b111010000000010010001001111101011001000110010101;
			5'h0a: pow_lut_out = 48'b101110100010001011101110111000010011101010110101;
			5'h09: pow_lut_out = 48'b101100110011001111111001011000010011001111110011;
			5'h08: pow_lut_out = 48'b101100110011001110010011111001001011100010110001;
			5'h07: pow_lut_out = 48'b100101110111011111010100111001000011000010101010;
			5'h06: pow_lut_out = 48'b100101110111010111100011011000000011101110111000;
			5'h05: pow_lut_out = 48'b100101110111010100101100111100001001001010011010;
			5'h04: pow_lut_out = 48'b100101110111010000011011011100011001000110010000;
			5'h03: pow_lut_out = 48'b100101110111000001011000011001010011101010110001;
			5'h02: pow_lut_out = 48'b100101110101001000100111111001010011001110111011;
			5'h01: pow_lut_out = 48'b100101110101001000100001011101001001000100000000;
			5'h00: pow_lut_out = 48'b100101110001011001000110011000000011101010110000;
		endcase
	end
	
	wire pow_index_top_sel[4];
	assign pow_index_top_sel[0] = pow_index[7:6] == 2'h0;
	assign pow_index_top_sel[1] = pow_index[7:6] == 2'h1;
	assign pow_index_top_sel[2] = pow_index[7:6] == 2'h2;
	assign pow_index_top_sel[3] = pow_index[7:6] == 2'h3;
	
	wire [12:0] pow_lut_mux;
	
	assign pow_lut_mux[0] = (pow_lut_out[0] & pow_index_top_sel[0]) | (pow_lut_out[1] & pow_index_top_sel[1])
		| (pow_lut_out[2] & pow_index_top_sel[2]) | (pow_lut_out[3] & pow_index_top_sel[3]);
	assign pow_lut_mux[1] = (pow_lut_out[4] & pow_index_top_sel[0]) | (pow_lut_out[5] & pow_index_top_sel[1])
		| (pow_lut_out[6] & pow_index_top_sel[2]) | (pow_lut_out[7] & pow_index_top_sel[3]);
	assign pow_lut_mux[2] = (pow_lut_out[8] & pow_index_top_sel[0]) | (pow_lut_out[9] & pow_index_top_sel[1])
		| (pow_lut_out[10] & pow_index_top_sel[2]) | (pow_lut_out[11] & pow_index_top_sel[3]);
	assign pow_lut_mux[3] = (pow_lut_out[12] & pow_index_top_sel[0]) | (pow_lut_out[13] & pow_index_top_sel[1])
		| (pow_lut_out[14] & pow_index_top_sel[3]);
	assign pow_lut_mux[4] = (pow_lut_out[15] & pow_index_top_sel[0]) | (pow_lut_out[16] & pow_index_top_sel[1])
		| (pow_lut_out[17] & pow_index_top_sel[2]) | (pow_lut_out[18] & pow_index_top_sel[3]);
	assign pow_lut_mux[5] = (pow_lut_out[19] & pow_index_top_sel[0]) | (pow_lut_out[20] & pow_index_top_sel[1])
		| (pow_lut_out[21] & pow_index_top_sel[2]) | (pow_lut_out[22] & pow_index_top_sel[3]);
	assign pow_lut_mux[6] = (pow_lut_out[23] & pow_index_top_sel[0]) | (pow_lut_out[24] & pow_index_top_sel[1])
		| (pow_lut_out[25] & pow_index_top_sel[2]) | (pow_lut_out[26] & pow_index_top_sel[3]);
	assign pow_lut_mux[7] = (pow_lut_out[27] & pow_index_top_sel[0]) | (pow_lut_out[28] & pow_index_top_sel[1])
		| (pow_lut_out[29] & pow_index_top_sel[2]) | (pow_lut_out[30] & pow_index_top_sel[3]);
	assign pow_lut_mux[8] = (pow_lut_out[31] & pow_index_top_sel[0]) | (pow_lut_out[32] & pow_index_top_sel[1])
		| (pow_lut_out[33] & pow_index_top_sel[2]) | (pow_lut_out[34] & pow_index_top_sel[3]);
	assign pow_lut_mux[9] = (pow_lut_out[35] & pow_index_top_sel[0]) | (pow_lut_out[36] & pow_index_top_sel[1])
		| (pow_lut_out[37] & pow_index_top_sel[2]) | (pow_lut_out[38] & pow_index_top_sel[3]);
	assign pow_lut_mux[10] = (pow_lut_out[39] & pow_index_top_sel[0]) | (pow_lut_out[40] & pow_index_top_sel[1])
		| (pow_lut_out[41] & pow_index_top_sel[2]) | (pow_lut_out[42] & pow_index_top_sel[3]);
	assign pow_lut_mux[11] = (pow_lut_out[43] & pow_index_top_sel[1])
		| (pow_lut_out[44] & pow_index_top_sel[2]) | (pow_lut_out[45] & pow_index_top_sel[3]);
	assign pow_lut_mux[12] = (pow_lut_out[46] & pow_index_top_sel[2]) | (pow_lut_out[47] & pow_index_top_sel[3]);
	
	wire [9:0] pow_base = { pow_lut_mux[12:6], pow_lut_mux[4], pow_lut_mux[2], pow_lut_mux[0] };
	wire [2:0] pow_delta = pow_index[0] ? { pow_lut_mux[5], pow_lut_mux[3], pow_lut_mux[1] } : 3'h0;
	
	wire [9:0] pow_sum = pow_base + pow_delta;
	
	wire [9:0] op_pow;
	ym_sr_bit_array #(.DATA_WIDTH(10)) l_op_pow(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(pow_sum), .val(op_pow));
	wire [3:0] op_shift;
	ym_sr_bit_array #(.DATA_WIDTH(4)) l_op_shift(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(att_clamp[11:8]), .val(op_shift));
	
	wire sh_sel1[4];
	
	assign sh_sel1[0] = op_shift[1:0] == 2'h0;
	assign sh_sel1[1] = op_shift[1:0] == 2'h1;
	assign sh_sel1[2] = op_shift[1:0] == 2'h2;
	assign sh_sel1[3] = op_shift[1:0] == 2'h3;
	
	wire sh_sel2[1:3];
	
	assign sh_sel2[1] = op_shift[3:2] == 2'h1 & ~op_mute;
	assign sh_sel2[2] = op_shift[3:2] == 2'h2 & ~op_mute;
	assign sh_sel2[3] = op_shift[3:2] == 2'h3 & ~op_mute;
	
	wire [11:0] pow_shift1 = ({12{sh_sel1[3]}} & { 1'h1, op_pow, 1'h0 })
		| ({12{sh_sel1[2]}} & { 2'h1, op_pow })
		| ({12{sh_sel1[1]}} & { 3'h1, op_pow[9:1] })
		| ({12{sh_sel1[0]}} & { 4'h1, op_pow[9:2] });
	
	wire [11:0] pow_shift2 = ({12{sh_sel2[3]}} & pow_shift1 )
		| ({12{sh_sel2[2]}} & { 4'h0, pow_shift1[11:4] } )
		| ({12{sh_sel2[1]}} & { 8'h0, pow_shift1[11:8] } );
	
	wire [12:0] op_value = (~op_mute & op_sign) ? { 1'h1, ~pow_shift2 } : { 1'h0, pow_shift2 };
	
	wire [12:0] op_fb[4];
	wire [12:0] op_fb1_o;
	wire [12:0] op_fb3_o;
	
	ym_sr_bit_array #(.DATA_WIDTH(13), .SR_LENGTH(9)) l_op_fb0(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(fsm_out[15] ? op_value : op_fb[0]), .val(op_fb[0]));
	ym_sr_bit_array #(.DATA_WIDTH(13), .SR_LENGTH(6)) l_op_fb1_0(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(fsm_out[15] ? op_fb[0] : op_fb[1]), .val(op_fb1_o));
	ym_sr_bit_array #(.DATA_WIDTH(13), .SR_LENGTH(3)) l_op_fb1_1(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(op_fb1_o), .val(op_fb[1]));
	
	ym_sr_bit_array #(.DATA_WIDTH(13), .SR_LENGTH(9)) l_op_fb2(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(fsm_out[15] ? op_fb[1] : op_fb[2]), .val(op_fb[2]));
	ym_sr_bit_array #(.DATA_WIDTH(13), .SR_LENGTH(6)) l_op_fb3_0(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(fsm_out[15] ? op_fb[2] : op_fb[3]), .val(op_fb3_o));
	ym_sr_bit_array #(.DATA_WIDTH(13), .SR_LENGTH(3)) l_op_fb3_1(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(op_fb3_o), .val(op_fb[3]));
	
	wire [13:0] fb_sum = { op_fb1_o[12], op_fb1_o } + { op_fb3_o[12], op_fb3_o };
	
	wire [9:0] mod = ((fsm_out[16] & ~fsm_out[14]) ? op_value[9:0] : 10'h0) |
		((fsm_out[12] & fb_l == 3'h1) ? { {4{fb_sum[13]}}, fb_sum[13:8] } : 10'h0) |
		((fsm_out[12] & fb_l == 3'h2) ? { {3{fb_sum[13]}}, fb_sum[13:7] } : 10'h0) |
		((fsm_out[12] & fb_l == 3'h3) ? { {2{fb_sum[13]}}, fb_sum[13:6] } : 10'h0) |
		((fsm_out[12] & fb_l == 3'h4) ? { fb_sum[13], fb_sum[13:5] } : 10'h0) |
		((fsm_out[12] & fb_l == 3'h5) ? fb_sum[13:4] : 10'h0) |
		((fsm_out[12] & fb_l == 3'h6) ? fb_sum[12:3] : 10'h0) |
		((fsm_out[12] & fb_l == 3'h7) ? fb_sum[11:2] : 10'h0);
	
	ym_sr_bit_array #(.DATA_WIDTH(10)) l_op_mod(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(mod), .val(op_mod));
	
	
	wire [18:0] op_out;
	assign op_out[13:0] = fsm_out[13] ? (fsm_out[11] ? { op_value, 1'h0 } : { op_value[12], op_value }) : 13'h0;
	assign op_out[18:14] = {5{op_out[13]}};
	
	wire accm_load_ac;
	ym_edge_detect l_accm_load_ac(.MCLK(MCLK), .c1(clk1), .inp(fsm_out[6]), .val(accm_load_ac));
	wire accm_load_bd;
	ym_edge_detect l_accm_load_bd(.MCLK(MCLK), .c1(clk1), .inp(fsm_out[4]), .val(accm_load_bd));
	
	wire [18:0] accm_a;
	ym_sr_bit_array #(.DATA_WIDTH(19)) l_accm_a(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp((fsm_out[6] ? 19'h0 : accm_a) + (pan_l[0] ? op_out : 19'h0)), .val(accm_a));
	wire [18:0] accm_b;
	ym_sr_bit_array #(.DATA_WIDTH(19)) l_accm_b(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp((fsm_out[4] ? 19'h0 : accm_b) + (pan_l[1] ? op_out : 19'h0)), .val(accm_b));
	wire [18:0] accm_c;
	ym_sr_bit_array #(.DATA_WIDTH(19)) l_accm_c(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp((fsm_out[6] ? 19'h0 : accm_c) + (pan_l[2] ? op_out : 19'h0)), .val(accm_c));
	wire [18:0] accm_d;
	ym_sr_bit_array #(.DATA_WIDTH(19)) l_accm_d(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp((fsm_out[4] ? 19'h0 : accm_d) + (pan_l[3] ? op_out : 19'h0)), .val(accm_d));
	
	wire accm_a_sign;
	wire accm_a_of;
	ym_slatch l_accm_a_sign(.MCLK(MCLK), .en(accm_load_ac), .inp(~accm_a[18]), .val(accm_a_sign));
	ym_slatch l_accm_a_of(.MCLK(MCLK), .en(accm_load_ac), .inp(~(accm_a[18:15] == 4'h0 | accm_a[18:15] == 4'hf)), .val(accm_a_of));
	wire accm_c_sign;
	wire accm_c_of;
	ym_slatch l_accm_c_sign(.MCLK(MCLK), .en(accm_load_ac), .inp(~accm_c[18]), .val(accm_c_sign));
	ym_slatch l_accm_c_of(.MCLK(MCLK), .en(accm_load_ac), .inp(~(accm_c[18:15] == 4'h0 | accm_c[18:15] == 4'hf)), .val(accm_c_of));
	wire accm_b_sign;
	wire accm_b_of;
	ym_slatch l_accm_b_sign(.MCLK(MCLK), .en(accm_load_bd), .inp(~accm_b[18]), .val(accm_b_sign));
	ym_slatch l_accm_b_of(.MCLK(MCLK), .en(accm_load_bd), .inp(~(accm_b[18:15] == 4'h0 | accm_b[18:15] == 4'hf)), .val(accm_b_of));
	wire accm_d_sign;
	wire accm_d_of;
	ym_slatch l_accm_d_sign(.MCLK(MCLK), .en(accm_load_bd), .inp(~accm_d[18]), .val(accm_d_sign));
	ym_slatch l_accm_d_of(.MCLK(MCLK), .en(accm_load_bd), .inp(~(accm_d[18:15] == 4'h0 | accm_d[18:15] == 4'hf)), .val(accm_d_of));
	
	wire accm_shift_a;
	ym_dbg_read #(.DATA_WIDTH(16)) l_accm_shift_a(.MCLK(MCLK), .c1(clk1), .c2(clk2), .prev(1'h0), .load(fsm_out[6]),
		.load_val({ ~accm_a[18], accm_a[14:0] }), .next(accm_shift_a));
	wire accm_shift_b;
	ym_dbg_read #(.DATA_WIDTH(16)) l_accm_shift_b(.MCLK(MCLK), .c1(clk1), .c2(clk2), .prev(1'h0), .load(fsm_out[4]),
		.load_val({ ~accm_b[18], accm_b[14:0] }), .next(accm_shift_b));
	wire accm_shift_c;
	ym_dbg_read #(.DATA_WIDTH(16)) l_accm_shift_c(.MCLK(MCLK), .c1(clk1), .c2(clk2), .prev(1'h0), .load(fsm_out[6]),
		.load_val({ ~accm_c[18], accm_c[14:0] }), .next(accm_shift_c));
	wire accm_shift_d;
	ym_dbg_read #(.DATA_WIDTH(16)) l_accm_shift_d(.MCLK(MCLK), .c1(clk1), .c2(clk2), .prev(1'h0), .load(fsm_out[4]),
		.load_val({ ~accm_d[18], accm_d[14:0] }), .next(accm_shift_d));
	
	assign DOAB = fsm_out[8] ? (accm_a_of ? accm_a_sign : accm_shift_a) : (accm_b_of ? accm_b_sign : accm_shift_b);
	assign DOCD = fsm_out[8] ? (accm_c_of ? accm_c_sign : accm_shift_c) : (accm_d_of ? accm_d_sign : accm_shift_d);
	
	assign SY = clk2;
	
	assign SMPAC = fsm_out[10];
	
	assign SMPBD = fsm_out[9];
	
	assign IRQ_pull = t1_status | t2_status;
	
	assign DATA_o = { t1_status | t2_status, t1_status, t2_status, 5'h0 };
	assign DATA_d = ~io_read;
	
	wire ra_dbg_load;
	ym_sr_bit l_ra_dbg_load(.MCLK(MCLK), .c1(clk1), .c2(clk2), .inp(reg_test0[7]), .val(ra_dbg_load));
	
	wire ra_dbg1;
	ym_dbg_read #(.DATA_WIDTH(35)) l_ra_dbg1(.MCLK(MCLK), .c1(clk1), .c2(clk2), .prev(1'h0), .load(reg_test0[7] & ~ra_dbg_load),
		.load_val({ wf, sl, rr, ar, dr, ksl, tl, am, vib, egt, ksr, multi}), .next(ra_dbg1));
	wire ra_dbg2;
	ym_dbg_read #(.DATA_WIDTH(23)) l_ra_dbg2(.MCLK(MCLK), .c1(clk1), .c2(clk2), .prev(1'h0), .load(reg_test0[7] & ~ra_dbg_load),
		.load_val({ fb, connect_pair, pan, connect, keyon, blk, fnum }), .next(ra_dbg2));
	
	assign TEST = (reg_test1[3:0] == 3'h0 ? 1'h0 : 1'h0) |
						(reg_test1[3:0] == 3'h1 ? ra_dbg1 : 1'h0) |
						(reg_test1[3:0] == 3'h2 ? ra_dbg2 : 1'h0) |
						(reg_test1[3:0] == 3'h3 ? pg_dbg : 1'h0) |
						(reg_test1[3:0] == 3'h4 ? eg_dbg : 1'h0);
	
endmodule
