module ym_sr_bit #(parameter SR_LENGTH = 1)
	(
	input MCLK,
	input c1,
	input c2,
	input inp,
	output val
	);
	
	reg [SR_LENGTH-1:0] v1 = 0;
	reg [SR_LENGTH-1:0] v2 = 0;
	
	wire [SR_LENGTH-1:0] v2_assign = c2 ? v1 : v2;
	
	assign val = v2[SR_LENGTH-1];
	
	always @(posedge MCLK)
	begin
		if (c1)
		begin
			if (SR_LENGTH == 1)
				v1 <= inp;
			else
				v1 <= { v2[SR_LENGTH-2:0], inp };
		end
		v2 <= v2_assign;
	end
endmodule

module ym_sr_bit_array #(parameter SR_LENGTH = 1, DATA_WIDTH = 1)
	(
	input MCLK,
	input c1,
	input c2,
	input [DATA_WIDTH-1:0] inp,
	output [DATA_WIDTH-1:0] val
	);
	
	wire out[0:DATA_WIDTH-1];
	
	generate
		genvar i;
		for (i = 0; i < DATA_WIDTH; i = i + 1)
		begin : l1
			ym_sr_bit #(.SR_LENGTH(SR_LENGTH)) sr (
			.MCLK(MCLK),
			.c1(c1),
			.c2(c2),
			.inp(inp[i]),
			.val(out[i])
			);
			
			assign val[i] = out[i];
		end
	endgenerate

endmodule

