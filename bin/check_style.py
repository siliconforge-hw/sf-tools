#!/usr/bin/env python3
"""Contrôle de la norme SF-HDL-001 sur des fichiers SystemVerilog (.sv).

Usage : check_style.py [--project DIR] [--force] [--ip <prefixe>] [--tab 4] fichier_ou_dossier...

Avec --project, le contrôle ne s'applique que si le projet déclare la norme :
  DIR/sf-project.env : HDL_STANDARD=SF-HDL-001 et IP_PREFIX=<ip>
  (repli pour les projets plus anciens : DIR/CLAUDE.md avec la ligne « | Norme de codage | SF-HDL-001 … | »
  et la ligne « | Préfixe IP | `uart` | »). --force ignore cette condition.
Sortie : une ligne par écart, au format  %Style-HDL-x.y: fichier:ligne: message
Code de sortie : 0 si aucun écart, 1 sinon.

Dérogations (avec une raison, comme pour Verilator) :
  // sf-hdl: waive HDL-5.8 raison          sur la ligne concernée ou la ligne au-dessus
  // sf-hdl: waive-file HDL-2.1 raison     n'importe où dans le fichier

Analyse par expressions régulières : le contrôle suppose du code proche de la
norme (déclarations ANSI, une déclaration par ligne). Il ne remplace pas la revue.
"""

import argparse
import re
import sys
from pathlib import Path

TAB = 4

ID = r"[A-Za-z_]\w*"
RE_UNIT = re.compile(rf"^\s*(module|package|interface)\s+({ID})")
RE_END = re.compile(r"^\s*(endmodule|endpackage|endinterface)\b(.*)$")
RE_PORT = re.compile(r"^\s*(input|output|inout)\b")
RE_PARAM = re.compile(rf"^\s*(parameter|localparam)\b.*?\b({ID})\s*=")
RE_TYPEDEF = re.compile(rf"\btypedef\b.*?\b({ID})\s*;")
RE_ENUM = re.compile(r"\btypedef\s+enum\b[^{]*\{([^}]*)\}\s*(\w+)\s*;")
RE_INST = re.compile(rf"^\s*({ID})\s*(#\s*\(.*)?\s+({ID})\s*\(")
RE_GEN = re.compile(r"\b(for|if)\s*\(.*\)\s*begin\s*(:\s*(\w+))?")
RE_DECL = re.compile(rf"^\t+(logic|wire|bit|int|integer|byte|{ID}_t)\b")
RE_ASSIGN = re.compile(rf"^(\t+)(assign\s+)?{ID}(\[[^\]]*\])*\s*(<=|=)(?!=)")
RE_SECTION = re.compile(r"^\s*//\s*={10,}\s*$")
RE_WAIVE = re.compile(r"sf-hdl:\s*waive\s+(HDL-[\d.]+)")
RE_WAIVE_FILE = re.compile(r"sf-hdl:\s*waive-file\s+(HDL-[\d.]+)")
RE_TAG_BAD = re.compile(r"//\s*(todo|fixme|note)\b(?!:)", re.IGNORECASE)
RE_TAG_LOWER = re.compile(r"//\s*(todo|fixme|note)\s*:")
RE_CODE_IN_COMMENT = re.compile(r"//\s*(assign\s|always|if\s*\(|end\b|\w+\s*<=|\w+\s*=\s*[^=].*;\s*$)")

KEYWORDS = {
    "module", "endmodule", "begin", "end", "if", "else", "case", "unique", "priority", "endcase",
    "always_ff", "always_comb", "always", "assign", "for", "generate", "endgenerate", "function",
    "task", "return", "typedef", "enum", "struct", "package", "import", "input", "output", "inout",
    "logic", "wire", "localparam", "parameter", "default", "initial", "genvar", "assert", "property",
    "interface", "modport", "int", "bit", "string",
}

SECTION_ORDER = [
    "TYPES ET CONSTANTES", "SIGNAUX INTERNES", "LOGIQUE SÉQUENTIELLE", "LOGIQUE COMBINATOIRE",
    "INSTANCES", "SORTIES", "ASSERTIONS",
]


