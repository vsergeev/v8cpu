/*

R15:R14 (and all other registers) initialize to 0 on reset, so the MEM operations always point to MEM[0]

Mnemonic	Encoded Instruction (hex)
mov R5, MEM	1150
mov R2, 0x01	2201
add R5, R2	5052
mov R0, R5	1005
mov MEM, R5	1250
mov R8, MEM	1180
cmp R7, R7	5677
je -7		30FA

*/

module vcpu_tb;
	reg clk;
	reg rst;

	reg memLoad;
	reg memClk, memWE;
	reg [15:0] memAddress;
	reg [7:0] memData;
	reg [7:0] memQ;

	wire [7:0] portA;
	wire [7:0] portB;

	integer i;

	initial begin
		$dumpvars;

		memLoad = 1;
		memClk = 0;
		memWE = 0;
		memAddress = 0;
		memData = 0;

		clk = 0;
		rst = 0;

		#1 memAddress = 0;
		memData = 'h50;
		writeMemory;
		#1 memAddress = memAddress + 1;
		memData = 'h11;
		writeMemory;

		#1 memAddress = memAddress + 1;
		memData = 'h01;
		writeMemory;
		#1 memAddress = memAddress + 1;
		memData = 'h22;
		writeMemory;

		#1 memAddress = memAddress + 1;
		memData = 'h52;
		writeMemory;
		#1 memAddress = memAddress + 1;
		memData = 'h50;
		writeMemory;

		#1 memAddress = memAddress + 1;
		memData = 'h05;
		writeMemory;
		#1 memAddress = memAddress + 1;
		memData = 'h10;
		writeMemory;

		#1 memAddress = memAddress + 1;
		memData = 'h50;
		writeMemory;
		#1 memAddress = memAddress + 1;
		memData = 'h12;
		writeMemory;

		#1 memAddress = memAddress + 1;
		memData = 'h80;
		writeMemory;
		#1 memAddress = memAddress + 1;
		memData = 'h11;
		writeMemory;
		
		#1 memAddress = memAddress + 1;
		memData = 'h77;
		writeMemory;
		#1 memAddress = memAddress + 1;
		memData = 'h56;
		writeMemory;

		#1 memAddress = memAddress + 1;
		memData = 'hF9;
		writeMemory;
		#1 memAddress = memAddress + 1;
		memData = 'h31;
		writeMemory;

		/***********************************************************/
		/***********************************************************/
		/***********************************************************/

		memLoad = 0;

		#10 rst = 1;
		#500 $finish;
	end

	always #5 clk = !clk;

	task writeMemory;
		begin
			memWE = 1;
			#1 memClk = 1;
			#1 memClk = 0; memWE = 0;
		end
	endtask

	always @(*) begin
		memQ = _memQ;
		cpuMemQ = _memQ;
		if (memLoad) begin
			_memClk = memClk;
			_memWE = memWE;
			_memAddress = memAddress;
			_memData = memData;
		end
		else begin
			_memClk = cpuMemClk;
			_memWE = cpuMemWE;
			_memAddress = cpuMemAddress;
			_memData = cpuMemData;
		end
	end

	reg _memClk, _memWE;
	reg [15:0] _memAddress;
	reg [7:0] _memData;
	wire [7:0] _memQ;

	vcpu_mem memory(.clk(_memClk), .we(_memWE), .address(_memAddress), .data(_memData), .q(_memQ));

	wire cpuMemClk, cpuMemWE;
	wire [15:0] cpuMemAddress;
	wire [7:0] cpuMemData;
	reg [7:0] cpuMemQ;

	wire [3:0] alu_op;
	wire [7:0] alu_a;
	wire [7:0] alu_b;
	wire [7:0] alu_c;
	wire [7:0] alu_flags;
	wire [7:0] alu_newFlags;

	vcpu_cu cu(.clk(clk), .reset(rst), .alu_op(alu_op), .alu_a(alu_a), .alu_b(alu_b), .alu_c(alu_c), .alu_flags(alu_flags), .alu_newFlags(alu_newFlags), .memClk(cpuMemClk), .memWE(cpuMemWE), .memAddress(cpuMemAddress), .memData(cpuMemData), .memQ(cpuMemQ));
	
	vcpu_alu alu(.op(alu_op), .a(alu_a), .b(alu_b), .c(alu_c), .flags(alu_flags), .newFlags(alu_newFlags));

endmodule

/* Output:
iverilog  -o sim/vcpu.vvp vcpu.v vcpu_tb.v
vvp -n  sim/vcpu.vvp -vcd
VCD info: dumpfile dump.vcd opened for output.
IP: 00000000
Flags: 00
Current Instruction: 1150
R00: 00
R01: 00
R02: 00
R03: 00
R04: 00
R05: 00
R06: 00
R07: 00
R08: 00
R09: 00
R10: 00
R11: 00
R12: 00
R13: 00
R14: 00
R15: 00
-----------------------

IP: 00000002
Flags: 00
Current Instruction: 2201
R00: 00
R01: 00
R02: 00
R03: 00
R04: 00
R05: 50
R06: 00
R07: 00
R08: 00
R09: 00
R10: 00
R11: 00
R12: 00
R13: 00
R14: 00
R15: 00
-----------------------

IP: 00000004
Flags: 00
Current Instruction: 5052
R00: 00
R01: 00
R02: 01
R03: 00
R04: 00
R05: 50
R06: 00
R07: 00
R08: 00
R09: 00
R10: 00
R11: 00
R12: 00
R13: 00
R14: 00
R15: 00
-----------------------

IP: 00000006
Flags: 00
Current Instruction: 1005
R00: 00
R01: 00
R02: 01
R03: 00
R04: 00
R05: 51
R06: 00
R07: 00
R08: 00
R09: 00
R10: 00
R11: 00
R12: 00
R13: 00
R14: 00
R15: 00
-----------------------

IP: 00000008
Flags: 00
Current Instruction: 1250
R00: 51
R01: 00
R02: 01
R03: 00
R04: 00
R05: 51
R06: 00
R07: 00
R08: 00
R09: 00
R10: 00
R11: 00
R12: 00
R13: 00
R14: 00
R15: 00
-----------------------

IP: 0000000a
Flags: 00
Current Instruction: 1180
R00: 51
R01: 00
R02: 01
R03: 00
R04: 00
R05: 51
R06: 00
R07: 00
R08: 00
R09: 00
R10: 00
R11: 00
R12: 00
R13: 00
R14: 00
R15: 00
-----------------------

IP: 0000000c
Flags: 00
Current Instruction: 5677
R00: 51
R01: 00
R02: 01
R03: 00
R04: 00
R05: 51
R06: 00
R07: 00
R08: 51
R09: 00
R10: 00
R11: 00
R12: 00
R13: 00
R14: 00
R15: 00
-----------------------

IP: 0000000e
Flags: 01
Current Instruction: 31f9
R00: 51
R01: 00
R02: 01
R03: 00
R04: 00
R05: 51
R06: 00
R07: 00
R08: 51
R09: 00
R10: 00
R11: 00
R12: 00
R13: 00
R14: 00
R15: 00
-----------------------

IP: 00000000
Flags: 01
Current Instruction: 1151
R00: 51
R01: 00
R02: 01
R03: 00
R04: 00
R05: 51
R06: 00
R07: 00
R08: 51
R09: 00
R10: 00
R11: 00
R12: 00
R13: 00
R14: 00
R15: 00
-----------------------

mv dump.vcd sim/vcpu.vcd

*/
