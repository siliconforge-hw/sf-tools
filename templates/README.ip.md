# <projet>

> <IPxxx> — <résumé>. Phase en cours : 1 — SPEC.

## Description

À compléter en phase SPEC (voir `docs/<IPxxx>-DS-v1.0.md`).

## Architecture

À compléter. Schéma bloc : `docs/diagrams/`.

## Structure

```
src/              RTL SystemVerilog (norme SF-HDL-001), un module par fichier
sim/cocotb/       Testbenches cocotb (test_<module>.py)
docs/             <IPxxx>-DS/TS/TP/TR-v*.md
  diagrams/       Schéma bloc, FSM, chronogrammes
synth/
  fpga/arty_z7_20/  run.tcl, constraints/top.xdc, bitstream/
  asic/sky130/      config.json LibreLane (USE_SLANG)
build/            Artefacts (gitignored)
```

## Branches git

| Branche          | Rôle                                    |
|------------------|-----------------------------------------|
| `main`           | RTL validé en simulation                |
| `fpga/arty-z7`   | Adaptations FPGA Arty Z7-20             |
| `asic/sky130`    | Adaptations ASIC PDK sky130             |

## Flow

```bash
make lint                  # Verilator + Icarus + Yosys/slang + norme SF-HDL-001
make sim                   # cocotb sur Icarus (SIM=verilator, WAVES=1)
make sim-all               # régression Icarus + Verilator
make wave                  # dernières formes d'onde dans GTKWave
make fpga                  # Vivado batch → bitstream Arty Z7-20
make asic-sky130           # LibreLane sky130 → GDSII dans synth/asic/sky130/runs/
make check-env             # état des outils
make help                  # liste des cibles
```

## Dépendances

Chemins des outils : `make sf-config` (défauts de sf-tools, surchargés par `~/.config/sf-tools/config.env`, voir `tools/sf/README.md`).

Cloner avec les outils de build : `git clone --recursive <url>` (ou `git submodule update --init` après coup). `tools/sf/` = sf-tools, épinglé sur un tag.

- Icarus Verilog, Verilator, GTKWave
- cocotb (venv)
- OSS CAD Suite (Yosys + slang, pour le lint)
- Vivado 2024.2 (environnement chargé par `make fpga`)
- LibreLane via Nix, PDK sky130
- Plugin Claude Code siliconforge : facultatif, pour travailler avec Claude

## Références

- Normes de codage : `tools/sf/docs/standards/` (SF-HDL-001 pour le RTL, SF-CS-001 pour le C)