def strip_comment(line):
    """Code sans commentaire de fin de ligne (ignore les // dans les chaînes, rares en RTL)."""
    i = line.find("//")
    return line if i < 0 else line[:i]


def comment_of(line):
    i = line.find("//")
    return "" if i < 0 else line[i:]


def fields(line):
    """Champs de la partie code d'une ligne avec leur colonne d'affichage (tabulations développées)."""
    code = strip_comment(line).rstrip()
    exp = code.expandtabs(TAB)
    out = []
    for m in re.finditer(r"\[[^\]]*\]|[^\s\[]+", exp):
        out.append((m.start(), m.group()))
    return out


def comment_col(line):
    i = line.find("//")
    if i < 0 or not strip_comment(line).strip():
        return None
    return len(line[:i].expandtabs(TAB))


class Checker:
    def __init__(self, path, ip):
        self.path = path
        self.ip = ip
        self.lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        self.issues = []
        text = "\n".join(self.lines)
        self.waived_file = set(RE_WAIVE_FILE.findall(text))

    def report(self, rule, lineno, msg):
        if rule in self.waived_file:
            return
        for ln in (lineno, lineno - 1):
            if 1 <= ln <= len(self.lines):
                m = RE_WAIVE.search(self.lines[ln - 1])
                if m and m.group(1) == rule:
                    return
        self.issues.append((rule, lineno, msg))

    # ------------------------------------------------------------------
    def run(self):
        units = [(i + 1, m.group(1), m.group(2)) for i, l in enumerate(self.lines)
                 if (m := RE_UNIT.match(strip_comment(l)))]
        self.check_file(units)
        self.check_header(units)
        self.check_layout()
        self.check_comments()
        self.check_subprograms()
        for lineno, kind, name in units:
            end = self.find_end(lineno, kind)
            self.check_unit_names(lineno, kind, name)
            self.check_endlabel(end, kind, name)
            if kind == "module":
                self.check_module(lineno, end, name)
        return self.issues

    def find_end(self, start, kind):
        for i in range(start, len(self.lines)):
            m = RE_END.match(strip_comment(self.lines[i]))
            if m and m.group(1) == "end" + kind:
                return i + 1
        return len(self.lines)

    # ---- HDL-1.x ------------------------------------------------------
    def check_file(self, units):
        if not units:
            return
        if len(units) > 1:
            self.report("HDL-1.1", units[1][0], f"plusieurs unités dans le fichier ({', '.join(u[2] for u in units)})")
        if units[0][2] != self.path.stem:
            self.report("HDL-1.1", units[0][0], f"fichier '{self.path.name}' ≠ unité '{units[0][2]}'")

    def check_layout(self):
        for i, l in enumerate(self.lines, 1):
            if re.match(r"^ +\S", l) or re.match(r"^\t* +\t", l):
                self.report("HDL-1.5", i, "indentation par espaces (tabulations attendues)")
            if l != l.rstrip():
                self.report("HDL-1.5", i, "espaces en fin de ligne")

    # ---- HDL-6.1 en-tête ------------------------------------------------
    def check_header(self, units):
        if not units:
            return
        head = self.lines[:8]
        if not head or not RE_SECTION.match(head[0]):
            self.report("HDL-6.1", 1, "en-tête de fichier absent (bloc // ==== en ligne 1)")
            return
        kinds = {"module": "Module", "package": "Package", "interface": "Interface"}
        label = kinds[units[0][1]]
        for key in (label, "Projet|IP", "Description", "Référence"):
            if not any(re.match(rf"^//\s*(?:{key})\s*:", h) for h in head):
                self.report("HDL-6.1", 1, f"en-tête : champ '{key.split('|')[0]}' manquant")
        for h in head:
            m = re.match(rf"^//\s*{label}\s*:\s*(\S+)", h)
            if m and m.group(1) != units[0][2]:
                self.report("HDL-6.1", 1, f"en-tête : '{m.group(1)}' ≠ '{units[0][2]}'")

    # ---- HDL-2.x noms d'unités -----------------------------------------
    def check_unit_names(self, lineno, kind, name):
        if kind == "package" and not name.endswith("_pkg"):
            self.report("HDL-2.7", lineno, f"package '{name}' : suffixe _pkg attendu")
        if kind == "interface" and not name.endswith("_if"):
            self.report("HDL-2.7", lineno, f"interface '{name}' : suffixe _if attendu")
        if kind == "module" and self.ip:
            ok = (name.startswith(self.ip + "_") or name == self.ip
                  or name.startswith("cmn_") or name.endswith("_top"))
            if not ok:
                self.report("HDL-2.1", lineno, f"module '{name}' : préfixe d'IP '{self.ip}_' attendu")
        if not re.fullmatch(r"[a-z][a-z0-9_]*", name):
            self.report("HDL-1.3", lineno, f"'{name}' : snake_case attendu")

    def check_endlabel(self, end, kind, name):
        if end > len(self.lines):
            return
        m = RE_END.match(strip_comment(self.lines[end - 1]))
        if not m:
            return
        label = m.group(2).strip()
        if label != f": {name}" and not re.fullmatch(rf":\s*{name}", label):
            self.report("HDL-5.6", end, f"'end{kind} : {name}' attendu")

    # ---- module ----------------------------------------------------------
    def check_module(self, start, end, name):
        self.check_nettype(start, end)
        hdr_end = start
        for i in range(start - 1, end):
            if re.search(r"\)\s*;", strip_comment(self.lines[i])):
                hdr_end = i + 1
                break
        self.check_params_and_ports(start, hdr_end)
        body = list(range(hdr_end + 1, end))
        self.check_body_indent(body)
        self.check_body_names(body)
        self.check_alignment(body)
        self.check_sections(body)
        if end - 2 >= hdr_end and self.lines[hdr_end].strip() != "":
            self.report("HDL-5.5", hdr_end + 1, "ligne vide attendue après ');'")
        if self.lines[end - 2].strip() != "":
            self.report("HDL-5.5", end - 1, "ligne vide attendue avant endmodule")

    def check_nettype(self, start, end):
        before = [strip_comment(l).strip() for l in self.lines[:start - 1]]
        after = [strip_comment(l).strip() for l in self.lines[end:]]
        if "`default_nettype none" not in before:
            self.report("HDL-5.7", start, "`default_nettype none attendu avant module")
        if "`default_nettype wire" not in after:
            self.report("HDL-5.7", end, "`default_nettype wire attendu après endmodule")

    def check_params_and_ports(self, start, hdr_end):
        ports, params = [], []
        for i in range(start - 1, hdr_end):
            line = self.lines[i]
            code = strip_comment(line)
            if RE_PORT.match(code):
                ports.append(i + 1)
            elif re.match(r"^\s*parameter\b", code):
                params.append(i + 1)
        for ln in params:
            m = RE_PARAM.match(strip_comment(self.lines[ln - 1]))
            if m and not re.fullmatch(r"[A-Z][A-Z0-9_]*", m.group(2)):
                self.report("HDL-4.4", ln, f"paramètre '{m.group(2)}' : UPPER_SNAKE_CASE attendu")
        for idx, ln in enumerate(ports):
            line = self.lines[ln - 1]
            code = strip_comment(line).rstrip()
            direction = RE_PORT.match(code).group(1)
            names = [n.strip() for n in re.sub(r"\[[^\]]*\]", " ", code).split(",") if n.strip()]
            pname = names[-1].split()[-1] if names else ""
            suffix = {"input": "_i", "output": "_o", "inout": "_io"}[direction]
            if not pname.endswith(suffix):
                self.report("HDL-3.1", ln, f"port {direction} '{pname}' : suffixe {suffix} attendu")
            if "clk" in pname and direction == "input" and not re.fullmatch(r"clk(_[a-z0-9]+)?_i", pname):
                self.report("HDL-3.2", ln, f"horloge '{pname}' : clk_i ou clk_<dom>_i attendu")
            if re.match(r"^(rst|reset)", pname) and not re.fullmatch(r"rst(_[a-z0-9]+)?_n_i", pname):
                self.report("HDL-3.2", ln, f"reset '{pname}' : rst_n_i ou rst_<dom>_n_i attendu (actif bas)")
            last = idx == len(ports) - 1
            if last and code.endswith(","):
                self.report("HDL-5.2", ln, "pas de virgule après le dernier port")
            if not last and not code.endswith(","):
                self.report("HDL-5.2", ln, "virgule attendue en fin de ligne")
            if re.search(r"\s,", code):
                self.report("HDL-5.2", ln, "virgule collée au nom attendue")
            if not line.startswith("\t") or line.startswith("\t\t"):
                self.report("HDL-5.1", ln, "port indenté d'une tabulation attendu")
        self.check_columns(ports, "HDL-5.1", "ports", "port")
        self.check_columns(params, "HDL-5.4", "paramètres", "param")

    def check_columns(self, lines, rule, what, mode="port"):
        """Même colonne pour chaque champ d'un bloc.

        mode port  : direction → type → [largeur] → nom (premier nom)
        mode param : parameter → type… → nom (avant '=')
        mode decl  : type → [largeur] → nom (premier nom)
        Le commentaire de fin de ligne est aussi aligné.
        """
        if len(lines) < 2:
            return
        lead = {"port": 2, "param": 1, "decl": 1}[mode]
        mods = {"signed", "unsigned"}
        name_cols, width_cols, type_cols, cmt_cols = {}, {}, {}, {}
        for ln in lines:
            code = re.sub(r"\[[^\]]*\]", "[]", strip_comment(self.lines[ln - 1]))
            head = re.split(r"[,;=]", code)[0].strip()
            if re.search(r"\S +\S", head):
                self.report(rule, ln, f"{what} : champs séparés par des espaces (tabulations attendues)")
            f = fields(self.lines[ln - 1])
            if len(f) <= lead:
                continue
            if mode != "decl":
                type_cols[ln] = f[1][0]
            widths = [c for c, t in f[lead:] if t.startswith("[")]
            if widths:
                width_cols[ln] = widths[0]
            if mode == "param":
                toks = [t for _, t in f]
                if "=" in toks and toks.index("=") > 0:
                    name_cols[ln] = f[toks.index("=") - 1][0]
            else:
                rest = [(c, t) for c, t in f[lead:] if not t.startswith("[") and t not in mods]
                if rest:
                    name_cols[ln] = rest[0][0]
            cc = comment_col(self.lines[ln - 1])
            if cc is not None:
                cmt_cols[ln] = cc
        for label, cols in (("type", type_cols), ("largeur", width_cols), ("nom", name_cols), ("commentaire", cmt_cols)):
            if len(set(cols.values())) > 1:
                ref = max(set(cols.values()), key=list(cols.values()).count)
                for ln, c in cols.items():
                    if c != ref:
                        self.report(rule, ln, f"{what} : colonne '{label}' non alignée ({c + 1} au lieu de {ref + 1})")

    def check_body_indent(self, body):
        for ln in body:
            line = self.lines[ln - 1]
            if line.strip() and not line.startswith("\t"):
                self.report("HDL-5.5", ln, "corps du module : une tabulation d'indentation attendue")

    def check_body_names(self, body):
        in_ff, depth = False, 0
        for ln in body:
            code = strip_comment(self.lines[ln - 1])
            for m in re.finditer(rf"\b(localparam)\b.*?\b({ID})\s*=", code):
                if not re.fullmatch(r"[A-Z][A-Z0-9_]*", m.group(2)):
                    self.report("HDL-4.4", ln, f"localparam '{m.group(2)}' : UPPER_SNAKE_CASE attendu")
            m = RE_TYPEDEF.search(code)
            if m and not m.group(1).endswith("_t"):
                self.report("HDL-4.5", ln, f"type '{m.group(1)}' : suffixe _t attendu")
            m = RE_ENUM.search(code)
            if m and "state" in m.group(2):
                for v in [x.strip().split("=")[0].strip() for x in m.group(1).split(",")]:
                    if v and not v.startswith("S_"):
                        self.report("HDL-4.5", ln, f"état '{v}' : préfixe S_ attendu")
            m = RE_INST.match(code)
            if m and m.group(1) not in KEYWORDS and m.group(3) not in KEYWORDS and not m.group(3).startswith("u_"):
                self.report("HDL-4.6", ln, f"instance '{m.group(3)}' : préfixe u_ attendu")
            m = RE_GEN.search(code)
            if m and re.search(r"\bgenvar\b|\bfor\s*\(\s*genvar", code) and not (m.group(3) or "").startswith("gen_"):
                self.report("HDL-4.6", ln, "bloc generate : étiquette 'begin : gen_<nom>' attendue")
            # registres (cibles de <= dans always_ff)
            if re.search(r"\balways_ff\b", code):
                in_ff, depth = True, 0
            if in_ff:
                depth += len(re.findall(r"\bbegin\b", code)) - len(re.findall(r"\bend\b", code))
                for t in re.findall(rf"({ID})(?:\[[^\]]*\])*\s*<=", code):
                    if not re.search(r"(_r|_meta|_sync|_d\d+)$", t):
                        self.report("HDL-4.1", ln, f"registre '{t}' : suffixe _r (ou _meta/_sync/_dN) attendu")
                if depth <= 0 and re.search(r"\bend\b", code):
                    in_ff = False

    def runs(self, body, pred):
        """Groupes de lignes consécutives (sans ligne vide) vérifiant pred, même indentation."""
        cur, out, indent = [], [], None
        for ln in body:
            line = self.lines[ln - 1]
            ind = len(line) - len(line.lstrip("\t"))
            if pred(line) and (indent is None or ind == indent):
                cur.append(ln)
                indent = ind
            else:
                if len(cur) > 1:
                    out.append(cur)
                cur, indent = ([ln], ind) if pred(line) else ([], None)
        if len(cur) > 1:
            out.append(cur)
        return out

    def check_alignment(self, body):
        for run in self.runs(body, lambda l: bool(RE_DECL.match(strip_comment(l)))):
            self.check_columns(run, "HDL-5.8", "déclarations", "decl")
        for run in self.runs(body, lambda l: bool(RE_ASSIGN.match(strip_comment(l)))):
            cols = {}
            for ln in run:
                code = strip_comment(self.lines[ln - 1]).expandtabs(TAB)
                m = re.search(r"<=|(?<![=!<>])=(?!=)", code)
                if m:
                    cols[ln] = m.start()
            if len(set(cols.values())) > 1:
                ref = max(set(cols.values()), key=list(cols.values()).count)
                for ln, c in cols.items():
                    if c != ref:
                        self.report("HDL-5.8", ln, f"affectations : opérateur non aligné ({c + 1} au lieu de {ref + 1})")

    def check_sections(self, body):
        titles = []
        for k in range(len(body) - 2):
            a, b, c = (self.lines[body[k] - 1], self.lines[body[k + 1] - 1], self.lines[body[k + 2] - 1])
            if RE_SECTION.match(a) and RE_SECTION.match(c):
                t = re.sub(r"^\s*//\s*", "", b).strip()
                titles.append((body[k + 1], t))
                if t != t.upper():
                    self.report("HDL-6.2", body[k + 1], f"section '{t}' : titre en majuscules attendu")
        last = -1
        for ln, t in titles:
            if t in SECTION_ORDER:
                r = SECTION_ORDER.index(t)
                if r < last:
                    self.report("HDL-6.2", ln, f"section '{t}' hors ordre ({' → '.join(SECTION_ORDER)})")
                last = max(last, r)

    # ---- HDL-7.1 fonctions et tâches ------------------------------------------
    def check_subprograms(self):
        for i, l in enumerate(self.lines, 1):
            code = strip_comment(l)
            m = re.match(r"^\s*(function|task)\b(.*)$", code)
            if not m:
                continue
            kind, rest = m.group(1), m.group(2)
            if not re.match(r"\s+automatic\b", rest):
                self.report("HDL-7.1", i, f"{kind} statique : '{kind} automatic' attendu "
                                          "(arguments partagés entre appels → multiple drivers)")
            elif kind == "function" and re.match(r"\s+automatic\s+(\[|\w+\s*[(;])", rest):
                self.report("HDL-7.1", i, "function : type de retour explicite attendu "
                                          "(function automatic logic [N:0] nom(...))")

    # ---- HDL-6.x commentaires ---------------------------------------------
    def check_comments(self):
        for i, l in enumerate(self.lines, 1):
            c = comment_of(l)
            if not c or "sf-hdl:" in c or "lint_" in c:
                continue
            if RE_TAG_BAD.search(c) or RE_TAG_LOWER.search(c):
                self.report("HDL-6.4", i, "étiquette attendue en majuscules suivie de ':' (TODO:, FIXME:, NOTE:)")
            if not strip_comment(l).strip() and RE_CODE_IN_COMMENT.search(c):
                self.report("HDL-6.6", i, "code commenté")


