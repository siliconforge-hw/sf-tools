#!/usr/bin/env bash
# Configuration des chemins d'outils sf-tools.
# Usage : sf_config.sh                 affiche chaque variable, sa valeur et son origine (env, user, defaults)
#         sf_config.sh --get CLE       affiche la valeur seule (utilisé par les Makefiles)
#         sf_config.sh --init          crée le fichier utilisateur, toutes les lignes commentées
#         sf_config.sh --path          affiche le chemin du fichier utilisateur
set -euo pipefail
source "$(dirname "$0")/sf_env.sh"

keys() { grep -oE '^[A-Z_][A-Z0-9_]*=' "$SF_DEFAULTS" | tr -d '='; }

case "${1:-}" in
	--get)
		[ -n "${2:-}" ] || { echo "sf_config.sh --get CLE" >&2; exit 1; }
		printf '%s\n' "${!2:-}" ;;
	--path)
		printf '%s\n' "$SF_USER_CONFIG" ;;
	--init)
		if [ -e "$SF_USER_CONFIG" ]; then
			echo "existe déjà : $SF_USER_CONFIG"; exit 1
		fi
		mkdir -p "$(dirname "$SF_USER_CONFIG")"
		{
			echo "# Configuration utilisateur sf-tools — décommenter et adapter les lignes qui diffèrent"
			echo "# des valeurs par défaut ($SF_DEFAULTS)."
			echo
			sed -E 's/^([A-Z_][A-Z0-9_]*=)/# \1/' "$SF_DEFAULTS" | grep -vE '^# =|^# (sf-tools|Ne pas|\(`|Priorité|Format)'
		} >"$SF_USER_CONFIG"
		echo "créé : $SF_USER_CONFIG" ;;
	"")
		printf '%-15s %-9s %s\n' CLE ORIGINE VALEUR
		for k in $(keys); do
			src="SF_SOURCE_$k"
			v="${!k:-}"
			flag=""
			case "$k" in TOOLS_ROOT|OSS_CAD|COCOTB_VENV|LIBRELANE|PDK_ROOT) [ -d "$v" ] || flag="  (absent)" ;;
				VITIS_SETTINGS) [ -f "$v" ] || flag="  (absent)" ;;
				*) command -v "$v" >/dev/null 2>&1 || flag="  (absent)" ;; esac
			printf '%-15s %-9s %s%s\n' "$k" "${!src:-?}" "$v" "$flag"
		done
		echo
		echo "fichier utilisateur : $SF_USER_CONFIG $([ -f "$SF_USER_CONFIG" ] && echo '(présent)' || echo '(absent : sf_config.sh --init)')" ;;
	*) sed -n '2,7p' "$0"; exit 1 ;;
esac
