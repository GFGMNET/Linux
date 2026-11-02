# ISO build: OK - ISO built

| | |
|---|---|
| Branch | `main` |
| Commit | `cf18059` |
| Started by | schedule |
| Time (UTC) | 2026-11-02 16:28 |
| Prepare | success |
| Build | success |
| Release | success |
| ISO | arch-profiles-installer-2026.11.02.iso |
| Full log | https://github.com/GFGMNET/Linux/actions/runs/41480133234 |

## Last 80 lines of the build log

```
Unrecognised xattr prefix system.posix_acl_default

[===========================================================-] 82833/82833 100%

Exportable Squashfs 4.0 filesystem, xz compressed, data block size 1048576
	compressed data, compressed metadata, compressed fragments,
	compressed xattrs, compressed ids
	duplicates are removed
Filesystem size 1076334.62 Kbytes (1051.11 Mbytes)
	48.95% of uncompressed filesystem size (2198674.86 Kbytes)
Inode table size 682024 bytes (666.04 Kbytes)
	19.92% of uncompressed inode table size (3424174 bytes)
Directory table size 904610 bytes (883.41 Kbytes)
	33.80% of uncompressed directory table size (2676335 bytes)
Xattr table size 78 bytes (0.08 Kbytes)
	97.50% of uncompressed xattr table size (80 bytes)
Number of duplicate files found 7414
Number of inodes 98229
Number of files 78118
Number of fragments 1470
Number of symbolic links 13247
Number of device nodes 0
Number of fifo nodes 0
Number of socket nodes 0
Number of directories 6864
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

xorriso : NOTE : Environment variable SOURCE_DATE_EPOCH encountered with value 1793636318
Drive current: -outdev 'stdio:/__w/Linux/Linux/out/arch-profiles-installer-2026.11.02-x86_64.iso'
Media current: stdio file, overwriteable
Media status : is blank
Media summary: 0 sessions, 0 data blocks, 0 data, 82.2g free
Added to ISO image: directory '/'='/tmp/archprofiles-iso/work/iso'
xorriso : UPDATE :     110 files added in 1 seconds
xorriso : UPDATE :     110 files added in 1 seconds
xorriso : NOTE : Copying to System Area: 432 bytes from file '/tmp/archprofiles-iso/work/iso/boot/syslinux/isohdpfx.bin'
libisofs: NOTE : Automatically adjusted MBR geometry to 1012/73/32
libisofs: NOTE : Aligned image size to cylinder size by 98 blocks
xorriso : UPDATE :  10.86% done
ISO image produced: 646832 sectors
Written to medium : 646832 sectors at LBA 0
Writing to 'stdio:/__w/Linux/Linux/out/arch-profiles-installer-2026.11.02-x86_64.iso' completed successfully.

[mkarchiso] INFO: Done!
1.3G	/__w/Linux/Linux/out/arch-profiles-installer-2026.11.02-x86_64.iso
[1;34m==>[0m Done: /__w/Linux/Linux/out/arch-profiles-installer-2026.11.02.iso (1.3G)
```
