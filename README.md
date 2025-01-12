# ==== ::UZI:: Ultracrepidarian ZFS Incrementalizm ::UZI:: =====
Unshitty ZFS pool to pool incremental backups script.
Designed to be run on FreeBSD.

Edit script and set source and destination.
It'll snapshot source and send it locally to destination, keeping whatever amount you have set as limit.
If the snapshots are not syncronised between source and destination a full backup will be conducted, cleaning up your mistakes.

No guarantees at all, anything could happen, for instance:
- Your data might vanish
- You'll live a happy life without ever having to work again
- Eternal life
- Eternal death
- 23 pounds of flax
- Anything inbetween

All rites reversed.

