#!/bin/bash

# ________                  _____________       ______
# ___  __ \_____ _______ ______  __ \__(_)_________  /__
# __  /_/ /  __ `/_  __ `__ \_  / / /_  /__  ___/_  //_/
# _  _, _// /_/ /_  / / / / /  /_/ /_  / _(__  )_  ,<
# /_/ |_| \__,_/ /_/ /_/ /_//_____/ /_/  /____/ /_/|_|
# Version 1.0  (c) 2026 Mhatxotic Design  https://github.com/Mhatxotic/RamDisk
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# * The above copyright notice and this permission notice shall be included in
#   all copies or substantial portions of the Software.
#
# * THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
#   DEALINGS IN THE SOFTWARE.

# Configuration
MOUNTOPTIONS=noatime,nobrowse
# File system type to use
FS=hfs

# Executables
BASENAME=/usr/bin/basename
CHFLAGS=/usr/bin/chflags
CHMOD=/bin/chmod
DISKUTIL=/usr/sbin/diskutil
ECHO=echo
GREP=/usr/bin/grep
MKDIR=/bin/mkdir
MOUNT=/sbin/mount
NEWFS=/sbin/newfs_$FS
READLINK=/usr/bin/readlink
RMDIR=/bin/rmdir
TEST=/bin/test
TOUCH=/usr/bin/touch
UMOUNT=/sbin/umount

# Error function.
Error()
{
  CODE=$1
  shift 1
  [ ! -z "$*" ] && $ECHO $*
  exit $CODE
}

# Check first parameter or show usage.
MOUNTPATH=$1
[ -z "$MOUNTPATH" ] && Error 1 "Usage: $0 <path> [sizemb]."

# The directory name will be the volume name.
MOUNTNAME=`$BASENAME "${1}"`
[ ! $? -eq 0 ] && Error 2

# This contains the name of the device (/dev/diskN).
DEVICEFILE=$MOUNTPATH/.device
# This is the file that stops Finder indexing
METADATAFILE=$MOUNTPATH/.metadata_never_index
# This is the file that tells unmounter that we created the directory.
MKDIRFILE=$MOUNTPATH/.mkdir
# This is the directory where MacOS file system events are stored.
FSEVENTSFILE=$MOUNTPATH/.fseventsd
# This is the filename of the file which disables file system events.
FSENOLOGFILE=$FSEVENTSFILE/no_log

# Check if user specified size in megabytes specified. Unmount if not.
MADEDIR=0
RmDir(){ [ $MADEDIR -eq 1 ] && $RMDIR "$MOUNTPATH"; }
Detach(){ $DISKUTIL eject $DEVICE; }
Unmount(){ $UMOUNT -f $DEVICE; }
ExpandMountPath(){
  MOUNTPATHNEW=`$READLINK -f "$MOUNTPATH"`
  [ ! $? -eq 0 ] && $1 $2 "$MOUNTPATH: Error reading full path!"
  [ -z "$MOUNTPATHNEW" ] && $1 $3 "$MOUNTPATH: Expansion failed!"
  MOUNTPATH=$MOUNTPATHNEW
  unset MOUNTPATHNEW
}
SIZE=$2
if [ -z "$SIZE" ]; then
  $TEST -L "$MOUNTPATH"
  [ $? -eq 0 ] && Error 3 "$MOUNTPATH: Is a symbolic link!"
  [ ! -e "$MOUNTPATH" ] && Error 4 "$MOUNTPATH: No mount here!"
  ExpandMountPath Error 5 6
  [ ! -d "$MOUNTPATH" ] && Error 7 "$MOUNTPATH: Not a directory!"
  [ ! -f "$DEVICEFILE" ] && Error 8 "$MOUNTPATH: Not mounted by ramdisk!"
  DEVICE=`cat "$DEVICEFILE"`
  [ ! $? -eq 0 ] && Error 9 "$MOUNTPATH: Not a valid mount!"
  if [ -f "$MKDIRFILE" ]; then MADEDIR=1; else MADEDIR=0; fi
  MOUNTEXIST=`$MOUNT|$GREP "^$DEVICE on $MOUNTPATH"`
  [ ! -z "$MOUNTEXIST" ] && Unmount
  HDIUTIL=`$DISKUTIL list|$GREP "^$DEVICE "`
  [ ! -z "$HDIUTIL" ] && Detach
  RmDir
  exit 0