def read_project_env(root):
    """Clés CLE=valeur de <root>/sf-project.env (commentaires et lignes vides ignorés)."""
    f = Path(root) / "sf-project.env"
    values = {}
    if f.is_file():
        for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
            m = re.match(r"^\s*([A-Z_][A-Z0-9_]*)=([^#]*)", line)
            if m:
                values[m.group(1)] = m.group(2).strip()
    return values


def project_config(root):
    """(norme déclarée ?, préfixe d'IP) d'après sf-project.env, sinon <root>/CLAUDE.md (jamais un parent)."""
    env = read_project_env(root)
    if env:
        return "SF-HDL-001" in env.get("HDL_STANDARD", ""), env.get("IP_PREFIX") or None
    f = Path(root) / "CLAUDE.md"
    if not f.is_file():
        return False, None
    text = f.read_text(encoding="utf-8", errors="replace")
    m = re.search(r"^\|\s*Préfixe IP\s*\|\s*`?([a-z][a-z0-9_]*)`?\s*\|", text, re.MULTILINE)
    # repli : la ligne du modèle « | Norme de codage | SF-HDL-001 … | », pas une simple mention du nom
    declared = re.search(r"^\|\s*Norme de codage\s*\|[^|\n]*SF-HDL-001", text, re.MULTILINE) is not None
    return declared, (m.group(1) if m else None)


