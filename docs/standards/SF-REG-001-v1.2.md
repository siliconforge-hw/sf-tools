# SF-REG-001-v1.2 — Convention des registres des IP siliconforge

| Champ      | Valeur                                            |
|------------|---------------------------------------------------|
| Auteur     | Gaël BOYA                                         |
| Date       | 2026-10-23                                        |
| Statut     | APPLICABLE                                        |
| Portée     | Toute IP siliconforge accessible par un bus (AXI4-Lite par défaut) : banc de registres généré (SystemRDL) ou écrit à la main |
| Références | SF-HDL-001 (RTL), SF-CS-001 (C), `regmap/sf_common.rdl` |

> Objectif : qu'un driver, un outil d'intégration ou un humain reconnaisse et pilote toutes les IP de la même façon (identification, capacités, interruptions, écritures atomiques). Une IP antérieure à cette norme s'y conforme **par ajout** (aucun registre existant déplacé) lors de sa prochaine version.

Les règles sont numérotées `REG-<n>` pour pouvoir être citées en revue.

---

## 1. Carte d'adresses

| Règle | Contenu |
|---|---|
| REG-1 | Registres de 32 bits, alignés sur 4 octets, accès 32 bits (SF-CS-001 SF-032). **Port d'adresse de 12 bits : fenêtre de 4 Ko (`0x000`–`0xFFF`), décodée sur toute sa largeur** (`addr[11:2]`). Une adresse sans registre — y compris au-delà de `0x0FF` — est lue à 0, l'écriture est ignorée, la réponse est `OKAY` : la fenêtre ne se répète jamais. Motif : le segment attribué à un esclave AXI dans la carte d'adresses d'un système est en général de 4 Ko (minimum de l'éditeur d'adresses Vivado) ; une IP qui ne décoderait que 8 bits y apparaîtrait 16 fois, et un logiciel qui se trompe d'adresse modifierait un vrai registre au lieu de lire 0. Une IP qui a besoin de plus de 4 Ko élargit son port et le documente dans sa DS. |
| REG-2 | Registres fonctionnels à partir de `0x000`, croissants, jusqu'à `0x0EC` (60 registres). **`0x0F0`–`0x0FF` sont réservés au bloc d'identification** (§2), à la même place dans toutes les IP. Au-delà de 60 registres, ou pour un tableau (canaux, coefficients, fenêtre mémoire), les registres supplémentaires vont à partir de `0x100`. |
| REG-3 | Bits réservés et offsets non décodés : lus à 0, écritures ignorées, réponse `OKAY`. Un nouveau registre se place dans un offset libre : une IP qui en ajoute reste compatible avec ses anciens drivers. |

## 2. Bloc d'identification

| Offset | Nom | Accès | Contenu |
|---|---|---|---|
| `0xF0` | `ID` | RO, constant | `[31:16]` `VENDOR` = `0x5346` (« SF ») ; `[15:0]` `IP_NUM` = numéro de l'IP (`IP002` → `0x0002`) |
| `0xF4` | `VERSION` | RO, constant | `[23:16]` `MAJOR`, `[15:8]` `MINOR`, `[7:0]` `PATCH` : version du **RTL** ; `[31:24]` réservés |
| `0xF8` | `CAPS` | RO, constant | capacités et paramètres de synthèse propres à l'IP (`N_GPIO`, profondeur de FIFO…), décrits par la DS de l'IP ; `0` si aucun |
| `0xFC` | — | réservé | — |

| Règle | Contenu |
|---|---|
| REG-4 | Toute IP implémente `ID` et `VERSION` ; `CAPS` dès qu'elle a un paramètre de synthèse visible du logiciel. Ce sont des constantes : aucune bascule. `ID` et `VERSION` sont des constantes RDL (`hw = na`). Un champ de `CAPS` fixé par un **paramètre de synthèse** ne peut pas être une constante RDL (le `.rdl` est compilé une fois pour toutes les configurations) : il est déclaré `sw = r; hw = w` (type `sf_param_f`) et son entrée est câblée **en constante** depuis les paramètres du top — toujours aucune bascule ; la couche C n'en donne alors pas de valeur attendue, le driver la lit. |
| REG-5 | `IP_NUM` est cohérent avec `IP_ID` de `sf-project.env` (vérifié par `make regs` pour une IP générée). `VERSION` est mis à jour avec le RTL, dans le même commit que le CHANGELOG et le tag de la version. |
| REG-6 | Le driver lit `ID` à l'initialisation : `VENDOR` ou `IP_NUM` inattendu → erreur « pas de périphérique » (`<ip>_ERR_NO_DEVICE`). Les paramètres viennent de `CAPS`, **jamais d'une sonde par écriture**. Un driver qui doit aussi piloter des RTL antérieurs (`ID` lu à 0) peut garder une sonde en repli, documentée. |

