# Changelog — sf-tools

## [0.7.1] — 2026-10-23
### Fixed
- `check_style.py` : le repli `CLAUDE.md` n'active la norme que sur la ligne du modèle
  `| Norme de codage | SF-HDL-001 … |`, plus sur une simple mention du nom (« ne s'applique pas »)
- SF-REG-001 REG-8a : cite aussi IP-001 BUG-RTL-007 (acquittement du même bit) ; REG-14 précise les deux cas

## [0.7.0] — 2026-10-23
### Added
- `docs/standards/SF-REG-001-v1.0.md` : convention des registres — carte ≥ 256 octets décodée en entier, bloc
  d'identification `0xF0` ID / `0xF4` VERSION / `0xF8` CAPS, interruptions `IE`/`IS` (événement W1C, niveau,
  acquittement implicite), non-perte d'un événement pendant un acquittement (REG-8a), alias SET/CLR/TGL
- `regmap/sf_common.rdl` : `sf_id_t`, `sf_version_t`, `sf_event_f` (`precedence = hw`), `sf_level_f`
- `gen_regs.sh` : chemin d'inclusion `regmap/` ; contrôle REG-5 (`ID.IP_NUM` = `IP_ID` de `sf-project.env`),
  exécuté avant toute écriture
### Note
- Vérifié par simulation : avec la priorité PeakRDL par défaut (`sw`), un événement simultané à l'acquittement
  d'un autre bit de `IS` est perdu ; `sf_event_f` le conserve

## [0.6.0] — 2026-10-22
### Added
- `bin/new_project.sh` : création d'un projet sans assistant (profils ip/board/hls, cibles FPGA/ASIC,
  SV-synth ou Verilog-2005, carte de registres optionnelle), sous-module épinglé, `sf-project.env`, CI, hook,
  vérification finale (`lint`, `regs-check`, `sw-lint`, `sim-all`), commit initial optionnel
- `templates/project/` : squelette versionné (docs, synth Arty Z7-20 avec ports `clk_i`/`rst_n_i`, configs
  LibreLane sky130/gf180 avec `USE_SLANG`, CHANGELOG, .gitignore) — remplace la copie locale non versionnée
  `project_template` pour ces profils
- `templates/module.v` : squelette Verilog-2005

## [0.5.0] — 2026-10-22
### Added
- `hooks/pre-commit` : `make lint` / `regs-check` / `sw-lint` selon les fichiers indexés ; activation `make hooks`
- `ci/setup_tools.sh` : installation idempotente de la chaîne d'outils (OSS CAD Suite épinglée, venvs cocotb et
  PeakRDL aux versions exactes de `ci/requirements-*.txt`, cppcheck, clang-format, arm-none-eabi-gcc)
- `templates/ci.yml` : workflow GitHub Actions (clone `--recursive`, cache des outils, `regs-check`, `lint`,
  `sw-lint`, `sim-all`, journaux en cas d'échec) — validé sur ip-uart : vert, et rouge sur une violation
- `templates/Makefile.ip` : cible `hooks`

## [0.4.0] — 2026-10-22
### Added
- `docs/standards/` : SF-HDL-001 v1.3 (autonome : profil SV-synth défini en HDL-7.5, activation par
  `sf-project.env`) et SF-CS-001 v1.0 — les normes publiées avec les outils qui les appliquent
- `templates/` : modèles d'un nouveau projet (`Makefile.ip`, `sf-project.env`, `module.sv`, `test_top.py`,
  `README.ip.md`, `editorconfig`, `misra_suppressions.txt`), versionnés avec les scripts qu'ils appellent
- `sf-project.env` : déclaration neutre du projet (PROJECT, IP_ID, TOP_MODULE, IP_PREFIX, HDL_STANDARD),
  incluse par le Makefile
### Changed
- `check_style.py` : norme et préfixe d'IP lus dans `sf-project.env` ; `CLAUDE.md` n'est plus qu'un repli
- README : plus de référence à un dépôt non publié ni à des chemins locaux

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
