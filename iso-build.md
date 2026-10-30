# ISO build: OK - ISO built

| | |
|---|---|
| Branch | `main` |
| Commit | `b854379` |
| Started by | push |
| Time (UTC) | 2026-10-30 12:07 |
| Prepare | success |
| Build | success |
| Release | success |
| ISO | arch-profiles-installer-2026.10.30.iso |
| Full log | https://github.com/GFGMNET/Linux/actions/runs/41051861041 |

## Last 80 lines of the build log

```

[===========================================================\] 81672/81672 100%

Exportable Squashfs 4.0 filesystem, xz compressed, data block size 1048576
	compressed data, compressed metadata, compressed fragments,
	compressed xattrs, compressed ids
	duplicates are removed
Filesystem size 1069289.65 Kbytes (1044.23 Mbytes)
	48.78% of uncompressed filesystem size (2192166.42 Kbytes)
Inode table size 675286 bytes (659.46 Kbytes)
	20.00% of uncompressed inode table size (3376319 bytes)
Directory table size 890768 bytes (869.89 Kbytes)
	34.07% of uncompressed directory table size (2614525 bytes)
Xattr table size 78 bytes (0.08 Kbytes)
	97.50% of uncompressed xattr table size (80 bytes)
Number of duplicate files found 7408
Number of inodes 96933
Number of files 77015
Number of fragments 1461
Number of symbolic links 13069
Number of device nodes 0
Number of fifo nodes 0
Number of socket nodes 0
Number of directories 6849
Number of hard-links 2422
Number of ids (unique uids + gids) 19
Number of uids 9
	root (0)
	unknown (964)
	unknown (110)
	unknown (968)
	tss (971)
	unknown (34)
	unknown (32)
	systemd-imds (977)
	systemd-timesync (972)
Number of gids 18
	root (0)
	uuidd (970)
	unknown (40)
	network (90)
	unknown (110)
	unknown (102)
	ftp (11)
	tty (5)
	dbus (81)
	utmp (996)
	games (50)
	unknown (968)
	tss (971)
	unknown (34)
	unknown (32)
	systemd-imds (977)
	systemd-timesync (972)
	systemd-journal (981)
[mkarchiso] INFO: Creating checksum file for self-test...
[mkarchiso] INFO: Done!
[mkarchiso] INFO: Creating ISO image...
xorriso 1.5.8.pl02 : RockRidge filesystem manipulator, libburnia project.

xorriso : NOTE : Environment variable SOURCE_DATE_EPOCH encountered with value 1793361575
Drive current: -outdev 'stdio:/__w/Linux/Linux/out/arch-profiles-installer-2026.10.30-x86_64.iso'
Media current: stdio file, overwriteable
Media status : is blank
Media summary: 0 sessions, 0 data blocks, 0 data, 80.0g free
Added to ISO image: directory '/'='/tmp/archprofiles-iso/work/iso'
xorriso : UPDATE :     107 files added in 1 seconds
xorriso : UPDATE :     107 files added in 1 seconds
xorriso : NOTE : Copying to System Area: 432 bytes from file '/tmp/archprofiles-iso/work/iso/boot/syslinux/isohdpfx.bin'
libisofs: NOTE : Automatically adjusted MBR geometry to 1017/82/32
libisofs: NOTE : Aligned image size to cylinder size by 313 blocks
xorriso : UPDATE :  11.88% done
xorriso : UPDATE :  82.39% done
ISO image produced: 802848 sectors
Written to medium : 802848 sectors at LBA 0
Writing to 'stdio:/__w/Linux/Linux/out/arch-profiles-installer-2026.10.30-x86_64.iso' completed successfully.

[mkarchiso] INFO: Done!
1.6G	/__w/Linux/Linux/out/arch-profiles-installer-2026.10.30-x86_64.iso
[1;34m==>[0m Done: /__w/Linux/Linux/out/arch-profiles-installer-2026.10.30.iso (1.6G)
```
