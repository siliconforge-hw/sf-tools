#!/usr/bin/env bash
# Crée un nouveau projet d'IP sf-tools, sans assistant : arborescence, sf-tools en sous-module épinglé,
# sf-project.env, Makefile, squelettes RTL et cocotb, CI, hook pre-commit, puis vérification.
#
# Usage : new_project.sh --name ip-<nom> --ip-id IPnnn [options]
#   --name NOM          nom du projet et du dossier (ip-<nom> pour une IP)              (requis)
#   --ip-id ID          identifiant IPnnn                                                (requis)
#   --prefix P          préfixe des modules, HDL-2.1           (défaut : <nom> sans « ip- », - → _)
#   --top T             module top                                         (défaut : <prefix>_top)
#   --profile P         ip | board | hls                                                (défaut : ip)
#   --asic PDK          sky130 | gf180 | both | none                (défaut : sky130 ; none si board)
#   --no-fpga           sans cible FPGA (Arty Z7-20)
#   --lang L            sv (profil SV-synth, norme SF-HDL-001) | v (Verilog-2005, sans norme)  (défaut : sv)
#   --regs              ajoute une carte de registres SystemRDL (regs/<prefix>.rdl) et la génère
#   --dir D             dossier parent                                                   (défaut : .)
#   --sf-url URL        dépôt sf-tools du sous-module   (défaut : git@github.com:siliconforge-hw/sf-tools.git)
#   --sf-ref REF        tag/branche de sf-tools à épingler       (défaut : dernier tag de ce sf-tools)
#   --no-relative-url   garder --sf-url tel quel dans .gitmodules (défaut : ../sf-tools, même organisation)
#   --no-check          ne pas lancer make lint / sim-all à la fin
#   --commit            faire le commit initial « chore: init project from template (profil <p>) »
# Le profil soc (CPU, logiciel, sim système) n'est pas couvert. Aucun fichier propre à un assistant n'est créé.
set -euo pipefail

SELF_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME=""; IP_ID=""; PREFIX=""; TOP=""; PROFILE=ip; ASIC=""; FPGA=1; LANG_RTL=sv; REGS=0
PARENT="."; SF_URL="git@github.com:siliconforge-hw/sf-tools.git"; SF_REF=""; RELATIVE=1; CHECK=1; COMMIT=0

die() { echo "new_project.sh : $*" >&2; exit 1; }
while [ $# -gt 0 ]; do
	case "$1" in
		--name) NAME="$2"; shift 2 ;;
		--ip-id) IP_ID="$2"; shift 2 ;;
		--prefix) PREFIX="$2"; shift 2 ;;
		--top) TOP="$2"; shift 2 ;;
		--profile) PROFILE="$2"; shift 2 ;;
		--asic) ASIC="$2"; shift 2 ;;
		--no-fpga) FPGA=0; shift ;;
		--lang) LANG_RTL="$2"; shift 2 ;;
		--regs) REGS=1; shift ;;
		--dir) PARENT="$2"; shift 2 ;;
		--sf-url) SF_URL="$2"; shift 2 ;;
		--sf-ref) SF_REF="$2"; shift 2 ;;
		--no-relative-url) RELATIVE=0; shift ;;
		--no-check) CHECK=0; shift ;;
		--commit) COMMIT=1; shift ;;
		-h|--help) sed -n '2,24p' "$0"; exit 0 ;;
		*) die "option inconnue : $1 (--help)" ;;
	esac
done

# --- Validation ---
[ -n "$NAME" ] || die "--name requis"
[[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]] || die "--name : minuscules, chiffres, tirets ($NAME)"
[[ "$IP_ID" =~ ^IP[0-9]{3}$ ]] || die "--ip-id : forme IPnnn ($IP_ID)"
PREFIX="${PREFIX:-$(echo "${NAME#ip-}" | tr '-' '_')}"
[[ "$PREFIX" =~ ^[a-z][a-z0-9_]*$ ]] || die "--prefix : snake_case ($PREFIX)"
TOP="${TOP:-${PREFIX}_top}"
[[ "$TOP" == "$PREFIX" || "$TOP" == "${PREFIX}_"* ]] || die "--top doit commencer par le préfixe d'IP ${PREFIX}_ (HDL-2.1)"
case "$PROFILE" in ip|hls) ASIC="${ASIC:-sky130}" ;; board) ASIC="${ASIC:-none}" ;;
	soc) die "profil soc non couvert par ce script" ;; *) die "--profile : ip | board | hls" ;; esac
case "$ASIC" in sky130|gf180|both|none) ;; *) die "--asic : sky130 | gf180 | both | none" ;; esac
case "$LANG_RTL" in sv) HDL_STANDARD=SF-HDL-001 ;; v) HDL_STANDARD="" ;; *) die "--lang : sv | v" ;; esac
[ $REGS -eq 0 ] || [ "$LANG_RTL" = sv ] || die "--regs suppose --lang sv"
if [ -z "$SF_REF" ]; then
	SF_REF="$(git -C "$SELF_ROOT" describe --tags --abbrev=0 2>/dev/null)" || die "--sf-ref requis (pas de tag dans $SELF_ROOT)"
fi
DEST="$(cd "$PARENT" && pwd)/$NAME"
[ ! -e "$DEST" ] || die "$DEST existe déjà"

step() { echo "== $*"; }
fill() { # fichier : remplace les champs du projet
	sed -i -e "s/<projet>/$NAME/g" -e "s/<IPxxx>/$IP_ID/g" -e "s/<top>/$TOP/g" -e "s/<ip>/$PREFIX/g" \
		-e "s/<profil>/$PROFILE/g" "$1"
}

