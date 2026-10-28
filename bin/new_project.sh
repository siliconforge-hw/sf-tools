#!/usr/bin/env bash
# Crée un nouveau projet sf-tools, sans assistant : arborescence, sf-tools en sous-module épinglé,
# sf-project.env, Makefile, squelettes RTL et cocotb, CI, hook pre-commit, puis vérification.
# La catégorie du projet se déduit de la famille de son identifiant (config/categories.conf).
#
# Usage : new_project.sh --name <nom> --id <FAMnnn> [options]
#   --name NOM          nom du projet et du dossier (ip-<nom> pour une IP)              (requis)
#   --id ID             identifiant FAMnnn, FAM dans config/categories.conf (IP, SYS, DEM, EXP)  (requis)
#                       (--ip-id : ancien nom de cette option, toujours accepté)
#   --prefix P          préfixe des modules, HDL-2.1   (défaut : <nom> sans « ip- »/« exp- »…, - → _)
#   --top T             module top                                         (défaut : <prefix>_top)
#   --profile P         ip | board | hls                         (défaut : celui de la catégorie)
#   --asic PDK          sky130 | gf180 | both | none                (défaut : sky130 ; none si board)
#   --no-fpga           sans cible FPGA (Arty Z7-20)
#   --lang L            sv (profil SV-synth, norme SF-HDL-001) | v (Verilog-2005, sans norme)  (défaut : sv)
#   --regs              ajoute une carte de registres SystemRDL (regs/<prefix>.rdl) et la génère
#   --dir D             dossier parent                                                   (défaut : .)
#   --into DIR          initialiser un dossier EXISTANT (spec déjà écrite…) : aucun fichier existant n'est
#                       écrasé (créés / conservés listés à la fin), .gitignore complété, --name = nom du dossier,
#                       --commit ne commite que les fichiers créés
#   --sf-url URL        dépôt sf-tools du sous-module   (défaut : git@github.com:siliconforge-hw/sf-tools.git)
#   --sf-ref REF        tag/branche de sf-tools à épingler       (défaut : dernier tag de ce sf-tools)
#   --no-relative-url   garder --sf-url tel quel dans .gitmodules (défaut : ../sf-tools, même organisation)
#   --no-check          ne pas lancer make lint / sim-all à la fin
#   --commit            faire le commit initial « chore: init project from template (profil <p>) »
# Le profil soc (CPU, logiciel, sim système) n'est pas couvert. Aucun fichier propre à un assistant n'est créé.
set -euo pipefail

SELF_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME=""; ID=""; PREFIX=""; TOP=""; PROFILE=""; ASIC=""; FPGA=1; LANG_RTL=sv; REGS=0
INTO=""; PARENT="."; SF_URL="git@github.com:siliconforge-hw/sf-tools.git"; SF_REF=""; RELATIVE=1; CHECK=1; COMMIT=0

die() { echo "new_project.sh : $*" >&2; exit 1; }
while [ $# -gt 0 ]; do
	case "$1" in
		--name) NAME="$2"; shift 2 ;;
		--id|--ip-id) ID="$2"; shift 2 ;;
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
		--into) INTO="$2"; shift 2 ;;
		-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
		*) die "option inconnue : $1 (--help)" ;;
	esac
done

# --- Validation ---
if [ -n "$INTO" ]; then
	[ -d "$INTO" ] || die "--into : $INTO n'existe pas"
	INTO="$(cd "$INTO" && pwd)"
	NAME="${NAME:-$(basename "$INTO")}"
	[ ! -e "$INTO/tools/sf" ] || die "--into : $INTO/tools/sf existe déjà (projet déjà initialisé)"
