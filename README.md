# PVE CLI dashboard

If you've got a lot of VMs, you might want to see their status quickly when on any PVE host. Also, i've added some handy extra functions.

## Color

This snippet just prettifies the output by adding some colors.


![](pve-cli-dashboard.png)

![](pve-cli-dashboard-single.png)

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

## Installation

```
wget https://raw.githubusercontent.com/morph027/pve-cli-dashboard/master//.bash_aliases -O /etc/pve/.bash_aliases

cat >> ~/.bash_aliases << EOF

# https://github.com/morph027/pve-cli-dashboard
[ -f /etc/pve/.bash_aliases ] && . /etc/pve/.bash_aliases

EOF
```