## 3. Interruptions

| Règle | Contenu |
|---|---|
| REG-7 | Une IP qui produit des interruptions a deux registres, mêmes noms et mêmes positions de bits pour une même source : **`IE`** (RW, validation) et **`IS`** (état des sources). `irq_o = |(IS & IE)`, de niveau, active haut ; elle peut être registrée (un cycle de retard, sans glitch), ce que la DS précise. |
| REG-8 | Chaque bit de `IS` est d'un des trois types suivants, indiqué dans la DS : **événement** — mémorisé par le matériel, effacé en écrivant 1 (W1C) ; **niveau** — image instantanée d'une condition (RO), qui retombe quand le logiciel a traité la cause ; **drapeau à acquittement implicite** — mémorisé, RO, effacé par l'action qui le traite (lecture d'une donnée…). Dans tous les cas, `IS` évolue **indépendamment de `IE`** : une source survenue alors que sa validation est à 0 est visible et lève `irq_o` dès la validation. Écrire 0 dans `IS`, ou 1 dans un bit qui n'est pas W1C, est sans effet. |
| REG-8a | **Un événement n'est jamais perdu** : s'il survient au même cycle qu'une écriture dans `IS` (y compris une écriture qui acquitte un autre bit), le bit est à 1 après ce cycle. En SystemRDL : `precedence = hw` sur tout champ événement — type `sf_event_f` de `sf_common.rdl` ; la valeur par défaut de PeakRDL (`sw`) perd l'événement. Retour d'expérience : IP-001 BUG-RTL-005 (acquittement d'un autre bit) et BUG-RTL-007 (acquittement du même bit : l'événement l'emporte, le bit reste à 1). |
| REG-9 | La configuration **propre aux sources d'interruption** (choix des fronts, des niveaux, de la polarité) va dans des registres `IC_<qualif>` (ex. `IC_RISE`, `IC_FALL`). Les paramètres d'un bloc fonctionnel qui conditionnent aussi une interruption (seuils de FIFO, durée de timeout…) gardent un nom fonctionnel (`FIFO_THRESHOLD`, `RX_TIMEOUT`). |

## 4. Écritures atomiques

| Règle | Contenu |
|---|---|
| REG-10 | Un registre de données ou de contrôle dont les bits sont modifiés **indépendamment depuis plusieurs contextes** (thread et ISR, plusieurs tâches) a des alias en écriture seule, placés juste après lui ou groupés : `<REG>_SET` (écrire 1 met à 1), `<REG>_CLR` (écrire 1 met à 0), `<REG>_TGL` (écrire 1 inverse) ; lus à 0. Le registre de base reste RW. |
| REG-11 | Une écriture qui déclenche une action (émission d'un octet…) se fait par un registre en écriture seule avec impulsion (`swmod`), jamais par un bit à remettre à 0 par logiciel. |

## 5. Nommage et description

| Règle | Contenu |
|---|---|
| REG-12 | Noms de registres et de champs en majuscules, courts, sans le préfixe de l'IP (`CTRL`, `DOUT`, `IS`) : le préfixe est ajouté par la couche C générée. Un champ d'un bit par broche ou par source porte le nom de la grandeur (`RX_VALID`, et non `BIT2`). |
| REG-13 | Toute IP nouvelle décrit ses registres en SystemRDL (`regs/<ip>.rdl`) et inclut `sf_common.rdl` (§7) ; `name` et `desc` en anglais (ils produisent les commentaires du C). Une IP dont le banc est écrit à la main suit la même carte et documente ses registres dans sa DS. |

## 6. Vérification

| Règle | Contenu |
|---|---|
| REG-14 | Les tests de l'IP vérifient au minimum : valeurs de reset, `ID`/`VERSION`/`CAPS` (et qu'une écriture ne les modifie pas), lecture-écriture des registres RW, W1C de `IS`, **événement simultané à un acquittement, d'un autre bit et du même bit (REG-8a)**, alias SET/CLR/TGL, lecture à 0 d'un offset non décodé et absence de repliement : une lecture en `0x1F0` (au-delà de `0x0FF`) renvoie 0 et non `ID` (REG-1). |

