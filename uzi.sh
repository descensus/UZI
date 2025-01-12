#!/bin/sh
set -e
SNAPDATE=$(date +%Y%m%d%H%M%S)
LIMIT_PRUNIES="10"
SRCDATASET="mypool/linuxiso"
DSTDATASET="backup/linuxiso"
BACKUPTAG="backup"

SRCPREVSNAP=$(zfs list -H -t snapshot -o name,guid -S creation $SRCDATASET |head -n1)
DSTPREVSNAP=$(zfs list -H -t snapshot -o name,guid -S creation $DSTDATASET |head -n1)

SRCOLDSNAPS=$(zfs list -H -t snapshot -o name -S creation $SRCDATASET |grep $BACKUPTAG|tail -n +$LIMIT_PRUNIES | tr ' ' '\n')
DSTOLDSNAPS=$(zfs list -H -t snapshot -o name -S creation $DSTDATASET |grep $BACKUPTAG|tail -n +$LIMIT_PRUNIES | tr ' ' '\n')

SRCOLDSNAPS_C=$(echo "$SRCOLDSNAPS" | wc -l| tr -d ' ')
DSTOLDSNAPS_C=$(echo "$DSTOLDSNAPS" | wc -l| tr -d ' ')

SRCNAME=$(echo $SRCPREVSNAP|awk '{print $1}')
SRCGUID=$(echo $SRCPREVSNAP|awk '{print $2}')
DSTNAME=$(echo $DSTPREVSNAP|awk '{print $1}')
DSTGUID=$(echo $DSTPREVSNAP|awk '{print $2}')


echo 
echo "==== ::UZI:: Ultracrepidarian ZFS Incrementalizm ::UZI:: ====="

echo "**********************************************************************************************************"
echo "	=> Source has $SRCOLDSNAPS_C snapshots over the prunies limit ($LIMIT_PRUNIES)."
echo "	=> Destination has $DSTOLDSNAPS_C snapshots over the prunies limit ($LIMIT_PRUNIES)."
echo "	=> Last Source snap: $SRCNAME ($SRCGUID)"
echo "	=> Last destination snap: $DSTNAME ($DSTGUID)"
echo "**********************************************************************************************************"

echo
if [ "$SRCGUID" == "$DSTGUID" ]; then
	    echo "[ We are in sync with destination ]"
	    echo "[  Last Source snap: $SRCNAME ($SRCGUID) ]"
	    echo "[  Last destination snap: $DSTNAME ($DSTGUID) ]"
    else
	    echo "[ We are not in sync with destination. Sending a full backup and starting all over ]"
	    echo "[  Last Source snap: $SRCNAME ($SRCGUID) ]"
	    echo "[  Last destination snap: $DSTNAME ($DSTGUID) ]"
	    echo "** Snapshoting $SRCDATASET@$BACKUPTAG-$SNAPDATE"
            zfs snapshot $SRCDATASET@$BACKUPTAG-$SNAPDATE
	    echo "** Destroying destination $DSTDATASET"
	    zfs destroy -r $DSTDATASET
	    echo "** Sending $SRCDATASET@$BACKUPTAG-$SNAPDATE to $DSTDATASET"
            zfs send -v $SRCDATASET@$BACKUPTAG-$SNAPDATE | zfs recv -Fu $DSTDATASET 
	    exit 0
fi 
echo
echo
echo "** Creating snapshot $SRCDATASET@$BACKUPTAG-$SNAPDATE"
zfs snapshot $SRCDATASET@$BACKUPTAG-$SNAPDATE
echo "** Sending snapshot $SRCNAME->$SRCDATASET@$BACKUPTAG-$SNAPDATE to $DSTDATASET"
echo 
zfs send -v -i $SRCNAME $SRCDATASET@$BACKUPTAG-$SNAPDATE | zfs recv -Fu $DSTDATASET 
echo 
echo "[ ========= ALL DONE ========= ]"

echo $SRCOLDSNAPS_C
echo $DSTOLDSNAPS_C
if [ $SRCOLDSNAPS_C -gt 0  ]; then 
	echo "** Source / Pruning $SRCOLDSNAPS_C snaps. Keeping last $LIMIT_PRUNIES"
        for snap in $SRCOLDSNAPS; do
	    zfs destroy $snap
        done
else 
	echo "** No prunies on $SRCDATASET. Dissolving myself into oblivion until next time..."

fi	


if [ $DSTOLDSNAPS_C -gt 0 ]; then
        echo "** Destination / Pruning $DSTOLDSNAPS_C snaps. Keeping last $LIMIT_PRUNIES"
        for snap in $DSTOLDSNAPS; do
            zfs destroy $snap
        done
else
        echo "** No prunies on $DSTDATASET. Dissolving myself into oblivion until next time..."

fi
