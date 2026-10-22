#!/usr/bin/env bash
# Affiche la version de chaque outil EDA attendu, ou ABSENT.
T="$HOME/tools"

check() { # nom commande...
	local name="$1"; shift
	local out
	if out=$("$@" 2>&1 | head -1) && [ -n "$out" ]; then
		printf "  %-16s %s\n" "$name" "$out"
	else
		printf "  %-16s ABSENT\n" "$name"
	fi
}

echo "Simulation / lint"
check iverilog   sh -c 'iverilog -V 2>&1 | head -1'
check verilator  verilator --version
check gtkwave    sh -c 'command -v gtkwave'
check vsim       sh -c 'command -v vsim'
echo "Synthèse"
check yosys      yosys -V
check yosys-oss  "$T/oss-cad-suite/bin/yosys" -V
check slang      sh -c "$T/oss-cad-suite/bin/yosys -m slang -p 'help read_slang' >/dev/null 2>&1 && echo 'plugin OK' || false"
check oss-cad    cat "$T/oss-cad-suite/VERSION"
check vivado    sh -c "ls -d $T/Xilinx/Vivado/*/ 2>/dev/null | xargs -n1 basename | tr '\n' ' '"
echo "ASIC"
check nix        nix --version
check librelane  sh -c "cd $T/librelane 2>/dev/null && git describe --tags"
check pdk        sh -c "ls $HOME/workspace/asic/pdk 2>/dev/null | tr '\n' ' '"
echo "Toolchains"
check riscv32    "$T/riscv/bin/riscv32-unknown-elf-gcc" --version
check arm-gcc    sh -c "ls $T/Xilinx/Vitis/*/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-gcc 2>/dev/null"
echo "Python"
check cocotb     "$T/venvs/cocotb/bin/cocotb-config" --version
check pyuvm      "$T/venvs/cocotb/bin/python" -c 'import importlib.metadata as m; print(m.version("pyuvm"))'
check cocotbext  "$T/venvs/cocotb/bin/python" -c 'import importlib.metadata as m; print(m.version("cocotbext-axi"))'
check peakrdl    "$T/venvs/peakrdl/bin/peakrdl" --version
