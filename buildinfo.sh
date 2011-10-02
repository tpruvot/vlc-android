#!/bin/sh

VERSION=`cd vlc && git describe`
DATE=`date +"%d-%m-%Y"`

INFOS="Built from git sources $VERSION\n$DATE by Tanguy Pruvot\nhttp://github.com/tpruvot/vlc-android/"

FILE=vlc-android/res/values/strings.xml
git checkout $FILE

DATA=`cat $FILE | head --lines=-3`
DATA=$DATA$INFOS
DATA=$DATA`cat $FILE | tail --lines=3`

echo $DATA > $FILE
