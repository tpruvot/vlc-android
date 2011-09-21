LOCAL_PATH := $(call my-dir)

# This Makefile is used by "install.sh", not by repo
ifneq (${ANDROID_NDK},)

$(print-vars VLC DIRECTORY=${VLC_SRC_DIR})

include $(CLEAR_VARS)

LOCAL_MODULE    := libvlcjni

LOCAL_MODULE_TAGS := optional
LOCAL_PRELINK_MODULE := false

LOCAL_SRC_FILES := libvlcjni.c aout.c thumbnailer.c

LOCAL_C_INCLUDES := ${VLC_SRC_DIR}/include

VLC_CONTRIB ?= ${VLC_SRC_DIR}/extras/contrib/hosts/arm-eabi
LOCAL_C_INCLUDES += \
	$(VLC_CONTRIB)/include \

ifeq ($(NO_NEON),)
ARCH=armeabi-v7a
else
ARCH=armeabi
endif

ANDROID_LDLIBS := -L$(ANDROID_LIBS) -lstagefright -lmedia -lutils -lbinder

LOCAL_LDLIBS := -L${VLC_CONTRIB}/lib \
	${VLC_MODULES} \
	${VLC_BUILD_DIR}/compat/.libs/libcompat.a \
	${VLC_BUILD_DIR}/lib/.libs/libvlc.a \
	${VLC_BUILD_DIR}/src/.libs/libvlccore.a \
	-ldl -lz -lm -logg -lvorbisenc -lvorbis -lFLAC -lspeex -lspeexdsp -ltheora \
	-lavformat -lavcodec -lswscale -lavutil -lpostproc \
	-lmpeg2 -lpng -ldca -ldvbpsi -ltwolame -lkate -llog -la52 \
	-lebml -lmatroska -ltag \
	$(ANDROID_LDLIBS) \
	${ANDROID_NDK}/sources/cxx-stl/gnu-libstdc++/libs/$(ARCH)/libstdc++.a

include $(BUILD_SHARED_LIBRARY)

endif #ANDROID_NDK != ""
