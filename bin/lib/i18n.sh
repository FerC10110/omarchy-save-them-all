# shellcheck shell=bash
# Messages for the scripts in bin/, in English or Spanish. The English text is
# the key: bin/messages.es.json holds its Spanish, and %1, %2… take the
# arguments in one pass (a value holding %2 is not filled again). The language
# is SAVE_THEM_ALL_LANG (the panel passes the one it shows), else the choice
# in settings.json, else the system's.

I18N_TABLE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../messages.es.json"

msg_lang() {
  local chosen sys
  case ${SAVE_THEM_ALL_LANG:-} in en | es) echo "$SAVE_THEM_ALL_LANG"; return ;; esac
  chosen=$(jq -r '.language // "auto"' "${SAVE_THEM_ALL_STATE:-$HOME/.local/state/save-them-all}/settings.json" 2>/dev/null || true)
  case $chosen in en | es) echo "$chosen"; return ;; esac
  sys=${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}
  if [[ $sys == es* ]]; then echo es; else echo en; fi
}
MSG_LANG=$(msg_lang)

msg() { # $1 English text with %1, %2…; the rest fill them in
  local text=$1
  shift
  jq -rn --arg t "$text" --arg lang "$MSG_LANG" --slurpfile es "$I18N_TABLE" '
    (if $lang == "es" then ($es[0][$t] // $t) else $t end)
    | gsub("%(?<n>[0-9]+)"; (.n | tonumber) as $i
        | if $i > 0 and $i <= ($ARGS.positional | length) then $ARGS.positional[$i - 1] else "%" + .n end)
  ' --args "$@" 2>/dev/null || printf '%s\n' "$text"
}
