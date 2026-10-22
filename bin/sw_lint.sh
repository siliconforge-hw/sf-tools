#!/usr/bin/env bash
# Conformité SF-CS-001 du logiciel d'un projet : compilation stricte SF-090, cppcheck MISRA C:2012, clang-format.
# Usage : sw_lint.sh [--targets "host arm riscv"] [--fix] [dossier...]      (défaut : sw/)
#   --targets : compilateurs à utiliser (défaut "host arm") ; un compilateur absent est signalé et ignoré
#   --fix     : applique clang-format aux fichiers écrits à la main au lieu de vérifier (jamais sur gen/)
# Variables : MISRA_SUPPR (défaut sw/misra_suppressions.txt), MISRA_RULES (textes des règles, facultatif),
#             ARM_CC, RISCV_CC, CPPCHECK, CLANG_FORMAT, SW_LINT_DIR (défaut build/sw-lint).
# Chaque header est aussi compilé seul (SF-004) : un projet qui n'a encore que sa couche générée est contrôlé.
# Code de sortie : 0 si conforme, 1 sinon.
set -uo pipefail

SF_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGETS="host arm"
FIX=0
DIRS=()
while [ $# -gt 0 ]; do
	case "$1" in
		--targets) TARGETS="$2"; shift 2 ;;
		--fix) FIX=1; shift ;;
		-h|--help) sed -n '2,9p' "$0"; exit 0 ;;
		*) DIRS+=("$1"); shift ;;
	esac
