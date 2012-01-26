#!/bin/bash
#author: trile7 at gmail dot com
#dependencies: yad, openssl, imagemagick, curl, alsa-utils (to play sound)

function createrc(){
  [[ $# -eq 0 ]] && readrc -once
  oIFS=$IFS; IFS='|'
  x=(`yad --title gmailchecker --window-icon "${x[2]}" --center --text "<b>gmail account information:</b>" --form --field "<i>username (required)</i>" "${x[0]}" --field "<i>password (required)</i>":H "${x[1]}" --field "<i>icon fullpath (required)</i>" "${x[2]}" --field "check frequency (s)":NUM "${x[3]:=120}!1..3600" --field "open link command (browser)" "${x[4]:=xdg-open}" --field "run when icon is clicked" "${x[5]}" --field "sound WAV fullpath" "${x[6]}" --field "play sound on new mail":CHK "${x[7]:=TRUE}"`) || exit
  IFS=$oIFS
  rm "$rc"
  [[ ${x[1]} ]] && x[1]=`echo ${x[1]} | openssl enc -base64`
  for i in "${x[@]}"; do echo $i >> "$rc"; done
  chmod 600 "$rc"
  readrc
  }

function readrc(){
  touch "$rc"
  i=0
  while read line; do
    x[$i]=$line; ((i++))
  done < "$rc"
  [[ ${x[1]} ]] && x[1]=`echo ${x[1]} | openssl enc -base64 -d`
  if [[ -z ${x[0]} ]] || [[ -z ${x[1]} ]] || [[ ! -e ${x[2]} ]]; then
    [[ $# -eq 0 ]] && (yad --center --title gmailchecker --window-icon "${x[2]}" --button gtk-ok:0 --text "make sure username and password fields are filled, and icon fullpath exists."; createrc -missinginfo)
  fi
  }

function checkmail(){
  readrc
  mv $tmp $_tmp
  if which curl; then
    curl -su ${x[0]}:${x[1]} https://mail.google.com/mail/feed/atom | grep title | sed "s/<title>//" | sed "s/<\/title>//" > $tmp
  else
    wget -q --secure-protocol=TLSv1 --no-check-certificate --user=trile7 --password=chels120 https://mail.google.com/mail/feed/atom -O - | grep title | sed "s/<title>//" | sed "s/<\/title>//" > $tmp
  fi
  oIFS=$IFS; IFS=$'\n'
  m=(`cat $tmp`)
  IFS=$oIFS
  tip="${m[0]}"
  if [[ ${#m[@]} -gt 1 ]]; then
    convert "${x[2]}" -gravity North -pointsize 16 -annotate 0 `expr ${#m[@]} - 1` $_img
    echo "icon:$_img" >&4
    if [[ ${x[7]} = "TRUE" ]] && [[ -e ${x[6]} ]]; then diff $tmp $_tmp || aplay "${x[6]}"; fi
    for i in "${m[@]:1}"; do
      tip="$tip\n-${i:0:50}"
    done
  elif [[ ${#m[@]} -eq 1 ]]; then
    echo "icon:${x[2]}" >&4
  else
    convert "${x[2]}" -gravity Center -pointsize 24 -annotate 0 "X" $_img
    tip="cannot access gmail!"
    echo "icon:$_img" >&4
  fi
  echo  "tooltip:$tip" >&4
  [[ ${x[5]} ]] && echo "action:${x[5]}" >&4
  [[ ${x[4]} ]] && opengmail="open gmail!${x[4]} https://mail.google.com|"
  echo "menu:${opengmail}|refresh!$0 -refresh|configuration!$0 -c|quit!kill `cat $pid`" >&4
  rm $_tmp
  }

function on_exit(){
  echo quit >&4
  rm -f $pipe $_img $tmp $pid
  }

if [[ -z $DISPLAY ]]; then echo "Cannot detect display.  Exit"; exit 1; fi
pipe="/tmp/gmailchecker.pipe"
rc="$HOME/.gmailcheckerrc"
_img="/tmp/gmail.png"
pid="/tmp/gmail.pid"
tmp=/tmp/gmail.txt
_tmp=/tmp/gmail.old
case $1 in
  -c) 
    createrc
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
[[ -e $pid ]] && (kill `cat $pid`; sleep 1)
[[ -e $pipe ]] || mkfifo $pipe
exec 4<> $pipe
trap on_exit EXIT
echo $$ > $pid
while true; do
  if ! ps -C yad -f | grep -q gmail.*notification; then
    yad --kill-parent --text gmailchecker --notification --listen <&4 &
    sleep 1
  fi
  checkmail
  sleep ${x[3]}
done
