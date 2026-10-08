#!/bin/bash

unset -v VMCONFIG
declare -A VMCONFIG

##
## _vm_status() just greps for status in "pct/qm list" output (submitted by _prettify())
## return values:
## 0 - running
## 1 - stopped
## 2 - other/unknown (header line, paused, ...)
##

_vm_status() {
  # match the status as a standalone column, so names like "running-app" don't count
  case " $1 " in
    *" running "*) return 0 ;;
    *" stopped "*) return 1 ;;
    *) return 2 ;;
  esac
}

##
## _info() will parse the config file of vm $1 into an associative bash array
## values can then be accessed using ${VMCONFIG[KEY]}, e.g. {VMCONFIG[net0]}
## sets VMTYPE to "qemu-server" or "lxc"; returns 1 if no local config exists
##

_info() {
  local vm="$1" configfile line key
  VMCONFIG=()
  VMTYPE=""
  [[ "$vm" =~ ^[0-9]+$ ]] || return 1
  if [ -f "/etc/pve/qemu-server/${vm}.conf" ]; then
    VMTYPE="qemu-server"
  elif [ -f "/etc/pve/lxc/${vm}.conf" ]; then
    VMTYPE="lxc"
  else
    return 1
  fi
  configfile="/etc/pve/${VMTYPE}/${vm}.conf"
  while IFS= read -r line || [ -n "$line" ]
  do
    case "$line" in
      \[*) break ;;          # snapshot/pending sections follow the current config
      \#*|"") continue ;;    # description comments and blank lines
    esac
    key="${line%%:*}"
    VMCONFIG[$key]="${line#*: }"
  done < "$configfile"
}

##
## _destroy() will ask for confirmation before destroying
## usage: _destroy <qm|pct> destroy <vmid> [options]
##

_destroy() {
  local cmd="$1" vmid="$3" label hostattr answer
  shift
  # no ID given: let the real command print its usage
  [ -z "$vmid" ] && { command "$cmd" "$@"; return; }
  if ! _info "$vmid"; then
    echo "No guest with ID '$vmid' found on this node" >&2
    return 1
  fi
  case "$cmd:$VMTYPE" in
    qm:qemu-server) label="VM"; hostattr="name" ;;
    pct:lxc)        label="CT"; hostattr="hostname" ;;
    *)
      echo "$vmid is not a $([ "$cmd" = qm ] && echo VM || echo CT); refusing to destroy" >&2
      return 1
    ;;
  esac
  echo -ne "\n\e[1;31m$label $vmid - Destroy\n\n\e[0m"
  read -r -p "Please enter the ID to confirm ($vmid - ${VMCONFIG[$hostattr]}): " answer
  if [ "$answer" == "$vmid" ]; then
    echo "Destroying $vmid ..."
    command "$cmd" "$@"
  else
    echo "Good thing I asked; I won't destroy $vmid"
    return 1
  fi
}

##
## _align_qm() re-aligns "qm list" output: qm uses a fixed-width NAME column,
## so names longer than 20 chars shift the rest of the row.
## Every qm list field is non-empty and names can't contain spaces, so
## splitting on whitespace is safe (unlike pct list, where Lock may be empty).
## NAME and STATUS are left-aligned, the numeric columns right-aligned.
##

_align_qm() {
  awk '
    {
      nf[NR] = NF
      for (i = 1; i <= NF; i++) {
        f[NR, i] = $i
        if (length($i) > w[i]) w[i] = length($i)
      }
    }
    END {
      for (r = 1; r <= NR; r++) {
        s = ""
        for (i = 1; i <= nf[r]; i++) {
          fmt = (i == 2 || i == 3) ? "%-" w[i] "s" : "%" w[i] "s"
          s = s (i > 1 ? " " : "") sprintf(fmt, f[r, i])
        }
        print s
      }
    }'
}

##
## _prettify() just colors the command $1 by vm status (running/stopped)
##

_prettify() {
  local cmd="$1" line color
  # IFS= keeps leading spaces (column alignment), -r keeps backslashes
  while IFS= read -r line
  do
    if [[ "$line" == *VMID* ]]; then
      color="1;37"
    else
      _vm_status "$line"
      case $? in
        0) color="0;32" ;;
        1) color="0;31" ;;
        *) color="0;33" ;;
      esac
    fi
    # print the line literally via %s; only the color codes are interpreted
    printf '\n\e[%sm%s\e[0m' "$color" "$line"
  done < <(if [ "$cmd" = qm ]; then command qm list | _align_qm; else command pct list; fi)
  printf '\n\n'
}

