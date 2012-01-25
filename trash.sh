#!/bin/bash

icon="/home/tri/icons/trash.png"
trashcan="$HOME/.local/trash"
[ $# -eq 0 ] && exit
mkdir -p $trashcan
case $1 in
  --empty)
    rm -rf $trashcan/* ;;
  --restore)
    shift
    for i; do
      if [ ${i:0:1} = "_" ]; then
        F=${i##*/}
        F=${F//_/\/}
        if [ -e "$F" ]; then
          yad --center --on-top --window-icon $icon gtk-delete --button gtk-no:1 --button gtk-yes:0 --title "Confirm Overwrite" --text "$F existed.  Do you want to overwrite?"
          [ $? -eq 0 ] && mv -f "$i" "$F"
        else
          mv "$i" "$F"
        fi
      fi
    done ;;
  *)
    for i; do
      [[ $trashcan = ${i%/*} ]] && continue
      S=(`du -bs "$i"`)
      if [ $S -gt 1000000000 ]; then
        yad --center --on-top --window-icon $icon gtk-delete --button gtk-no:1 --button gtk-yes:0 --title "Confirm Delete" --text "$i size is greater than 1GB.  Delete permanently? \n<b>No</b> will move it to trash"
        ret=$?
      fi
      if [[ $ret -eq 0 ]]; then
        rm -rf "$i"
      elif [ $ret -eq 1 ]; then
        cd `dirname "$i"`
        F=${PWD//\//_}_${i##*/}
        mv -f "$i" $trashcan/"$F"
      else
        exit $ret
      fi
    done ;;
esac
