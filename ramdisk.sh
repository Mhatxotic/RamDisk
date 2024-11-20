#!/bin/bash

# ________                  _____________       ______
# ___  __ \_____ _______ ______  __ \__(_)_________  /__
# __  /_/ /  __ `/_  __ `__ \_  / / /_  /__  ___/_  //_/
# _  _, _// /_/ /_  / / / / /  /_/ /_  / _(__  )_  ,<
# /_/ |_| \__,_/ /_/ /_/ /_//_____/ /_/  /____/ /_/|_|
# Version 1.0  (c) 2024 MS-Design  https://github.com/Mhatxotic
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

# Error function.
Error()
{
  CODE=$1
  shift 1
  [ ! -z "$*" ] && echo $*
  exit $CODE
}

# Check first parameter and show usage.
MOUNTPATH=$1
[ -z "$MOUNTPATH" ] && Error 1 "Usage: $0 <path> [SIZE]."

# Prepare filenames.
DEVICEFILE=$MOUNTPATH/.device
METADATAFILE=$MOUNTPATH/.metadata_never_index
MKDIRFILE=$MOUNTPATH/.mkdir
FSEVENTSFILE=$MOUNTPATH/.fseventsd
FSENOLOGFILE=$FSEVENTSFILE/no_log

# Check if user specified size in megabytes specified. Unmount if not.
MKDIR=0
RmDir(){ [ $MKDIR -eq 1 ] && rmdir "$MOUNTPATH"; }
Detach(){ hdiutil detach $DEVICE; }
Unmount(){ umount -f "$DEVICE"; }
SIZE=$2
if [ -z "$SIZE" ]; then
  test -L "$MOUNTPATH"
  [ $? -eq 0 ] && Error 2 "$MOUNTPATH: Is a symbolic link!"
  [ ! -e "$MOUNTPATH" ] && Error 3 "$MOUNTPATH: No mount here!"
  MOUNTPATH=`readlink -f "$MOUNTPATH"`
  [ -z "$MOUNTPATH" ] && Error 4 "$MOUNTPATH: Expansion failed!"
  [ ! -d "$MOUNTPATH" ] && Error 5 "$MOUNTPATH: Not a directory!"
  [ ! -f "$DEVICEFILE" ] && Error 6 "$MOUNTPATH: Not mounted by ramdisk!"
  DEVICE=`cat "$DEVICEFILE"`
  [ ! $? -eq 0 ] && Error 7 "$MOUNTPATH: Not a valid mount!"
  if [ -f "$MKDIRFILE" ]; then MKDIR=1; else MKDIR=0; fi
  MOUNT=`mount|grep "^$DEVICE on $MOUNTPATH"`
  [ ! -z "$MOUNT" ] && Unmount
  HDIUTIL=`diskutil list|grep "^$DEVICE "`
  [ ! -z "$HDIUTIL" ] && Detach
  RmDir
  exit 0
fi

# Check size limits
[ -z "${SIZE##*[!0-9]*}" ] && Error 8 "$MOUNTPATH: Size not a valid integer!"
[ $SIZE -lt 1 ] && Error 9 "$MOUNTPATH: Size of $SIZE < 1 megabyte!"
[ $SIZE -gt 65535 ] && Error 10 "$MOUNTPATH: Size of $SIZE > 64 gigabytes!"
SECTORS=$((2048 * $SIZE))

# Check for super user.
if [ "$USER" = "root" ]; then MODEMOUNT=777; MODEDIR=555; MODEFILE=444
                         else MODEMOUNT=700; MODEDIR=500; MODEFILE=400; fi

# Check mount point
ErrorMd(){ [ RmDir; Error $*; }
test -L "$MOUNTPATH"
[ $? -eq 0 ] && Error 11 "$MOUNTPATH: Is a symbolic link!"
if [ -e "$MOUNTPATH" ]; then
  MOUNTPATH=`readlink -f "$MOUNTPATH"`
  [ ! $? -eq 0 ] && Error 12 "$MOUNTPATH: Error reading full path!"
  [ -z "$MOUNTPATH" ] && Error 13 "$MOUNTPATH: Expansion failed 2!"
  [ ! -d "$MOUNTPATH" ] && Error 14 "$MOUNTPATH: Is a file!"
  MOUNT=`mount|grep "on $MOUNTPATH"`
  if [ ! -z "$MOUNT" ]; then
    [ ! -f "$DEVICEFILE" ] && Error 16 "$MOUNTPATH: Already mounted elseware!"
    DEVICE=`cat "$DEVICEFILE"`
    [ ! $? -eq 0 ] && Error 17 "$MOUNTPATH: Error reading $DEVICEFILE!"
    Error 18 "$MOUNTPATH: Already mounted from $DEVICE!"
  fi
else
  mkdir -pm 700 $MOUNTPATH
  [ ! $? -eq 0 ] && Error 19 "$MOUNTPATH: Error creating directory!"
  MKDIR=1
  MOUNTPATH=`readlink -f "$MOUNTPATH"`
  [ ! $? -eq 0 ] && Error 20 "$MOUNTPATH: Error reading full path!"
  [ -z "$MOUNTPATH" ] && ErrorMd 21 "$MOUNTPATH: Expansion failed 3!"
fi

# Create the ramdisk
DEVICE=$(hdiutil attach -nomount ram://$SECTORS)
[ ! $? -eq 0 ] && ErrorMd 22

# Format the ramdisk
ErrorMdMr(){ Detach; ErrorMd $*; }
newfs_hfs -v 'Ram Disk' $DEVICE
[ ! $? -eq 0 ] && ErrorMdMr 23

# Mount the ramdisk and set attributes
mount -o noatime,nobrowse -t hfs $DEVICE $MOUNTPATH
[ ! $? -eq 0 ] && ErrorMdMr 24

# Setup metadata
ErrorMdMrUm(){ Unmount; ErrorMdMr $*; }
chmod $MODEMOUNT "$MOUNTPATH"
[ ! $? -eq 0 ] && ErrorMdMrUm 25
echo $DEVICE>$DEVICEFILE
[ ! $? -eq 0 ] && ErrorMdMrUm 26
chmod $MODEFILE "$DEVICEFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 27
chflags uchg "$DEVICEFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 28
touch $METADATAFILE
[ ! $? -eq 0 ] && ErrorMdMrUm 29
chmod $MODEFILE "$METADATAFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 30
chflags uchg "$METADATAFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 31
mkdir $FSEVENTSFILE
[ ! $? -eq 0 ] && ErrorMdMrUm 32
touch $FSENOLOGFILE
[ ! $? -eq 0 ] && ErrorMdMrUm 33
chmod $MODEFILE "$FSENOLOGFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 34
chflags uchg "$FSENOLOGFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 35
chmod $MODEDIR "$FSEVENTSFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 36
chflags uchg "$FSEVENTSFILE"
[ ! $? -eq 0 ] && ErrorMdMrUm 37

# Add and protect indicator that we created the directory.
if [ $MKDIR -eq 1 ]; then
  touch $MKDIRFILE
  [ ! $? -eq 0 ] && ErrorMdMrUm 38
  chmod $MODEFILE "$MKDIRFILE"
  [ ! $? -eq 0 ] && ErrorMdMrUm 39
  chflags uchg "$MKDIRFILE"
  [ ! $? -eq 0 ] && ErrorMdMrUm 40
fi

# Success!
exit 0
