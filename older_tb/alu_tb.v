module vcpu_alu_tb;
	reg [2:0] aluOp;
	reg [7:0] aluA;
	reg [7:0] aluB;
	wire [7:0] aluC;
	wire aluEq;

	reg [15:0] address;
	reg collapse;

	initial begin
		$dumpvars;
		aluA = 'd23;
		aluB = 'd44;
		
		#5 aluOp = 3'b000;
		#5 aluOp = 3'b001;
		#5 aluOp = 3'b010;
		#5 aluOp = 3'b011;
		#5 aluOp = 3'b100;
		#5 aluOp = 3'b101;
		#5 aluOp = 3'b110;
		
		#5
		#5 address = 'd1023; collapse = |address[15:10];
		#5 address = 'd1024; collapse = |address[15:10];
		#5 address = 'd5000; collapse = |address[15:10];
		#5 address = 'd500; collapse = |address[15:10];
		#10 $finish;
	end

	vcpu_alu alu(.op(aluOp), .a(aluA), .b(aluB), .c(aluC), .flag_eq(aluEq));
endmodule
