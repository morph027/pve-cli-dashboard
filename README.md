# PVE CLI dashboard

If you've got a lot of VMs, you might want to see their status quickly when on any PVE host. Also, i've added some handy extra functions.

## Color

This snippet just prettifies the output by adding some colors.


![](pve-cli-dashboard.png)

![](pve-cli-dashboard-single.png)

## Bash tab completion

Tab everything ;)

```bash
root@proxmox:~# enter-by-name <tab>
debian        ubuntu             centos  alpine
root@proxmox:~# reset-by-name <tab>
debian        ubuntu             centos  alpine
root@proxmox:~# enter-by-name deb<tab>
root@proxmox:~# enter-by-name debian
root@debian:~#
```

## Extra functions

### destroy guard

If you destroyed a vm by accident once (wrong bash history call, typo, whatever,...) you might like this one. It mimics the new behaviour of the web gui asking for confirmation when trying to destroy a VM.

```
root@pve:~# qm destroy 101

CT 101 - Destroy

Please enter the ID to confirm (101): 100
Good thing I asked; I won't destroy 101
root@pve:~# qm destroy 101

CT 101 - Destroy

Please enter the ID to confirm (101): 101
Destroying 101 ...
```

### reset

Just stops and starts a VM.

## Goodies

### config file to bash array

Inside ```.bash_aliases```, you can find the nifty function ```_info()``` which is filling an associative bash array with values from config file.

If sourced correctly, you can then do things like this (and use in other scripts):

```bash
root@pve:~# _info 101
root@pve:~# echo ${VMCONFIG[arch]}
amd64
root@pve:~# echo ${VMCONFIG[cpulimit]}
2
root@pve:~# echo ${VMCONFIG[cpuunits]}
1024
root@pve:~# echo ${VMCONFIG[hostname]}
vm-101
root@pve:~# echo ${VMCONFIG[memory]}
512
root@pve:~# echo ${VMCONFIG[mp0]}
/tank/dataset,mp=/mnt/mountpoint0
root@pve:~# echo ${VMCONFIG[net0]}
name=eth0,hwaddr=XX:XX:XX:XX:XX:XX,bridge=vmbr0,ip=XXX.XXX.XXX.XXX/XX,gw=XXX.XXX.XXX.XXX
root@pve:~# echo ${VMCONFIG[onboot]}
1
root@pve:~# echo ${VMCONFIG[ostype]}
debian
root@pve:~# echo ${VMCONFIG[rootfs]}
tank:subvol-101-disk-1,size=16G
root@pve:~# echo ${VMCONFIG[swap]}
256
root@pve:~# _info 102
root@pve:~# echo ${VMCONFIG[balloon]}
1024
root@pve:~# echo ${VMCONFIG[bootdisk]}
virtio0
root@pve:~# echo ${VMCONFIG[cores]}
4
root@pve:~# echo ${VMCONFIG[cpu]}
host
root@pve:~# echo ${VMCONFIG[memory]}
2048
root@pve:~# echo ${VMCONFIG[name]}
vm-102
root@pve:~# echo ${VMCONFIG[net0]}
virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr0
root@pve:~# echo ${VMCONFIG[numa]}
0
root@pve:~# echo ${VMCONFIG[ostype]}
l26
root@pve:~# echo ${VMCONFIG[smbios1]}
uuid=4ca3a687-6906-4973-b21d-c3b587955c42
root@pve:~# echo ${VMCONFIG[sockets]}
1
root@pve:~# echo ${VMCONFIG[vga]}
qxl
root@pve:~# echo ${VMCONFIG[virtio0]}
tank:vm-102-disk-1,cache=writeback,size=32G
```

## Installation

```
wget https://raw.githubusercontent.com/morph027/pve-cli-dashboard/master//.bash_aliases -O /etc/pve/.bash_aliases

cat >> ~/.bash_aliases << EOF

# https://github.com/morph027/pve-cli-dashboard
[ -f /etc/pve/.bash_aliases ] && . /etc/pve/.bash_aliases

EOF
```
