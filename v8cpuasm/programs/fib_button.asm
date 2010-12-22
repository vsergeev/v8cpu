; 16-bit Fibonacci Number Generator for v8cpu
; Vanya A. Sergeev - vsergeev@gmail.com
; Next 16-bit Fibonacci Number is computed and written across port A (high byte) and port B (low byte) each time
; a button pulls pin C.0 high.
;
; R0:R1 = Fn-2
; R2:R3 = Fn-1
; R4:R5 = Fn
; R0:R1, R2:R3 initialize to 0

; Initialize R4:R5 to 0x0001
mov R4, 0x00
mov R5, 0x01

; Save a constant 0 and constant 1
mov R10, 0x00
mov R11, 0x01

; Save constant for 46368 (biggest 16-bit fibonacci number)
mov R8, 0xB5
mov R9, 0x20

; Address for portA (0x800) in R14:R15
mov R14, 0x08
mov R15, 0x00

; Wait for the button to be depressed
buttonClrWait:	mov R15, 0x02	; R14:R15 = 0x0802 = pin C address
		mov R12, MEM
		and R12, R11	; R12 & 0x1, to keep just bit 0, the button
		cmp R12, R11
		je buttonClrWait	; If button == 1, loop buttonClrWait

buttonDbWait:	mov R15, 0x02	; R14:R15 = 0x0802 = pin C address
		mov R12, MEM
		and R12, R11	; R12 & 0x1, to keep just bit 0, the button
		cmp R12, R10
		je buttonDbWait	; If button == 0, loop buttonDbWait

		; Button was been pressed, delay and check again for debouncing
		; Outer loop is 100 loops, inner loop should take 6 CPI * 3 * 255 = 4590 clock cycles
		; With a 50MHz clock this yields roughly 10ms delay

		mov R12, 0x64

outerDelayLoop:	mov R13, 0xFF
innerDelayLoop:	sub R13, R11	; R13 = R13 - 1
		cmp R13, R10
		jne innerDelayLoop	; If R13 != 0, loop innerDelayLoop
		sub R12, R11	; R12 = R12 - 1
		cmp R12, R10
		jne outerDelayLoop	; If R12 != 0, loop outerDelayLoop


		; Check that the button is still pressed

		mov R12, MEM
		and R12, R11	; R12 & 0x1, to keep just bit 0, the button
		cmp R12, R10
		je buttonDbWait	; If button == 0, loop buttonDbWait

		; Otherwise continue to computing the next fibonacci number

		mov R0, R2	; Fn-2 (hi byte) <= Fn-1 (hi byte)
		mov R1, R3	; Fn-2 (lo byte) <= Fn-1 (lo byte)

		mov R2, R4	; Fn-1 (hi byte) <= Fn (hi byte)
		mov R3, R5	; Fn-1 (lo byte) <= Fn (lo byte)

		; R4:R5 contains Fn-1, R0:R1 contains Fn-2

		add R5, R1	; Fn-1 + Fn-2 (lo bytes)
		cmp R5, R3	; Compare the new R5 to the old R5 (R3)
		je fibContinue	; No carry if they're equal
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
		jne buttonClrWait
		cmp R5, R9
		jne buttonClrWait

		; Reset to initial conditions
		mov R0, 0x00
		mov R1, 0x00
		mov R2, 0x00
		mov R3, 0x00
		mov R4, 0x00
		mov R5, 0x01
		jmp buttonClrWait


addCarryBit:	add R4, R11	; Hi byte += 1
		jmp fibContinue

