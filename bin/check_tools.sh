#!/usr/bin/env bash
# Affiche la version de chaque outil EDA attendu, ou ABSENT. Chemins : bin/sf_config.sh.
source "$(dirname "$0")/sf_env.sh"

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
check iverilog   sh -c "$IVERILOG -V 2>&1 | head -1"
check verilator  "$VERILATOR" --version
check gtkwave    sh -c "command -v $GTKWAVE"
check vsim       sh -c 'command -v vsim'
echo "Synthèse"
check yosys      "$YOSYS" -V
check slang      sh -c "$YOSYS -m slang -p 'help read_slang' >/dev/null 2>&1 && echo 'plugin OK' || false"
check oss-cad    cat "$OSS_CAD/VERSION"
check vivado     sh -c "test -f '$VITIS_SETTINGS' && echo '$VITIS_SETTINGS'"
echo "ASIC"
check nix        nix --version
check librelane  sh -c "cd '$LIBRELANE' 2>/dev/null && git describe --tags"
check pdk        sh -c "ls '$PDK_ROOT' 2>/dev/null | tr '\n' ' '"
echo "Logiciel"
check arm-gcc    "$ARM_CC" --version
check riscv32    "$RISCV_CC" --version
check cppcheck   "$CPPCHECK" --version
check clang-fmt  "$CLANG_FORMAT" --version
echo "Python"
check cocotb     "$COCOTB_VENV/bin/cocotb-config" --version
check pyuvm      "$COCOTB_VENV/bin/python" -c 'import importlib.metadata as m; print(m.version("pyuvm"))'
check cocotbext  "$COCOTB_VENV/bin/python" -c 'import importlib.metadata as m; print(m.version("cocotbext-axi"))'
check peakrdl    "$PEAKRDL" --version
echo
echo "Configuration : $(dirname "$0")/sf_config.sh (fichier utilisateur : $SF_USER_CONFIG)"
