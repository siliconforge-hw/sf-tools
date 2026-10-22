# SF-CS-001-v1.0 — Norme de codage C embarqué (drivers et firmware)

| Champ           | Valeur                                                        |
|-----------------|---------------------------------------------------------------|
| ID              | SF-CS-001                                                     |
| Type            | Norme de codage (commune à tous les projets siliconforge)     |
| Statut          | FINAL                                                         |
| Auteur          | Gaël BOYA                                                     |
| Date            | 2026-10-14                                                    |
| Langage         | C99 (ISO/IEC 9899:1999)                                       |
| Bases           | MISRA C:2012 (règles de sûreté) + BARR-C:2018 (style)         |
| Outillage       | GCC (warnings stricts), cppcheck + addon MISRA, clang-format  |
| Première application | IP-001 `sw/drivers/gpio_ctrl` v1.2.0                     |

---

## 1. Objet et portée

Cette norme s'applique au **code C de production** des projets siliconforge :

| Code                                              | Norme applicable                          |
|---------------------------------------------------|-------------------------------------------|
| Drivers bare-metal d'IP (`sw/drivers/<ip>/`)      | **Intégrale** (§3 à §7)                    |
| Firmware et applications (`sw/apps/`)             | Intégrale, sauf code fourni par un BSP tiers |
| Code de test (`sw/drivers/<ip>/test/`, testbenches C++) | Allégée (§8)                        |
| Drivers Linux (noyau)                             | **Hors portée** : Linux kernel coding style + `checkpatch.pl` |
| Code tiers (BSP Xilinx, bibliothèques)            | Hors portée, non modifié                  |

---

## 2. Références

| Réf.          | Document                                                                 |
|---------------|--------------------------------------------------------------------------|
| [C99]         | ISO/IEC 9899:1999 — Programming languages — C                            |
| [MISRA]       | MISRA C:2012 — Guidelines for the use of the C language in critical systems (avec amendements ; contenu repris dans MISRA C:2023) |
| [BARR]        | Barr Group — Embedded C Coding Standard, BARR-C:2018                     |
| [CPPCHECK]    | cppcheck — addon `misra.py`                                              |

Le texte des règles MISRA est payant et n'est pas reproduit ici : seuls les
numéros de règles sont cités.

---

## 3. Principes

### 3.1 Hiérarchie

En cas de conflit, l'ordre de priorité est :

1. Règles **Mandatory** et **Required** de [MISRA] ;
2. Règles projet **SF-xxx** de ce document (§5) ;
3. Règles **Advisory** de [MISRA] ;
4. Règles de style de [BARR].

### 3.2 Application des catégories MISRA

| Catégorie MISRA | Application                                                        |
|-----------------|--------------------------------------------------------------------|
| Mandatory       | Toujours respectée. Aucune déviation possible.                     |
| Required        | Respectée. Déviation possible uniquement par fiche formelle (§6), avec revue. |
| Advisory        | Respectée par défaut. Déviation possible par fiche (§6).            |

### 3.3 Objectif mesurable

Un driver est **conforme** quand `make sw-lint` ne rapporte **aucune**
violation hors déviations enregistrées, et que la compilation stricte (§5.10)
ne produit aucun warning.

> cppcheck ne vérifie qu'une partie des règles MISRA. La conformité outillée
> de cette norme n'est **pas** une certification MISRA. Les règles non
> vérifiables par l'outil sont couvertes par la revue de code.

---

## 4. Organisation d'un driver d'IP

```
sw/drivers/<ip>/
  <ip>_hw.h            Couche matérielle : structure des registres, offsets,
                       vérifications à la compilation, hooks d'accès
  <ip>.h               API publique : types, codes retour, prototypes documentés
  <ip>.c               Implémentation
  test/test_<ip>_host.c  Test hôte contre un modèle de registres
```

`<ip>_hw.h` ne dépend de rien d'autre que `<stdint.h>` / `<stddef.h>` : il doit
pouvoir être utilisé seul (bootloader, test, autre driver).

---

## 5. Règles projet

### 5.1 Fichiers

