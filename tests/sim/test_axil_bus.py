"""Test sf-tools : sim/sf_cocotb.axil_bus pilote un top dont les ports AXI4-Lite suivent HDL-3.4
(s_axi_<signal>_i / _o), sur le regblock de tests/regs/sigreset.rdl.

Lancé par tests/run_tests.sh, qui génère le regblock et donne son dossier dans SF_TEST_SRC.
Verilator uniquement (Icarus ne compile pas le code PeakRDL).
"""

import os
import sys
from pathlib import Path

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
from cocotbext.axi import AxiLiteMaster

SF_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SF_ROOT / "sim"))
from sf_cocotb import axil_bus  # noqa: E402

TOP = "sigreset_top"
DIV_RESET = 0x5A
DIVR, ID = 0x00, 0xF0
ID_EXPECTED = 0x5346_0000 | 999          # SF-REG-001 REG-4 : VENDOR « SF » + IP_NUM de la carte de test


async def setup(dut):
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    dut.rst_n_i.value = 0
    await ClockCycles(dut.clk_i, 4)
    dut.rst_n_i.value = 1
    await RisingEdge(dut.clk_i)
    return AxiLiteMaster(axil_bus(dut, "s_axi"), dut.clk_i, dut.rst_n_i, reset_active_level=False)


async def rd(axi, addr):
    return int.from_bytes((await axi.read(addr, 4)).data, "little")


@cocotb.test()
async def tc_id(dut):
    """Lecture du bloc d'identification par les ports suffixés."""
    axi = await setup(dut)
    assert await rd(axi, ID) == ID_EXPECTED


@cocotb.test()
async def tc_reset_from_parameter(dut):
    """Reset de DIVR.DIV porté par un signal, fixé par le paramètre DIV_RESET du top."""
    axi = await setup(dut)
    assert await rd(axi, DIVR) == DIV_RESET
    assert int(dut.div_o.value) == DIV_RESET


@cocotb.test()
async def tc_write_read(dut):
    """Écriture relue, et visible côté matériel."""
    axi = await setup(dut)
    await axi.write(DIVR, (0x1C3).to_bytes(4, "little"))
    assert await rd(axi, DIVR) == 0x1C3
    assert int(dut.div_o.value) == 0xC3
    assert int(dut.en_o.value) == 1


@cocotb.test()
async def tc_prefix_without_role(dut):
    """Un préfixe sans rôle (ni s_ ni m_) est refusé."""
    with pytest.raises(ValueError):
        axil_bus(dut, "axi")


def test_runner():
    from cocotb_tools.runner import get_runner

    src = Path(os.environ["SF_TEST_SRC"])
    sources = [src / "gen" / "sigreset_regs_pkg.sv", src / "gen" / "sigreset_regs.sv", src / "sigreset_top.sv"]
    build_dir = Path(os.environ.get("SF_TEST_BUILD", "build")) / "cocotb"
    runner = get_runner("verilator")
    runner.build(
        sources=sources,
        hdl_toplevel=TOP,
        parameters={"DIV_RESET": DIV_RESET},
        build_dir=build_dir,
        build_args=["-Wno-fatal"],
        timescale=("1ns", "1ps"),
        always=True,
    )
    runner.test(hdl_toplevel=TOP, test_module=Path(__file__).stem, test_dir=Path(__file__).parent, build_dir=build_dir)
