# RamDisk

A simple shell script to effortlessly create and destroy Ram Disks in MacOS. The whole point of course is to be as simple and helpful as possible.

## Create

`ramdisk.sh /path/to/directory nummegs`

## Destroy

`ramdisk.sh /path/to/ramdisk`

## Notes

* You can rename the script to whatever suits you.
* The path doesn't have to exist to create the ramdisk as the script will create the directory and the directory will be deleted when the ramdisk is destroyed. The directory will not be deleted if the directory already existed prior to creation. The controlling file for this is the `ramdisk/.mkdir` file.
* If any sort of failure occurs during creation, any changes will attempt to be rolled back.
* The script is safe to use as `root` as the script can see this and will make sure your ramdisk is available to all users by default.
* The device name is stored in the `ramdisk/.device` folder.
* The files `.metadata_never_index` and `.fsevents/no_log` are used to prevent indexing.
* All descriptor files are made completely read-only to prevent accidental deletion.
* A case-insensetive HFS filesystem is used.
* Access time updates are disabled by default.
* The ramdisk by default will not be visible in Finder.
* The allowable megabytes range is soft-limited from 1MB to 64GB.
* If a problem with destruction occurs then attempts will continue to try and destroy the ramdisk.
