#!/bin/sh
set -e

SNAPDATE=$(date +%Y%m%d%H%M%S)
echo $SNAPDATE
BACKUPTAG="backup"


LIMIT_PRUNIES="10"
SRCDATASET=$1
DSTDATASET=$2
DSTSNAP=0

check_zfs_dataset_and_snapshots() {
    DATASET_1="$1"
    DATASET_2="$2"

   for INDEX in 1 2; do
        if [ "$INDEX" -eq 1 ]; then
            DATASET="$DATASET_1"
            LABEL="Source"
        else
            DATASET="$DATASET_2"
            LABEL="Destination"
        fi

        if [ -z "$DATASET" ]; then
            echo "Error: $LABEL name not provided."
            exit 1
        fi

        # Check if the dataset exists
        if zfs list -H "$DATASET" >/dev/null 2>&1; then
            echo "$LABEL ('$DATASET') exists."
        else
            echo "$LABEL ('$DATASET') does not exist."
            if [ "$LABEL" = "Destination" ]; then
            sync_src_dst $DATASET_1 $DATASET_2
            fi
            continue
        fi

        # Check if any snapshots exist for the dataset
        if zfs list -t snapshot -H -o name | grep -q "^$DATASET@"; then
            echo "Snapshots exist for $LABEL ('$DATASET')."
        else
            echo "No snapshots exist for $LABEL ('$DATASET')."
        fi
    done

     }


sync_src_dst() {

    SRC="$1"
    DST="$2"

    echo "** Snapshoting: $SRC@$BACKUPTAG-$SNAPDATE"
    zfs snapshot $SRC@$BACKUPTAG-$SNAPDATE

    echo "** Performing full Sync: $SRC -> $DST"
    zfs send -v $SRC@$BACKUPTAG-$SNAPDATE | zfs recv -Fu $DST
}

create_snap(){
        SRC="$1"
        zfs snapshot $SRC@$BACKUPTAG-$SNAPDATE
}

check_zfs_dataset_and_snapshots "$SRCDATASET" "$DSTDATASET"


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
echo "  => Source has ${SRCOLDSNAPS_C} snapshots over the prunies limit ($LIMIT_PRUNIES)."
echo "  => Destination has $DSTOLDSNAPS_C snapshots over the prunies limit ($LIMIT_PRUNIES)."
echo "  => Last Source snap: $SRCNAME ($SRCGUID)"
echo "  => Last destination snap: $DSTNAME ($DSTGUID)"
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
            exit 1

fi
echo
echo
echo "** Creating snapshot $SRCDATASET@$BACKUPTAG-$SNAPDATE"
create_snap "$SRCDATASET"
#zfs snapshot $SRCDATASET@$BACKUPTAG-$SNAPDATE
echo "** Sending snapshot $SRCDATASET -> $SRCDATASET@$BACKUPTAG-$SNAPDATE to $DSTDATASET"
echo "zfs send -v -i ${SRCDATASET} ${SRCDATASET}@${BACKUPTAG}-${SNAPDATE} | zfs recv -Fu $DSTDATASET"
echo "---> $SRCPREVSNAP"
zfs send -v -i ${SRCNAME} ${SRCDATASET}@${BACKUPTAG}-${SNAPDATE} | zfs recv -Fu $DSTDATASET
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
