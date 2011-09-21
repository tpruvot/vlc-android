LOCAL_PATH:= $(call my-dir)

# First: Use "./install.sh" to generate jni libvlc
# Use ant or eclipse to generate the full user APK

include $(CLEAR_VARS)

LOCAL_PACKAGE_NAME := VLC
LOCAL_MODULE_TAGS := optional
LOCAL_CERTIFICATE := platform

LOCAL_SRC_FILES := $(call all-java-files-under, src)
LOCAL_SRC_FILES += \
	gen/org/videolan/vlc/android/IAudioServiceCallback.java \
	gen/org/videolan/vlc/android/IAudioService.java \

LOCAL_JAVACFLAGS += -encoding UTF-8 -Xlint:unchecked

#LOCAL_JNI_SHARED_LIBRARIES := libvlcjni
LOCAL_REQUIRED_MODULES := system-libvlcjni

include $(BUILD_PACKAGE)

###############################################################
# Dont build, copy prebuilt lib compiled by "install.sh"

include $(CLEAR_VARS)

LOCAL_MODULE      := system-libvlcjni
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES   := libs/armeabi/libvlcjni.so
LOCAL_SHARED_LIBRARY := libc
LOCAL_MODULE_STEM := libvlcjni.so
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
include $(BUILD_PREBUILT)


# Use the folloing include to make the jni lib
# include $(call all-makefiles-under,$(LOCAL_PATH))
