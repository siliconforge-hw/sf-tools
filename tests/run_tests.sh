#!/usr/bin/env bash
# Tests de non-régression de sf-tools (local et CI). Besoins : venv PeakRDL et clang-format
# (config/defaults.env, ou ci/setup_tools.sh).
set -euo pipefail

SF_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
FAIL=0
ok()   { echo "   OK    $*"; }
fail() { echo "   ÉCHEC $*"; FAIL=1; }

# --- gen_regs.sh : reset par signal (SF-REG-001 §7), sorties déterministes ---
echo "== gen_regs.sh : reset par signal"
mkdir -p "$WORK/p/regs"; cp "$SF_ROOT/tests/regs/sigreset.rdl" "$WORK/p/regs/"
cd "$WORK/p"
bash "$SF_ROOT/bin/gen_regs.sh" regs/sigreset.rdl >"$WORK/gen1.log" 2>&1 || { cat "$WORK/gen1.log"; fail "première génération"; exit 1; }
mkdir -p "$WORK/run1"; cp -r src sw docs ipxact "$WORK/run1/"
bash "$SF_ROOT/bin/gen_regs.sh" regs/sigreset.rdl >"$WORK/gen2.log" 2>&1 || { cat "$WORK/gen2.log"; fail "seconde génération"; exit 1; }
for f in src/gen/sigreset_regs.sv src/gen/sigreset_regs_pkg.sv sw/gen/sigreset_regs_hw.h docs/gen/sigreset_regs.md ipxact/sigreset_regs.xml; do
	cmp -s "$f" "$WORK/run1/$f" && ok "identique sur deux générations : $f" || fail "diffère d'une génération à l'autre : $f"
done
if bash "$SF_ROOT/bin/gen_regs.sh" --check regs/sigreset.rdl >"$WORK/check.log" 2>&1; then ok "--check renvoie 0"; else cat "$WORK/check.log"; fail "--check renvoie 1"; fi
grep -q 'signal `div_reset`' docs/gen/sigreset_regs.md && ok "markdown : reset « signal \`div_reset\` »" || fail "markdown : reset du champ DIV"
! grep -rqE ' at 0x[0-9a-f]+>' src sw docs ipxact && ok "aucun repr d'objet Python" || fail "repr d'objet Python dans une sortie"
! grep -q 'Unsupported type of node' "$WORK/gen2.log" && ok "pas d'avertissement bénin de l'exporteur markdown" || fail "avertissement SignalNode affiché"
grep -q 'IP-XACT sans valeur de reset .*div_reset' "$WORK/gen2.log" && ok "note de limitation IP-XACT" || fail "note de limitation IP-XACT absente"
awk '/<ipxact:name>DIV</,/<\/ipxact:field>/' ipxact/sigreset_regs.xml | grep -q 'ipxact:reset' \
	&& fail "IP-XACT : valeur de reset écrite pour DIV" || ok "IP-XACT : DIV sans valeur de reset"
grep -q 'hwif_in.div_reset' src/gen/sigreset_regs.sv && ok "regblock : reset de DIV chargé depuis hwif_in.div_reset" || fail "regblock : hwif_in.div_reset absent"
! grep -qE '^#define SIGRESET_DIVR(_DIV)?_RESET ' sw/gen/sigreset_regs_hw.h && ok "couche C : pas de macro RESET pour DIVR ni DIV" || fail "couche C : macro RESET pour un reset par signal"
grep -q 'SIGRESET_DIVR_DIV : reset value from hardware signal div_reset' sw/gen/sigreset_regs_hw.h && ok "couche C : reset de DIV documenté (signal div_reset)" || fail "couche C : commentaire du reset de DIV"

echo
[ $FAIL -eq 0 ] && echo "TESTS : tous OK" || { echo "TESTS : échec"; exit 1; }
