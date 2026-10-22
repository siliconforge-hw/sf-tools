#!/usr/bin/env bash
# Lint RTL en quatre passes : Verilator -Wall, Icarus (-g2012), Yosys (synthèse générique + détection de latch),
# norme SF-HDL-001 (si le CLAUDE.md du projet la déclare, ou --style).
# Usage : lint.sh [-t top] [-D MACRO=val]... [-I dir]... [--style|--no-style] [--ip prefixe] fichier_ou_dossier...
# À lancer depuis la racine du projet.
# Code de sortie : 0 si aucune erreur, 1 sinon. Les warnings n'échouent pas le lint mais sont listés.
set -u
source "$(dirname "$0")/sf_env.sh"   # VERILATOR, IVERILOG, YOSYS (config/defaults.env, ~/.config/sf-tools/config.env)

TOP=""
DEFS=()
INCS=()
FILES=()
STYLE=auto
IP=""

while [ $# -gt 0 ]; do
	case "$1" in
		-t) TOP="$2"; shift 2 ;;
		-D) DEFS+=("$2"); shift 2 ;;
		-I) INCS+=("$2"); shift 2 ;;
		--style) STYLE=force; shift ;;
		--no-style) STYLE=off; shift ;;
		--ip) IP="$2"; shift 2 ;;
		-h|--help) sed -n '2,6p' "$0"; exit 0 ;;
		*)
			if [ -d "$1" ]; then
				while IFS= read -r f; do FILES+=("$f"); done < <(find "$1" -type f \( -name '*.v' -o -name '*.sv' \) | sort)
			else
				FILES+=("$1")
			fi
			shift ;;
	esac
done

