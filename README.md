# raw_disk
OP5 dynamic disk check for unpartitioned disks

<pre>
NAME
    raw_disk

SYNOPSIS
    ./raw_disk.sh [-c] [-h]

DESCRIPTION
    raw_disk checks the remaining space on unpartitioned disks (/dev/sda /dev/sdb /dev/sdc etcetera),
    based on the size of the disk.

    Built primarily for use with OP5 monitoring system.

    The thresholds are defined within the script with these variables:
    ### Disk size limits in megabyte
    # default: 200 gigabyte (204800 Mb) 
    diskDefaultMb=204800
    # Huge disk:
    hugeDiskMb=1000000

    ### Warning and critical levels in percent
    # Defaults: disks < 200G
    warnDefault=15
    critDefault=10
    # Levels for disks >= 200G
    warnBigdisk=10
    critBigdisk=5
    # Levels for huge disks >= 1TB
    warnHugedisk=7
    critHugedisk=3

    Exit codes:
    0: No alerts
    1: Warning
    2: Critical
    3: No partitions to check
    4: Incorrect command line argument

    Note that this check will ALWAYS exit with 2 (Critical) if ANY of 
    the partitions are in Critical level.
    In other words; if one disk is 'Warning' and the other is 
    'Critical', the value submitted to OP5 will be 'Critical'.

OPTIONS
    -h
        Show this help and exit
    -c
        Show only critical disks to stdout

AUTHOR
    Magnus Wallin (magnus.wallin@24solutions.com)

COPYRIGHT
   Copyright  ©  2013  Free  Software  Foundation,  Inc.   License  GPLv3+:  GNU  GPL  version 3 or later
   <http://gnu.org/licenses/gpl.html>.
   This is free software: you are free to change and redistribute it.   There  is  NO  WARRANTY,  to  the
   extent permitted by law.
</pre>
