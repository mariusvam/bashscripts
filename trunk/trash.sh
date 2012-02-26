#!/bin/bash
# author: trile7 at gmail dot com

trashcan="$HOME/.local/share/Trash/files"
maxsize=1000000000 #in byte.  Leave blank to ignore file size

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
    echo "When a file is move to trashcan using this script, a .filename.info containing the filepath and deletion date is created in the trashcan.  The script uses this info file with the --restore option."
    echo
    echo "When trash or restore a file, if the destination already have the same filename, _1 is added to the new filename." ;;
  --empty)
    cd "$trashcan"
    rm -rf * .??* ;;
  --restore)
    shift
    for i; do
      infofile=`dirname "$1"`/.`basename "$i"`.info
      if [[ -f "$infofile" ]]; then
        filepath=`head -n1 $infofile`
      else
        echo "cannot restore $i due to $infofile missing"
        continue
      fi
      targetfolder=`dirname "$filepath"`
      while [[ -e "$filepath" ]]; do
        (( j++ ))
        filepath="$filepath"_1
        if [[ $j -gt 100 ]]; then
          echo "cannot restore $i due to too many conflicts in $targetfolder"
          break
        fi
      done
      [[ -e "$filepath" ]] && continue
      mkdir -p "$targetfolder" && mv -n "$i" "$filepath" && rm "$infofile"
    done ;;
  *)
    for i; do
      if [[ `dirname "$i"` = "$trashcan" ]]; then
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
      while [[ -e "$trashcan/$filename" ]]; do
        (( j++ ))
        filename="$filename"_1
        if [[ $j -gt 100 ]]; then
          echo "cannot trash $i due to conflict in $trashcan"
          break
        fi
      done
      [[ -e "$trashcan/$filename" ]] && continue
      mv -n "$i" "$trashcan/$filename" && echo -e "$i\ndeleted on `date`" > "$trashcan/.$filename.info"
    done ;;
esac
