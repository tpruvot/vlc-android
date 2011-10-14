#!/bin/sh

PWD=`pwd`
VLC=${PWD}/vlc
GIT=git

if [ -z "$ANDROID_NDK" -o -z "$ANDROID_SDK" ]; then
   echo "You must define ANDROID_NDK and ANDROID_SDK before starting"
   exit 1
fi

echo "Fetching Android system headers"
# Using CyanogenMod headers instead of AOSP, since CyanogenMod
# has commit 1563f4aca88d354c502dba056d173cefc7c2ea7f,
# "Stagefright: Memcpy optimization on output port." (available
# upstream at https://www.codeaurora.org/gitweb/quic/la/?p=platform/frameworks/base.git;a=commit;h=052368f194c9fc180b9b0335b60114a2f1fb88d8),
# which adds some vtable entries needed on newer qualcomm devices.
if [ -z "$ANDROID_BUILD_TOP" ]; then
    $GIT clone --depth=1 git://github.com/CyanogenMod/android_frameworks_base.git android-headers/frameworks/base
    $GIT clone --depth=1 git://github.com/CyanogenMod/android_system_core.git android-headers/system/core
    export ANDROID_SYS_HEADERS=${PWD}/android-headers
else
    export ANDROID_SYS_HEADERS=$ANDROID_BUILD_TOP
fi

echo "Fetching Android libraries for linking"
# Libraries from any froyo/gingerbread device/emulator should work
# fine, since the symbols used should be available on most of them.

# HTC passion
# cyanogen_zip=update-cm-7.0.3-N1-signed.zip

# Motorola Droid : TI omap3420
# cyanogen_zip=update-cm-7.0.3-Droid-signed.zip

# Motorola Defy : TI omap3630 :
cyanogen_zip=cm_jordan_full-20.zip

if [ ! -f "$cyanogen_zip" ]; then
    wget http://download.cyanogenmod.com/get/$cyanogen_zip
    unzip $cyanogen_zip system/lib/*
    mv system/lib android-libs
    rmdir system
fi
export ANDROID_LIBS=${PWD}/android-libs

echo "Cloning and updating VLC"
if [ ! -d $VLC ]; then
    $GIT clone git://git.videolan.org/vlc.git
    cd $VLC
    # add a git remote to cherry-pick new patchs if required
    $GIT remote add mstorsjo git://github.com/mstorsjo/vlc.git && $GIT fetch mstorsjo
else
    cd $VLC
    $GIT fetch
    $GIT checkout -f master && $GIT branch -D android
    $GIT pull --rebase
fi

echo "Applying the patches"
$GIT branch android && $GIT checkout -f android
$GIT am ../patches/*.patch
ERR=$?
if [ $ERR -eq 1 ] ; then
    $GIT am --abort
    echo
    echo "Patches needs to be rebased !"
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

#./buildinfo.sh

VLC_BUILD_DIR=vlc/android V=1 make

VERSION=`cd $VLC && git describe`
if [ -f vlc-android/bin/VLC-debug.apk ]; then
  cp -f vlc-android/bin/VLC-debug.apk VLC-$VERSION.apk
fi

# cleanup build info
git checkout vlc-android/res/values/

