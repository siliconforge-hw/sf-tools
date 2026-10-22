# sf-tools — outils de build siliconforge

Outils, normes et modèles utilisés par les projets d'IP siliconforge : lint RTL, contrôle de la norme de codage, génération des registres (SystemRDL), conformité du C embarqué. Ils sont appelés par les `Makefile` des projets ; aucune dépendance à un assistant ou à un éditeur. (Le plugin Claude Code siliconforge, facultatif, appelle les mêmes scripts.)

## Intégration dans un projet

Chaque projet l'intègre en **sous-module git épinglé sur un tag** :

```bash
git submodule add git@github.com:siliconforge-hw/sf-tools.git tools/sf
git -C tools/sf checkout v0.4.0
git config -f .gitmodules submodule.tools/sf.url ../sf-tools   # URL relative : même organisation que le projet
git add .gitmodules tools/sf

git clone --recursive <projet>                                  # un clone fonctionne seul, outils EDA installés
```

Le projet se déclare dans **`sf-project.env`** (modèle : `templates/sf-project.env`), lu par le `Makefile` et par les outils :

```
PROJECT=ip-uart
IP_ID=IP002
TOP_MODULE=uart_top
IP_PREFIX=uart
HDL_STANDARD=SF-HDL-001
```

## Contenu

| Fichier | Rôle | Cible make |
|---|---|---|
| `bin/lint.sh` | lint 4 passes : Verilator `-Wall`, Icarus, Yosys + slang, norme SF-HDL-001 | `make lint` |
| `bin/check_style.py` | contrôle de la norme SF-HDL-001 (activé par `HDL_STANDARD` dans `sf-project.env`) | — |
| `bin/gen_regs.sh` | SystemRDL → banc de registres SV, couche C SF-CS-001, doc, IP-XACT ; `--check` | `make regs`, `make regs-check` |
| `regmap/gen_c_hw.py` | générateur de `<ip>_regs_hw.h` (structure, macros, hooks, accesseurs typés) | — |
| `bin/sw_lint.sh` | conformité SF-CS-001 : SF-090 (hôte, ARM, RISC-V), headers seuls (SF-004), cppcheck MISRA, clang-format | `make sw-lint`, `make sw-format` |
| `bin/check_tools.sh` | versions des outils EDA installés | `make check-env` |
| `bin/sf_config.sh`, `bin/sf_env.sh`, `config/defaults.env` | configuration des chemins d'outils | `make sf-config` |
| `style/clang-format` | mise en forme C (SF-CS-001 §5.9) | — |
| `docs/standards/` | **SF-HDL-001** (RTL SystemVerilog) et **SF-CS-001** (C embarqué) : les normes appliquées par ces outils | — |
| `templates/` | modèles d'un nouveau projet : `Makefile.ip`, `sf-project.env`, `module.sv`, `test_top.py` (cocotb), `README.ip.md`, `editorconfig`, `misra_suppressions.txt` | — |

Les messages des outils citent les règles des normes (`%Style-HDL-3.1`, `SF-033`, `DP-02`…) : leur texte est dans `docs/standards/`. Le texte des règles MISRA C:2012, payant, n'est pas reproduit (numéros seulement).

## Configurer les chemins des outils

Les chemins par défaut sont ceux de l'environnement de référence (`config/defaults.env`). Sur un autre poste :

```bash
bash tools/sf/bin/sf_config.sh --init     # crée ~/.config/sf-tools/config.env, tout commenté
$EDITOR ~/.config/sf-tools/config.env      # décommenter les lignes qui diffèrent (souvent TOOLS_ROOT suffit)
bash tools/sf/bin/sf_config.sh            # vérifier : valeur, origine (env/user/defaults), (absent)
```

Priorité : variable d'environnement (`PEAKRDL=… make regs`) > fichier utilisateur > défauts. Le fichier utilisateur vaut pour tous les projets ; il n'est jamais versionné. Les Makefiles lisent la même configuration (`sf_config.sh --get`).

Outils attendus : Verilator, Icarus, OSS CAD Suite (Yosys + slang), PeakRDL (venv), clang-format, cppcheck (addon MISRA), gcc, arm-none-eabi-gcc, riscv32-unknown-elf-gcc, cocotb (venv), Vivado et LibreLane pour les flots FPGA et ASIC.

## Versionnement

Semver, un tag par version, `CHANGELOG.md`. Un changement qui peut faire échouer le lint d'un projet existant (nouvelle règle contrôlée) est une version MINOR ; un changement de l'interface en ligne de commande des scripts ou des modèles est une version MAJOR. Un tag publié n'est jamais déplacé.
