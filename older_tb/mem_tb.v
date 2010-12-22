module vcpu_alu_tb;

	reg memClk, memWE;
	reg [15:0] memAddress;
	reg [7:0] memData;
	wire [7:0] memQ;

	wire [7:0] portA;
	wire [7:0] portB;

	integer i;

	initial begin
		$dumpvars;

		memClk = 0;
		memWE = 0;
		memAddress = 0;
		memData = 0;

		/* Write 0x55, 0xFF, and then 0x23 for the rest of 512 bytes */
		#1 memAddress = 0;
		memData = 'h55;
		writeMemory;
		
		#1 memAddress = 1;
		memData = 'hFF;
		writeMemory;

		memData = 'h23;
		for (i = 0; i < 510; i = i + 1) begin
			memAddress = memAddress + 1;
			writeMemory;
		end

		#10

		for (i = 0; i < 512; i = i + 1) begin
			memAddress = i;
			memData = memData + 1;
			#1 $display("%d: %02X", memAddress, memQ);
		end

		#10 $finish;
	end

	task writeMemory;
		begin
			memWE = 1;
			#1 memClk = 1;
			#1 memClk = 0; memWE = 0;
		end
	endtask

	vcpu_mem memory(.clk(memClk), .we(memWE), .address(memAddress), .data(memData), .q(memQ), .portA(portA), .portB(portB), .pinC(8'd0), .pinD(8'd0)); 
endmodule

