#!/bin/bash

usage="$0 [-c] [-h]"

helpText="
NAME
    raw_disk

SYNOPSIS
$(echo "    $usage")

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
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
"
# Show only critical disks or not. Default is 0 (show all disks)
onlyCritical=0

### Get command line options
while getopts ":ch" opt; do
    case $opt in
        c)
            onlyCritical=1
        ;;
        h)
            echo "$helpText" | less
            exit 0
        ;;
        \?)
            echo "Invalid option: -$OPTARG"
            exit 4
        ;;
    esac
done

shift $(($OPTIND-1))

# Exit directly if we don't have any partitions to check
if ! df | egrep -q '/dev/sd[a-z] '; then
    echo "No disks to check. Exiting."
    exit 3
fi

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

### Other variables
# Save disk information in this array
diskArray=()
# Store graph data in this string
graph=""
# Output string
output=""


# Loop and parse output from df
while read device size used free percent mountpoint; do
    # Get percent used, strip non-digits
    percUsed=$(echo $percent | grep -o '[0-9]*')
    # Calculate percent free
    percFree=$((100-$percUsed))
    # Check size of disk, if smaller than or equal to default,
    # compare against the default warning & critical values.
    if (( $size <= $diskDefaultMb )); then
        # Calculate graph data:
        # Warning:
        warnValueDefault=$(awk -v v1=$size 'BEGIN { print int(v1*0.85) }')
        # Critical:
        critValueDefault=$(awk -v v1=$size 'BEGIN { print int(v1*0.9) }')
        # Build graph string:
        graph+="$mountpoint=${used}MB;$warnValueDefault;$critValueDefault;0;$size "

        # Check against default values
        if (( $percFree <= $critDefault )); then
            diskArray+=("Critical: $percFree% left on $mountpoint ")
        elif (( $percFree <= $warnDefault )); then
            diskArray+=("Warning: $percFree% left on $mountpoint ")
        else
            diskArray+=("OK: $percFree% left on $mountpoint ")
        fi
    # Check if disk is >= default and < "huge"
    elif (( $size >= $diskDefaultMb && $size < $hugeDiskMb )); then
        # Calculate graph data:
        # Warning:
        warnValueBigdisk=$(awk -v v1=$size 'BEGIN { print int(v1*0.9) }')
        # Critical:
        critValueBigdisk=$(awk -v v1=$size 'BEGIN { print int(v1*0.95) }')
        # Build graph string:
        graph+="$mountpoint=${used}MB;$warnValueBigdisk;$critValueBigdisk;0;$size "

        # Check against values for big disks
        if (( $percFree <= $critBigdisk )); then
            diskArray+=("Critical: $percFree% left on $mountpoint ")
        elif (( $percFree <= $warnBigdisk )); then
            diskArray+=("Warning: $percFree% left on $mountpoint ")
        else
            diskArray+=("OK: $percFree% left on $mountpoint ")
        fi
    else
        # Calculate graph data:
        # Warning:
        warnValueHugedisk=$(awk -v v1=$size 'BEGIN { print int(v1*0.93) }')
        # Critical:
        critValueHugedisk=$(awk -v v1=$size 'BEGIN { print int(v1*0.97) }')
        # Build graph string:
        graph+="$mountpoint=${used}MB;$warnValueHugedisk;$critValueHugedisk;0;$size "

        # Check against values for "huge" disks
        if (( $percFree <= $critHugedisk )); then
            diskArray+=("Critical: $percFree% left on $mountpoint ")
        elif (( $percFree <= $warnHugedisk )); then
            diskArray+=("Warning: $percFree% left on $mountpoint ")
        else
            diskArray+=("OK: $percFree% left on $mountpoint ")
        fi
    fi
done < <(df -m | egrep '/dev/sd[a-z] ')

# Create exit code by parsing the $diskArray
# If _any_ 'Critical', exit with 2.
# If we have a 'Warning', but no 'Critical' exit with 1.
# Else, exit with 0.
if echo "${diskArray[@]}" | grep -q 'Critical'; then
    exitCode=2
elif echo "${diskArray[@]}" | grep -q 'Warning'; then
    # If warning level is already Critical, leave it!
    if [[ $exitCode != 2 ]]; then
        exitCode=1
    fi
else
    exitCode=0
fi

# Check if we have ANY critical disk(s)
haveCriticalDisk=$(echo "${diskArray[@]}" | grep -o 'Critical')

### Print status to stdout
# If we have the '-c' flag and any disk is critical...
if [[ $onlyCritical == 1 && -n $haveCriticalDisk ]]; then
    # Loop diskArray and save the "Critical" disks in string
    for disk in "${diskArray[@]}"; do
        if [[ $disk =~ ^Critical ]]; then
            output+="$disk"
        fi
    done
    echo -en "$output | $graph\n"
# Otherwise, print information about all the disks
else
    echo -en "${diskArray[@]} | $graph\n"
fi

exit $exitCode


exit $exitCode
