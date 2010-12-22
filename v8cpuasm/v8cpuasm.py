# v8cpuasm - Two-pass assembler for v8cpu
# Vanya A. Sergeev - vsergeev@gmail.com
# Generates a memory file that can be loaded by Verilog simulator's $readmemh()

import sys

#####################################################################

# Valid operand checkers

def isOperandRegister(operand):
	# Must be at least "r" and maximum 3 digits
	if (len(operand) < 2 or len(operand) > 3):
		return False
	if (operand[0] != 'r' and operand[0] != 'R'):
		return False
	# Attempt to convert it
	try:
		value = int(operand[1:], 10)
	except ValueError:
		return False
	# Check that it's in range
	if (value < 0 or value > 15):
		return False

	return True

def isOperandData(operand):
	# Must be at least "0x" and must be 8-bits max
	if (len(operand) < 3 or len(operand) > 4):
		return False
	if (operand[0:2] != "0x"):
		return False
	# Attempt to convert it
	try:
		value = int(operand[2:], 16)
	except ValueError:
		return False

	return True

def isOperandLabel(operand):
	if (operand in addressLabelDict):
		return True
	return False

def isOperandMEM(operand):
	if (operand == "MEM"):
		return True
	return False

#####################################################################

# Operand data extractors

def operandRegister(operand):
	return int(operand[1:], 10)

def operandData(operand):
	return int(operand[2:], 16)

def operandLabel(operand):
	return addressLabelDict[operand]

#####################################################################

# Quick clean-up exit
def exit(retVal):
	fileASM.close()
	fileOut.close()
	sys.exit(retVal)

#####################################################################

if (len(sys.argv) < 3):
	print("Usage: %s <input assembly> <output memory dat>" % sys.argv[0])
	sys.exit(0)

fileASM = open(sys.argv[1], 'r')
fileOut = open(sys.argv[2], 'w')

# Instruction and max number of operands
validInstructions = {"mov":2, "jmp":1, "je":1, "jne":1, "jg":1, "jl":1, "ljmp":0, "add":2, "sub":2, "and":2, "or":2, "xor":2, "not":2, "cmp":2, "nop":0}
IP = 0
addressLabelDict = {}

# First pass finds all of the address labels and validates the instruction mnemonics
for line in fileASM:
	line = line.rstrip("\r\n")
	lineClean = line.replace(',', ' ')
	lineTokens = lineClean.split()
	
	if (len(lineTokens) == 0):
		continue

	# Skip if this line is a comment
	if (lineTokens[0][0] == ';'):
		continue

	# If this is an address label
	if (lineTokens[0][-1] == ':'):
		addressLabelDict[lineTokens[0][:-1]] = IP
		# If this line only contains an address label
		if (len(lineTokens) == 1):
			# Don't increment the IP until we've actually seen an instruction
			continue
		# Make sure that if the next token is not a comment, that it is is a valid instruction mnemonic
		if (lineTokens[1][0] != ';' and (not lineTokens[1] in validInstructions)):
			print("Error: Unknown instruction!")
			print("Line: %s" % line)
			exit(-1)
	# Check if this is a valid instruction
	elif (not lineTokens[0] in validInstructions):
		print("Error: Unknown instruction!")
		print("Line: %s" % line)
		exit(-1)

	IP += 2


# Reset our IP
IP = 0

# Rewind the file
fileASM.seek(0)

