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

#dependencies: yad, openssl, imagemagick, alsa-utils (to play sound)

pipe="/tmp/gmailchecker.pipe"
rc="$HOME/.gmailcheckerrc"
_img="/tmp/gmail.png"
pid="/tmp/gmail.pid"
tmp=/tmp/gmail.txt
_tmp=/tmp/gmail.old

function createrc(){
  x=`yad --title gmailchecker --window-icon "$ICON" --center --text "<b>gmail account information:</b>" --form --field "<i>username (required)</i>" "$USER" --field "<i>password (required)</i>":H "$PASS" --field "<i>icon fullpath (required)</i>" "$ICON" --field "check interval (s)":NUM "${INTERVAL:=120}!1..3600" --field "open link command (browser)" "${OPEN:=xdg-open}" --field "run when icon is clicked" "$RUN" --field "sound WAV fullpath" "$WAV" --field "play sound on new mail":CHK "${SOUND:=TRUE}"`
  if [[ $? -eq 0 ]]; then
    echo USER=\'`echo $x | cut -d'|' -f1`\' > $rc
    echo PASS=\'`echo $x | cut -d'|' -f2 | openssl enc -base64`\' >> $rc
    echo ICON=\'`echo $x | cut -d'|' -f3`\' >> $rc
    echo INTERVAL=\'`echo $x | cut -d'|' -f4`\' >> $rc
    echo OPEN=\'`echo $x | cut -d'|' -f5`\' >> $rc
    echo RUN=\'`echo $x | cut -d'|' -f6`\' >> $rc
    echo WAV=\'`echo $x | cut -d'|' -f7`\' >> $rc
    echo SOUND=\'`echo $x | cut -d'|' -f8`\' >> $rc
    chmod 600 "$rc"
  elif [[ ! -f "$rc" ]]; then
    pkill gmailchecker
  else
    exit
  fi
  readrc
  }

function readrc(){
  if [[ -f "$rc" ]]; then
   source "$rc"
    PASS=`echo "$PASS" | openssl enc -base64 -d`
    [[ $1 ]] && createrc
  else
    createrc
  fi
  }

function checkmail(){
  readrc
  mv $tmp $_tmp
  wget -q --secure-protocol=TLSv1 --no-check-certificate --user=$USER --password=$PASS https://mail.google.com/mail/feed/atom -O - | grep title | sed "s/<title>//" | sed "s/<\/title>//" > $tmp
  oIFS=$IFS; IFS=$'\n'
  diff $tmp $_tmp && return
  m=(`cat $tmp`)
  IFS=$oIFS
  tip="${m[0]}"
  if [[ ${#m[@]} -gt 1 ]]; then
    convert "$ICON" -gravity North -pointsize 16 -annotate 0 `expr ${#m[@]} - 1` $_img
    if [[ $SOUND = "TRUE" ]] && [[ -f "$WAV" ]]; then aplay "$WAV"; fi
    for i in "${m[@]:1}"; do
      tip="$tip\n-${i:0:50}"
    done
  elif [[ ${#m[@]} -eq 1 ]]; then
    cp "$ICON" $_img
  else
    convert "$ICON" -gravity Center -pointsize 24 -annotate 0 "X" $_img
    tip="cannot access gmail!"
  fi
  echo  "tooltip:$tip" >&4
  echo "action:$RUN" >&4
  [[ $OPEN ]] && opengmail="open gmail!$OPEN https://mail.google.com|"
  echo "menu:${opengmail}|refresh!$0 -refresh|configuration!$0 -c|quit!pkill -f gmailchecker" >&4
  }

function on_exit(){
  echo quit >&4
  rm -f $pipe $_img $tmp $_tmp $pid
  }

if [[ -z $DISPLAY ]]; then echo "Cannot detect display.  Exit"; exit 1; fi
case $1 in
  -c)
    readrc then-createrc
    exit ;;
  -b)
    nohup $0 &> /dev/null &
    exit ;;
  -h|--help)
    echo "Usage: $0 [OPTIONS]"
    echo "  -b run in background.  Use this option instead of '&'"
    echo "  -c change configuration"
    exit  ;;
  -refresh)
    [[ -e $pipe ]] && exec 4<> $pipe || exit 1
    checkmail
    exit ;;
esac
[[ -e $pid ]] && exit
[[ -e $pipe ]] || mkfifo $pipe
exec 4<> $pipe
trap on_exit EXIT
cp "$ICON" $_img
while true; do
  if ! pgrep -f "gmail.*notification"; then
    yad --kill-parent --text gmailchecker --notification --listen <&4 &
    echo $! > $pid
    sleep 1
  fi
  checkmail
  echo "icon:$_img" >&4
  sleep $INTERVAL
done
