# sf-tools — outils de build siliconforge

Scripts utilisés par les `Makefile` des projets (et par le plugin Claude Code siliconforge, qui appelle les mêmes scripts). Aucune dépendance à Claude.

Chaque projet l'intègre en **sous-module git épinglé sur un tag** :

```bash
git submodule add ../sf-tools tools/sf        # URL relative : même compte/organisation que le projet
git -C tools/sf checkout v0.1.0 && git add tools/sf
git clone --recursive <projet>                 # un clone fonctionne seul, outils EDA installés
```

| Fichier | Rôle | Cible make |
|---|---|---|
| `bin/lint.sh` | lint 4 passes : Verilator `-Wall`, Icarus, Yosys + slang, norme SF-HDL-001 | `make lint` |
| `bin/check_style.py` | contrôle de la norme SF-HDL-001 (appelé par `lint.sh` et par le hook du plugin) | — |
| `bin/gen_regs.sh` | SystemRDL → banc de registres SV, couche C SF-CS-001, doc, IP-XACT ; `--check` | `make regs`, `make regs-check` |
| `regmap/gen_c_hw.py` | générateur de `<ip>_regs_hw.h` (structure, macros, hooks, accesseurs typés) | — |
| `style/clang-format` | mise en forme C SF-CS-001 §5.9 | — |
| `bin/check_tools.sh` | versions des outils EDA installés | `make check-env` |

Outils attendus (voir `~/tools/tools.txt`) : Verilator, Icarus, OSS CAD Suite (Yosys + slang), PeakRDL (`~/tools/venvs/peakrdl`), clang-format, cocotb (`~/tools/venvs/cocotb`).

Normes : SF-HDL-001 (RTL) et SF-CS-001 (C), dans le dépôt `claude-env` (`docs/standards/`).

Versionnement : semver, un tag par version ; un changement qui peut faire échouer le lint d'un projet existant (nouvelle règle contrôlée) est une version MINOR, documentée dans `CHANGELOG.md`.
