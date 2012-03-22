#!/bin/bash
: <<COMMENT
  Copyright (C) 2012 Tri Le <trile7 at gmail dot com>

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
COMMENT

maxsize=1000000000 #in byte.  Leave blank to ignore file size

#Do not edit after this
trashcan="$HOME/.local/share/Trash"
if ! mkdir -p "$trashcan"; then
  echo "cannot create trashcan"
  exit 1
fi
case $1 in
  -h|--help|--usage|--info)
    echo "$0 filepath1 filepath2 ...            #move file to trashcan"
    echo "$0 --restore filepath1 filepath2 ...  #restore item to its orginal location"
    echo "$0 --empty                            #remove all items in trashcan"
    echo "$0 --list                             #list content of trashcan"
    echo
    echo "trashcan location is $trashcan"
    echo
    echo "When a file is moved using this script, it's moved to $trashcan/files folder and a file with the same filename plus the extension .trashinfo containing the filepath and deletion date is created in the $trashcan/info folder."
    echo
    echo "When trash or restore a file, if the destination already have the same filename, _1 is added to the new filename." ;;
  --list)
    for i in $trashcan/info/*.trashinfo; do
      tail -n2 "$i"
      echo "---------"
    done ;;
  --empty)
    rm -rf "$trashcan"/files/*
    rm -rf "$trashcan"/info/* ;;
  --restore)
    shift
    for i; do
      infofile="$trashcan"/info/`basename "$i"`.trashinfo
      Path=`cat "$infofile" | grep -m1 Path= | cut -d'=' -f2`
      if [[ -z $Path ]]; then
        echo "Cannot restore $i due to missing filepath"
        continue
      fi
      targetfolder=`dirname "$Path"`
      while [[ -e "$Path" ]]; do
        (( j++ ))
        Path="$Path"_1
        if [[ $j -gt 100 ]]; then
          echo "cannot restore $i due to too many conflicts in $targetfolder"
          break
        fi
      done
      [[ -e "$Path" ]] && continue
      mkdir -p "$targetfolder" && mv -n "$i" "$Path" && rm "$infofile"
    done ;;
  *)
    for i; do
      if echo $i | egrep -q ^$trashcan; then
        echo "cannot trash $i because it's already in the trashcan"
        continue
      fi
      if [[ $i != /* ]]; then
        echo "full filepath is needed for $i"
        continue
      fi
      if [[ $maxsize ]] && [[ `du -bs "$i" | awk '{print $1}'` -gt $maxsize ]]; then
        echo "skip $i because it's larger than $maxsize"
        continue
      fi
      filename=`basename "$i"`
      while [[ -e "$trashcan/files/$filename" ]]; do
        (( j++ ))
        filename="$filename"_1
        if [[ $j -gt 100 ]]; then
          echo "cannot trash $i due to conflict in $trashcan"
          break
        fi
      done
      [[ -e "$trashcan/files/$filename" ]] && continue
      mv -n "$i" "$trashcan/files/$filename" && echo -e "[Trash Info]\nPath=$i\nDeletionDate=`date`" > "$trashcan/info/$filename.trashinfo"
    done ;;
esac
