# gencoe - Generates a Xilinx ISE WebPACK compatible .coe memory initialization file from
# a Verilog memory dat file created by v8cpuasm.

import sys

if (len(sys.argv) < 3):
	print("Usage: %s <memory dat file> <coe file>" % sys.argv[0])
	sys.exit(0)

datFile = open(sys.argv[1], 'r')
coeFile = open(sys.argv[2], 'w')

coeFile.write("memory_initialization_radix=16;\n")
coeFile.write("memory_initialization_vector=\n")

firstTokenWritten = False
for line in datFile:
	if (firstTokenWritten):
		coeFile.write(",\n");
	line = line.rstrip("\r\n")
	lineTokens = line.split(' ')
	for i in range(len(lineTokens)):
		coeFile.write("%s" % lineTokens[i])
		if (i < len(lineTokens)-1):
			coeFile.write(",\n")
		firstTokenWritten = True

coeFile.write(";\n")

datFile.close()
coeFile.close()
