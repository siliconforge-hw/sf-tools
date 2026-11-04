"""Aides cocotb communes aux projets sf-tools.

Import depuis un banc de test (sf-tools en sous-module tools/sf/) :

    import sys
    from pathlib import Path
    PROJ = Path(__file__).resolve().parents[2]
    sys.path.insert(0, str(PROJ / "tools" / "sf" / "sim"))
    from sf_cocotb import axil_bus

Le sys.path est modifié dans le module de test lui-même : il vaut pour pytest et pour le processus du
simulateur, qui réimporte ce module.
"""

from cocotbext.axi import AxiLiteBus, AxiLiteReadBus, AxiLiteWriteBus
from cocotbext.axi.axil_channels import AxiLiteARBus, AxiLiteAWBus, AxiLiteBBus, AxiLiteRBus, AxiLiteWBus

# Signaux AXI4-Lite pilotés par l'esclave ; tous les autres le sont par le maître
_SLAVE_DRIVEN = {"awready", "wready", "bvalid", "bresp", "arready", "rvalid", "rdata", "rresp"}


def _channel(bus_cls, entity, prefix, dut_is_slave):
    """Bus d'un canal AXI4-Lite dont les signaux portent le suffixe de direction vu du DUT."""

    def port(sig):
        driven_by_dut = (sig in _SLAVE_DRIVEN) == dut_is_slave
        return f"{sig}_o" if driven_by_dut else f"{sig}_i"

    suffixed = type(
        bus_cls.__name__ + "Suffixed",
        (bus_cls,),
        {
            "_signals": {s: port(s) for s in bus_cls._signals},
            "_optional_signals": {s: port(s) for s in bus_cls._optional_signals},
        },
    )
    return suffixed(entity, prefix)


def axil_bus(dut, prefix="s_axi"):
    """AxiLiteBus pour des ports nommés selon SF-HDL-001 HDL-3.4 (<prefix>_<signal>_i / _o).

    AxiLiteBus.from_prefix cherche <prefix>_<signal> sans suffixe de direction. Le rôle du DUT se déduit
    du préfixe : s_* esclave (awvalid_i, awready_o…), m_* maître (awvalid_o, awready_i…). Les signaux
    optionnels (awprot, arprot, wstrb, bresp, rresp) peuvent être absents.

    Exemple : AxiLiteMaster(axil_bus(dut, "s_axi"), dut.clk_i, dut.rst_n_i, reset_active_level=False)
    """
    if prefix.startswith("s_"):
        dut_is_slave = True
    elif prefix.startswith("m_"):
        dut_is_slave = False
    else:
        raise ValueError(f"axil_bus : préfixe {prefix!r} sans rôle (s_… esclave, m_… maître, HDL-3.4)")
    write = AxiLiteWriteBus(
        aw=_channel(AxiLiteAWBus, dut, prefix, dut_is_slave),
        w=_channel(AxiLiteWBus, dut, prefix, dut_is_slave),
        b=_channel(AxiLiteBBus, dut, prefix, dut_is_slave),
    )
    read = AxiLiteReadBus(
        ar=_channel(AxiLiteARBus, dut, prefix, dut_is_slave),
        r=_channel(AxiLiteRBus, dut, prefix, dut_is_slave),
    )
    return AxiLiteBus(write=write, read=read)