# Second pass assembles the instructions
for line in fileASM:
	line = line.rstrip("\r\n")
	lineClean = line.replace(',', ' ')
	lineTokens = lineClean.split()
	
	if (len(lineTokens) == 0):
		continue

	# Skip if this line is a comment
	if (lineTokens[0][0] == ';'):
		continue
	
	# Strip out the address label from the tokens and isolate the mnemonic
	if (lineTokens[0][-1] == ':'):
		# If this line only contains an address label
		if (len(lineTokens) == 1):
			continue
		lineTokens.pop(0)
		asmMnemonic = lineTokens.pop(0)
	else:
		asmMnemonic = lineTokens.pop(0)
	
	# Operands are the rest of the tokens
	asmOperands = lineTokens

	# Strip out any comment at the end of the tokens
	for i in range(len(asmOperands)):
		if (asmOperands[i][0] == ';'):
			asmOperands = asmOperands[:i]
			break

	# Check number of operands
	if (len(asmOperands) < validInstructions[asmMnemonic]):
		print("Error: Invalid number of operands!")
		print("Line: %s" % line)
		exit(-1)
	
	if (asmMnemonic == "mov"):
		# mov Ra, Rb
		if (isOperandRegister(asmOperands[0]) and isOperandRegister(asmOperands[1])):
			fileOut.write("%01X%01X " % (operandRegister(asmOperands[0]), operandRegister(asmOperands[1])))
			fileOut.write("10")
		# mov Ra, MEM
		elif (isOperandRegister(asmOperands[0]) and isOperandMEM(asmOperands[1])):
			fileOut.write("%01X0 " % operandRegister(asmOperands[0]))
			fileOut.write("11")
		# mov MEM, Ra
		elif (isOperandMEM(asmOperands[0]) and isOperandRegister(asmOperands[1])):
			fileOut.write("%01X0 " % operandRegister(asmOperands[1]))
			fileOut.write("12")
		# mov Ra, d
		elif (isOperandRegister(asmOperands[0]) and isOperandData(asmOperands[1])):
			fileOut.write("%02X " % operandData(asmOperands[1]))
			fileOut.write("2%01X" % operandRegister(asmOperands[0]))
		# Unknown operands
		else:
			print("Error: Invalid operands!")
			print("Line: %s" % line)
			exit(-1)

	elif (asmMnemonic == "jmp" or asmMnemonic == "je" or asmMnemonic == "jne" or asmMnemonic == "jg" or asmMnemonic == "jl"):
		# jmp k
		if (isOperandLabel(asmOperands[0])):
			targetIP = operandLabel(asmOperands[0])
			# If the target is behind this instruction (negative relative distance)
			if (targetIP < IP):
				relativeDistance = (IP - targetIP) >> 1
				if (relativeDistance > 127):
					print("Error: Relative branch too far!")
					print("Line: %s" % line)
					exit(-1)
				# Encode the distance with two's complement
				relativeDistance = ~relativeDistance + 1
				relativeDistance = relativeDistance & 0xFF
				fileOut.write("%02X " % relativeDistance)

			# If the target is ahead of this instruction (positive relative distance)
			else:
				relativeDistance = (targetIP - IP) >> 1
				if (relativeDistance > 127):
					print("Error: Relative branch too far!")
					print("Line: %s" % line)
					exit(-1)
				relativeDistance = relativeDistance & 0xFF
				fileOut.write("%02X " % relativeDistance)
				# Unknown operands

			# Encode the appropriate branch mnemonic
			if (asmMnemonic == "jmp"):
				fileOut.write("30")
			elif (asmMnemonic == "je"):
				fileOut.write("31")
			elif (asmMnemonic == "jne"):
				fileOut.write("32")
			elif (asmMnemonic == "jg"):
				fileOut.write("33")
			elif (asmMnemonic == "jl"):
				fileOut.write("34")
		else:
			print("Error: Invalid label!")
			print("Line: %s" % line)
			exit(-1)

	elif (asmMnemonic == "ljmp"):
		fileOut.write("00 40")	

	elif (asmMnemonic == "add" or asmMnemonic == "sub" or asmMnemonic == "and" or asmMnemonic == "or" or asmMnemonic == "xor" or asmMnemonic == "cmp"):
		# <math instruction> Ra, Rb
		if (isOperandRegister(asmOperands[0]) and isOperandRegister(asmOperands[1])):
			fileOut.write("%01X%01X " % (operandRegister(asmOperands[0]), operandRegister(asmOperands[1])))
			# Encode the appropriate math mnemonic
			if (asmMnemonic == "add"):
				fileOut.write("50")
			elif (asmMnemonic == "sub"):
				fileOut.write("51")
			elif (asmMnemonic == "and"):
				fileOut.write("52")
			elif (asmMnemonic == "or"):
				fileOut.write("53")
			elif (asmMnemonic == "xor"):
				fileOut.write("54")
			elif (asmMnemonic == "cmp"):
				fileOut.write("56")
		# Unknown operands
		else:
			print("Error: Invalid operands!")
			print("Line: %s" % line)
			exit(-1)

	elif (asmMnemonic == "not"):
		# not Ra
		if (isOperandRegister(asmOperands[0])):
			fileOut.write("%01X0 " % operandRegister(asmOperands[0]))
			fileOut.write("55")
		# Unknown operands
		else:
			print("Error: Invalid operands!")
			print("Line: %s" % line)
			exit(-1)

	elif (asmMnemonic == "nop"):
		fileOut.write("00 00")

	else:
		print("Error: Unknown instruction!")
		print("Line: %s" % line)
		exit(-1)
	
	fileOut.write("\n")	
	IP += 2

fileASM.close()
fileOut.close()