done
[ ${#DIRS[@]} -gt 0 ] || DIRS=(sw)

ARM_CC="${ARM_CC:-$(command -v arm-none-eabi-gcc || ls "$HOME"/tools/Xilinx/Vitis/*/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-gcc 2>/dev/null | tail -1)}"
RISCV_CC="${RISCV_CC:-$(command -v riscv32-unknown-elf-gcc || echo "$HOME/tools/riscv/bin/riscv32-unknown-elf-gcc")}"
CPPCHECK="${CPPCHECK:-cppcheck}"
CLANG_FORMAT="${CLANG_FORMAT:-clang-format}"
MISRA_SUPPR="${MISRA_SUPPR:-sw/misra_suppressions.txt}"
OUT="${SW_LINT_DIR:-build/sw-lint}"
SF_CFLAGS=(-std=c99 -Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion -Wshadow -Wcast-qual
	-Wstrict-prototypes -Wmissing-prototypes -Werror)

C_SRCS=(); H_SRCS=()
for d in "${DIRS[@]}"; do
	[ -d "$d" ] || continue
	while IFS= read -r f; do C_SRCS+=("$f"); done < <(find "$d" -name '*.c' -not -path '*/test/*' | sort)
	while IFS= read -r f; do H_SRCS+=("$f"); done < <(find "$d" -name '*.h' | sort)
done
[ $(( ${#C_SRCS[@]} + ${#H_SRCS[@]} )) -gt 0 ] || { echo "SW-LINT : aucun fichier C dans ${DIRS[*]}"; exit 0; }

mkdir -p "$OUT"
FAIL=0
INCS=()
for h in "${H_SRCS[@]}"; do INCS+=("-I$(dirname "$h")"); done
INCS=($(printf '%s\n' "${INCS[@]+"${INCS[@]}"}" | sort -u))

# Une unité de compilation par header : vérifie qu'il compile seul (SF-004)
TUS=()
for h in "${H_SRCS[@]}"; do
	tu="$OUT/$(echo "$h" | tr '/' '_').c"
	printf '#include "%s"\n' "$(basename "$h")" >"$tu"
	TUS+=("$tu")
done

echo "== [1/3] Compilation stricte SF-090 (${TARGETS})"
for t in $TARGETS; do
	case "$t" in
		host)  CC=gcc; FLAGS=() ;;
		arm)   CC="$ARM_CC"; FLAGS=(-mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard) ;;
		riscv) CC="$RISCV_CC"; FLAGS=(-march=rv32i -mabi=ilp32) ;;
		*) echo "   cible inconnue : $t"; FAIL=1; continue ;;
	esac
	if [ -z "$CC" ] || ! command -v "$CC" >/dev/null 2>&1; then
		echo "   $t : compilateur absent, cible ignorée"
		continue
	fi
	n=0; bad=0
	for f in "${C_SRCS[@]+"${C_SRCS[@]}"}" "${TUS[@]+"${TUS[@]}"}"; do
		n=$((n + 1))
		if ! "$CC" "${SF_CFLAGS[@]}" "${FLAGS[@]+"${FLAGS[@]}"}" "${INCS[@]}" -c "$f" -o /dev/null 2>"$OUT/cc_$t.log.tmp"; then
			bad=$((bad + 1)); cat "$OUT/cc_$t.log.tmp" | head -20
		fi
	done
	rm -f "$OUT/cc_$t.log.tmp"
	echo "   $t ($(basename "$CC")) : $((n - bad))/$n unité(s) OK"
	[ $bad -eq 0 ] || FAIL=1
done

echo "== [2/3] cppcheck MISRA C:2012"
if command -v "$CPPCHECK" >/dev/null; then
	ADDON=(--addon=misra)
	if [ -n "${MISRA_RULES:-}" ]; then
		printf '{"script":"misra.py","args":["--rule-texts=%s"]}' "$(realpath "$MISRA_RULES")" >"$OUT/misra.json"
		ADDON=(--addon="$OUT/misra.json")
	fi
	SUPPR=()
	[ -f "$MISRA_SUPPR" ] && SUPPR=(--suppressions-list="$MISRA_SUPPR")
	if "$CPPCHECK" --std=c99 --enable=warning,style,portability --inline-suppr "${ADDON[@]}" \
		"${SUPPR[@]+"${SUPPR[@]}"}" --error-exitcode=1 --quiet \
		--template='{file}:{line}: [{id}] {message}' "${INCS[@]}" \
		"${C_SRCS[@]+"${C_SRCS[@]}"}" "${TUS[@]+"${TUS[@]}"}" >"$OUT/cppcheck.log" 2>&1; then
		echo "   -> conforme (déviations : ${SUPPR[*]:-aucune})"
	else
		grep -v '^$' "$OUT/cppcheck.log" | sort -u | head -30
		echo "   -> ÉCARTS (log : $OUT/cppcheck.log)"
		FAIL=1
	fi
else
	echo "   cppcheck absent, passe ignorée"
fi

echo "== [3/3] Mise en forme clang-format"
STYLE="$SF_ROOT/style/clang-format"
[ -f .clang-format ] && STYLE=.clang-format
FMT=()
for f in "${C_SRCS[@]+"${C_SRCS[@]}"}" "${H_SRCS[@]}"; do FMT+=("$f"); done
if ! command -v "$CLANG_FORMAT" >/dev/null; then
	echo "   clang-format absent, passe ignorée"
elif [ $FIX -eq 1 ]; then
	HAND=(); for f in "${FMT[@]}"; do [[ "/$f" == */gen/* ]] || HAND+=("$f"); done
	[ ${#HAND[@]} -gt 0 ] && "$CLANG_FORMAT" --style="file:$STYLE" -i "${HAND[@]}"
	echo "   -> ${#HAND[@]} fichier(s) écrit(s) à la main reformaté(s) (gen/ exclu)"
elif "$CLANG_FORMAT" --style="file:$STYLE" --dry-run --Werror "${FMT[@]}" 2>"$OUT/format.log"; then
	echo "   -> conforme ($STYLE)"
else
	grep -E 'error:' "$OUT/format.log" | head -10
	echo "   -> mise en forme non conforme : make sw-format"
	FAIL=1
fi

echo
[ $FAIL -eq 0 ] && echo "SW-LINT : OK (SF-CS-001)" || echo "SW-LINT : ÉCHEC"
exit $FAIL
