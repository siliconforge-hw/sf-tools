# Changelog — sf-tools

## [0.3.0] — 2026-10-22
### Added
- `config/defaults.env` : chemins des outils de l'environnement de référence, en un seul endroit
- `bin/sf_env.sh` : chargeur (variable d'environnement > `~/.config/sf-tools/config.env` > défauts),
  valeurs fusionnées puis développées (redéfinir `TOOLS_ROOT` déplace les chemins qui en dépendent)
- `bin/sf_config.sh` : affichage avec origine de chaque valeur, `--get` (Makefiles), `--init` (nouvel utilisateur)
### Changed
- `lint.sh`, `gen_regs.sh`, `sw_lint.sh`, `check_tools.sh` : plus aucun chemin en dur ; slang détecté
  en chargeant le plugin (plus de comparaison de chemin) ; branche principale renommée `main`

## [0.2.0] — 2026-10-22
### Added
- `bin/sw_lint.sh` : conformité SF-CS-001 — compilation stricte SF-090 (hôte, arm-none-eabi, riscv32),
  chaque header compilé seul (SF-004), cppcheck MISRA C:2012 avec `sw/misra_suppressions.txt`,
  clang-format (`--fix` pour reformater, jamais `gen/`) ; cibles `make sw-lint` / `make sw-format`

## [0.1.0] — 2026-10-22
### Added
- `bin/lint.sh`, `bin/check_style.py`, `bin/check_tools.sh` : extraits du plugin siliconforge 0.4.0
- `bin/gen_regs.sh` : SystemRDL → regblock SV, couche C, doc, IP-XACT ; `--check`
- `regmap/gen_c_hw.py` : couche matérielle C SF-CS-001 (`<ip>_regs_hw.h`) générée, remplace PeakRDL c-header
- `style/clang-format` : style SF-CS-001 §5.9 (repris d'ip-gpio)
