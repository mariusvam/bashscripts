#!/bin/bash
# author: trile7 at gmail dot com

maxsize=1000000000 #in byte.  Leave blank to ignore file size

#Do not edit after this
trashcan="$HOME/.local/share/Trash"
if ! mkdir -p "$trashcan"; then
  echo "cannot create trashcan"
  exit 1
fi
case $1 in
  -h|--help|--usage|--info)
    echo "$0 filepath1 filepath2 ...            #move file to $trashcan"
    echo "$0 --restore filepath1 filepath2 ...  #restore item to its orginal location"
    echo "$0 --empty                            #remove all items in $trashcan"
    echo
    echo "trashcan location $trashcan"
    echo
    echo "When a file is moved using this script, it's moved to $trashcan/files folder and a file with the same filename plus the extension .trashinfo containing the filepath and deletion date is created in the $trashcan/info folder."
    echo
    echo "When trash or restore a file, if the destination already have the same filename, _1 is added to the new filename." ;;
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