fi
[ -n "$NAME" ] || die "--name requis"
[[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]] || die "--name : minuscules, chiffres, tirets ($NAME)"
# Catégorie : famille de l'identifiant, lue dans config/categories.conf
CAT_FILE="$SELF_ROOT/config/categories.conf"
FAMILIES="$(grep -vE '^[[:space:]]*(#|$)' "$CAT_FILE" | cut -d'|' -f1 | tr -d ' ' | tr '\n' ' ')"
[[ "$ID" =~ ^([A-Z]+)([0-9]{3})$ ]] || die "--id : forme FAMnnn, FAM parmi : $FAMILIES($ID)"
FAMILY="${BASH_REMATCH[1]}"
CAT_LINE="$(grep -E "^[[:space:]]*$FAMILY[[:space:]]*\|" "$CAT_FILE" || true)"
[ -n "$CAT_LINE" ] || die "--id : famille $FAMILY inconnue (connues : $FAMILIES; ajout : config/categories.conf)"
catf() { echo "$CAT_LINE" | cut -d'|' -f"$1" | sed 's/^ *//; s/ *$//'; }
CATEGORY="$(catf 2)"; PROFILE="${PROFILE:-$(catf 3)}"; REGS_ALLOWED="$(catf 4)"; EXTRA_DIRS="$(catf 5)"; CAT_LABEL="$(catf 6)"
[ $REGS -eq 0 ] || [ "$REGS_ALLOWED" = allowed ] || die "--regs : pas de carte de registres pour la catégorie $CATEGORY"
PREFIX="${PREFIX:-$(echo "$NAME" | sed -E 's/^(ip|sys|dem|exp)-//' | tr '-' '_')}"
[[ "$PREFIX" =~ ^[a-z][a-z0-9_]*$ ]] || die "--prefix : snake_case ($PREFIX)"
TOP="${TOP:-${PREFIX}_top}"
[[ "$TOP" == "$PREFIX" || "$TOP" == "${PREFIX}_"* ]] || die "--top doit commencer par le préfixe d'IP ${PREFIX}_ (HDL-2.1)"
case "$PROFILE" in ip|hls) ASIC="${ASIC:-sky130}" ;; board) ASIC="${ASIC:-none}" ;;
	soc) die "profil soc (catégorie $CATEGORY) pas encore couvert par ce script : voir sf-handbook, catégories" ;; *) die "--profile : ip | board | hls" ;; esac
case "$ASIC" in sky130|gf180|both|none) ;; *) die "--asic : sky130 | gf180 | both | none" ;; esac
case "$LANG_RTL" in sv) HDL_STANDARD=SF-HDL-001 ;; v) HDL_STANDARD="" ;; *) die "--lang : sv | v" ;; esac
[ $REGS -eq 0 ] || [ "$LANG_RTL" = sv ] || die "--regs suppose --lang sv"
if [ -z "$SF_REF" ]; then
	SF_REF="$(git -C "$SELF_ROOT" describe --tags --abbrev=0 2>/dev/null)" || die "--sf-ref requis (pas de tag dans $SELF_ROOT)"
fi
if [ -n "$INTO" ]; then
	DEST="$INTO"
else
	DEST="$(cd "$PARENT" && pwd)/$NAME"
	[ ! -e "$DEST" ] || die "$DEST existe déjà (initialiser un dossier existant : --into $DEST)"
fi

step() { echo "== $*"; }
fill() { # fichier : remplace les champs du projet
	sed -i -e "s/<projet>/$NAME/g" -e "s/<IPxxx>/$ID/g" -e "s/<categorie>/$CATEGORY/g" -e "s/<top>/$TOP/g" -e "s/<ip>/$PREFIX/g" \
		-e "s/<profil>/$PROFILE/g" "$1"
}

CREATED=(); KEPT=()
put() { # source destination [fill] : copie si la destination est absente
	local src="$1" dst="$2"
	if [ -e "$dst" ]; then KEPT+=("$dst"); return 1; fi
	mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"; CREATED+=("$dst")
	[ "${3:-}" = fill ] && fill "$dst"
	return 0
}
put_text() { # destination : contenu sur l'entrée standard (appeler avec < <(…), jamais en fin de tube : CREATED serait perdu)
	local dst="$1" tmp; tmp="$(mktemp)"; cat >"$tmp"
	if [ -e "$dst" ]; then KEPT+=("$dst"); rm -f "$tmp"; return 1; fi
	mkdir -p "$(dirname "$dst")"; mv "$tmp" "$dst"; CREATED+=("$dst"); return 0
}
keep_dir() { # dossier : .gitkeep seulement si le dossier est absent ou vide
	mkdir -p "$1"; [ -n "$(ls -A "$1")" ] || { touch "$1/.gitkeep"; CREATED+=("$1/.gitkeep"); }
}