| ID     | Règle |
|--------|-------|
| SF-001 | Chaque fichier commence par l'en-tête standard : `File`, `Project`, `Description`, `Reference`, `Author`, `Version`. |
| SF-002 | Garde d'inclusion `<NOM_FICHIER>_H` (`GPIO_CTRL_HW_H`). Pas de `#pragma once`. |
| SF-003 | Les headers publics encadrent leurs déclarations par `extern "C"` sous `#ifdef __cplusplus`. |
| SF-004 | Un header n'inclut que ce dont il a besoin pour compiler seul. Un `.c` inclut d'abord son propre header. |

### 5.2 Nommage

| ID     | Règle | Exemple |
|--------|-------|---------|
| SF-010 | Tout identifiant externe est préfixé par le nom du module. | `gpio_ctrl_init` |
| SF-011 | Fonctions et variables : `snake_case` minuscule. | `pin_mask` |
| SF-012 | Types : `snake_case` suffixé `_t`. | `gpio_ctrl_edge_t` |
| SF-013 | Macros et constantes d'énumération : `MAJUSCULES`, préfixées. | `GPIO_CTRL_EDGE_BOTH` |
| SF-014 | Membres de la structure de registres : nom exact de la datasheet, en majuscules. | `regs->IC_RISE` |
| SF-015 | Les constantes non signées portent le suffixe `U` (MISRA 7.2). | `0xFFU`, `1U << pin` |

### 5.3 Types

| ID     | Règle |
|--------|-------|
| SF-020 | Utiliser les types de `<stdint.h>` (`uint32_t`, `int32_t`...). Les types de base `int`, `long`, `short` sont interdits dans l'API et pour les données (MISRA Dir 4.6). |
| SF-021 | Les valeurs booléennes utilisent `bool` (`<stdbool.h>`). Une condition de `if`/`while` est une expression booléenne (MISRA 14.4) : `if (x != 0U)`, jamais `if (x)`. |
| SF-022 | Chaque module définit un type de statut `<ip>_status_t` (`int32_t`) : `0` = succès, valeurs négatives = erreurs nommées. Une fonction ne mélange pas statut et donnée dans sa valeur de retour : la donnée passe par un paramètre de sortie. |
| SF-023 | Pas de conversion vers un type `enum` depuis un entier hors de la plage des énumérateurs. Les conversions entre catégories de types essentiels (signé/non signé/enum/booléen) sont explicites et portent sur une variable, pas sur une expression composée (MISRA 10.8). |

### 5.4 Accès aux registres

| ID     | Règle |
|--------|-------|
| SF-030 | Les registres sont décrits par une structure `<ip>_regs_t` aux membres `volatile uint32_t`, `volatile const` pour les registres en lecture seule. Les offsets sont vérifiés à la compilation contre la datasheet. |
| SF-031 | Tout accès registre du driver passe par les hooks `<IP>_RD(reg)` / `<IP>_WR(reg, val)` (déviation permanente DP-02). |
| SF-032 | Accès 32 bits alignés uniquement. |
| SF-033 | **Au plus un accès registre (volatile) par expression** (MISRA 13.2) : une lecture-modification-écriture passe par une variable locale. |
| SF-034 | Jamais de lecture-modification-écriture sur un registre W1C : on écrit uniquement le masque des bits à acquitter. |
| SF-035 | Dans une routine d'interruption, l'acquittement est suivi d'une relecture du registre avant de rendre la main au contrôleur d'interruptions. |

### 5.5 Fonctions

| ID     | Règle |
|--------|-------|
| SF-040 | Toute fonction publique qui modifie l'état valide ses pointeurs et paramètres et retourne un statut (`<ip>_status_t`) au lieu de planter. Les accesseurs en lecture (`get_*`, `read*`) retournent directement la donnée ; sur instance invalide, ils retournent `0U` sans accéder au matériel, et ce comportement est documenté. |
| SF-041 | Les fonctions internes sont `static`. |
| SF-042 | Paramètres pointeurs `const` quand la fonction ne modifie pas l'objet (MISRA 8.13). |
| SF-043 | Pas de récursivité (MISRA 17.2), pas d'allocation dynamique (MISRA 21.3), pas de `<stdio.h>` dans un driver (MISRA 21.6). |
| SF-044 | La valeur de retour d'une fonction non `void` est utilisée ou explicitement ignorée par `(void)` (MISRA 17.7). |
| SF-045 | Une sortie anticipée n'est autorisée que pour la validation des paramètres en tête de fonction (déviation permanente DP-03). |

