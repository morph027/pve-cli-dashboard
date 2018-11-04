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
## _get-id-by-name() gets the lxc VMID of a given name
##

_get-id-by-name() {
  local VM_NAME="$1"
  VM_CONFIG=$(grep -l 'name: '"$VM_NAME"'' /etc/pve/lxc/*)
  if [ ! ${#VM_CONFIG} -eq "0" ]; then
    VM_CONFIG=$(basename "$VM_CONFIG")
    echo "${VM_CONFIG%%.*}"
  else
    return 1
  fi
}

##
## start-by-name starts the lxc container by given name
##

start-by-name() {
  local VM_NAME="$1"
  if VM_ID=$(get-id-by-name $VM_NAME); then
    pct start "$VM_ID"
  fi
}

##
## stop-by-name stops the lxc container by given name
##

stop-by-name() {
  local VM_NAME="$1"
  if VM_ID=$(get-id-by-name $VM_NAME); then
    pct stop "$VM_ID"
  fi
}

##
## shutdown-by-name shuts down the lxc container by given name
##

shutdown-by-name() {
  local VM_NAME="$1"
  if VM_ID=$(get-id-by-name $VM_NAME); then
    pct shutdown "$VM_ID"
  fi
}

##
## enter-by-name enters the lxc container by given name
##

enter-by-name() {
  local VM_NAME="$1"
  if VM_ID=$(get-id-by-name $VM_NAME); then
    pct enter "$VM_ID"
  fi
}

##
## reset-by-name resets the lxc container by given name
##

reset-by-name() {
  local VM_NAME="$1"
  if VM_ID=$(get-id-by-name $VM_NAME); then
    pct reset "$VM_ID"
  fi
}

##
## tab completion for commands
##

complete -W "$(grep -hPo '(?<=^hostname: ).*' /etc/pve/lxc/*.conf)" \
  start-by-name \
  stop-by-name \
  shutdown-ny-name \
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

##
## motd
##

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
