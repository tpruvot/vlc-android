# Sources and objects
JAVA_SOURCES=vlc-android/src/org/videolan/vlc/android/*.java
JNI_SOURCES=vlc-android/jni/*.c vlc-android/jni/*.h
VLC_APK=vlc-android/bin/VLC-debug.apk
LIBVLCJNI=vlc-android/libs/armeabi/libvlcjni.so
LIBVLCJNI_H=vlc-android/jni/libvlcjni.h

# Verbose level: -q -v or nothing (default)
VERBOSE ?= -v

all: vlc.apk

VLC_MODULES=`find $(VLC_BUILD_DIR)/modules -name 'lib*_plugin.a'|grep -v stats|tr \\\\n \ `

$(LIBVLCJNI_H):
	@if [ -z "$(VLC_BUILD_DIR)" ]; then echo "VLC_BUILD_DIR not defined" ; exit 1; fi
	@modules="$(VLC_MODULES)" ; \
	if [ -z "$$modules" ]; then echo "No VLC modules found in $(VLC_BUILD_DIR)/modules"; exit 1; fi; \
	DEFINITION=""; \
	BUILTINS="const void *vlc_static_modules[] = {\n"; \
	for file in $$modules; do \
		name=`echo $$file | sed 's/.*\.libs\/lib//' | sed 's/_plugin\.a//'`; \
		DEFINITION=$$DEFINITION"int vlc_entry__$$name (int (*)(void *, void *, int, ...), void *);\n"; \
		BUILTINS="$$BUILTINS vlc_entry__$$name,\n"; \
	done; \
	BUILTINS="$$BUILTINS NULL\n};\n"; \
	printf "/* Autogenerated from the list of modules */\n $$DEFINITION\n $$BUILTINS\n" > $@

$(LIBVLCJNI): $(JNI_SOURCES) $(LIBVLCJNI_H)
	@if [ -z "$(VLC_BUILD_DIR)" ]; then echo "VLC_BUILD_DIR not defined" ; exit 1; fi
	@if [ -z "$(ANDROID_NDK)" ]; then echo "ANDROID_NDK not defined" ; exit 1; fi
	@echo "=== Building libvlcjni with$${NO_NEON:+out} neon ==="
	@if [ -z "$(VLC_SRC_DIR)" ] ; then VLC_SRC_DIR=./vlc; fi ; \
	if [ -z "$(VLC_CONTRIB)" ] ; then VLC_CONTRIB="$$VLC_SRC_DIR/extras/contrib/build"; fi ; \
	vlc_modules="$(VLC_MODULES)" ; \
	if [ `echo "$(VLC_BUILD_DIR)" | head -c 1` != "/" ] ; then \
		vlc_modules="`echo $$vlc_modules|sed \"s|$(VLC_BUILD_DIR)|../$(VLC_BUILD_DIR)|g\"`" ; \
        VLC_BUILD_DIR="../$(VLC_BUILD_DIR)"; \
	fi ; \
	if [ `echo "$$VLC_CONTRIB"   | head -c 1` != "/" ] ; then VLC_CONTRIB="../$$VLC_CONTRIB"; fi ; \
	if [ `echo "$$VLC_SRC_DIR"   | head -c 1` != "/" ] ; then VLC_SRC_DIR="../$$VLC_SRC_DIR"; fi ; \
	$(ANDROID_NDK)/ndk-build -C vlc-android \
		VLC_SRC_DIR="$$VLC_SRC_DIR" \
		VLC_CONTRIB="$$VLC_CONTRIB" \
		VLC_BUILD_DIR="$$VLC_BUILD_DIR" \
		VLC_MODULES="$$vlc_modules"

vlc-android/local.properties:
	@echo "=== Preparing Ant ==="
	@if [ -z "$$ANDROID_SDK" ]; then echo "ANDROID_SDK not defined" ; exit 1; fi
	@printf "# Auto-generated file. Do not edit.\nsdk.dir=$$ANDROID_SDK" > $@

$(VLC_APK): $(LIBVLCJNI) $(JAVA_SOURCES) vlc-android/local.properties
	@echo "=== Building APK =="
	@cd vlc-android && ant $(VERBOSE) debug

libvlcjni: $(LIBVLCJNI)

vlc.apk: libvlcjni $(VLC_APK)

clean:
	rm -rf vlc-android/libs
	rm -rf vlc-android/obj
	rm -rf vlc-android/bin

distclean: clean
	rm -f $(LIBVLCJNI_H)
	rm -f vlc-android/local.properties

install: vlc.apk
	@echo "=== Installing APK on a remote device ==="
	@echo "Waiting for a device to be ready..." && adb wait-for-device
	@echo "Installing package" && adb install -r $(VLC_APK)

run:
	@echo "=== Running application on device ==="
	@adb wait-for-device && adb shell monkey -p org.videolan.vlc.android -s 0 1

build-and-run: vlc.apk install run
	@echo "=== Application is running ==="
