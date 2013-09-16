//`timescale 1ns/1ps

module v8cpu_tb(
	output [7:0] portA,
	output [7:0] portB,
	input [7:0] pinC,
	input [7:0] pinD);

	reg clk;
	reg rst;

	initial begin
		$dumpvars;

		clk = 0;
		rst = 0;

		#100 rst = 1;
		#100000 $finish;
	end

	always #20 clk = !clk;

	v8cpu cpu(.clk(clk), .reset(rst), .portA(portA), .portB(portB), .pinC(pinC), .pinD(pinD));
endmodule

