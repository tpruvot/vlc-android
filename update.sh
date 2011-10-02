#!/bin/sh

PWD=`pwd`
VLC=${PWD}/vlc
GIT=git

if [ -z "$ANDROID_NDK" -o -z "$ANDROID_SDK" ]; then
   echo "You must define ANDROID_NDK and ANDROID_SDK env variables"
   exit 1
fi

# Using CyanogenMod headers instead of AOSP, since CyanogenMod
# has commit 1563f4aca88d354c502dba056d173cefc7c2ea7f,
# "Stagefright: Memcpy optimization on output port." (available
# upstream at https://www.codeaurora.org/gitweb/quic/la/?p=platform/frameworks/base.git;a=commit;h=052368f194c9fc180b9b0335b60114a2f1fb88d8),
# which adds some vtable entries needed on newer qualcomm devices.
if [ -z "$ANDROID_BUILD_TOP" ]; then
    if [ ! -d "${PWD}/android-headers" ]; then
        echo "Android headers not found !"
        exit 1
    fi
    export ANDROID_SYS_HEADERS=${PWD}/android-headers
else
    export ANDROID_SYS_HEADERS=$ANDROID_BUILD_TOP
fi

# Libraries from any froyo/gingerbread device/emulator should work
# fine, since the symbols used should be available on most of them.
if [ ! -d "${PWD}/android-libs" ]; then
    echo "Android libs not found !"
    exit 1
fi
export ANDROID_LIBS=${PWD}/android-libs

echo "Updating VLC"
if [ ! -d $VLC ]; then
    echo "VLC Directory not found !"
    exit 1
fi

cd $VLC
echo "Applying the patches"
$GIT fetch origin
$GIT rebase origin/master android
ERR=$?
if [ $ERR -eq 1 ] ; then
    $GIT rebase --abort
    echo
    echo "Rebase error !"
    exit 1
fi

cd $VLC/extras/contrib/build-src/ffmpeg
echo "Update ffmpeg"
$GIT fetch origin
$GIT rebase origin/master
ERR=$?
if [ $ERR -eq 1 ] ; then
    $GIT rebase --abort
    echo
    echo "Rebase error !"
    exit 1
fi

echo "Building the contribs"
cd $VLC/extras/contrib
./bootstrap -t arm-eabi -d android && make

mkdir -p $VLC/android
cd $VLC/android
if [ ! -s "../configure" ]; then
    echo "Bootstraping"
    ../bootstrap
fi

echo "Configuring..."
cd $VLC/android
sh ../extras/package/android/configure.sh

echo "Building libvlc"
make

echo "Building Android"
cd $VLC/../

# Clean previous apk
make distclean

./buildinfo.sh

VLC_BUILD_DIR=vlc/android V=1 make

VERSION=`cd $VLC && git describe`
if [ -f vlc-android/bin/VLC-debug.apk ]; then
  cp -f vlc-android/bin/VLC-debug.apk VLC-$VERSION.apk
fi

# cleanup build info
git checkout vlc-android/res/values/