# --- Dépôt et sous-module sf-tools (les modèles viennent de la version épinglée) ---
step "dépôt $DEST$([ -n "$INTO" ] && echo ' (dossier existant)')"
mkdir -p "$DEST"; cd "$DEST"
[ -d .git ] || git init -q -b main
GITC=(); [[ "$SF_URL" == /* || "$SF_URL" == ./* || "$SF_URL" == ../* || "$SF_URL" == file://* ]] && GITC=(-c protocol.file.allow=always)
step "sous-module tools/sf ← $SF_URL ($SF_REF)"
git "${GITC[@]}" submodule add -q "$SF_URL" tools/sf
git -C tools/sf checkout -q "$SF_REF"
[ $RELATIVE -eq 1 ] && git config -f .gitmodules submodule.tools/sf.url ../sf-tools
T=tools/sf/templates
[ -d "$T/project" ] || die "sf-tools $SF_REF trop ancien : templates/project absent"

# --- Arborescence ---
step "arborescence (catégorie $CATEGORY, profil $PROFILE, FPGA $([ $FPGA -eq 1 ] && echo oui || echo non), ASIC $ASIC, $LANG_RTL)"
keep_dir docs/diagrams
mkdir -p src sim/cocotb .github/workflows; keep_dir build
if [ $FPGA -eq 1 ]; then
	while IFS= read -r f; do put "$T/project/$f" "$f" || true; done < <(cd "$T/project" && find synth/fpga -type f)
fi
for pdk in sky130 gf180; do
	if [ "$ASIC" = "$pdk" ] || [ "$ASIC" = both ]; then
		keep_dir "synth/asic/$pdk/runs"
		if put "$T/project/synth/asic/$pdk/config.json" "synth/asic/$pdk/config.json" fill && [ "$LANG_RTL" = v ]; then
			sed -i -e 's|\["dir::../../../src/\*\*/\*.sv"\]|["dir::../../../src/**/*.v"]|' \
				-e '/"USE_SLANG": true,/d' "synth/asic/$pdk/config.json"
		fi
	fi
done
[ "$PROFILE" = hls ] && keep_dir hls && keep_dir python
for d in ${EXTRA_DIRS//-/}; do keep_dir "$d"; done

# --- Fichiers du projet ---
step "fichiers"
put "$T/sf-project.env" sf-project.env fill && sed -i "s/^HDL_STANDARD=.*/HDL_STANDARD=$HDL_STANDARD/" sf-project.env
put "$T/Makefile.ip" Makefile || true
PHASE=SPEC; [ -n "$INTO" ] && PHASE="à préciser"
put "$T/README.ip.md" README.md fill && sed -i -e "s|<résumé>|$CAT_LABEL, préfixe \`$PREFIX\`|" -e "s|<phase>|$PHASE|" README.md
put "$T/project/CHANGELOG.md" CHANGELOG.md fill || true
if [ -e .gitignore ]; then # complété : lignes du modèle absentes ajoutées, rien n'est retiré
	added=0
	while IFS= read -r line; do
		[ -n "$line" ] && [[ "$line" != \#* ]] && ! grep -qxF "$line" .gitignore && { echo "$line" >>.gitignore; added=$((added + 1)); }
	done <"$T/project/gitignore"
	[ $added -gt 0 ] && CREATED+=(".gitignore (+$added lignes)") || KEPT+=(.gitignore)
else
	put "$T/project/gitignore" .gitignore
fi
put "$T/editorconfig" .editorconfig || true
put "$T/ci.yml" .github/workflows/ci.yml || true
put_text "sim/cocotb/test_$TOP.py" < <(sed "s/TOP = \"my_top\"/TOP = \"$TOP\"/" "$T/test_top.py") || true
MOD_EXT=sv; [ "$LANG_RTL" = v ] && MOD_EXT=v
DS_REF="$ID-DS-v1.0 (à écrire)" # DS déjà écrite (--into) : sa dernière version, section à préciser
DS_FILE="$(ls docs/"$ID"-DS-v*.md 2>/dev/null | sort -V | tail -1 || true)"
[ -n "$DS_FILE" ] && DS_REF="$(basename "$DS_FILE" .md) §(à préciser)"
put_text "src/$TOP.$MOD_EXT" < <(sed -e "s/<IPxxx>-DS-v1.0 §<x>/$DS_REF/" -e "s/<ip>_<role>/$TOP/g" -e "s/<IPxxx>/$ID/g" -e "s/<ip>/$PREFIX/g" \
	-e "s/<une phrase>/Top de $ID $PREFIX (squelette, à remplacer en phase RTL)/" \
	-e "s|// <description>|// largeur des données (squelette)|" -e "s|// <Interface>|// Données (squelette)|" \
	"$T/module.$MOD_EXT") || true
if [ $REGS -eq 1 ]; then
	put "$T/misra_suppressions.txt" sw/misra_suppressions.txt || true
	NUM=$((10#${ID#$FAMILY}))
	put_text "regs/$PREFIX.rdl" <<EOF || true
// ============================================================
// Register map : $ID $PREFIX — skeleton, to be written in the SPEC phase
// Convention : SF-REG-001 (tools/sf/docs/standards/). Single source : make regs generates
// src/gen/, sw/gen/, docs/gen/, ipxact/. Language : English (source of the C comments, SF-070).
// ============================================================

\`include "sf_common.rdl"

addrmap ${PREFIX}_regs {
	name = "$ID $PREFIX";
	desc = "$PREFIX control and status registers.";

	default regwidth = 32;
	default accesswidth = 32;

	// --- Functional registers from 0x000 (REG-2) ---
	reg {
		name = "Control";
		field { desc = "Block enable."; sw = rw; hw = r; } EN[0:0] = 0;
	} CTRL @ 0x00;

	// --- Identification block (REG-4) ---
	sf_id_t      #(.P_IP_NUM($NUM))                         ID      @ 0xF0;
	sf_version_t #(.P_MAJOR(0), .P_MINOR(1), .P_PATCH(0)) VERSION @ 0xF4;
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

if [ -n "$INTO" ]; then
	step "fichiers créés (${#CREATED[@]}) : ${CREATED[*]:-aucun}"
	step "fichiers existants conservés (${#KEPT[@]}) : ${KEPT[*]:-aucun}"
	[ ${#KEPT[@]} -gt 0 ] && echo "   Vérifier que les fichiers conservés (Makefile, sf-project.env…) conviennent aux outils sf-tools."
fi

COMMIT_MSG="chore: init project from template (profil $PROFILE)"
[ -n "$INTO" ] && COMMIT_MSG="chore: add sf-tools project infrastructure (profil $PROFILE)"
if [ $COMMIT -eq 1 ]; then
	if [ -n "$INTO" ]; then # seulement ce que le script a créé : jamais les fichiers du projet en cours
		files=(.gitmodules tools/sf) # sans les chemins ignorés (build/, runs/…), comme git add -A
		for f in "${CREATED[@]}"; do f="${f%% (*}"; git check-ignore -q -- "$f" || files+=("$f"); done
		git add -- "${files[@]}"
	else
		git add -A
	fi
	git commit -q -m "$COMMIT_MSG"
	step "commit : $(git log --oneline -1)"
fi

cat <<EOF

Projet $([ -n "$INTO" ] && echo initialisé || echo créé) : $DEST  (sf-tools $SF_REF, hook pre-commit actif)
Suite :
  cd $DEST
  $([ $COMMIT -eq 1 ] || echo "git add <fichiers> && git commit -m \"$COMMIT_MSG\"")
  gh repo create siliconforge-hw/$NAME --private --source . --remote origin --push && git submodule sync
EOF