# --- Dépôt et sous-module sf-tools (les modèles viennent de la version épinglée) ---
step "dépôt $DEST"
mkdir -p "$DEST"; cd "$DEST"
git init -q -b main
GITC=(); [[ "$SF_URL" == /* || "$SF_URL" == ./* || "$SF_URL" == ../* || "$SF_URL" == file://* ]] && GITC=(-c protocol.file.allow=always)
step "sous-module tools/sf ← $SF_URL ($SF_REF)"
git "${GITC[@]}" submodule add -q "$SF_URL" tools/sf
git -C tools/sf checkout -q "$SF_REF"
[ $RELATIVE -eq 1 ] && git config -f .gitmodules submodule.tools/sf.url ../sf-tools
T=tools/sf/templates
[ -d "$T/project" ] || die "sf-tools $SF_REF trop ancien : templates/project absent"

# --- Arborescence ---
step "arborescence (profil $PROFILE, FPGA $([ $FPGA -eq 1 ] && echo oui || echo non), ASIC $ASIC, $LANG_RTL)"
cp -r "$T/project/docs" .
mkdir -p src sim/cocotb build .github/workflows; touch build/.gitkeep
if [ $FPGA -eq 1 ]; then mkdir -p synth/fpga; cp -r "$T/project/synth/fpga/arty_z7_20" synth/fpga/; fi
for pdk in sky130 gf180; do
	if [ "$ASIC" = "$pdk" ] || [ "$ASIC" = both ]; then
		mkdir -p "synth/asic/$pdk/runs"; touch "synth/asic/$pdk/runs/.gitkeep"
		cp "$T/project/synth/asic/$pdk/config.json" "synth/asic/$pdk/"; fill "synth/asic/$pdk/config.json"
		[ "$LANG_RTL" = v ] && sed -i -e 's|\["dir::../../../src/\*\*/\*.sv"\]|["dir::../../../src/**/*.v"]|' \
			-e '/"USE_SLANG": true,/d' "synth/asic/$pdk/config.json"
	fi
done
[ "$PROFILE" = hls ] && mkdir -p hls python && touch hls/.gitkeep python/.gitkeep

# --- Fichiers du projet ---
step "fichiers"
cp "$T/sf-project.env" sf-project.env; fill sf-project.env
sed -i "s/^HDL_STANDARD=.*/HDL_STANDARD=$HDL_STANDARD/" sf-project.env
cp "$T/Makefile.ip" Makefile
cp "$T/README.ip.md" README.md; fill README.md; sed -i "s/<résumé>/IP $PREFIX/" README.md
cp "$T/project/CHANGELOG.md" CHANGELOG.md; fill CHANGELOG.md
cp "$T/project/gitignore" .gitignore
cp "$T/editorconfig" .editorconfig
cp "$T/ci.yml" .github/workflows/ci.yml
sed "s/TOP = \"my_top\"/TOP = \"$TOP\"/" "$T/test_top.py" > "sim/cocotb/test_$TOP.py"
if [ "$LANG_RTL" = sv ]; then
	sed -e "s/<ip>_<role>/$TOP/g" -e "s/<IPxxx>/$IP_ID/g" -e "s/<ip>/$PREFIX/g" \
		-e "s/<une phrase>/Top de l'IP $PREFIX (squelette, à remplacer en phase RTL)/" -e "s/§<x>/(à écrire)/" \
		-e "s|// <description>|// largeur des données (squelette)|" -e "s|// <Interface>|// Données (squelette)|" \
		"$T/module.sv" > "src/$TOP.sv"
fi
if [ $REGS -eq 1 ]; then
	mkdir -p regs sw; cp "$T/misra_suppressions.txt" sw/misra_suppressions.txt
	cat >"regs/$PREFIX.rdl" <<EOF
// ============================================================
// Register map : $IP_ID $PREFIX — skeleton, to be written in the SPEC phase
// Single source : make regs generates src/gen/, sw/gen/, docs/gen/, ipxact/.
// Language : English (source of the C comments, SF-CS-001 SF-070).
// ============================================================

addrmap ${PREFIX}_regs {
	name = "$IP_ID $PREFIX";
	desc = "$PREFIX control and status registers.";

	default regwidth = 32;
	default accesswidth = 32;

	reg {
		name = "Control";
		field { desc = "Block enable."; sw = rw; hw = r; } EN[0:0] = 0;
	} CTRL @ 0x00;
};
EOF
fi

# --- Hook pre-commit ---
git config core.hooksPath tools/sf/hooks

# --- Génération et vérification ---
if [ $REGS -eq 1 ]; then step "génération des registres"; make -s regs >/dev/null; fi
if [ $CHECK -eq 1 ]; then
	step "vérification"
	make -s help >/dev/null
	for t in lint $([ $REGS -eq 1 ] && echo "regs-check sw-lint") sim-all; do
		printf '   make %-10s ' "$t"
		if make -s "$t" >"build/new_project_$t.log" 2>&1; then echo OK; else echo "ÉCHEC (build/new_project_$t.log)"; exit 1; fi
	done
fi

if [ $COMMIT -eq 1 ]; then
	git add -A
	git commit -q -m "chore: init project from template (profil $PROFILE)"
	step "commit initial : $(git log --oneline -1)"
fi

cat <<EOF

Projet créé : $DEST  (sf-tools $SF_REF, hook pre-commit actif)
Suite :
  cd $DEST
  $([ $COMMIT -eq 1 ] || echo 'git add -A && git commit -m "chore: init project from template (profil '"$PROFILE"')"')
  gh repo create siliconforge-hw/$NAME --private --source . --remote origin --push && git submodule sync
EOF