module ym_cnt_bit #(parameter DATA_WIDTH = 1)
	(
	input MCLK,
	input c1,
	input c2,
	input c_in,
	input rst,
	output [DATA_WIDTH-1:0] val,
	output c_out
	);
	
	wire [DATA_WIDTH-1:0] data_in;
	wire [DATA_WIDTH-1:0] data_out;
	wire [DATA_WIDTH:0] sum;
	
	ym_sr_bit_array #(.DATA_WIDTH(DATA_WIDTH)) mem
		(
		.MCLK(MCLK),
		.c1(c1),
		.c2(c2),
		.inp(data_in),
		.val(data_out)
		);
	
	assign sum = { 1'h0, data_out } + {{DATA_WIDTH{1'h0}}, c_in};
	assign val = data_out;
	assign data_in = rst ? {DATA_WIDTH{1'h0}} : sum[DATA_WIDTH-1:0];
	assign c_out = sum[DATA_WIDTH];
	
endmodule

module ym_dlatch #(parameter DATA_WIDTH = 1)
	(
	input MCLK,
	input en,
	input [DATA_WIDTH-1:0] inp,
	output [DATA_WIDTH-1:0] val,
	output [DATA_WIDTH-1:0] nval
	);
	
	reg [DATA_WIDTH-1:0] mem = {DATA_WIDTH{1'h0}};
	
	wire [DATA_WIDTH-1:0] mem_assign = en ? inp : mem;
	
	always @(posedge MCLK)
	begin
		mem <= mem_assign;
	end
	
	//assign val = mem_assign;
	//assign nval = ~mem_assign;
	assign val = mem;
	assign nval = ~mem;
	
endmodule

module ym_edge_detect
	(
	input MCLK,
	input c1,
	input inp,
	output val
	);
	
	wire prev_out;
	
	ym_dlatch prev
		(
		.MCLK(MCLK),
		.en(c1),
		.inp(inp),
		.val(prev_out),
		.nval()
		);
	assign val = ~(prev_out | ~inp);
endmodule

module ym_slatch #(parameter DATA_WIDTH = 1)
	(
	input MCLK,
	input en,
	input [DATA_WIDTH-1:0] inp,
	output [DATA_WIDTH-1:0] val,
	output [DATA_WIDTH-1:0] nval
	);
	
	reg [DATA_WIDTH-1:0] mem = {DATA_WIDTH{1'h0}};
	
	wire [DATA_WIDTH-1:0] mem_assign = en ? inp : mem;
	
	always @(posedge MCLK)
	begin
		mem <= mem_assign;
	end
	
	assign val = mem;
	assign nval = ~mem;
	
endmodule

module ym_rs_trig
	(
	input MCLK,
	input set,
	input rst,
	output reg q = 1'h0,
	output reg nq = 1'h1
	);
	
	always @(posedge MCLK)
	begin
		q <= rst ? 1'h0 : (set ? 1'h1 : q);
		nq <= set ? 1'h0 : (rst ? 1'h1 : ~q); 
	end
	
endmodule

module ym_cnt_bit_load #(parameter DATA_WIDTH = 1)
	(
	input MCLK,
	input c1,
	input c2,
	input c_in,
	input rst,
	input load,
	input [DATA_WIDTH-1:0] load_val,
	output [DATA_WIDTH-1:0] val,
	output c_out
	);
	
	wire [DATA_WIDTH-1:0] data_in;
	wire [DATA_WIDTH-1:0] data_out;
	wire [DATA_WIDTH:0] sum;
	
	ym_sr_bit_array #(.DATA_WIDTH(DATA_WIDTH)) mem
		(
		.MCLK(MCLK),
		.c1(c1),
		.c2(c2),
		.inp(data_in),
		.val(data_out)
		);
	
	wire [DATA_WIDTH-1:0] base_val = load ? load_val : data_out;
	
	assign sum = {1'h0, base_val} + {{DATA_WIDTH{1'h0}},c_in};
	assign data_in = rst ? {DATA_WIDTH{1'h0}} : sum[DATA_WIDTH-1:0];
	assign val = data_out;
	assign c_out = sum[DATA_WIDTH];
	
endmodule

module ym_dbg_read #(parameter DATA_WIDTH = 1)
	(
	input MCLK,
	input c1,
	input c2,
	input prev,
	input load,
	input [DATA_WIDTH-1:0] load_val,
	output next
	);
	
	wire [DATA_WIDTH-1:0] data_in;
	wire [DATA_WIDTH-1:0] data_out;
	
	ym_sr_bit_array #(.DATA_WIDTH(DATA_WIDTH)) mem
		(
		.MCLK(MCLK),
		.c1(c1),
		.c2(c2),
		.inp(data_in),
		.val(data_out)
		);
		
	wire [DATA_WIDTH-1:0] chain;
	
	assign data_in = chain | (load ? load_val : {DATA_WIDTH{1'h0}});
	
	generate
		if (DATA_WIDTH == 1)
			assign chain = prev;
		else
			assign chain = { prev, data_out[DATA_WIDTH-1:1] };
	endgenerate
	
	assign next = data_out[0];
	
endmodule

module ym_dbg_read_eg #(parameter DATA_WIDTH = 1)
	(
	input MCLK,
	input c1,
	input c2,
	input prev,
	input load,
	input [DATA_WIDTH-1:0] load_val,
	output next
	);
	
	wire [DATA_WIDTH-1:0] data_in;
	wire [DATA_WIDTH-1:0] data_out;
	
	ym_sr_bit_array #(.DATA_WIDTH(DATA_WIDTH)) mem
		(
		.MCLK(MCLK),
		.c1(c1),
		.c2(c2),
		.data_in(data_in),
		.data_out(data_out)
		);
		
	wire [DATA_WIDTH-1:0] chain;
	
	assign data_in = chain | (load ? load_val : {DATA_WIDTH{1'h0}});
	
	generate
		if (DATA_WIDTH == 1)
			assign chain = prev;
		else
			assign chain = { data_out[DATA_WIDTH-2:0], prev };
	endgenerate
	
	assign next = data_out[DATA_WIDTH-1];
	
endmodule

module ym_slatch_r #(parameter DATA_WIDTH = 1)
	(
	input MCLK,
	input en,
	input rst,
	input [DATA_WIDTH-1:0] inp,
	output [DATA_WIDTH-1:0] val,
	output [DATA_WIDTH-1:0] nval
	);
	
	reg [DATA_WIDTH-1:0] mem = {DATA_WIDTH{1'h0}};
	
	wire [DATA_WIDTH-1:0] mem_assign = rst ? {DATA_WIDTH{1'h0}} : (en ? inp : mem);
	
	always @(posedge MCLK)
	begin
		mem <= mem_assign;
	end
	
	assign val = mem;
	assign nval = ~mem;
	
endmodule