##
## _get-id-by-name() gets the lxc VMID of a given name
##

_get-id-by-name() {
  local VM_NAME="$1" matches
  # exact, literal match on the hostname line (no substrings, no regex)
  mapfile -t matches < <(grep -lFx -- "hostname: $VM_NAME" /etc/pve/lxc/*.conf 2>/dev/null)
  case ${#matches[@]} in
    0)
      echo "No container named '$VM_NAME' found" >&2
      return 1
    ;;
    1)
      basename "${matches[0]}" .conf
    ;;
    *)
      echo "Multiple containers named '$VM_NAME':" "${matches[@]##*/}" >&2
      return 1
    ;;
  esac
}

##
## _handle_by_name() iterate over given VM names
##

_handle_by_name() {
  local action="$1" vm_name vm_id rc=0
  shift
  for vm_name in "$@"
  do
    if vm_id=$(_get-id-by-name "$vm_name"); then
      echo "${action} $vm_name"
      pct "$action" "$vm_id" || rc=1
    else
      rc=1
    fi
  done
  return $rc
}

##
## start-by-name starts the lxc container by given name
##

start-by-name() {
  _handle_by_name "start" "$@"
}

##
## stop-by-name stops the lxc container by given name
##

stop-by-name() {
  _handle_by_name "stop" "$@"
}

##
## shutdown-by-name shuts down the lxc container by given name
##

shutdown-by-name() {
  _handle_by_name "shutdown" "$@"
}

##
## enter-by-name enters the lxc container by given name
##

enter-by-name() {
  local vm_id
  vm_id=$(_get-id-by-name "$1") && pct enter "$vm_id"
}

##
## reset-by-name resets the lxc container by given name
##

reset-by-name() {
  _handle_by_name "reset" "$@"
}

##
## tab completion for commands
## names are read on every <tab>, so new containers show up without re-sourcing
##

_complete_ct_names() {
  local cur="${COMP_WORDS[COMP_CWORD]}" names
  names=$(grep -hPo '(?<=^hostname: ).*' /etc/pve/lxc/*.conf 2>/dev/null)
  mapfile -t COMPREPLY < <(compgen -W "$names" -- "$cur")
}

complete -F _complete_ct_names \
  start-by-name \
  stop-by-name \
  shutdown-by-name \
  enter-by-name \
  reset-by-name

##
## wrapper for real pct command
##

pct() {
  case $1 in

    "list")
      _prettify pct
    ;;

    "destroy")
      _destroy pct "$@"
    ;;

    "reset")
      # shutdown blocks until the CT is stopped (or fails on timeout)
      local vmid="$2"
      if [ -z "$vmid" ]; then
        echo "usage: pct reset <vmid>" >&2
        return 1
      fi
      if ! command pct shutdown "$vmid"; then
        echo "Shutdown of $vmid failed; not starting it again" >&2
        return 1
      fi
      command pct start "$vmid"
    ;;

    *)
      command pct "$@"
    ;;
  esac
}

##
## wrapper for real qm command
##

qm() {
  case $1 in

    "list")
      _prettify qm
    ;;

    "destroy")
      _destroy qm "$@"
    ;;

    *)
      command qm "$@"
    ;;
  esac
}

##
## motd (interactive shells only, so scp/rsync/"ssh host cmd" stay clean)
##

[[ $- == *i* ]] || return 0

echo -ne "\n\n\e[1;34m### extra functions and colored output by https://github.com/morph027/pve-cli-dashboard ###\e[0m\n\n"

shopt -s nullglob
lxcfiles=(/etc/pve/lxc/*.conf)
qmfiles=(/etc/pve/qemu-server/*.conf)
shopt -u nullglob

echo "-------"

if [ ! ${#lxcfiles[@]} -eq 0 ]; then
  _prettify pct
  echo -ne "-------\n"
fi

if [ ! ${#qmfiles[@]} -eq 0 ]; then
  _prettify qm
  echo -ne "-------\n"
fi
