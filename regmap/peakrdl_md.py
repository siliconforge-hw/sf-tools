"""PeakRDL en ligne de commande, avec un affichage stable des resets portés par un signal (SF-REG-001 §7).

L'exporteur markdown (peakrdl_markdown 1.0.3) écrit str(reset) quand le reset d'un champ n'est pas un
entier : pour un reset `CHAMP->reset = <signal>`, c'est le repr Python du SignalNode, qui contient une
adresse mémoire différente à chaque exécution (docs/gen/<ip>_regs.md jamais à jour pour --check).
Ici, un SignalNode s'affiche « signal `<nom>` » ; le reste du comportement est celui de `peakrdl`.

Usage (gen_regs.sh) : python -I peakrdl_md.py markdown <fichier.rdl> -I <inc> -o <sortie.md>
"""

import sys

from peakrdl.main import main
from systemrdl.node import SignalNode

SignalNode.__str__ = lambda self: f"signal `{self.inst_name}`"

if __name__ == "__main__":
    sys.argv[0] = "peakrdl"
    sys.exit(main())
