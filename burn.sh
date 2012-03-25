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

#dependencies: cdrtools, dvd+rw-tools
#optional dependencies: mpg123 or lame or normalize to convert mp3 to wav for audio cd

burndir="/tmp/burndir"
tmpfile="/tmp/burn.txt"

function menu {
  echo "---BurnCDDVD Menu---"
  n=0
  for i in "$@"; do
    echo "$((n++))) $i"
  done
  echo "Enter c or q to cancel"
  echo
  read -p "Enter a number from menu: " i
  case $i in
    [0-$n]) return $i ;;
    c|q) exit 1 ;;
    *) echo "Invalid entry...please try again!"; menu "$@" ;;
  esac
  }

function burnmenu {
  checksize
  clear
  echo "Drive: $DEV"
  echo "Media: $DISCTYPE"
  echo "Status: $DISCSTAT"
  echo "Est. extra space: $EXTRASPACE MB"
  echo "Data content: $burndir"
  echo "Mode: $MODE"
  echo
  #Burn audio CD from mp3
  if [[ $MODE = audio && $DISCTYPE = CD* && $cue ]]; then
    cmd="cdrecord -v dev=$DEV driveropts=burnfree cuefile=$cue -text -raw -pad"
    burndir=`dirname $burndir`
  #Burn audio CD from WAV
  elif [[ $MODE = audio && $DISCTYPE = CD* ]]; then
    cmd="cdrecord -v dev=$DEV driveropts=burnfree -pad -audio *.wav"
  #Burn video DVD
  elif [[ $MODE = video && $DISCTYPE = DVD* ]]; then
    vollabel
    cmd="growisofs -dvd-video -udf -f -l -V ${VOLID:0:8} -Z $DEV $burndir"
  #Burn data
  elif [[ $MODE = data && $DISCTYPE = DVD* ]]; then
    vollabel
    cmd="growisofs -r -f -J -l -V ${VOLID:0:8} -Z $DEV $burndir"
  elif [[ $MODE = data && $DISCTYPE = DVD* ]]; then
    vollabel
    cmd="growisofs -r -f -J -l -V ${VOLID:0:8} -M $DEV $burndir"
  elif [[ $MODE = data && $DISCTYPE = CD* ]]; then
    cmd="cdrecord -v -overburn -eject -multi dev=$DEV $burndir"
  #Burn iso file
  elif [[ $MODE = burniso && $DISCTYPE = DVD* ]]; then
    cmd="growisofs -Z $DEV=$ISO"
  elif [[ $MODE = burniso && $DISCTYPE = DVD* ]]; then
    cmd="growisofs -M $DEV=$ISO"
  elif [[ $MODE = burniso && $DISCTYPE = CD* ]]; then
    cmd="cdrecord -v -eject -multi dev=$DEV $ISO"
  #Make iso from burndir or DEV
  elif [[ $MODE = makeiso ]]; then
    read -p "ISO filename: " i
    FNAME=${i:-$HOME/image.iso}
    while [[ -e $FNAME ]]; do FNAME=${FNAME%.*}_1.iso; done
    VOLID=`basename "$FNAME" .iso`
    menu "Data content" "Video DVD content"
    if [[ $? -eq 1 ]]; then
      cmd="mkisofs -r -f -J -l -V ${VOLID:0:8} -o $FNAME $burndir"
    else
      cmd="mkisofs -dvd-video -udf -f -l -V ${VOLID:0:8} -o $FNAME $burndir"
    fi
  fi
  echo "Burning command:"
  echo "$cmd"
  echo
  menu "Burn" "Change device" "Drive and media info" "Erase RW media" "Refresh" "Mode menu"
  case $? in
    0) $cmd ;;
    1) read -p "device path: " i
       [[ -e $i ]] || echo "Device $i doesn't exist!"
       DEV=${i:=$DEV}
       burnmenu
       ;;
    2) clear
       cat $tmpfile
       burnmenu
       ;;
    3) if [[ $DISCTYPE = DVD-RW* ]]; then
         dvd+rw-format $DEV
       elif [[ $DISCTYPE = CD-RW* ]]; then
         cdrecord dev=$DEV -v -eject blank=fast
       else
         echo "Media is not rewritable"
       fi
       burnmenu
       ;;
    4) burnmenu ;;
    5) modemenu ;;
  esac
  }

