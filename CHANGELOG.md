# Changelog — sf-tools

## [0.11.0] — 2026-10-28
### Added
- `new_project.sh --into DIR` : initialise un dossier existant (spec déjà écrite, dépôt avec ou sans commit) ;
  aucun fichier existant n'est écrasé (créés / conservés listés à la fin), `.gitignore` complété des lignes
  manquantes, `--name` = nom du dossier, `--commit` ne commite que les fichiers créés ; refus si `tools/sf`
  existe déjà

## [0.10.0] — 2026-10-28
### Added
- Catégories de projets : `config/categories.conf` (IP, SYS, DEM, EXP — famille, profil par défaut, registres
  autorisés, dossiers propres), source unique lue par `new_project.sh` ; ajouter une catégorie = une ligne
- `new_project.sh --id FAMnnn` (`--ip-id` toujours accepté) : catégorie déduite de la famille ; refus d'une
  famille inconnue, de `--regs` hors IP/SYS, et du profil soc (pas encore couvert) ; `python/` pour une EXP
- `sf-project.env` : `PROJECT_ID` et `CATEGORY` (les outils lisent encore `IP_ID` des projets antérieurs)
### Changed
- SF-HDL-001 v1.4 : HDL-2.1 / 2.2 parlent du préfixe du **projet** ; champ d'en-tête `Projet` (`IP` accepté)
- `new_project.sh --regs` : le squelette suit SF-REG-001 (`sf_common.rdl`, `ID` numéroté depuis l'identifiant,
  `VERSION` 0.1.0)

## [0.9.0] — 2026-10-23
### Added
- SF-REG-001 v1.2 : REG-4 — champs de `CAPS` fixés par un paramètre de synthèse (`sf_param_f`, `sw = r;
  hw = w`, câblés en constante depuis le top) ; §7 — reset dépendant d'un paramètre (`signal` RDL +
  `<champ>->reset = <signal>`, entrée `hwif_in` chargée au reset, vérifié avec PeakRDL-regblock 1.3)
- `sf_common.rdl` : `sf_param_f`
### Changed
- SF-REG-001 REG-9 : `IC_<qualif>` réservé à la configuration propre aux sources ; seuils et timeouts gardent
  un nom fonctionnel
- Couche C : un `signal` RDL est ignoré (matériel seulement) ; `<IP>_<REG>_RESET` n'est produit que si tous les
  champs ont un reset constant (sinon commentaire explicite). **Effet** : disparition de macros `_RESET` qui
  étaient fausses pour les registres pilotés par le matériel (ex. `STATUS`) — un driver qui les utilisait doit
  être corrigé

## [0.8.0] — 2026-10-23
### Changed
- SF-REG-001 v1.1 : REG-1 impose un port d'adresse de 12 bits (fenêtre de 4 Ko) décodé sur toute sa largeur,
  sans repliement dans le segment AXI ; REG-2 : 60 registres fonctionnels (`0x000`–`0x0EC`), extension à
  partir de `0x100` ; REG-14 : test de non-repliement
- `gen_regs.sh` : `--addr-width` (défaut 12) pour regblock et la couche C (`<IP>_ADDR_WINDOW`) ; refus d'une
  carte qui dépasse la fenêtre. **Effet sur un projet existant** : ports `s_axil_*addr` de 12 bits après
  `make regs` (`regs-check` échoue tant que ce n'est pas fait ; adapter les enveloppes de test)
### Note
- Vérifié par simulation : décodage 12 bits, `0x1F0` lu à 0 ; avec 8 bits, `0x1F0` renvoie `ID` (repliement)

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