### 5.6 Expressions et contrôle

| ID     | Règle |
|--------|-------|
| SF-050 | Accolades sur tous les blocs, même d'une ligne (MISRA 15.6). |
| SF-051 | Tout `switch` a un `default` (MISRA 16.4) ; chaque clause se termine par `break` (MISRA 16.3). |
| SF-052 | Pas de `goto` (MISRA 15.1). |
| SF-053 | Un décalage `1U << n` n'est fait qu'après vérification `n < 32` (MISRA 12.2). |
| SF-054 | Parenthèses explicites dès que deux opérateurs de précédences différentes se suivent (MISRA 12.1). |
| SF-055 | Les paramètres de macro sont parenthésés dans le corps de la macro (MISRA 20.7). |

### 5.7 Interruptions et concurrence

| ID     | Règle |
|--------|-------|
| SF-060 | Une ISR est courte : elle lit, acquitte et notifie. Le traitement se fait hors interruption. |
| SF-061 | Toute variable partagée entre ISR et code principal est `volatile` et son accès est protégé si non atomique. |
| SF-062 | Le header documente, dans une section *Concurrency*, quelles fonctions ne sont pas atomiques. |

### 5.8 Commentaires et documentation

| ID     | Règle |
|--------|-------|
| SF-070 | Code et commentaires de code en anglais ; documents de projet (`docs/`) en français. |
| SF-071 | Chaque fonction publique est documentée dans le header : rôle, paramètres, valeur de retour, contexte d'appel (thread/ISR). |
| SF-072 | Commentaires `//` autorisés (C99, [BARR]). Pas de code mis en commentaire (MISRA Dir 4.4). |

### 5.9 Mise en forme

| ID     | Règle |
|--------|-------|
| SF-080 | La mise en forme est **définie par `.clang-format`** à la racine du dépôt et vérifiée automatiquement. |
| SF-081 | Indentation 4 espaces, pas de tabulation. Largeur maximale **100 colonnes** (choix projet : [BARR] recommande 80). |
| SF-082 | Accolade de fonction sur sa propre ligne ; accolade de bloc de contrôle sur la même ligne. |

### 5.10 Compilation

| ID     | Règle |
|--------|-------|
| SF-090 | Les drivers compilent sans warning avec : `-std=c99 -Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion -Wshadow -Wcast-qual -Wstrict-prototypes -Wmissing-prototypes -Werror`, pour la cible (`arm-none-eabi-gcc`) et l'hôte (`gcc`). |
| SF-091 | Aucune extension de compilateur dans un driver (`__attribute__`, assembleur en ligne...) sauf dans un fichier de portage dédié. |

---

## 6. Déviations

### 6.1 Procédure

Une déviation est enregistrée **avant** d'être acceptée en revue :

| Champ          | Contenu                                              |
|----------------|------------------------------------------------------|
| ID             | `DP-xx` (permanente, ce document) ou `D-<ip>-xx` (propre au driver, note de conformité `docs/<IPID>-TN-xxx`) |
| Règle          | Numéro MISRA et catégorie                            |
| Portée         | Construction, fichier ou macro concernés             |
| Justification  | Pourquoi la règle ne peut pas être respectée         |
| Maîtrise       | Ce qui limite le risque                              |

Dans le code, la ligne concernée est marquée par un commentaire
`// MISRA deviation DP-xx` et, si nécessaire, par une suppression cppcheck
ciblée (`// cppcheck-suppress misra-c2012-x.y`).

### 6.2 Déviations permanentes

Ces déviations découlent de la nature des drivers matériels et s'appliquent à
tous les projets.

