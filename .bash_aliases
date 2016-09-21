#!/bin/bash

unset -v VMCONFIG
declare -A VMCONFIG

echo -ne "\n\n\e[1;34m### extra functions and colored output by https://github.com/morph027/pve-cli-dashboard ###\e[0m\n\n"

##
## _vm_status() just greps for status in "pct/qm list" output (submitted by _prettify())
## return values:
## 0 - running
## 1 - stopped
##

_vm_status() {
  local vm_info="$1"
  local vm_status=$(echo "$vm_info" | grep -oE 'stopped|running')
  case $vm_status in
    "running")
      return 0
    ;;
    "stopped")
      return 1
    ;;
  esac
}

##
## _info() will parse the config file of vm $1 into an associative bash array
## values can then be accessed using ${VMCONFIG[KEY]}, e.g. {VMCONFIG[net0]}
##

_info() {
  local VM=$1
  local CONFIGFILE=$(find /etc/pve -name ${VM}.conf)
  VMTYPE=$(basename $(dirname $CONFIGFILE))
  case $VMTYPE in
    "qemu-server")
      HOSTNAMEATTR="name"
      COMMAND="qm"
    ;;
   "lxc")
      HOSTNAMEATTR="hostname"
      COMMAND="pct"
   ;;
  esac
  while read line
  do
    local KEY="$(printf '%q' ${line%%:*})"
    local VALUE="$(printf '%q' ${line#* })"
    VMCONFIG[$KEY]="$VALUE"
  done < $CONFIGFILE
}

##
## _destroy() will ask for confirmation before destroying
##

_destroy() {
  local PCT=$2
  _info $PCT
  $COMMAND status $PCT >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -ne "\n\e[1;31mCT $PCT - Destroy\n\n\e[0m"
    read -r -p "Please enter the ID to confirm ($PCT - ${VMCONFIG[$HOSTNAMEATTR]}): " answer
    if [ "$answer" == "$PCT" ]; then
      echo "Destroying $PCT ..."
      command $COMMAND "$@"
    else
      echo "Good thing I asked; I won't destroy $PCT"
    fi
  fi
}

##
## _prettify() just colors the command $1 by vm status (running/stopped)
##

_prettify() {
  local COMMAND=$1
  while read line
  do
    line=$(echo "$line" | sed 's,\(VMID.*\),\\e[1;37m\1\\e[0m,')
    _vm_status "$line" && echo -e "\e[0;32m" || echo -e "\e[0;31m"
    echo -ne "$line\e[0m"
  done < <(command $COMMAND list)
  echo -ne "\n\n"
}

##
## wrapper for real pct command
##

pct() {
  case $1 in

    "list")
      _prettify pct
    ;;

    "destroy")
      _destroy "$@"
    ;;

    "reset")
      VM=$2; command pct shutdown $VM && sleep 5 && command pct start $VM
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
      _destroy "$@"
    ;;

    *)
      command qm "$@"
    ;;
  esac
}

echo "-------"

_prettify pct

echo -ne "-------\n"

_prettify qm

echo -ne "-------\n"