[ ${#FILES[@]} -gt 0 ] || { echo "lint.sh : aucun fichier RTL"; exit 1; }

LOG_DIR="${LINT_LOG_DIR:-build/lint}"
mkdir -p "$LOG_DIR"
FAIL=0

V_ARGS=(); I_ARGS=(); Y_DEFS=""
for d in "${DEFS[@]+"${DEFS[@]}"}"; do V_ARGS+=("+define+$d"); I_ARGS+=("-D$d"); Y_DEFS+=" -D$d"; done
for i in "${INCS[@]+"${INCS[@]}"}"; do V_ARGS+=("-I$i"); I_ARGS+=("-I$i"); Y_DEFS+=" -I$i"; done

# Code généré (dossiers gen/, SF-HDL-001 HDL-1.6) : compilé avec le reste, mais ses warnings
# Verilator sont neutralisés (on ne corrige pas un fichier généré) et la norme ne s'y applique pas.
GEN_FILES=()
for f in "${FILES[@]}"; do [[ "/$f" == */gen/* ]] && GEN_FILES+=("$f"); done
V_GEN=()
if [ ${#GEN_FILES[@]} -gt 0 ]; then
	printf '`verilator_config\nlint_off -file "*/gen/*"\n' >"$LOG_DIR/gen_waivers.vlt"
	V_GEN=("$LOG_DIR/gen_waivers.vlt")
	echo "   (${#GEN_FILES[@]} fichier(s) généré(s) : warnings Verilator neutralisés, norme non appliquée)"
fi

echo "== [1/4] Verilator --lint-only -Wall"
if command -v "$VERILATOR" >/dev/null; then
	"$VERILATOR" --lint-only -Wall ${TOP:+--top-module "$TOP"} "${V_ARGS[@]+"${V_ARGS[@]}"}" "${V_GEN[@]+"${V_GEN[@]}"}" "${FILES[@]}" >"$LOG_DIR/verilator.log" 2>&1
	rc=$?
	grep -E '^%(Error|Warning)' "$LOG_DIR/verilator.log" | grep -v 'Exiting due to' | head -40
	nerr=$(grep '^%Error' "$LOG_DIR/verilator.log" | grep -vc 'Exiting due to')
	nwarn=$(grep -c '^%Warning' "$LOG_DIR/verilator.log")
	echo "   -> $nerr erreur(s), $nwarn warning(s)  (log : $LOG_DIR/verilator.log)"
	# -Wall rend les warnings fatals : on n'échoue que sur les vraies erreurs
	[ "$nerr" -gt 0 ] && FAIL=1
	# warnings bloquants : latch, boucle combinatoire, multi-driver
	if grep -qE '^%Warning-(LATCH|UNOPTFLAT|MULTIDRIVEN)' "$LOG_DIR/verilator.log"; then
		echo "   -> warning bloquant (LATCH/UNOPTFLAT/MULTIDRIVEN)"
		FAIL=1
	fi
	[ $rc -ne 0 ] && [ "$nerr" -eq 0 ] && [ "$nwarn" -eq 0 ] && FAIL=1
else
	echo "   verilator absent, passe ignorée"
fi

echo "== [2/4] Icarus iverilog -g2012"
if command -v "$IVERILOG" >/dev/null; then
	if "$IVERILOG" -g2012 -Wall ${TOP:+-s "$TOP"} "${I_ARGS[@]+"${I_ARGS[@]}"}" -o /dev/null "${FILES[@]}" >"$LOG_DIR/iverilog.log" 2>&1; then
		echo "   -> OK"
	elif [ ${#GEN_FILES[@]} -gt 0 ] && ! grep -E '^[^:]+:[0-9]+:' "$LOG_DIR/iverilog.log" | grep -qv '/gen/'; then
		# tous les messages viennent du code généré (PeakRDL : struct non packés, variables automatic)
		n=$(grep -cE '^[^:]+:[0-9]+:' "$LOG_DIR/iverilog.log")
		echo "   -> non applicable : $n message(s), tous dans le code généré, non supporté par Icarus (log : $LOG_DIR/iverilog.log)"
	else
		head -20 "$LOG_DIR/iverilog.log"
		echo "   -> ÉCHEC (log : $LOG_DIR/iverilog.log)"
		FAIL=1
	fi
	grep -i 'warning' "$LOG_DIR/iverilog.log" | head -10
else
	echo "   iverilog absent, passe ignorée"
fi

# Yosys récent + frontend slang (OSS CAD Suite) si disponible, sinon Yosys apt avec read_verilog -sv
# YOSYS de la configuration s'il existe, sinon celui du PATH ; slang utilisé s'il se charge
command -v "$YOSYS" >/dev/null 2>&1 || YOSYS="$(command -v yosys || true)"
SLANG=0
[ -n "$YOSYS" ] && "$YOSYS" -m slang -p "help read_slang" >/dev/null 2>&1 && SLANG=1
echo "== [3/4] Yosys synth générique ($("$YOSYS" -V 2>/dev/null | awk '{print $2}')$([ $SLANG -eq 1 ] && echo " + slang"))"
if [ -n "$YOSYS" ]; then
	if [ $SLANG -eq 1 ]; then
		Y_ARGS=(-m slang)
		READ="read_slang$Y_DEFS ${TOP:+--top $TOP} ${FILES[*]}"
	else
		Y_ARGS=()
		READ="read_verilog -sv$Y_DEFS ${FILES[*]}"
	fi
	SYN="synth ${TOP:+-top $TOP}"
	[ -z "$TOP" ] && SYN="synth -auto-top"
	if "$YOSYS" "${Y_ARGS[@]+"${Y_ARGS[@]}"}" -p "$READ; $SYN; check; stat" >"$LOG_DIR/yosys.log" 2>&1; then
		# read_verilog signale « Latch inferred » ; read_slang produit une boucle combinatoire
		latches=$(grep -cE 'Latch inferred|found logic loop' "$LOG_DIR/yosys.log")
		# signal piloté par plusieurs processus (ex. fonction statique appelée de deux blocs, SF-HDL-001 HDL-7.1)
		drivers=$(grep -c 'multiple conflicting drivers' "$LOG_DIR/yosys.log")
		cells=$(grep -m1 -E 'Number of cells|^ +[0-9]+ cells$' "$LOG_DIR/yosys.log" | grep -oE '[0-9]+' | tail -1)
		echo "   -> OK, ${cells:-?} cellules, $latches latch(s)/boucle(s) combinatoire(s)  (log : $LOG_DIR/yosys.log)"
		if [ "$latches" -gt 0 ]; then
			grep -E -A3 'Latch inferred|found logic loop' "$LOG_DIR/yosys.log" | head -12
			FAIL=1
		fi
		if [ "$drivers" -gt 0 ]; then
			echo "   -> pilotes multiples sur $drivers bit(s) (fonction non automatic ? signal affecté dans deux blocs ?)"
			grep -A1 'multiple conflicting drivers' "$LOG_DIR/yosys.log" | head -8
			FAIL=1
		fi
		grep -E '^Warning' "$LOG_DIR/yosys.log" | grep -v 'multiple conflicting drivers' | sort -u | head -10
	else
		grep -E 'ERROR' "$LOG_DIR/yosys.log" | head -10
		echo "   -> ÉCHEC (log : $LOG_DIR/yosys.log)"
		grep -q 'Latch inferred' "$LOG_DIR/yosys.log" \
			|| echo "   (si Verilator passe : construction SV hors du profil SV-synth, ou Yosys apt 0.33 utilisé à la place de slang)"
		FAIL=1
	fi
else
	echo "   yosys absent, passe ignorée"
fi

echo "== [4/4] Norme SF-HDL-001"
SV_FILES=()
for f in "${FILES[@]}"; do [[ "$f" == *.sv ]] && SV_FILES+=("$f"); done
if [ "$STYLE" = off ]; then
	echo "   passe désactivée (--no-style)"
elif [ ${#SV_FILES[@]} -eq 0 ]; then
	echo "   aucun fichier .sv, passe ignorée"
else
	S_ARGS=(--project .)
	[ "$STYLE" = force ] && S_ARGS+=(--force)
	[ -n "$IP" ] && S_ARGS+=(--ip "$IP")
	python3 "$(dirname "$0")/check_style.py" "${S_ARGS[@]}" "${SV_FILES[@]}" >"$LOG_DIR/style.log" 2>&1 || FAIL=1
	grep '^%Style' "$LOG_DIR/style.log" | head -40
	grep -v '^%Style' "$LOG_DIR/style.log"
	n=$(grep -c '^%Style' "$LOG_DIR/style.log")
	[ "$n" -gt 40 ] && echo "   ($n écarts, liste complète : $LOG_DIR/style.log)"
fi

echo
[ $FAIL -eq 0 ] && echo "LINT : OK" || echo "LINT : ÉCHEC"
exit $FAIL
