"""Testbench cocotb — structure UVM-lite (driver / monitor / modèle de référence / scoreboard / coverage).

Modèle à copier dans <projet>/sim/cocotb/test_<top>.py puis adapter :
  - TOP, RTL_SOURCES, PARAMETERS
  - Driver / Monitor : protocole de l'interface du DUT
  - RefModel : comportement attendu, écrit d'après la DS (pas d'après le RTL)
  - un @cocotb.test() par TC-xxx du Test Plan, ou un test par section

Lancement (depuis la racine du projet) :
  SIM=icarus    ~/tools/venvs/cocotb/bin/pytest sim/cocotb -v
  SIM=verilator ~/tools/venvs/cocotb/bin/pytest sim/cocotb -v
"""

import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, ReadOnly

PROJ = Path(__file__).resolve().parents[2]
TOP = "my_top"                                  # à adapter
RTL_SOURCES = sorted(p for p in (PROJ / "src").rglob("*") if p.suffix in (".v", ".sv"))
PARAMETERS = {}                                 # ex. {"WIDTH": 8}
CLK_PERIOD_NS = 10


# --------------------------------------------------------------------------
# Composants UVM-lite
# --------------------------------------------------------------------------
class Driver:
    """Applique les stimuli sur les entrées du DUT, synchronisé sur clk."""

    def __init__(self, dut):
        self.dut = dut

    async def reset(self, cycles=4):
        self.dut.rst_n_i.value = 0
        await ClockCycles(self.dut.clk_i, cycles)
        self.dut.rst_n_i.value = 1
        await RisingEdge(self.dut.clk_i)


class Monitor:
    """Échantillonne les sorties à chaque cycle et les pousse au scoreboard."""
    # Ports nommés selon SF-HDL-001 (clk_i, rst_n_i, *_i / *_o)

    def __init__(self, dut, callback):
        self.dut = dut
        self.callback = callback

    async def run(self):
        while True:
            await RisingEdge(self.dut.clk_i)
            await ReadOnly()
            self.callback(self.sample())

    def sample(self):
        return {}                               # ex. {"q": int(self.dut.q_o.value)}


class RefModel:
    """Modèle de référence cycle à cycle, d'après la DS."""

    def step(self, inputs):
        return {}


class Scoreboard:
    def __init__(self):
        self.errors = []
        self.checks = 0

    def compare(self, tc, expected, observed):
        self.checks += 1
        if expected != observed:
            self.errors.append(f"{tc}: attendu {expected}, observé {observed}")

    def assert_clean(self):
        assert not self.errors, "\n".join(self.errors[:20])


async def setup(dut):
    cocotb.start_soon(Clock(dut.clk_i, CLK_PERIOD_NS, unit="ns").start())
    drv = Driver(dut)
    await drv.reset()
    return drv


# --------------------------------------------------------------------------
# Tests : un par TC-xxx (ou par section) du Test Plan
# --------------------------------------------------------------------------
@cocotb.test()
async def tc_001_reset(dut):
    """TC-001 — valeurs de reset conformes à la DS."""
    await setup(dut)
    await ReadOnly()
    # assert int(dut.q.value) == 0, "TC-001: q != 0 après reset"


# --------------------------------------------------------------------------
# Runner pytest
# --------------------------------------------------------------------------
def test_runner():
    from cocotb_tools.runner import get_runner

    sim = os.getenv("SIM", "icarus")
    if sim == "icarus" and any("gen" in p.parts for p in RTL_SOURCES):
        import pytest
        pytest.skip("src/gen/ (PeakRDL) non compilable par Icarus : SIM=verilator")
    build_dir = PROJ / "build" / "cocotb" / sim
    build_args = ["-Wno-fatal"] if sim == "verilator" else []
    runner = get_runner(sim)
    runner.build(
        sources=RTL_SOURCES,
        hdl_toplevel=TOP,
        parameters=PARAMETERS,
        build_dir=build_dir,
        build_args=build_args,
        timescale=("1ns", "1ps"),               # le RTL n'a pas de `timescale
        waves=bool(int(os.getenv("WAVES") or 0)),
        always=True,
    )
    runner.test(
        hdl_toplevel=TOP,
        test_module=Path(__file__).stem,
        test_dir=Path(__file__).parent,
        build_dir=build_dir,
        waves=bool(int(os.getenv("WAVES") or 0)),
    )
