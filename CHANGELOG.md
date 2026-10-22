# Changelog — sf-tools

## [0.1.0] — 2026-10-22
### Added
- `bin/lint.sh`, `bin/check_style.py`, `bin/check_tools.sh` : extraits du plugin siliconforge 0.4.0
- `bin/gen_regs.sh` : SystemRDL → regblock SV, couche C, doc, IP-XACT ; `--check`
- `regmap/gen_c_hw.py` : couche matérielle C SF-CS-001 (`<ip>_regs_hw.h`) générée, remplace PeakRDL c-header
- `style/clang-format` : style SF-CS-001 §5.9 (repris d'ip-gpio)
