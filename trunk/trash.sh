#!/bin/bash

icon="/home/tri/icons/trash.png"
trashcan="$HOME/.local/trash"
max_size=1000000000
d="%fs%"

function usage() {
cat << EOF
Dependencies: yad

Usage:
  -h|--help|--usage|--info     print this message
  --empty                      empty everything in $trashcan
  --restore filepaths          restore selected files to it original location
  filepaths                    move files to $trashcan

When a file is move to the trashcan by this script, the directory indicator forward slash is converted to "$d".  This is necessary if one want to restore the file to its original location.

Author: trile7 at gmail dot com
EOF
exit
}

[ $# -eq 0 ] && usage
mkdir -p $trashcan
case $1 in
  -h|--help|--usage|--info) usage ;;
  --empty) rm -rf $trashcan/* ;;
  --restore)
    shift
    for i; do
      f=${i##*/}
      f=${f//$d/\/}
      if [ -e "$f" ]; then
        yad --center --on-top --window-icon $icon gtk-delete --button gtk-no:1 --button gtk-yes:0 --title "Confirm Overwrite" --text "$f existed.  Do you want to overwrite?"
        [ $? -eq 0 ] && mv -f "$i" "$f"
      else
        mv "$i" "$f"
      fi
    done ;;
  *)
    for i; do
      [[ $trashcan = ${i%/*} ]] && continue
      s=(`du -bs "$i"`)
      if [ $s -gt $max_size ]; then
        yad --center --on-top --window-icon $icon gtk-delete --button gtk-no:1 --button gtk-yes:0 --title "Confirm Delete" --text "$i size is greater than $max_size.  Delete permanently? \n<b>No</b> will move it to trash"
        ret=$?
      else
        ret=1
      fi
      if [[ $ret -eq 0 ]]; then
        rm -rf "$i"
      elif [ $ret -eq 1 ]; then
        cd `dirname "$i"`
        f=${PWD//\//$d}$d${i##*/}
        mv -f "$i" $trashcan/"$f"
      else
        exit $ret
      fi
    done ;;
esac
