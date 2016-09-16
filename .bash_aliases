#!/bin/bash

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

_pct_prettify() {
  while read line
  do
    line=$(echo "$line" | sed 's,\(VMID.*\),\\e[1;37m\1\\e[0m,')
    _vm_status "$line" && echo -e "\e[0;32m" || echo -e "\e[0;31m"
    echo -ne "$line\e[0m"
  done < <(command pct list)
  echo -ne "\n\n"
}

_qm_prettify() {
  while read line
  do
    line=$(echo "$line" | sed 's,\(VMID.*\),\\e[1;37m\1\\e[0m,')
    _vm_status "$line" && echo -e "\e[0;32m" || echo -e "\e[0;31m"
    echo -ne "$line\e[0m"
  done < <(command qm list)
  echo -ne "\n\n"
}

pct() {
  case $1 in

    "list")
      _pct_prettify
    ;;

    *)
      command pct "$@"
    ;;
  esac
}

qm() {
  case $1 in

    "list")
      _qm_prettify
    ;;

    *)
      command qm "$@"
    ;;
  esac
}

echo "-------"

_pct_prettify

echo -ne "-------\n"

_qm_prettify

echo -ne "-------\n"
