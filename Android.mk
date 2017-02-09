LOCAL_PATH := $(call my-dir)

zstd_version_major := `sed -n '/define ZSTD_VERSION_MAJOR/s/.*[[:blank:]]\([0-9][0-9]*\).*/\1/p' < "$(LOCAL_PATH)/lib/zstd.h"`
zstd_version_minor := `sed -n '/define ZSTD_VERSION_MINOR/s/.*[[:blank:]]\([0-9][0-9]*\).*/\1/p' < "$(LOCAL_PATH)/lib/zstd.h"`
zstd_version_patch := `sed -n '/define ZSTD_VERSION_RELEASE/s/.*[[:blank:]]\([0-9][0-9]*\).*/\1/p' < "$(LOCAL_PATH)/lib/zstd.h"`
zstd_version := $(shell echo $(zstd_version_major).$(zstd_version_minor).$(zstd_version_patch))

common_c_includes := \
	$(LOCAL_PATH)/lib \
	$(LOCAL_PATH)/lib/common \
	$(LOCAL_PATH)/lib/compress

common_cflags := \
	-std=c99 \
	-O3 \
	-Wall -Wextra -Wcast-qual -Wcast-align -Wshadow -Wstrict-aliasing=1 \
	-Wswitch-enum -Wdeclaration-after-statement -Wstrict-prototypes \
	-Wundef -Wpointer-arith \
	-DZSTD_LEGACY_SUPPORT=0 \
	-DZSTD_VERSION=\"$(zstd_version)\"

compress_src_files := \
	lib/compress/zstd_compress.c \
	lib/compress/fse_compress.c \
	lib/compress/huf_compress.c

decompress_src_files := \
	lib/decompress/zstd_decompress.c \
	lib/decompress/huf_decompress.c

lib_c_includes :=

lib_cflags :=

lib_src_files := \
	lib/common/error_private.c \
	lib/common/entropy_common.c \
	lib/common/xxhash.c \
	lib/common/zstd_common.c \
	lib/common/fse_decompress.c \
	$(compress_src_files) \
	$(decompress_src_files)

ifndef ZSTD_NO_COMPRESS
	programs_cflags += -DZSTD_NOCOMPRESS
	ZSTD_INCLUDE_DICT :=
	ZSTD_INCLUDE_BENCH :=
endif

ifndef ZSTD_NO_DECOMPRESS
	programs_cflags += -DZSTD_NODECOMPRESS
	ZSTD_INCLUDE_DICT :=
	ZSTD_INCLUDE_BENCH :=
endif

programs_c_includes := $(LOCAL_PATH)/programs

programs_cflags :=

programs_src_files := \
	programs/zstdcli.c \
	programs/fileio.c

ifdef ZSTD_INCLUDE_DICT
	common_c_includes += $(LOCAL_PATH)/lib/dictBuilder
	lib_src_files += \
		lib/dictBuilder/zdict.c \
		lib/dictBuilder/divsufsort.c \
		lib/dictBuilder/cover.c
	ZSTD_INCLUDE_DIBIO := y
else
	common_cflags += -DZSTD_NODICT
endif

ifdef ZSTD_INCLUDE_BENCH
	programs_src_files += \
		programs/datagen.c \
		programs/bench.c
else
	common_cflags += -DZSTD_NOBENCH
endif

ifdef ZSTD_INCLUDE_DIBIO
	programs_src_files += \
		programs/dibio.c
endif

ifdef ZSTD_MULTITHREAD
	programs_src_files += \
		lib/common/xxhash.c \
		lib/common/pool.c \
		lib/common/threading.c
	ifndef ZSTD_NO_COMPRESS
		programs_src_files += \
			lib/compress/zstdmt_compress.c
	endif
	common_cflags += -DZSTD_MULTITHREAD
endif

include $(CLEAR_VARS)
LOCAL_MODULE := libzstd-static
LOCAL_C_INCLUDES := $(lib_c_includes) $(common_c_includes)
LOCAL_CFLAGS := $(common_cflags) $(lib_cflags)
LOCAL_SRC_FILES := $(lib_src_files)
LOCAL_SDK_VERSION := 21
LOCAL_MODULE_TAGS := optional
include $(BUILD_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := libzstd
LOCAL_C_INCLUDES := $(lib_c_includes) $(common_c_includes)
LOCAL_CFLAGS := $(common_cflags) $(lib_cflags)
LOCAL_SRC_FILES := $(lib_src_files)
LOCAL_SDK_VERSION := 21
LOCAL_MODULE_TAGS := optional
include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := zstd
LOCAL_C_INCLUDES := $(programs_c_includes) $(common_c_includes)
LOCAL_CFLAGS := $(common_cflags) $(programs_cflags)
LOCAL_SRC_FILES := $(programs_src_files)
LOCAL_SDK_VERSION := 21
LOCAL_MODULE_TAGS := optional
ifdef ZSTD_STATIC
	LOCAL_STATIC_LIBRARIES := libzstd-static
else
	LOCAL_SHARED_LIBRARIES := libzstd
endif
include $(BUILD_EXECUTABLE)