function modemenu {
  burndir="/tmp/burndir"
  if ISO=`ls | grep -m1 -i .iso`; then
    MODE=burniso
    burndir=$ISO
  else
    menu "Burn audio CD" "Burn video DVD" "Burn data" "Make ISO from $burndir content" "Make ISO from $DEV content"
    case $? in
      0) MODE=audio ;;
      1) MODE=video ;;
      2) MODE=data ;;
      3) MODE=makeiso ;;
      4) MODE=makeiso; burndir=$DEV ;;
      *) exit 1 ;;
    esac
  fi
  if [ $MODE = "audio" ]; then
    read -p "Convert mp3s to wavs? (Y/n) " i
    [[ $i = "n" ]] || mp3-wav
  fi
  burnmenu
  }

function checksize {
  echo "checking media and capcity..."
  cdrecord dev=$DEV -minfo > $tmpfile
  DISCTYPE=`grep "media type" $tmpfile|awk '{print $4}'`
  DISCSIZE=`grep "writable size" $tmpfile|awk '{print $4}'`
  DISCSTAT=`grep "disk status" $tmpfile|awk '{print $3}'`
  DIRSIZE=`du -sLb $burndir|awk '{print $1}'`; DIRSIZE=$(( DIRSIZE / 2048 ))
  EXTRASPACE=$(( (DISCSIZE-DIRSIZE)/512 ))
  }

function vollabel {
  read -p "Volume label: " i
  VOLID=${i:=CDDVD}
  }

function mp3-wav {
  burndir=$burndir/WAV
  mkdir -p $burndir
  for i in *.mp3; do
    [[ -f $i ]] || break
    mpg123 -w "WAV/${i%.*}.wav" "$i" || lame --decode "$i" "WAV/${i%.*}.wav"
  done
  normalize -b $burndir/*.wav
  cuesheet
  }

function cuesheet {
  cue=$burndir/cuesheet.cue
  header=yes
  for i in *.mp3; do
    [[ -f $i ]] || continue
    oIFS=$IFS; IFS=$'\n'
    tags=(`id3info "$i" | egrep "TIT2|TPE1|TALB|TYER|TRCK" | awk -F ': ' '{print $2}'`)
    IFS=$oIFS
    title="${tags[0]}"
    performer="${tags[1]}"
    album="${tags[2]}"
    year="${tags[3]}"
    track="${tags[4]}"
    if [[ $header = "yes" ]]; then
      echo "REM COMMENT 'Enter genre, album title, album artist, and year in quote.  This line can be removed.'" > $cue
      echo "REM GENRE ''" >> $cue
      echo "REM YEAR '$year'" >> $cue
      echo "TITLE '$title'" >> $cue
      echo "PERFORMER 'Various Artist'"
      header=no
    fi
    echo "FILE '$burndir/${i%.*}.wav' WAVE" >> $cue
    echo "  TRACK $track AUDIO" >> $cue
    echo "  PERFORMER '$performer'" >> $cue
    echo "  INDEX 01 00:00:00" >> $cue
  done
  $EDITOR $cue
  }

function addfile {
  [[ -e $1 ]] && ln -sf "$1" $burndir
  }

mkdir -p $burndir
cd $burndir
case $1 in
  --addfiles)
    shift
    for i; do addfile "$i"; done
    exit 0 ;;
  --help|-h)
    tty -s || exit 1
    echo "$0 --addfiles               #add files to burn folder, then exit"
    echo "$0 --help                   #print this, then exit"
    echo "$0 filepath1 filepath2 .... #add files for burn folder, then start burn menu"
    echo "$0                          #start burn menu"
    echo "To burn ISO file, copy/link it to burn folder.  Only the first ISO file will be burned."
    echo "Burn folder is located at $burndir"
    exit 0 ;;
  *)
    for i; do addfile "$i"; done ;;
esac
tty -s || exit 1
DEV=(`ls /dev/sr*`)
if [[ ${#DEV[@]} -gt 2 ]]; then
  menu ${DEV[@]}
  DEV=${DEV[$?]}
fi
modemenu
eject $DEV
read -p "Clear $burndir content? (Y/n) " i
[[ $i = "n" ]] || rm -rf "$burndir/*"
