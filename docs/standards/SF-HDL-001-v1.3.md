# SF-HDL-001-v1.3 — Norme de codage RTL (SystemVerilog)

| Champ      | Valeur                                            |
|------------|---------------------------------------------------|
| Auteur     | Gaël BOYA                                         |
| Date       | 2026-10-22                                        |
| Statut     | APPLICABLE                                        |
| Portée     | Projets siliconforge qui la déclarent dans `sf-project.env` (`HDL_STANDARD=SF-HDL-001`), profil SV-synth (HDL-7.5) |
| Références | SF-CS-001 (norme C), outils `sf-tools` (contrôle automatique, §10) |

> Un projet antérieur à la norme n'a pas à être migré. Un projet peut déroger à une règle s'il le justifie dans sa documentation (et, pour le contrôle automatique, par une dérogation en ligne, §10).

Les règles sont numérotées `HDL-<section>.<n>` pour pouvoir être citées dans une revue (`reviewer-rtl`).

---

## 1. Fichiers

| Règle | Contenu |
|---|---|
| HDL-1.1 | Un module (ou package, ou interface) par fichier ; nom du fichier = nom de l'unité. |
| HDL-1.2 | Extensions : `.sv` (RTL et testbench), `.svh` (fichiers inclus). Pas de nouveau `.v`. |
| HDL-1.3 | Identifiants en anglais, `snake_case`. Commentaires en français. |
| HDL-1.4 | RTL dans `src/` (sous-dossiers autorisés par sous-bloc : `src/cpu/`, `src/bus/`…). Vérification dans `sim/`. |
| HDL-1.5 | Encodage UTF-8, fins de ligne LF, indentation par **tabulation** (largeur d'affichage 4, fixée par `.editorconfig`). |
| HDL-1.6 | **Code généré** (banc de registres PeakRDL, en-têtes, IP-XACT…) : dans un dossier `gen/` (`src/gen/`, `sw/gen/`, `docs/gen/`) ou `ipxact/`, **jamais édité à la main** ; on modifie la source (`regs/<ip>.rdl`) et on régénère. Les fichiers générés sont commités avec leur source. Les règles SF-HDL-001 et les restrictions de constructions (HDL-7.5) ne s'y appliquent pas ; ils doivent en revanche passer Verilator, Yosys + slang et Vivado, et sont toujours instanciés derrière un module écrit à la main dont les ports sont conformes. |

## 2. Nommage des modules

| Règle | Contenu | Exemple |
|---|---|---|
| HDL-2.1 | Tout module d'une IP commence par le **nom court de l'IP**. | `uart_tx`, `uart_rx`, `uart_baudgen` |
| HDL-2.2 | Une IP à **plusieurs modules** a un top `<ip>_top`. Une IP à un seul module n'a pas de `_top`. | `uart_top` ; `clk_div` seul |
| HDL-2.3 | Suffixes de rôle (liste fermée) : `_top`, `_ctrl` (contrôleur), `_regs` (banc de registres/CSR), `_fsm`, `_dp` (chemin de données), `_<bus>_wrapper` (adaptation à un bus). | `uart_regs`, `gpio_ctrl_axi_wrapper` |
| HDL-2.4 | Top de carte : `<carte>_top`. | `arty_z7_20_top` |
| HDL-2.5 | Bibliothèque commune (dépôt `rtl-common`) : préfixe `cmn_`. Ces modules sont référencés, jamais recopiés. | `cmn_sync_2ff`, `cmn_edge_detect`, `cmn_fifo_sync` |
| HDL-2.6 | Préfixe `sf_` / `SF_` réservé au niveau « siliconforge » : package global `sf_pkg`, macros globales `SF_*`, vendeur/bibliothèque dans l'IP Packager Vivado. | `sf_pkg::bool_t` |
| HDL-2.7 | Packages et interfaces : suffixes `_pkg`, `_if`. | `uart_pkg`, `axi4lite_if` |

## 3. Nommage des ports

| Règle | Contenu | Exemple |
|---|---|---|
| HDL-3.1 | Suffixe de direction obligatoire : `_i` (entrée), `_o` (sortie), `_io` (bidirectionnel). | `data_i`, `tx_o`, `gpio_io` |
| HDL-3.2 | Horloge `clk_i`, reset synchrone actif bas `rst_n_i`. | |
| HDL-3.3 | Plusieurs domaines : `clk_<dom>_i`, `rst_<dom>_n_i`. | `clk_sys_i`, `rst_sys_n_i` |
| HDL-3.4 | Bus AXI : préfixe `s_axi_` (esclave) / `m_axi_` (maître) + nom du signal AXI + direction, pour l'inférence automatique dans l'IP Packager. | `s_axi_awvalid_i`, `s_axi_awready_o` |
| HDL-3.5 | Ordre des suffixes : **nom → polarité (`_n`) → direction (`_i`/`_o`)**. | `cs_n_o`, `rst_n_i` |

## 4. Nommage des signaux, types et instances

| Règle | Contenu | Exemple |
|---|---|---|
| HDL-4.1 | Registre : `_r` ; valeur suivante : `_next` ; actif bas : `_n`. Ordre : nom → polarité → `_r`. | `state_r`, `state_next`, `cs_n_r` |
| HDL-4.2 | Synchroniseur CDC : `_meta` (1er étage), `_sync` (sortie). | `btn_meta`, `btn_sync` |
| HDL-4.3 | Étages de retard/pipeline : `_d1`, `_d2`… | `valid_d1` |
| HDL-4.4 | Paramètres et `localparam` : `UPPER_SNAKE_CASE`. | `DATA_W`, `CLK_DIV` |
| HDL-4.5 | Types : suffixe `_t`. États de FSM : préfixe `S_`. | `state_t`, `S_IDLE` |
| HDL-4.6 | Instances : `u_<module>` (suffixe `_<n>` si plusieurs). Blocs `generate` : `gen_<nom>`. | `u_uart_tx`, `gen_pins` |
| HDL-4.7 | Macros `` `define `` : préfixe de l'IP en majuscules, et seulement pour ce qu'un `parameter` ne peut pas faire. | `` `UART_DEBUG `` |

## 5. Mise en forme

### 5.1 Déclaration du module

Principe : les champs qui définissent un signal sont lus en colonnes. Exemple (`→` = une tabulation, largeur 4) :

```
→input→logic→→→clk_i,
→input→logic→[7:0]→data_i,→→→→// octet à émettre
→output→logic→→→tx_o
```

donne à l'affichage :

```
    input   logic           clk_i,
    input   logic   [7:0]   data_i,             // octet à émettre
    output  logic           tx_o
```

| Règle | Contenu |
|---|---|
| HDL-5.1 | Colonnes **direction → type → largeur → nom**, séparées par **une ou plusieurs tabulations** : le nombre de tabulations varie d'une ligne à l'autre pour que chaque champ commence à la **même colonne** dans tout le bloc (affichage en largeur 4). La colonne largeur reste présente même pour 1 bit (tabulations à la place). |
| HDL-5.2 | Virgule **en fin de ligne**, collée au nom ; pas de virgule après le dernier port. |
| HDL-5.3 | Ports regroupés par interface, chaque groupe précédé d'un commentaire (`// Horloge et reset`, `// Interface AXI4-Lite`…). Commentaire de fin de ligne pour décrire un port si besoin. |
| HDL-5.4 | Paramètres dans `#( … )`, une ligne par paramètre, même alignement : `parameter → type → nom → = valeur`. |

### 5.2 Corps du module

| Règle | Contenu |
|---|---|
| HDL-5.5 | Tout le corps est indenté d'**une tabulation** par rapport à `module` ; une ligne vide après `);` et avant `endmodule`. |
| HDL-5.6 | Fin de module : `endmodule : <nom_du_module>` (idem `endpackage : <nom>`, `endinterface : <nom>`). |
| HDL-5.7 | `` `default_nettype none `` avant `module`, `` `default_nettype wire `` après `endmodule`. |
| HDL-5.8 | Même principe d'alignement pour les **déclarations de signaux internes** (type → largeur → nom), les paramètres (`parameter` → type → nom → `= valeur`) et les commentaires de fin de ligne d'un même bloc. Dans un bloc d'affectations, les `<=` / `=` sont alignés de la même façon. `begin` sur la même ligne que `if`/`else`/`always_ff`. |
| HDL-5.9 | Une instruction par ligne (exception : `case` dont chaque branche tient sur une ligne). |

## 6. Commentaires

### 6.1 En-tête de fichier (obligatoire)

```systemverilog
// ============================================================
// Module      : uart_tx
// IP          : IP002 uart
// Description : Émetteur série 8N1, débit fixé par CLK_DIV
// Référence   : IP002-DS-v1.0 §4.2, IP002-TS-v1.0 §2
// ============================================================
```

Pas d'auteur ni de date dans l'en-tête : git les connaît, et ils deviennent faux.

### 6.2 Séparateurs de sections

Deux niveaux seulement :

```systemverilog
	// ============================================================
	// FSM D'ÉMISSION                          ← niveau 1, majuscules
	// ============================================================

	// ---- Compteur de bits ----              ← niveau 2
```

Ordre des sections de niveau 1 dans un module (omettre celles qui sont vides) :

1. `TYPES ET CONSTANTES` (typedef, localparam)
2. `SIGNAUX INTERNES`
3. `LOGIQUE SÉQUENTIELLE` / un bloc par fonction (`FSM …`, `REGISTRES …`)
4. `LOGIQUE COMBINATOIRE`
5. `INSTANCES`
6. `SORTIES`
7. `ASSERTIONS` (sous `` `ifndef SYNTHESIS ``)

### 6.3 Commentaires de ligne ou de portion de code

| Règle | Contenu |
|---|---|
| HDL-6.1 | Expliquer le **pourquoi** (choix, contrainte, cas limite), pas le *quoi* que le code dit déjà. |
| HDL-6.2 | Citer la spec quand une ligne implémente une exigence précise : `// DS §5.3 : W1C`, `// REQ-012`. |
| HDL-6.3 | Commentaire de fin de ligne aligné par tabulation ; au-dessus du code si plus d'une ligne. |
| HDL-6.4 | Étiquettes normalisées, en majuscules suivies de `:` : `TODO:` (à faire), `FIXME:` (connu faux), `NOTE:` (subtilité), `BUG-RTL-xxx:` (référence au TR). `TODO`/`FIXME` interdits dans un tag de release. |
| HDL-6.5 | Dérogation lint : `/* verilator lint_off <RÈGLE> */ … /* verilator lint_on <RÈGLE> */` avec, sur la ligne au-dessus, la raison. |
| HDL-6.6 | Pas de code commenté dans `src/` : git garde l'historique. |

## 7. Constructions

Règles de sens (ce que le code fait), complémentaires de la mise en forme. HDL-7.5 définit le **profil SV-synth** : le sous-ensemble de SystemVerilog accepté par toute la chaîne (Verilator, Icarus 12, Yosys + slang, Vivado, LibreLane avec `USE_SLANG`).

| Règle | Contenu |
|---|---|
| HDL-7.1 | Toute `function` ou `task` est **`automatic`**, avec un type de retour explicite : `function automatic logic [7:0] merge(input logic [7:0] cur);`. Dans un module comme dans un package, une fonction est statique par défaut (Verilog comme SystemVerilog) : ses arguments et variables locales n'existent qu'en un exemplaire, partagé par tous les appels. Appelée depuis plusieurs blocs `always`, elle donne une variable pilotée par plusieurs processus. Verilator `-Wall` et Icarus l'acceptent sans rien dire ; Yosys + slang (frontend du flow ASIC) signale *multiple conflicting drivers*, que le lint siliconforge traite comme une erreur. Cas réel : IP-001, BUG-RTL-008. |
| HDL-7.2 | Logique séquentielle dans `always_ff` (affectations `<=` uniquement) ; logique combinatoire dans `always_comb` (affectations `=` uniquement, valeurs par défaut en tête de bloc). Pas de `always` nu ni `always @(*)` dans `src/`. |
| HDL-7.3 | Pas de latch : tout signal affecté dans un `always_comb` reçoit une valeur sur tous les chemins ; tout `case` a une branche `default`. |
| HDL-7.4 | Reset synchrone actif bas (`rst_n_i`) ; la valeur de reset de chaque registre est documentée dans la DS. |
| HDL-7.5 | **Profil SV-synth** dans `src/` (hors `src/gen/`, HDL-1.6). Autorisés : `logic`, `always_ff`, `always_comb`, `typedef enum`, `localparam`, paramètres typés, `'0`, tableaux packés, `package`/`import`, `typedef struct packed` (y compris dans les ports), `unique`/`priority case`. Interdits : `interface`/`modport` (Icarus 12, et cocotb ne pilote pas une interface en port de top), `struct` non packé, `union`, classes, `initial`, délais `#`, `$display`. Assertions SVA seulement dans `sim/` ou sous `` `ifndef SYNTHESIS ``. Ports du module top : types simples ou `struct packed`. |
| HDL-7.6 | Pas de logique dans les connexions d'instance (pas de `.en_i(~busy)`) : passer par un signal nommé. |

## 8. Exemple complet

```systemverilog
// ============================================================
// Module      : uart_tx
// IP          : IP002 uart
// Description : Émetteur série 8N1, LSB en premier, débit = f(clk_i) / CLK_DIV
// Référence   : IP002-DS-v1.0 §4.2
// ============================================================

`default_nettype none

module uart_tx #(
	parameter	int	unsigned	CLK_DIV	= 16	// cycles d'horloge par bit (>= 2)
) (
	// Horloge et reset
	input	logic			clk_i,
	input	logic			rst_n_i,
	// Flux de données (handshake valid/ready)
	input	logic	[7:0]	data_i,				// octet à émettre
	input	logic			valid_i,
	output	logic			ready_o,
	// Ligne série
	output	logic			tx_o				// au repos à 1
);

	// ============================================================
	// TYPES ET CONSTANTES
	// ============================================================
	localparam	int	unsigned	CNT_W	= $clog2(CLK_DIV);

	typedef enum logic [1:0] {S_IDLE, S_START, S_DATA, S_STOP} state_t;

	// ============================================================
	// SIGNAUX INTERNES
	// ============================================================
	state_t				state_r, state_next;
	logic	[CNT_W-1:0]	baud_cnt_r, baud_cnt_next;
	logic	[2:0]		bit_cnt_r, bit_cnt_next;
	logic	[7:0]		shift_r, shift_next;
	logic				baud_tick;

	// ============================================================
	// LOGIQUE SÉQUENTIELLE
	// ============================================================
	always_ff @(posedge clk_i) begin
		if (!rst_n_i) begin
			state_r		<= S_IDLE;
			baud_cnt_r	<= '0;
			bit_cnt_r	<= '0;
			shift_r		<= '0;
		end else begin
			state_r		<= state_next;
			baud_cnt_r	<= baud_cnt_next;
			bit_cnt_r	<= bit_cnt_next;
			shift_r		<= shift_next;
		end
	end

	// ============================================================
	// LOGIQUE COMBINATOIRE
	// ============================================================

	// ---- Générateur de débit ----
	assign baud_tick	= (baud_cnt_r == CNT_W'(CLK_DIV - 1));

	always_comb begin
		// NOTE: compteur maintenu à 0 au repos pour que le bit de start dure exactement CLK_DIV cycles
		if (state_r == S_IDLE || baud_tick) begin
			baud_cnt_next	= '0;
		end else begin
			baud_cnt_next	= baud_cnt_r + 1'b1;
		end
	end

	// ---- FSM d'émission ----
	always_comb begin
		state_next		= state_r;
		bit_cnt_next	= bit_cnt_r;
		shift_next		= shift_r;
		unique case (state_r)
			S_IDLE: begin
				if (valid_i) begin
					state_next	= S_START;
					shift_next	= data_i;
				end
			end
			S_START: begin
				if (baud_tick) begin
					state_next		= S_DATA;
					bit_cnt_next	= '0;
				end
			end
			S_DATA: begin
				if (baud_tick) begin
					shift_next		= {1'b0, shift_r[7:1]};	// DS §4.2 : LSB en premier
					bit_cnt_next	= bit_cnt_r + 1'b1;
					if (bit_cnt_r == 3'd7) begin
						state_next	= S_STOP;
					end
				end
			end
			S_STOP:		if (baud_tick) state_next = S_IDLE;
			default:	state_next = S_IDLE;
		endcase
	end

	// ============================================================
	// SORTIES
	// ============================================================
	assign ready_o	= (state_r == S_IDLE);
	assign tx_o		= (state_r == S_START) ? 1'b0
					: (state_r == S_DATA)  ? shift_r[0]
					: 1'b1;

endmodule : uart_tx

`default_nettype wire
```

Exemple vérifié : lint 3 passes sans warning, trame 8N1 validée en cocotb sur Icarus et Verilator.
Le modèle vierge correspondant est `templates/module.sv` de sf-tools.

## 9. Compatibilité outils (vérifiée le 2026-10-19)

`endmodule : <nom>`, ports alignés par tabulations et suffixes `_i`/`_o` : acceptés par Verilator 5.052 (`-Wall`), Icarus 12 et 14-dev (`-g2012`), Yosys 0.70 + slang. Non valide en Verilog-2005 : ces règles supposent le profil SV-synth.

HDL-7.1 (vérifiée le 2026-10-21) : fonction statique appelée depuis deux `always_ff` → aucun message de Verilator 5.052 `-Wall` ni d'Icarus 12 ; `Warning: multiple conflicting drivers` avec Yosys 0.70 + slang. Version `automatic` : propre sur les trois outils.

## 10. Contrôle automatique

Le script `bin/check_style.py` de sf-tools vérifie les règles suivantes sur les fichiers `.sv` :

| Vérifiées | Non vérifiées (revue `reviewer-rtl`) |
|---|---|
| HDL-1.1, 1.3 (noms d'unités), 1.5, 1.6 (exclusion de `gen/` ; le hook refuse l'édition d'un fichier généré) · 2.1 (si le préfixe d'IP est connu), 2.7 · 3.1, 3.2 · 4.1 (cibles de `<=` dans `always_ff`), 4.4, 4.5, 4.6 · 5.1, 5.2, 5.4, 5.5, 5.6, 5.7, 5.8 · 6.1, 6.2, 6.4, 6.6 (heuristique) · 7.1 | 1.2, 1.4 · 2.2 à 2.6 · 3.3 à 3.5 · 4.2, 4.3, 4.7 · 5.3, 5.9 · 6.3, 6.5 · 7.4 à 7.6 |

- HDL-7.2 et 7.3 sont couvertes par les autres passes du lint : Verilator (`BLKSEQ`, `COMBDLY`, `LATCH`, `CASEINCOMPLETE`) et Yosys (latch, boucle combinatoire, *multiple conflicting drivers*).
- **Activation** : le contrôle s'applique quand le fichier `sf-project.env` à la racine du projet contient `HDL_STANDARD=SF-HDL-001` ; le préfixe d'IP (HDL-2.1) y est lu dans `IP_PREFIX=<ip>`. (Repli pour les projets plus anciens : un `CLAUDE.md` racine avec la ligne `| Norme de codage | SF-HDL-001 … |` et une ligne `| Préfixe IP | `<ip>` |` ; une simple mention du nom ne suffit pas.)
- **Où** : 4ᵉ passe de `bin/lint.sh` (`make lint`, échec en cas d'écart) ; avec le plugin Claude Code siliconforge, aussi après chaque écriture d'un `.sv` sous `src/`/`rtl/`.
- **Dérogation** : `// sf-hdl: waive HDL-x.y raison` sur la ligne concernée ou celle du dessus ; `// sf-hdl: waive-file HDL-x.y raison` pour tout le fichier. La raison est obligatoire (vérifiée en revue).
- **Forcer / couper** : `lint.sh --style` (même sans déclaration), `lint.sh --no-style`.
- Analyse par expressions régulières : elle suppose du code proche de la norme (déclarations ANSI, une déclaration par ligne) et ne remplace pas la revue.

## 11. Historique

| Version | Date | Changements |
|---|---|---|
| 1.0 | 2026-10-19 | Création ; HDL-5.1/5.8 précisées (tabulations multiples pour aligner les champs) ; §9 contrôle automatique |
| 1.1 | 2026-10-21 | §7 Constructions : HDL-7.1 fonctions et tâches `automatic` (retour d'expérience IP-001 BUG-RTL-008), HDL-7.2 à 7.6 reprises du profil SV-synth ; §8 à §11 renumérotées |
| 1.2 | 2026-10-22 | HDL-1.6 : code généré (dossiers `gen/`), exclu de la norme, jamais édité à la main ; HDL-7.5 précisée |
| 1.3 | 2026-10-22 | Norme autonome, publiée avec sf-tools : profil SV-synth défini dans HDL-7.5 ; activation par `sf-project.env` ; §10 à jour (`bin/check_style.py` de sf-tools) |
