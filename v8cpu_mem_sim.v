/* v8CPU Memory: 0x000-0x3FF = 1024 bytes; 8-bit data */
module v8cpu_mem_sim (
	input clk,
	input we,
	input [15:0] address,
	input [7:0] data,
	output reg [7:0] q);

	reg [7:0] memory[0:1023];

	/* Use Verilog's $readmemh() to initialize the memory with a program for simulation purposes */
	integer i;
	initial begin
		$readmemh("fib.dat", memory);
		for (i = 0; i < 50; i = i + 1) $display("mem[%02d]: %02X", i, memory[i]);
	end

	always @(posedge clk) begin
		if (|address[15:10] == 'd0) begin
			q <= memory[address];
			if (we) memory[address] <= data;
		end
		else q <= 8'bZZZZZZZZ;
	end
endmodule


