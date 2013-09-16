/* v8cpu by Vanya A. Sergeev - vsergeev@gmail.com
 * Simple multi-cycle von Neumann architecture 8-bit CPU
 *
 * 6-7 CPI, 80MHz Maximum Clock --> ~11.4 MIPS */

`define SIMULATION

/* v8cpu ALU for Add, Subtract, AND, OR, XOR, NOT, and Compare. */
module v8cpu_alu (
	input [3:0] op,
	input [7:0] a,
	input [7:0] b,
	output reg [7:0] c,
	input [7:0] flags,
	output reg [7:0] newFlags);

	parameter	ALU_OP_ADD	= 4'b0000,
			ALU_OP_SUB	= 4'b0001,
			ALU_OP_AND	= 4'b0010,
			ALU_OP_OR	= 4'b0011,
			ALU_OP_XOR	= 4'b0100,
			ALU_OP_NOT	= 4'b0101,
			ALU_OP_CMP	= 4'b0110;

	parameter	FLAG_INDEX_EQ		= 'd0,
			FLAG_INDEX_GREATER	= 'd1;

	always @(*) begin
		c = a;
		newFlags = flags;
		case (op)
			ALU_OP_ADD: c = a + b;
			ALU_OP_SUB: c = a - b;
			ALU_OP_AND: c = a & b;
			ALU_OP_OR: c = a | b;
			ALU_OP_XOR: c = a ^ b;
			ALU_OP_NOT: c = ~a;
			ALU_OP_CMP: begin
				newFlags[FLAG_INDEX_EQ] = (a == b);
				newFlags[FLAG_INDEX_GREATER] = (a > b);
			end
		endcase
	end
endmodule

`ifdef SIMULATION
`else
/* v8cpu Memory: 0x000-0x3FF = 1024 bytes; 8-bit data */
module v8cpu_mem (
	input clk,
	input we,
	input [15:0] address,
	input [7:0] data,
	output reg [7:0] q);

	wire [7:0] q_memory;
	reg we_validated;

	blk_mem_gen memory(.clka(clk), .wea(we_validated), .addra(address[9:0]), .dina(data), .douta(q_memory));

	always @(*) begin
		if (|address[15:10] == 'd0) begin
			q = q_memory;
			we_validated = we;
		end
		else begin
			q = 8'bZZZZZZZZ;
			we_validated = 0;
		end
	end
endmodule
`endif

