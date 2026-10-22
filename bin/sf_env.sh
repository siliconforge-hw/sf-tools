# shellcheck shell=bash
# Chargeur de configuration sf-tools, à sourcer : `source "$(dirname "$0")/sf_env.sh"`.
# Priorité : variable d'environnement > utilisateur > défauts.
#   défauts      : <sf-tools>/config/defaults.env
#   utilisateur  : ${SF_TOOLS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/sf-tools/config.env}
# Les valeurs brutes des deux fichiers sont d'abord fusionnées, puis développées dans l'ordre des
# défauts : redéfinir TOOLS_ROOT côté utilisateur déplace tous les chemins qui en dépendent.
# Après chargement, SF_SOURCE_<CLE> indique l'origine de chaque valeur (env, user, defaults).

SF_ROOT="${SF_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SF_DEFAULTS="$SF_ROOT/config/defaults.env"
SF_USER_CONFIG="${SF_TOOLS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/sf-tools/config.env}"

declare -gA _SF_RAW=() _SF_ORIGIN=()
declare -ga _SF_ORDER=()

_sf_read() { # fichier origine : valeurs brutes, sans développement
	local file="$1" origin="$2" line key
	[ -f "$file" ] || return 0
	while IFS= read -r line || [ -n "$line" ]; do
		line="${line%%#*}"
		line="${line%"${line##*[![:space:]]}"}"
		[[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)=(.*)$ ]] || continue
		key="${BASH_REMATCH[1]}"
		[ -n "${_SF_RAW[$key]+x}" ] || _SF_ORDER+=("$key")
		_SF_RAW[$key]="${BASH_REMATCH[2]}"
		_SF_ORIGIN[$key]="$origin"
	done <"$file"
}

_sf_read "$SF_DEFAULTS" defaults
_sf_read "$SF_USER_CONFIG" user

for _sf_key in "${_SF_ORDER[@]}"; do
	if [ -n "${!_sf_key+x}" ]; then
		# posée par l'environnement : jamais écrasée
		printf -v "SF_SOURCE_$_sf_key" '%s' env
	else
		printf -v "$_sf_key" '%s' "$(eval "printf '%s' \"${_SF_RAW[$_sf_key]}\"")"
		printf -v "SF_SOURCE_$_sf_key" '%s' "${_SF_ORIGIN[$_sf_key]}"
	fi
	export "${_sf_key?}"
done
unset _sf_key
