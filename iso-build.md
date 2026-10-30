# ISO build: FAILED

| | |
|---|---|
| Branch | `main` |
| Commit | `dbc9232` |
| Started by | push |
| Time (UTC) | 2026-10-30 11:58 |
| Prepare | success |
| Build | cancelled |
| Release | skipped |
| ISO | none |
| Full log | https://github.com/GFGMNET/Linux/actions/runs/41051799520 |

## Last 80 lines of the build log

```
Creating group 'vboxsf' with GID 109.
Creating group 'alpm' with GID 969.
Creating user 'alpm' (Arch Linux Package Management) with UID 969 and GID 969.
Creating group 'named' with GID 40.
Creating user 'named' (BIND DNS Server) with UID 40 and GID 40.
Creating group 'brltty' with GID 968.
Creating user 'brltty' (Braille Device Daemon) with UID 968 and GID 968.
Creating group 'dhcpcd' with GID 967.
Creating user 'dhcpcd' (dhcpcd privilege separation) with UID 967 and GID 967.
Creating group 'dnsmasq' with GID 966.
Creating user 'dnsmasq' (dnsmasq daemon) with UID 966 and GID 966.
Creating group 'nbd' with GID 965.
Creating user 'nbd' (Network Block Device) with UID 965 and GID 965.
Creating group 'openvpn' with GID 964.
Creating user 'openvpn' (OpenVPN) with UID 964 and GID 964.
Creating group 'partimag' with GID 110.
Creating user 'partimag' (Partimage user) with UID 110 and GID 110.
Creating group 'pcscd' with GID 963.
Creating user 'pcscd' (PC/SC Smart Card Daemon) with UID 963 and GID 963.
Creating user 'polkitd' (User for polkitd) with UID 102 and GID 102.
Creating group 'rpc' with GID 32.
Creating user 'rpc' (Rpcbind Daemon) with UID 32 and GID 32.
Creating group 'rpcuser' with GID 34.
Creating user 'rpcuser' (RPC Service User) with UID 34 and GID 34.
Creating group 'usbmux' with GID 140.
Creating user 'usbmux' (usbmux user) with UID 140 and GID 140.
( 5/22) Creating temporary files...
( 6/22) Updating journal message catalog...
( 7/22) Updating udev hardware database...
( 8/22) Applying kernel sysctl settings...
  Skipped: Running in chroot.
( 9/22) Reloading system manager configuration...
  Skipped: Running in chroot.
(10/22) Reloading user manager configuration...
  Skipped: Running in chroot.
(11/22) Reloading device manager configuration...
  Skipped: Running in chroot.
(12/22) Arming ConditionNeedsUpdate...
(13/22) Loading new kernel modules...
Running in chroot, ignoring command 'restart'
(14/22) Rebuilding certificate stores...
(15/22) Updating module dependencies...
(16/22) Updating linux initcpios...
==> Building image from preset: /etc/mkinitcpio.d/linux.preset: 'default'
==> Using default configuration file: '/etc/mkinitcpio.conf'
  -> -k /boot/vmlinuz-linux -g /boot/initramfs-linux.img
==> Using drop-in configuration file: 'archiso.conf'
==> Starting build: '7.2.11-arch1-1'
  -> Running build hook: [base]
  -> Running build hook: [udev]
  -> Running build hook: [microcode]
  -> Running build hook: [modconf]
  -> Running build hook: [kms]
==> WARNING: Possibly missing firmware for module: 'ast'
  -> Running build hook: [memdisk]
  -> Running build hook: [archiso]
  -> Running build hook: [archiso_loop_mnt]
  -> Running build hook: [archiso_pxe_common]
==> WARNING: Possibly missing firmware for module: 'adf7242'
==> WARNING: Possibly missing firmware for module: 'softing_cs'
==> WARNING: Possibly missing firmware for module: 'liquidio'
==> WARNING: Possibly missing firmware for module: 'mlxsw_spectrum'
==> WARNING: Possibly missing firmware for module: 'nfp'
==> WARNING: Possibly missing firmware for module: 'qed'
==> WARNING: Possibly missing firmware for module: 'cassini'
==> WARNING: Possibly missing firmware for module: 'bna'
  -> Running build hook: [archiso_pxe_nbd]
  -> Running build hook: [archiso_pxe_http]
  -> Running build hook: [archiso_pxe_nfs]
  -> Running build hook: [block]
==> WARNING: Possibly missing firmware for module: 'bfa'
==> WARNING: Possibly missing firmware for module: 'qla2xxx'
==> WARNING: Possibly missing firmware for module: 'qla1280'
==> WARNING: Possibly missing firmware for module: 'wd719x'
==> WARNING: Possibly missing firmware for module: 'aic94xx'
==> WARNING: Possibly missing firmware for module: 'xhci_pci_renesas'
  -> Running build hook: [filesystems]
  -> Running build hook: [keyboard]
==> Generating module dependencies
==> Creating xz-compressed initcpio image: '/boot/initramfs-linux.img'
```