/* v8cpu Memory-Mapped I/O: 0x800 = Port A, 0x801 = Port B, 0x803 = Pin C, 0x804 = Pin D; 8-bit data */
module v8cpu_io (
	input clk,
	input reset,
	input we,
	input [15:0] address,
	input [7:0] data,
	output reg [7:0] q,

	output reg [7:0] portA,
	output reg [7:0] portB,
	input [7:0] pinC,
	input [7:0] pinD);

	reg [7:0] q_reg;

	always @(posedge clk or negedge reset) begin
		if (!reset) begin
			portA <= 8'd0;
			portB <= 8'd0;
		end
		else if (we) begin
			if (address == 'h800) portA <= data;
			else if (address == 'h801) portB <= data;
			/* Print the current values of PortA:PortB for simulation purposes as PortA is being overwritten */
			if (address == 'h800) $display("PortA:PortB = %01d", {portA, portB});
		end
		else begin
			if (address == 'h802) q_reg <= pinC;
			else if (address == 'h803) q_reg <= pinD;
		end
	end

	always @(*) begin
		if (address == 'h802) q = q_reg;
		else if (address == 'h803) q = q_reg;
		else q = 8'bZZZZZZZZ;
	end
endmodule

/* v8cpu Control Unit: IP, 16 8-bit Registers, 8-bit Flags Register, Fetch/Decode/Execute State Machine */
module v8cpu_cu (
	input clk,
	input reset,

	output reg [3:0] alu_op,
	output reg [7:0] alu_a,
	output reg [7:0] alu_b,
	input [7:0] alu_c,
	output [7:0] alu_flags,
	input [7:0] alu_newFlags,

	output reg memClk,
	output reg memWE,
	output reg [15:0] memAddress,
	output reg [7:0] memData,
	input [7:0] memQ);

	/* Instruction pointer */
	reg [15:0] v8CPU_IP;
	/* Register file */
	reg [7:0] v8CPU_RegisterFile[0:15];
	/* Flags, currently just EQ flag in bit 0 */
	reg [7:0] v8CPU_Flags;

	/* Indexing into v8CPU_Flags for various flags modified by the compare instruction */
	parameter	FLAG_INDEX_EQ		= 'd0,
			FLAG_INDEX_GREATER	= 'd1;

	/* 16-bit instruction register for decoding/execution */
	reg [15:0] Instruction;

	/* Major classes of instructions, see v8cpu ISA */
	parameter 	INSTR_CLASS_MOVE	= 4'b0001,
			INSTR_CLASS_MOVE_IMM 	= 4'b0010,
			INSTR_CLASS_BRANCH	= 4'b0011,
			INSTR_CLASS_JUMP	= 4'b0100,
			INSTR_CLASS_MATH	= 4'b0101;

	/* State machine states */
	reg [3:0] state;
	reg [3:0] nextState;

	parameter	STATE_FETCH_INSTR_LO 		= 'b0000,
			STATE_FETCH_INSTR_LO_READ 	= 'b0001,
			STATE_FETCH_INSTR_HI 		= 'b0010,
			STATE_FETCH_INSTR_HI_READ 	= 'b0011,
			STATE_DECODE			= 'b0100,
			STATE_CLASS_MOVE		= 'b0101,
			STATE_CLASS_MOVE_IMM		= 'b0110,
			STATE_CLASS_BRANCH		= 'b0111,
			STATE_CLASS_JUMP		= 'b1000,
			STATE_CLASS_MATH		= 'b1001,
			STATE_CLASS_MOVE_READ_MEM_CLK	= 'b1010,
			STATE_CLASS_MOVE_READ_MEM	= 'b1011,
			STATE_CLASS_MOVE_WRITE_MEM_CLK	= 'b1100,
			STATE_CLASS_MOVE_WRITE_MEM	= 'b1101,
			STATE_CLASS_NOP			= 'b1110;

	/* Combinational next values for memory output regs */
	reg [15:0] n_memAddress;
	reg [7:0] n_memData;
	reg n_memClk;
	reg n_memWE;

	/* Combinational next values for CPU state and instruction decoding/execution */
	reg [15:0] n_v8CPU_IP;
	reg [15:0] calc_n_v8CPU_IP;
	reg [7:0] n_v8CPU_Flags;
	reg [7:0] n_Instruction_Lo;
	reg [7:0] n_Instruction_Hi;
	reg [3:0] n_Register_Index;
	reg [7:0] n_Register_Data;

	/* Assign the flags input of the ALU directly to the v8CPU_Flags register */
	assign alu_flags = v8CPU_Flags;

	/* Combinational block for state machine (spelled out due to Xilinx tools bug with arrays in sensitivity list) */
	always @(state or Instruction or v8CPU_IP or v8CPU_Flags or memQ or calc_n_v8CPU_IP or alu_c or alu_newFlags or v8CPU_RegisterFile[0] or v8CPU_RegisterFile[1] or v8CPU_RegisterFile[2] or v8CPU_RegisterFile[3] or v8CPU_RegisterFile[4] or v8CPU_RegisterFile[5] or v8CPU_RegisterFile[6] or v8CPU_RegisterFile[7] or v8CPU_RegisterFile[8] or v8CPU_RegisterFile[9] or v8CPU_RegisterFile[10] or v8CPU_RegisterFile[11] or v8CPU_RegisterFile[12] or v8CPU_RegisterFile[13] or v8CPU_RegisterFile[14] or v8CPU_RegisterFile[15]) begin
		nextState = STATE_FETCH_INSTR_LO;

		/* Default assignments */
		n_memAddress = 'd0;
		n_memData = 'd0;
		n_memClk = 0;
		n_memWE = 0;

		n_Instruction_Lo = Instruction[7:0];
		n_Instruction_Hi = Instruction[15:8];
		n_v8CPU_IP = v8CPU_IP;
		n_v8CPU_Flags = v8CPU_Flags;

		n_Register_Index = 0;
		n_Register_Data = v8CPU_RegisterFile[0];

		alu_op = Instruction[11:8];
		alu_a = v8CPU_RegisterFile[Instruction[7:4]];
		alu_b = v8CPU_RegisterFile[Instruction[3:0]];

		case (state)
			STATE_FETCH_INSTR_LO: begin
				n_memAddress = v8CPU_IP;
				n_memClk = 1;
				nextState = STATE_FETCH_INSTR_LO_READ;
			end
			STATE_FETCH_INSTR_LO_READ: begin
				/* For some reason Icarus *does not* re-evaluate the
				 * always block sensitivity list when memQ updates.
				 * The #1 delay is a work-around to read in the correct value
				 * of memQ. */
				#1 n_Instruction_Lo = memQ;
				n_memAddress = v8CPU_IP+1;
				nextState = STATE_FETCH_INSTR_HI;
			end
			STATE_FETCH_INSTR_HI: begin
				n_memAddress = v8CPU_IP+1;
				n_memClk = 1;
				nextState = STATE_FETCH_INSTR_HI_READ;
			end
			STATE_FETCH_INSTR_HI_READ: begin
				/* For some reason Icarus *does not* re-evaluate the
				 * always block sensitivity list when memQ updates.
				 * The #1 delay is a work-around to read in the correct value
				 * of memQ. */
				#1 n_Instruction_Hi = memQ;
				nextState = STATE_DECODE;
			end
			STATE_DECODE: begin
				case (Instruction[15:12])
					INSTR_CLASS_MOVE_IMM: nextState = STATE_CLASS_MOVE_IMM;
					INSTR_CLASS_BRANCH: nextState = STATE_CLASS_BRANCH;
					INSTR_CLASS_JUMP: nextState = STATE_CLASS_JUMP;
					INSTR_CLASS_MATH: nextState = STATE_CLASS_MATH;
					INSTR_CLASS_MOVE: begin
						/* Do some additional decoding in case we need to setup the memory addresses
						 * for the read MEM / write MEM instructions, to keep the CPI down for memory
						 * access instructions. */
						case (Instruction[11:8])
							/* mov Ra, Rb */
							'b0000: nextState = STATE_CLASS_MOVE;
							/* mov Ra, MEM */
							'b0001: begin
								n_memAddress = {v8CPU_RegisterFile[14], v8CPU_RegisterFile[15]};
								nextState = STATE_CLASS_MOVE_READ_MEM_CLK;
							end
							/* mov MEM, Ra */
							'b0010: begin
								n_memAddress = {v8CPU_RegisterFile[14], v8CPU_RegisterFile[15]};
								n_memData = v8CPU_RegisterFile[Instruction[7:4]];
								n_memWE = 1;
								nextState = STATE_CLASS_MOVE_WRITE_MEM_CLK;
							end
							default: nextState = STATE_CLASS_NOP;
						endcase
					end
					default: nextState = STATE_CLASS_NOP;
				endcase
			end

			STATE_CLASS_BRANCH: begin
				/* If the number is negative, then undo two's complement and subtract from IP */
				if (Instruction[7]) calc_n_v8CPU_IP = v8CPU_IP - {8'b0000_0000, ((~Instruction[6:0])+1'b1) << 1};
				/* Otherwise, if the relative jump is positive, just add to IP */
				else calc_n_v8CPU_IP = v8CPU_IP + {8'b0000_0000, Instruction[6:0] << 1};

				n_v8CPU_IP = v8CPU_IP+2;
				case (Instruction[11:8])
					/* jmp */
					'b0000: n_v8CPU_IP = calc_n_v8CPU_IP;
					/* je */
					'b0001: if (v8CPU_Flags[FLAG_INDEX_EQ]) n_v8CPU_IP = calc_n_v8CPU_IP;
					/* jne */
					'b0010: if (!v8CPU_Flags[FLAG_INDEX_EQ]) n_v8CPU_IP = calc_n_v8CPU_IP;
					/* jg */
					'b0011: if (v8CPU_Flags[FLAG_INDEX_GREATER]) n_v8CPU_IP = calc_n_v8CPU_IP;
					/* jl */
					'b0100: if (!v8CPU_Flags[FLAG_INDEX_GREATER]) n_v8CPU_IP = calc_n_v8CPU_IP;
				endcase
				n_memAddress = n_v8CPU_IP;
				nextState = STATE_FETCH_INSTR_LO;
			end

			STATE_CLASS_JUMP: begin
				n_v8CPU_IP = ({v8CPU_RegisterFile[14], v8CPU_RegisterFile[15]} << 1);
				n_memAddress = n_v8CPU_IP;
				nextState = STATE_FETCH_INSTR_LO;
			end

			STATE_CLASS_MOVE_IMM: begin
				n_Register_Index = Instruction[11:8];
				n_Register_Data = Instruction[7:0];
				setupFetch;
			end

			STATE_CLASS_MATH: begin
				alu_op = Instruction[11:8];
				alu_a = v8CPU_RegisterFile[Instruction[7:4]];
				alu_b = v8CPU_RegisterFile[Instruction[3:0]];
				n_Register_Index = Instruction[7:4];
				n_Register_Data = alu_c;
				n_v8CPU_Flags = alu_newFlags;
				setupFetch;
			end

			STATE_CLASS_MOVE: begin
				n_Register_Index = Instruction[7:4];
				n_Register_Data = v8CPU_RegisterFile[Instruction[3:0]];
				setupFetch;
			end

			STATE_CLASS_MOVE_READ_MEM_CLK: begin
				n_memAddress = {v8CPU_RegisterFile[14], v8CPU_RegisterFile[15]};
				n_memClk = 1;
				nextState = STATE_CLASS_MOVE_READ_MEM;
			end

			STATE_CLASS_MOVE_READ_MEM: begin
				n_Register_Index = Instruction[7:4];
				n_Register_Data = memQ;
				setupFetch;
			end

			STATE_CLASS_MOVE_WRITE_MEM_CLK: begin
				n_memAddress = {v8CPU_RegisterFile[14], v8CPU_RegisterFile[15]};
				n_memData = v8CPU_RegisterFile[Instruction[7:4]];
				n_memWE = 1;
				n_memClk = 1;
				nextState = STATE_CLASS_MOVE_WRITE_MEM;
			end

			STATE_CLASS_MOVE_WRITE_MEM: begin
				setupFetch;
			end

			STATE_CLASS_NOP: begin
				setupFetch;
			end
		endcase
	end

	/* A task to increment the IP and setup the memory address to fetch the next instruction */
	task setupFetch;
	begin
		n_v8CPU_IP = v8CPU_IP+2;
		n_memAddress = v8CPU_IP+2;
		nextState = STATE_FETCH_INSTR_LO;
	end
	endtask

	integer i;
	/* Sequential block for state machine */
	always @(posedge clk or negedge reset) begin
		if (!reset) begin
			v8CPU_RegisterFile[0] <= 'd0; v8CPU_RegisterFile[1] <= 'd0;
			v8CPU_RegisterFile[2] <= 'd0; v8CPU_RegisterFile[3] <= 'd0;
			v8CPU_RegisterFile[4] <= 'd0; v8CPU_RegisterFile[5] <= 'd0;
			v8CPU_RegisterFile[6] <= 'd0; v8CPU_RegisterFile[7] <= 'd0;
			v8CPU_RegisterFile[8] <= 'd0; v8CPU_RegisterFile[9] <= 'd0;
			v8CPU_RegisterFile[10] <= 'd0; v8CPU_RegisterFile[11] <= 'd0;
			v8CPU_RegisterFile[12] <= 'd0; v8CPU_RegisterFile[13] <= 'd0;
			v8CPU_RegisterFile[14] <= 'd0; v8CPU_RegisterFile[15] <= 'd0;
			v8CPU_IP <= 16'h0000;
			v8CPU_Flags <= 'd0;
			state <= 'd0;
			memAddress <= 'd0;
			memData <= 'd0;
			memClk <= 0;
			memWE <= 0;
			Instruction <= 'd0;
		end
		else begin
			state <= nextState;
			memAddress <= n_memAddress;
			memData <= n_memData;
			memClk <= n_memClk;
			memWE <= n_memWE;

			Instruction[15:8] <= n_Instruction_Hi;
			Instruction[7:0] <= n_Instruction_Lo;
			v8CPU_IP <= n_v8CPU_IP;
			v8CPU_Flags <= n_v8CPU_Flags;
			v8CPU_RegisterFile[n_Register_Index] <= n_Register_Data;

			/* Print the CPU state for simulation purposes */
			if (state == STATE_DECODE) begin
				$display("IP: %08X", v8CPU_IP);
				$display("Flags: %02X", v8CPU_Flags);
				$display("Current Instruction: %04X", Instruction);
				for (i = 0; i < 16; i = i + 1) $display("R%02d: %02X", i, v8CPU_RegisterFile[i]);
				$display("-----------------------\n");
			end
		end
	end
endmodule

/* v8cpu Top-Level Module: Clock input, Reset input, 8-bit Port A output, 8-bit Port B output, 8-bit Pin C input, 8-bit Pin D input */
module v8cpu (
	input clk,
	input reset,
	output [7:0] portA,
	output [7:0] portB,
	input [7:0] pinC,
	input [7:0] pinD);

	wire [3:0] alu_op;
	wire [7:0] alu_a;
	wire [7:0] alu_b;
	wire [7:0] alu_c;
	wire [7:0] alu_flags;
	wire [7:0] alu_newFlags;
	wire memClk, memWE;
	wire [15:0] memAddress;
	wire [7:0] memData;
	wire [7:0] memQ;

	v8cpu_cu cu(.clk(clk), .reset(reset), .alu_op(alu_op), .alu_a(alu_a), .alu_b(alu_b), .alu_c(alu_c), .alu_flags(alu_flags), .alu_newFlags(alu_newFlags), .memClk(memClk), .memWE(memWE), .memAddress(memAddress), .memData(memData), .memQ(memQ));

	v8cpu_alu alu(.op(alu_op), .a(alu_a), .b(alu_b), .c(alu_c), .flags(alu_flags), .newFlags(alu_newFlags));

	`ifdef SIMULATION
	v8cpu_mem_sim mem(.clk(memClk), .we(memWE), .address(memAddress), .data(memData), .q(memQ));
	`else
	v8cpu_mem mem(.clk(memClk), .we(memWE), .address(memAddress), .data(memData), .q(memQ));
	`endif

	v8cpu_io io(.clk(memClk), .reset(reset), .we(memWE), .address(memAddress), .data(memData), .q(memQ), .portA(portA), .portB(portB), .pinC(pinC), .pinD(pinD));
endmodule