| ID    | Règle MISRA        | Portée | Justification | Maîtrise |
|-------|--------------------|--------|---------------|----------|
| DP-01 | 11.4 (Advisory) — conversion entier ↔ pointeur | Macro `<IP>_REGS(base)` uniquement | L'accès à un périphérique mappé en mémoire impose de convertir l'adresse de base en pointeur. | Une seule macro par driver ; adresse validée (≠ 0) à l'initialisation ; structure vérifiée à la compilation (SF-030). |
| DP-02 | Dir 4.9 (Advisory) — macro de type fonction | Hooks `<IP>_RD` / `<IP>_WR` | Ils opèrent sur une *lvalue* (membre de structure) et doivent pouvoir être redirigés vers un modèle de test ou une trace sans modifier le driver. | Corps d'une seule expression, paramètres parenthésés, pas d'effet de bord multiple. |
| DP-03 | 15.5 (Advisory) — point de sortie unique | Validation de paramètres en tête de fonction | Les retours anticipés de validation rendent le code plus lisible que l'imbrication. | Uniquement avant tout accès matériel ou modification d'état. |
| DP-04 | 11.5 (Advisory) — conversion `void *` → pointeur d'objet | Paramètre `ref` des ISR et callbacks | Signature imposée par les contrôleurs d'interruption (`void (*)(void *)`). | Pointeur testé contre `NULL` ; un seul type d'instance par ISR. |
| DP-05 | 20.10 (Advisory) — opérateur `##` ; 2.3 (Advisory) — type non utilisé | Macro `<IP>_STATIC_ASSERT` et ses utilisations | C99 ne fournit pas `_Static_assert`. Le collage de jeton crée un nom de type unique, qui n'est jamais utilisé : seule sa déclaration compte. | Utilisé uniquement pour des vérifications à la compilation. |
| DP-06 | 2.5 (Advisory) — macro non utilisée | Macros publiques des headers (offsets, version, limites) | Elles font partie de l'API destinée aux utilisateurs du driver. | Toutes documentées dans le header. |
| DP-07 | 8.7 (Advisory) — liaison externe | Fonctions de l'API publique | Une bibliothèque expose des fonctions que l'analyse d'un seul module ne voit pas appelées. | Seules les fonctions déclarées dans `<ip>.h` sont externes (SF-041). |

---

## 7. Outillage

### 7.1 Commande

```bash
make sw-lint
```

Elle enchaîne, pour chaque driver :

1. **Compilation stricte** (SF-090) pour l'hôte et la cible ;
2. **cppcheck** avec l'addon MISRA, suppressions limitées aux déviations
   enregistrées (`sw/misra_suppressions.txt`) ;
3. **clang-format** en mode vérification (`--dry-run --Werror`).

Le résultat attendu est vide. Toute violation fait échouer la commande.

### 7.2 Couverture de l'outil

L'addon MISRA de cppcheck ne détecte pas toutes les règles. Constaté avec
cppcheck 2.13 sur un fichier de contrôle :

| Règle                          | Détectée |
|--------------------------------|----------|
| 14.4 (condition non booléenne) | Oui      |
| 15.5 (retours multiples)       | Oui      |
| Dir 4.6 (type `int`)           | **Non**  |
| 12.2 (décalage par une variable non bornée) | **Partiellement** |

Chaque driver a une note de conformité dans `docs/` (TN) qui liste ses
déviations et les règles vérifiées en revue (gpio_ctrl : IP001-TN-003).

Les alertes MISRA de cppcheck ont la sévérité *style* : l'option
`--enable=style` est **obligatoire**, sinon aucune violation n'est affichée.
`make sw-lint` l'active.

### 7.3 Textes des règles

cppcheck affiche les numéros de règles. Pour afficher leur texte, fournir un
fichier de textes issu d'un exemplaire licencié de [MISRA] :
`make sw-lint MISRA_RULES=<fichier>`. Ce fichier ne doit pas être versionné.

---

## 8. Code de test

Le code de test (tests hôtes, modèles de registres, testbenches C++) n'est pas
soumis à MISRA. Il doit :

- compiler sans warning avec SF-090 (sauf `-Wmissing-prototypes`) ;
- passer sans erreur avec AddressSanitizer et UndefinedBehaviorSanitizer ;
- respecter la mise en forme (SF-080).

---

## 9. Historique des révisions

| Version | Date       | Auteur     | Description      |
|---------|------------|------------|------------------|
| 1.0     | 2026-10-14 | Gaël BOYA  | Version initiale |