def main():
    global TAB
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ip", help="préfixe d'IP attendu pour les modules (HDL-2.1)")
    ap.add_argument("--tab", type=int, default=4)
    ap.add_argument("--project", help="racine du projet : contrôle seulement si sf-project.env (ou CLAUDE.md) déclare SF-HDL-001")
    ap.add_argument("--force", action="store_true", help="contrôler même si la norme n'est pas déclarée")
    ap.add_argument("paths", nargs="+")
    a = ap.parse_args()
    TAB = a.tab
    if a.project:
        declared, ip = project_config(a.project)
        if not declared and not a.force:
            print("   -> norme SF-HDL-001 non déclarée (sf-project.env : HDL_STANDARD) : contrôle ignoré", file=sys.stderr)
            return 0
        a.ip = a.ip or ip
    if not a.ip:
        print("   (préfixe d'IP inconnu : HDL-2.1 non vérifiée ; renseigner IP_PREFIX dans sf-project.env)", file=sys.stderr)
    files = []
    for p in map(Path, a.paths):
        files += sorted(p.rglob("*.sv")) if p.is_dir() else [p]
    files = [f for f in files if "gen" not in f.parts]
    total = 0
    for f in files:
        if f.suffix != ".sv":
            continue
        if "gen" in f.parts:        # HDL-1.6 : code généré, hors norme
            continue
        for rule, ln, msg in sorted(Checker(f, a.ip).run(), key=lambda x: x[1]):
            print(f"%Style-{rule}: {f}:{ln}: {msg}")
            total += 1
    print(f"   -> {total} écart(s) SF-HDL-001 sur {len([f for f in files if f.suffix == '.sv'])} fichier(s)", file=sys.stderr)
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
