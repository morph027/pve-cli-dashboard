#!/bin/bash

echo -ne "\n\n\e[1;34m### extra functions and colored output by https://github.com/morph027/pve-cli-dashboard ###\e[0m\n\n"

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

_destroy() {
  local COMMAND=$1
  shift
  local PCT=$2
  $COMMAND status $PCT >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -ne "\n\e[1;31mCT $PCT - Destroy\n\n\e[0m"
    read -r -p "Please enter the ID to confirm ($PCT): " answer
    if [ "$answer" == "$PCT" ]; then
      echo "Destroying $PCT ..."
      command $COMMAND "$@"
    else
      echo "Good thing I asked; I won't destroy $PCT"
    fi
  fi
}

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

pct() {
  case $1 in

    "list")
      _prettify pct
    ;;

    "destroy")
      _destroy pct "$@"
    ;;

    *)
      command pct "$@"
    ;;
  esac
}

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

echo "-------"

_prettify pct

echo -ne "-------\n"

_prettify pct

echo -ne "-------\n"
