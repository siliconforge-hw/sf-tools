#!/usr/bin/env bash
# Génère, depuis une carte SystemRDL, le banc de registres SV, la couche C SF-CS-001, la doc Markdown et l'IP-XACT.
# Usage : gen_regs.sh [--check] [--cpuif axi4-lite-flat] [--version 1.0] regs/<ip>.rdl
#   --check : régénère dans un dossier temporaire et compare aux fichiers du projet (rien n'est écrit)
# À lancer depuis la racine du projet. Le nom de l'addrmap racine doit être <ip>_regs (HDL-2.3).
# Sorties (SF-HDL-001 HDL-1.6, jamais éditées à la main) :
#   src/gen/<ip>_regs.sv, src/gen/<ip>_regs_pkg.sv   PeakRDL regblock
#   sw/gen/<ip>_regs_hw.h                            regmap/gen_c_hw.py + clang-format (style/clang-format, SF-CS-001)
#   docs/gen/<ip>_regs.md                            PeakRDL markdown
#   ipxact/<ip>_regs.xml                             PeakRDL ip-xact
set -euo pipefail

SF_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$SF_ROOT/bin/sf_env.sh"   # PEAKRDL, CLANG_FORMAT
PYTHON="$(dirname "$PEAKRDL")/python"
CHECK=0
CPUIF="axi4-lite-flat"
VERSION="1.0"
RDL=""

while [ $# -gt 0 ]; do
	case "$1" in
		--check) CHECK=1; shift ;;
		--cpuif) CPUIF="$2"; shift 2 ;;
		--version) VERSION="$2"; shift 2 ;;
		-h|--help) sed -n '2,11p' "$0"; exit 0 ;;
		*) RDL="$1"; shift ;;
	esac
done

[ -n "$RDL" ] && [ -f "$RDL" ] || { echo "gen_regs.sh : fichier .rdl attendu"; exit 1; }
[ -x "$PEAKRDL" ] || { echo "gen_regs.sh : PeakRDL introuvable ($PEAKRDL) : renseigner PEAKRDL (bin/sf_config.sh)"; exit 1; }
command -v "$CLANG_FORMAT" >/dev/null || { echo "gen_regs.sh : $CLANG_FORMAT introuvable (requis pour une sortie C déterministe)"; exit 1; }

NAME=$(basename "$RDL" .rdl)_regs
INC="$SF_ROOT/regmap"     # sf_common.rdl (SF-REG-001)
# REG-5 : IP_NUM de la carte vérifié contre IP_ID de sf-project.env
[ -f sf-project.env ] && SF_IP_ID="$(sed -n 's/^IP_ID=\([^ #]*\).*/\1/p' sf-project.env)" && export SF_IP_ID
OUT="."
if [ $CHECK -eq 1 ]; then
	OUT=$(mktemp -d)
	trap 'rm -rf "$OUT"' EXIT
fi
mkdir -p "$OUT/src/gen" "$OUT/sw/gen" "$OUT/docs/gen" "$OUT/ipxact"

"$PEAKRDL" regblock "$RDL" -I "$INC" -o "$OUT/src/gen/" --cpuif "$CPUIF" --default-reset rst_n \
	--module-name "$NAME" --package-name "${NAME}_pkg"
"$PYTHON" -I "$SF_ROOT/regmap/gen_c_hw.py" -I "$INC" "$RDL" >"$OUT/sw/gen/${NAME}_hw.h.raw"
"$CLANG_FORMAT" --style="file:$SF_ROOT/style/clang-format" --assume-filename="$NAME"_hw.h \
	<"$OUT/sw/gen/${NAME}_hw.h.raw" >"$OUT/sw/gen/${NAME}_hw.h"
rm -f "$OUT/sw/gen/${NAME}_hw.h.raw"
"$PEAKRDL" markdown "$RDL" -I "$INC" -o "$OUT/docs/gen/$NAME.md"
"$PEAKRDL" ip-xact "$RDL" -I "$INC" -o "$OUT/ipxact/$NAME.xml" --vendor siliconforge --library ip --version "$VERSION"

FILES=(src/gen/$NAME.sv src/gen/${NAME}_pkg.sv sw/gen/${NAME}_hw.h docs/gen/$NAME.md ipxact/$NAME.xml)
if [ $CHECK -eq 1 ]; then
	STALE=0
	for f in "${FILES[@]}"; do
		if ! cmp -s "$OUT/$f" "$f"; then
			echo "   périmé : $f"
			STALE=1
		fi
	done
	if [ $STALE -eq 1 ]; then
		echo "REGS : fichiers générés périmés par rapport à $RDL — lancer make regs"
		exit 1
	fi
	echo "REGS : à jour ($RDL)"
else
	printf '   %s\n' "${FILES[@]}"
	echo "REGS : générés depuis $RDL (cpuif $CPUIF, IP-XACT siliconforge:ip:$NAME:$VERSION)"
fi
