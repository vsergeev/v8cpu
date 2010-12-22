start: 	mov R5, MEM
	mov R2, 0x01
	add R5, R2
	mov R0, R5
	mov MEM, R5
	mov R8, MEM
	cmp R7, R7
	je start