fi

# Check size limits
[ -z "${SIZE##*[!0-9]*}" ] && Error 10 "$MOUNTPATH: Size not a valid integer!"
[ $SIZE -lt 1 ] && Error 11 "$MOUNTPATH: Size of $SIZE < 1 megabyte!"
[ $SIZE -gt 65535 ] && Error 12 "$MOUNTPATH: Size of $SIZE > 64 gigabytes!"
SECTORS=$((2048 * $SIZE))

# Check for super user.
if [ "$USER" = "root" ]; then MODEMOUNT=777; MODEDIR=555; MODEFILE=444
                         else MODEMOUNT=700; MODEDIR=500; MODEFILE=400; fi

# Check mount point
ErrorMd(){ RmDir; Error $*; }
$TEST -L "$MOUNTPATH"
[ $? -eq 0 ] && Error 13 "$MOUNTPATH: Is a symbolic link!"
if [ -e "$MOUNTPATH" ]; then
  ExpandMountPath Error 14 15
  [ ! -d "$MOUNTPATH" ] && Error 16 "$MOUNTPATH: Is a file!"
  MOUNTEXIST=`$MOUNT|$GREP "on $MOUNTPATH"`
  if [ ! -z "$MOUNTEXIST" ]; then
    [ ! -f "$DEVICEFILE" ] && Error 17 "$MOUNTPATH: Already mounted elseware!"
    DEVICE=`cat "$DEVICEFILE"`
    [ ! $? -eq 0 ] && Error 18 "$MOUNTPATH: Error reading $DEVICEFILE!"
    Error 18 "$MOUNTPATH: Already mounted from $DEVICE!"
  fi
else
  $MKDIR -pm 700 "$MOUNTPATH"
  [ ! $? -eq 0 ] && Error 19 "$MOUNTPATH: Error creating directory!"
  MADEDIR=1
  ExpandMountPath ErrorMd 20 21
fi

# Create the ramdisk
DEVICE=$($DISKUTIL image attach -n ram://$SECTORS)
[ ! $? -eq 0 ] && ErrorMd 22

# Format the ramdisk
ErrorMdMr(){ Detach; ErrorMd $*; }
$NEWFS -v "$MOUNTNAME" $DEVICE
[ ! $? -eq 0 ] && ErrorMdMr 23

# Mount the ramdisk and set attributes
$MOUNT -o $MOUNTOPTIONS -t $FS $DEVICE "$MOUNTPATH"
[ ! $? -eq 0 ] && ErrorMdMr 24

# Setup metadata
ErrorMdMrUm(){ Unmount; ErrorMdMr $*; }
$CHMOD $MODEMOUNT "$MOUNTPATH"
[ ! $? -eq 0 ] && ErrorMdMrUm 25
$ECHO $DEVICE>"$DEVICEFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 26
$CHMOD $MODEFILE "$DEVICEFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 27
$CHFLAGS uchg "$DEVICEFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 28
$TOUCH "$METADATAFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 29
$CHMOD $MODEFILE "$METADATAFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 30
$CHFLAGS uchg "$METADATAFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 31
$MKDIR "$FSEVENTSFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 32
$TOUCH "$FSENOLOGFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 33
$CHMOD $MODEFILE "$FSENOLOGFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 34
$CHFLAGS uchg "$FSENOLOGFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 35
$CHMOD $MODEDIR "$FSEVENTSFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 36
$CHFLAGS uchg "$FSEVENTSFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 37

# Add and protect indicator that we created the directory.
if [ $MADEDIR -eq 1 ]; then
  $TOUCH "$MKDIRFILE"
  [ ! $? -eq 0 ] && ErrorMdMrUm 38
  $CHMOD "$MODEFILE" "$MKDIRFILE"
  [ ! $? -eq 0 ] && ErrorMdMrUm 39
  $CHFLAGS uchg "$MKDIRFILE"
  [ ! $? -eq 0 ] && ErrorMdMrUm 40
fi

# Success!
exit 0
