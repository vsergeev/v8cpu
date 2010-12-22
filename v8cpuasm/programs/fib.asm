; 16-bit Fibonacci Number Generator for v8cpu
; Vanya A. Sergeev - vsergeev@gmail.com
; 16-bit Fibonacci Numbers are computed and written sequentially across port A (high byte) and port B (low byte)
;
; R0:R1 = Fn-2
; R2:R3 = Fn-1
; R4:R5 = Fn
; R0:R1, R2:R3 initialize to 0

; Initialize R4:R5 to 0x0001
mov R4, 0x00
mov R5, 0x01

; Save a constant 1
mov R11, 0x01

; Save constant for 46368 (biggest 16-bit fibonacci number)
mov R8, 0xB5
mov R9, 0x20

; Address for portA (0x800) in R14:R15
mov R14, 0x08
mov R15, 0x00

fibLoop:
		mov R0, R2	; Fn-2 (hi byte) <= Fn-1 (hi byte)
		mov R1, R3	; Fn-2 (lo byte) <= Fn-1 (lo byte)

		mov R2, R4	; Fn-1 (hi byte) <= Fn (hi byte)
		mov R3, R5	; Fn-1 (lo byte) <= Fn (lo byte)

		; R4:R5 contains Fn-1, R0:R1 contains Fn-2

		add R5, R1	; Fn-1 + Fn-2 (lo bytes)
		cmp R5, R3	; Compare the new R5 to the old R5 (R3)
		je fibContinue	; No carry occured if they're equal
		jl addCarryBit	; If the new R5 is less than the old R5, we had an overflow
				; and we need to add the carry bit

fibContinue:	add R4, R0	; Fn-1 + Fn-2 (hi bytes)

		; Write R4 to portA, R5 to portB
		mov R15, 0x00	; R14:R15 = 0x0800 = port A address
		mov MEM, R4
		mov R15, 0x01	; R14:R15 = 0x0801 = port B address
		mov MEM, R5

		; Check if we've reached 46368 (biggest 16-bit fibonacci number)
		cmp R4, R8
		jne fibLoop
		cmp R5, R9
		jne fibLoop

		; Reset to initial conditions
		mov R0, 0x00
		mov R1, 0x00
		mov R2, 0x00
		mov R3, 0x00
		mov R4, 0x00
		mov R5, 0x01
		jmp fibLoop


addCarryBit:	add R4, R11	; Hi byte += 1
		jmp fibContinue

