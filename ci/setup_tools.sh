#!/usr/bin/env bash
# Installe la chaîne d'outils sf-tools dans ${TOOLS_ROOT:-$HOME/tools}, avec la même disposition que
# config/defaults.env : oss-cad-suite/, venvs/cocotb/, venvs/peakrdl/. Utilisé par la CI (runner Ubuntu
# 24.04) ; utilisable sur un nouveau poste Ubuntu. Idempotent : ce qui est déjà installé est conservé
# (cache de la CI).
# Variables : TOOLS_ROOT (défaut $HOME/tools), SF_SKIP_APT=1 (ne pas appeler apt), SF_CI_CONFIG=0 (ne pas
# écrire ~/.config/sf-tools/config.env).
# Hors périmètre : Vivado/Vitis (licence, taille), LibreLane/Nix, toolchain RISC-V.
set -euo pipefail

SF_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$SF_ROOT/ci/versions.env"
TOOLS_ROOT="${TOOLS_ROOT:-$HOME/tools}"
mkdir -p "$TOOLS_ROOT/venvs"
step() { echo "== $*"; }

# --- Paquets système : analyse statique et compilation C (versions d'Ubuntu 24.04) ---
if [ -z "${SF_SKIP_APT:-}" ]; then
	step "apt : cppcheck clang-format gcc-arm-none-eabi libnewlib-arm-none-eabi"
	SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
	$SUDO apt-get update -qq
	$SUDO apt-get install -y -qq --no-install-recommends cppcheck clang-format \
		gcc-arm-none-eabi libnewlib-arm-none-eabi >/dev/null
fi

# --- OSS CAD Suite : Yosys + slang, Verilator (>= 5.036 pour cocotb 2), Icarus ---
OSS="$TOOLS_ROOT/oss-cad-suite"
if [ -x "$OSS/bin/yosys" ] && [ "$(cat "$OSS/VERSION" 2>/dev/null)" = "${OSS_CAD_VERSION//-/}" ]; then
	step "OSS CAD Suite $OSS_CAD_VERSION : déjà installée"
else
	step "OSS CAD Suite $OSS_CAD_VERSION : téléchargement"
	TMP="$(mktemp -d)"
	curl -fsSL -o "$TMP/oss.tgz" \
		"https://github.com/YosysHQ/oss-cad-suite-build/releases/download/$OSS_CAD_VERSION/oss-cad-suite-linux-x64-${OSS_CAD_VERSION//-/}.tgz"
	rm -rf "${OSS:?}"
	tar xzf "$TMP/oss.tgz" -C "$TOOLS_ROOT"
	rm -rf "${TMP:?}"
fi

# --- Environnements Python épinglés (sortie de génération déterministe : make regs-check) ---
for venv in cocotb peakrdl; do
	V="$TOOLS_ROOT/venvs/$venv"
	REQ="$SF_ROOT/ci/requirements-$venv.txt"
	if [ -x "$V/bin/python" ] && cmp -s "$REQ" "$V/.sf-requirements.txt"; then
		step "venv $venv : déjà installé"
		continue
	fi
	step "venv $venv : installation ($(grep -c . "$REQ") paquets épinglés)"
	python3 -m venv "$V"
	"$V/bin/pip" install -q --upgrade pip
	"$V/bin/pip" install -q -r "$REQ"
	cp "$REQ" "$V/.sf-requirements.txt"
done

# --- Configuration sf-tools : seuls les chemins qui diffèrent des défauts ---
if [ "${SF_CI_CONFIG:-1}" = "1" ]; then
	CFG="${XDG_CONFIG_HOME:-$HOME/.config}/sf-tools/config.env"
	mkdir -p "$(dirname "$CFG")"
	cat >"$CFG" <<EOT
# écrit par sf-tools/ci/setup_tools.sh
TOOLS_ROOT=$TOOLS_ROOT
ARM_CC=arm-none-eabi-gcc
EOT
	step "configuration : $CFG"
fi

# --- PATH : cocotb trouve verilator / iverilog dans le PATH ---
if [ -n "${GITHUB_PATH:-}" ]; then
	echo "$OSS/bin" >>"$GITHUB_PATH"
	step "PATH (GitHub Actions) : + $OSS/bin"
else
	step "à ajouter au PATH pour cocotb : $OSS/bin"
fi
