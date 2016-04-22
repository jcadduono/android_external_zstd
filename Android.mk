LOCAL_PATH := $(call my-dir)

zstd_version_major := `sed -n '/define ZSTD_VERSION_MAJOR/s/.*[[:blank:]]\([0-9][0-9]*\).*/\1/p' < "$(LOCAL_PATH)/lib/zstd.h"`
zstd_version_minor := `sed -n '/define ZSTD_VERSION_MINOR/s/.*[[:blank:]]\([0-9][0-9]*\).*/\1/p' < "$(LOCAL_PATH)/lib/zstd.h"`
zstd_version_patch := `sed -n '/define ZSTD_VERSION_RELEASE/s/.*[[:blank:]]\([0-9][0-9]*\).*/\1/p' < "$(LOCAL_PATH)/lib/zstd.h"`
zstd_version := $(shell echo $(zstd_version_major).$(zstd_version_minor).$(zstd_version_patch))

common_c_includes := $(LOCAL_PATH)/lib

common_cflags := \
	-std=c99 \
	-Wall -Wextra -Wundef -Wshadow -Wcast-qual -Wcast-align -Wstrict-prototypes -Wstrict-aliasing=1 \
	-DZSTD_LEGACY_SUPPORT=0 \
	-DZSTD_NODICT \
	-DZSTD_NOBENCH \
	-DZSTD_VERSION=\"$(zstd_version)\"

lib_src_files := \
	lib/zstd_compress.c \
	lib/zstd_decompress.c \
	lib/fse.c \
	lib/huff0.c

lib_cflags := \
	-O3

programs_c_includes := $(LOCAL_PATH)/programs

programs_src_files := \
	lib/zbuff.c \
	programs/zstdcli.c \
	programs/fileio.c

programs_cflags := \
	-Wswitch-enum

include $(CLEAR_VARS)
LOCAL_MODULE := libzstd-static
LOCAL_C_INCLUDES := $(common_c_includes)
LOCAL_CFLAGS := $(common_cflags) $(lib_cflags)
LOCAL_SRC_FILES := $(lib_src_files)
LOCAL_MODULE_TAGS := optional
include $(BUILD_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := libzstd
LOCAL_C_INCLUDES := $(common_c_includes)
LOCAL_CFLAGS := $(common_cflags) $(lib_cflags)
LOCAL_SRC_FILES := $(lib_src_files)
LOCAL_MODULE_TAGS := optional
include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := zstd
LOCAL_C_INCLUDES := $(programs_c_includes) $(common_c_includes)
LOCAL_CFLAGS := $(common_cflags) $(programs_cflags)
LOCAL_SRC_FILES := $(programs_src_files)
LOCAL_MODULE_TAGS := optional
ifdef ZSTD_STATIC
	LOCAL_STATIC_LIBRARIES := libzstd-static
else
	LOCAL_SHARED_LIBRARIES := libzstd
endif
include $(BUILD_EXECUTABLE)

