LOCAL_PATH := $(call my-dir)

zstd_version_major := `sed -n '/define ZSTD_VERSION_MAJOR/s/.*[[:blank:]]\([0-9][0-9]*\).*/\1/p' < "$(LOCAL_PATH)/lib/common/zstd.h"`
zstd_version_minor := `sed -n '/define ZSTD_VERSION_MINOR/s/.*[[:blank:]]\([0-9][0-9]*\).*/\1/p' < "$(LOCAL_PATH)/lib/common/zstd.h"`
zstd_version_patch := `sed -n '/define ZSTD_VERSION_RELEASE/s/.*[[:blank:]]\([0-9][0-9]*\).*/\1/p' < "$(LOCAL_PATH)/lib/common/zstd.h"`
zstd_version := $(shell echo $(zstd_version_major).$(zstd_version_minor).$(zstd_version_patch))

common_c_includes := $(LOCAL_PATH)/lib/common $(LOCAL_PATH)/lib/compress $(LOCAL_PATH)/lib/decompress

common_cflags := \
	-std=c99 \
	-Wall -Wextra -Wundef -Wshadow -Wcast-qual -Wcast-align -Wstrict-prototypes -Wstrict-aliasing=1 \
	-DZSTD_LEGACY_SUPPORT=0 \
	-DZSTD_VERSION=\"$(zstd_version)\"

compress_src_files := \
	lib/compress/zstd_compress.c \
	lib/compress/fse_compress.c \
	lib/compress/huf_compress.c


decompress_src_files := \
	lib/decompress/zstd_decompress.c \
	lib/decompress/huf_decompress.c

lib_src_files := \
	lib/common/entropy_common.c \
	lib/common/zstd_common.c \
	lib/common/fse_decompress.c \
	$(compress_src_files) \
	$(decompress_src_files)

lib_cflags := \
	-O3

programs_c_includes := $(LOCAL_PATH)/programs

programs_src_files := \
	lib/compress/zbuff_compress.c \
	lib/decompress/zbuff_decompress.c \
	programs/zstdcli.c \
	programs/fileio.c

programs_cflags := \
	-Wswitch-enum

ifdef ZSTD_INCLUDE_DICT
	lib_src_files += \
		lib/dictBuilder/zdict.c \
		lib/dictBuilder/divsufsort.c
	ZSTD_INCLUDE_DIBIO := y
else
	common_cflags += -DZSTD_NODICT
endif

ifdef ZSTD_INCLUDE_BENCH
	programs_src_files += \
		programs/xxhash.c \
		programs/datagen.c \
		programs/bench.c
	ZSTD_INCLUDE_DIBIO := y
else
	common_cflags += -DZSTD_NOBENCH
endif

ifdef ZSTD_INCLUDE_DIBIO
	programs_src_files += \
		programs/dibio.c
endif

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