## 7. Mise en œuvre SystemRDL

`regmap/sf_common.rdl` (sf-tools) fournit les types du bloc d'identification et les types de champs d'interruption (`sf_event_f` : W1C, `hwset`, `precedence = hw` ; `sf_level_f` : RO piloté par le matériel) ; `bin/gen_regs.sh` l'ajoute au chemin d'inclusion :

```systemverilog
`include "sf_common.rdl"

addrmap uart_regs {
	default regwidth = 32;
	…registres fonctionnels à partir de 0x00…

	sf_id_t      #(.P_IP_NUM(2))                              ID      @ 0xF0;
	sf_version_t #(.P_MAJOR(0), .P_MINOR(1), .P_PATCH(0))     VERSION @ 0xF4;
	reg { name = "Capabilities"; sf_param_f TX_FIFO_DEPTH_LOG2[3:0]; TX_FIFO_DEPTH_LOG2->desc = "…"; } CAPS @ 0xF8;   // câblé depuis un paramètre

	signal { desc = "Reset value of BAUD.DIV."; activehigh; } baud_div_reset[20];
	reg { name = "Baud"; field { desc = "…"; sw = rw; hw = r; } DIV[19:0]; DIV->reset = baud_div_reset; } BAUD @ 0x08;

	reg { name = "Interrupt status";
		sf_event_f RX_OVERRUN[5:5] = 0;     sf_level_f RX_READY[0:0];
		RX_OVERRUN->desc = "…";            RX_READY->desc = "…"; } IS @ 0x24;
};
```

**Valeur de reset dépendant d'un paramètre** (ex. diviseur de débit calculé depuis la fréquence d'horloge) : un `signal` RDL de la largeur du champ et `<CHAMP>->reset = <signal>` ; PeakRDL-regblock en fait une entrée `hwif_in.<signal>`, chargée au reset, que le top câble depuis ses paramètres. La couche C ne donne alors pas de valeur de reset pour ce champ ni pour son registre.

La couche C générée fournit les valeurs attendues (`<IP>_ID_VENDOR_RESET`, `<IP>_ID_IP_NUM_RESET`) pour le contrôle REG-6, et la taille de la fenêtre décodée (`<IP>_ADDR_WINDOW`, `0x1000U`). `gen_regs.sh` génère un port de 12 bits (`--addr-width`, défaut 12).

## 8. Historique

| Version | Date | Changements |
|---|---|---|
| 1.0 | 2026-10-23 | (sf-tools 0.7.1 : REG-8a cite aussi BUG-RTL-007 ; REG-14 précise les deux cas d'acquittement.) Création : carte (REG-1 à 3), bloc d'identification `0xF0`–`0xFF` (REG-4 à 6), interruptions `IE`/`IS` avec types de bits et non-perte des événements (REG-7 à 9), alias SET/CLR/TGL (REG-10, 11), nommage (REG-12, 13), tests minimaux (REG-14). Types de bits et REG-8a repris de IP002-DS-v1.0 (brouillon) |
| 1.1 | 2026-10-23 | REG-1 : port d'adresse de 12 bits (4 Ko) décodé sur toute sa largeur, pas de repliement dans le segment AXI ; REG-2 : 60 registres fonctionnels, extension à partir de `0x100` ; REG-14 : test de non-repliement en `0x1F0` |
| 1.2 | 2026-10-23 | REG-4 : champs de `CAPS` fixés par un paramètre de synthèse (`sf_param_f`, câblés en constante) ; REG-9 : `IC_<qualif>` pour la configuration propre aux sources seulement ; §7 : reset dépendant d'un paramètre (`signal` RDL). Questions de IP002-DS-v1.0 (P-01, P-25, P-26) |
