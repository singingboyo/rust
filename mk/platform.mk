# Copyright 2012 The Rust Project Developers. See the COPYRIGHT
# file at the top-level directory of this distribution and at
# http://rust-lang.org/COPYRIGHT.
#
# Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
# http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
# <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
# option. This file may not be copied, modified, or distributed
# except according to those terms.


# Create variables HOST_<triple> containing the host part
# of each target triple.  For example, the triple i686-darwin-macos
# would create a variable HOST_i686-darwin-macos with the value
# i386.
define DEF_HOST_VAR
  HOST_$(1) = $(subst i686,i386,$(word 1,$(subst -, ,$(1))))
endef
$(foreach t,$(CFG_TARGET),$(eval $(call DEF_HOST_VAR,$(t))))
$(foreach t,$(CFG_TARGET),$(info cfg: host for $(t) is $(HOST_$(t))))

# Ditto for OSTYPE
define DEF_OSTYPE_VAR
  OSTYPE_$(1) = $(subst $(firstword $(subst -, ,$(1)))-,,$(1))
endef
$(foreach t,$(CFG_TARGET),$(eval $(call DEF_OSTYPE_VAR,$(t))))
$(foreach t,$(CFG_TARGET),$(info cfg: os for $(t) is $(OSTYPE_$(t))))

# On Darwin, we need to run dsymutil so the debugging information ends
# up in the right place.  On other platforms, it automatically gets
# embedded into the executable, so use a no-op command.
CFG_DSYMUTIL := true

# Hack: not sure how to test if a file exists in make other than this
OS_SUPP = $(patsubst %,--suppressions=%, \
      $(wildcard $(CFG_SRC_DIR)src/etc/$(CFG_OSTYPE).supp*))

ifdef CFG_DISABLE_OPTIMIZE_CXX
  $(info cfg: disabling C++ optimization (CFG_DISABLE_OPTIMIZE_CXX))
  CFG_GCCISH_CFLAGS += -O0
else
  CFG_GCCISH_CFLAGS += -O2
endif

# The soname thing is for supporting a statically linked jemalloc.
# see https://blog.mozilla.org/jseward/2012/06/05/valgrind-now-supports-jemalloc-builds-directly/
ifdef CFG_VALGRIND
  CFG_VALGRIND += --error-exitcode=100 \
                  --soname-synonyms=somalloc=NONE \
                  --quiet \
                  --suppressions=$(CFG_SRC_DIR)src/etc/x86.supp \
                  $(OS_SUPP)
  ifdef CFG_ENABLE_HELGRIND
    CFG_VALGRIND += --tool=helgrind
  else
    CFG_VALGRIND += --tool=memcheck \
                    --leak-check=full
  endif
endif

# If we actually want to run Valgrind on a given platform, set this variable
define DEF_GOOD_VALGRIND
  ifeq ($(OSTYPE_$(1)),unknown-linux-gnu)
    GOOD_VALGRIND_$(1) = 1
  endif
  ifneq (,$(filter $(OSTYPE_$(1)),darwin freebsd))
    ifeq (HOST_$(1),x86_64)
      GOOD_VALGRIND_$(1) = 1
    endif
  endif
endef
$(foreach t,$(CFG_TARGET),$(eval $(call DEF_GOOD_VALGRIND,$(t))))
$(foreach t,$(CFG_TARGET),$(info cfg: good valgrind for $(t) is $(GOOD_VALGRIND_$(t))))

ifneq ($(findstring linux,$(CFG_OSTYPE)),)
  ifdef CFG_PERF
    ifneq ($(CFG_PERF_WITH_LOGFD),)
        CFG_PERF_TOOL := $(CFG_PERF) stat -r 3 --log-fd 2
    else
        CFG_PERF_TOOL := $(CFG_PERF) stat -r 3
    endif
  else
    ifdef CFG_VALGRIND
      CFG_PERF_TOOL := \
        $(CFG_VALGRIND) --tool=cachegrind --cache-sim=yes --branch-sim=yes
    else
      CFG_PERF_TOOL := /usr/bin/time --verbose
    endif
  endif
endif

# These flags will cause the compiler to produce a .d file
# next to the .o file that lists header deps.
CFG_DEPEND_FLAGS = -MMD -MP -MT $(1) -MF $(1:%.o=%.d)

AR := ar

define SET_FROM_CFG
  ifdef CFG_$(1)
    ifeq ($(origin $(1)),undefined)
      $$(info cfg: using $(1)=$(CFG_$(1)) (CFG_$(1)))
      $(1)=$(CFG_$(1))
    endif
    ifeq ($(origin $(1)),default)
      $$(info cfg: using $(1)=$(CFG_$(1)) (CFG_$(1)))
      $(1)=$(CFG_$(1))
    endif
  endif
endef

$(foreach cvar,CC CXX CPP CFLAGS CXXFLAGS CPPFLAGS, \
  $(eval $(call SET_FROM_CFG,$(cvar))))

CFG_RLIB_GLOB=lib$(1)-*.rlib

# x86_64-unknown-linux-gnu configuration
CC_x86_64-unknown-linux-gnu=$(CC)
CXX_x86_64-unknown-linux-gnu=$(CXX)
CPP_x86_64-unknown-linux-gnu=$(CPP)
AR_x86_64-unknown-linux-gnu=$(AR)
CFG_LIB_NAME_x86_64-unknown-linux-gnu=lib$(1).so
CFG_STATIC_LIB_NAME_x86_64-unknown-linux-gnu=lib$(1).a
CFG_LIB_GLOB_x86_64-unknown-linux-gnu=lib$(1)-*.so
CFG_LIB_DSYM_GLOB_x86_64-unknown-linux-gnu=lib$(1)-*.dylib.dSYM
CFG_CFLAGS_x86_64-unknown-linux-gnu := -m64
CFG_GCCISH_CFLAGS_x86_64-unknown-linux-gnu := -Wall -Werror -g -fPIC -m64
CFG_GCCISH_CXXFLAGS_x86_64-unknown-linux-gnu := -fno-rtti
CFG_GCCISH_LINK_FLAGS_x86_64-unknown-linux-gnu := -shared -fPIC -ldl -pthread  -lrt -g -m64
CFG_GCCISH_DEF_FLAG_x86_64-unknown-linux-gnu := -Wl,--export-dynamic,--dynamic-list=
CFG_GCCISH_PRE_LIB_FLAGS_x86_64-unknown-linux-gnu := -Wl,-whole-archive
CFG_GCCISH_POST_LIB_FLAGS_x86_64-unknown-linux-gnu := -Wl,-no-whole-archive
CFG_DEF_SUFFIX_x86_64-unknown-linux-gnu := .linux.def
CFG_LLC_FLAGS_x86_64-unknown-linux-gnu :=
CFG_INSTALL_NAME_x86_64-unknown-linux-gnu =
CFG_EXE_SUFFIX_x86_64-unknown-linux-gnu =
CFG_WINDOWSY_x86_64-unknown-linux-gnu :=
CFG_UNIXY_x86_64-unknown-linux-gnu := 1
CFG_PATH_MUNGE_x86_64-unknown-linux-gnu := true
CFG_LDPATH_x86_64-unknown-linux-gnu :=
CFG_RUN_x86_64-unknown-linux-gnu=$(2)
CFG_RUN_TARG_x86_64-unknown-linux-gnu=$(call CFG_RUN_x86_64-unknown-linux-gnu,,$(2))

# i686-unknown-linux-gnu configuration
CC_i686-unknown-linux-gnu=$(CC)
CXX_i686-unknown-linux-gnu=$(CXX)
CPP_i686-unknown-linux-gnu=$(CPP)
AR_i686-unknown-linux-gnu=$(AR)
CFG_LIB_NAME_i686-unknown-linux-gnu=lib$(1).so
CFG_STATIC_LIB_NAME_i686-unknown-linux-gnu=lib$(1).a
CFG_LIB_GLOB_i686-unknown-linux-gnu=lib$(1)-*.so
CFG_LIB_DSYM_GLOB_i686-unknown-linux-gnu=lib$(1)-*.dylib.dSYM
CFG_CFLAGS_i686-unknown-linux-gnu := -m32 $(CFLAGS)
CFG_GCCISH_CFLAGS_i686-unknown-linux-gnu := -Wall -Werror -g -fPIC -m32 $(CFLAGS)
CFG_GCCISH_CXXFLAGS_i686-unknown-linux-gnu := -fno-rtti $(CXXFLAGS)
CFG_GCCISH_LINK_FLAGS_i686-unknown-linux-gnu := -shared -fPIC -ldl -pthread  -lrt -g -m32
CFG_GCCISH_DEF_FLAG_i686-unknown-linux-gnu := -Wl,--export-dynamic,--dynamic-list=
CFG_GCCISH_PRE_LIB_FLAGS_i686-unknown-linux-gnu := -Wl,-whole-archive
CFG_GCCISH_POST_LIB_FLAGS_i686-unknown-linux-gnu := -Wl,-no-whole-archive
CFG_DEF_SUFFIX_i686-unknown-linux-gnu := .linux.def
CFG_LLC_FLAGS_i686-unknown-linux-gnu :=
CFG_INSTALL_NAME_i686-unknown-linux-gnu =
CFG_EXE_SUFFIX_i686-unknown-linux-gnu =
CFG_WINDOWSY_i686-unknown-linux-gnu :=
CFG_UNIXY_i686-unknown-linux-gnu := 1
CFG_PATH_MUNGE_i686-unknown-linux-gnu := true
CFG_LDPATH_i686-unknown-linux-gnu :=
CFG_RUN_i686-unknown-linux-gnu=$(2)
CFG_RUN_TARG_i686-unknown-linux-gnu=$(call CFG_RUN_i686-unknown-linux-gnu,,$(2))

# arm-apple-ios configuration
CFG_SDK_NAME_arm-apple-ios = iphoneos
CFG_SDK_ARCHS_arm-apple-ios = armv7
ifneq ($(findstring darwin,$(CFG_OSTYPE)),)
CFG_IOS_SDK = $(shell xcrun --show-sdk-path -sdk iphoneos 2>/dev/null)
CFG_IOS_FLAGS = -target armv7-apple-darwin -isysroot $(CFG_IOS_SDK) -mios-version-min=7.0
CC_arm-apple-ios = $(shell xcrun -find -sdk iphoneos clang)
CXX_arm-apple-ios = $(shell xcrun -find -sdk iphoneos clang++)
CPP_arm-apple-ios = $(shell xcrun -find -sdk iphoneos clang++)
AR_arm-apple-ios = $(shell xcrun -find -sdk iphoneos ar)
endif
CFG_LIB_NAME_arm-apple-ios = lib$(1).a
CFG_LIB_GLOB_arm-apple-ios = lib$(1)-*.a
CFG_STATIC_LIB_NAME_arm-apple-ios=lib$(1).a
CFG_LIB_DSYM_GLOB_arm-apple-ios = lib$(1)-*.a.dSYM
CFG_CFLAGS_arm-apple-ios := -arch armv7 -mfpu=vfp3 $(CFG_IOS_FLAGS)
CFG_GCCISH_CFLAGS_arm-apple-ios := -Wall -Werror -g -fPIC $(CFG_IOS_FLAGS) -mfpu=vfp3 -arch armv7
CFG_GCCISH_CXXFLAGS_arm-apple-ios := -fno-rtti $(CFG_IOS_FLAGS) -I$(CFG_IOS_SDK)/usr/include/c++/4.2.1
CFG_GCCISH_LINK_FLAGS_arm-apple-ios := -lpthread -syslibroot $(CFG_IOS_SDK) -Wl,-no_compact_unwind
CFG_GCCISH_DEF_FLAG_arm-apple-ios := -Wl,-exported_symbols_list,
CFG_GCCISH_PRE_LIB_FLAGS_arm-apple-ios :=
CFG_GCCISH_POST_LIB_FLAGS_arm-apple-ios :=
CFG_DEF_SUFFIX_arm-apple-ios := .darwin.def
CFG_LLC_FLAGS_arm-apple-ios := -mattr=+vfp3,+v7,+thumb2,+neon -march=arm
CFG_INSTALL_NAME_arm-apple-ios = -Wl,-install_name,@rpath/$(1)
CFG_EXE_SUFFIX_arm-apple-ios :=
CFG_WINDOWSY_arm-apple-ios :=
CFG_UNIXY_arm-apple-ios := 1
CFG_PATH_MUNGE_arm-apple-ios := true
CFG_LDPATH_arm-apple-ios :=
CFG_RUN_arm-apple-ios = $(2)
CFG_RUN_TARG_arm-apple-ios = $(call CFG_RUN_arm-apple-ios,,$(2))
RUSTC_FLAGS_arm-apple-ios := -C relocation_model=pic
RUSTC_CROSS_FLAGS_arm-apple-ios :=-C relocation_model=pic

# i386-apple-ios configuration
CFG_SDK_NAME_i386-apple-ios = iphonesimulator
CFG_SDK_ARCHS_i386-apple-ios = i386
ifneq ($(findstring darwin,$(CFG_OSTYPE)),)
CFG_IOSSIM_SDK = $(shell xcrun --show-sdk-path -sdk iphonesimulator 2>/dev/null)
CFG_IOSSIM_FLAGS = -target i386-apple-ios -isysroot $(CFG_IOSSIM_SDK) -mios-simulator-version-min=7.0
CC_i386-apple-ios = $(shell xcrun -find -sdk iphonesimulator clang)
CXX_i386-apple-ios = $(shell xcrun -find -sdk iphonesimulator clang++)
CPP_i386-apple-ios = $(shell xcrun -find -sdk iphonesimulator clang++)
AR_i386-apple-ios = $(shell xcrun -find -sdk iphonesimulator ar)
endif
CFG_LIB_NAME_i386-apple-ios = lib$(1).a
CFG_LIB_GLOB_i386-apple-ios = lib$(1)-*.dylib
CFG_STATIC_LIB_NAME_i386-apple-ios=lib$(1).a
CFG_LIB_DSYM_GLOB_i386-apple-ios = lib$(1)-*.dylib.dSYM
CFG_CFLAGS_i386-apple-ios = $(CFG_IOSSIM_FLAGS)
CFG_GCCISH_CFLAGS_i386-apple-ios = -Wall -Werror -g -fPIC -m32 $(CFG_IOSSIM_FLAGS)
CFG_GCCISH_CXXFLAGS_i386-apple-ios = -fno-rtti $(CFG_IOSSIM_FLAGS) -I$(CFG_IOSSIM_SDK)/usr/include/c++/4.2.1
CFG_GCCISH_LINK_FLAGS_i386-apple-ios = -lpthread -Wl,-no_compact_unwind -m32 -Wl,-syslibroot $(CFG_IOSSIM_SDK)
CFG_GCCISH_DEF_FLAG_i386-apple-ios = -Wl,-exported_symbols_list,
CFG_GCCISH_PRE_LIB_FLAGS_i386-apple-ios =
CFG_GCCISH_POST_LIB_FLAGS_i386-apple-ios =
CFG_DEF_SUFFIX_i386-apple-ios = .darwin.def
CFG_LLC_FLAGS_i386-apple-ios =
CFG_INSTALL_NAME_i386-apple-ios = -Wl,-install_name,@rpath/$(1)
CFG_EXE_SUFFIX_i386-apple-ios =
CFG_WINDOWSY_i386-apple-ios =
CFG_UNIXY_i386-apple-ios = 1
CFG_PATH_MUNGE_i386-apple-ios = true
CFG_LDPATH_i386-apple-ios =
CFG_RUN_i386-apple-ios = $(2)
CFG_RUN_TARG_i386-apple-ios = $(call CFG_RUN_i386-apple-ios,,$(2))
CFG_JEMALLOC_CFLAGS_i386-apple-ios = -target i386-apple-ios -Wl,-syslibroot $(CFG_IOSSIM_SDK) -Wl,-no_compact_unwind

# x86_64-apple-darwin configuration
CC_x86_64-apple-darwin=$(CC)
CXX_x86_64-apple-darwin=$(CXX)
CPP_x86_64-apple-darwin=$(CPP)
AR_x86_64-apple-darwin=$(AR)
CFG_LIB_NAME_x86_64-apple-darwin=lib$(1).dylib
CFG_STATIC_LIB_NAME_x86_64-apple-darwin=lib$(1).a
CFG_LIB_GLOB_x86_64-apple-darwin=lib$(1)-*.dylib
CFG_LIB_DSYM_GLOB_x86_64-apple-darwin=lib$(1)-*.dylib.dSYM
CFG_CFLAGS_x86_64-apple-darwin := -m64 -arch x86_64 $(CFLAGS)
CFG_GCCISH_CFLAGS_x86_64-apple-darwin := -Wall -Werror -g -fPIC -m64 -arch x86_64 $(CFLAGS)
CFG_GCCISH_CXXFLAGS_x86_64-apple-darwin := -fno-rtti $(CXXFLAGS)
CFG_GCCISH_LINK_FLAGS_x86_64-apple-darwin := -dynamiclib -pthread  -framework CoreServices -m64
CFG_GCCISH_DEF_FLAG_x86_64-apple-darwin := -Wl,-exported_symbols_list,
CFG_GCCISH_PRE_LIB_FLAGS_x86_64-apple-darwin :=
CFG_GCCISH_POST_LIB_FLAGS_x86_64-apple-darwin :=
CFG_DEF_SUFFIX_x86_64-apple-darwin := .darwin.def
CFG_LLC_FLAGS_x86_64-apple-darwin :=
CFG_INSTALL_NAME_x86_64-apple-darwin = -Wl,-install_name,@rpath/$(1)
CFG_EXE_SUFFIX_x86_64-apple-darwin :=
CFG_WINDOWSY_x86_64-apple-darwin :=
CFG_UNIXY_x86_64-apple-darwin := 1
CFG_PATH_MUNGE_x86_64-apple-darwin := true
CFG_LDPATH_x86_64-apple-darwin :=
CFG_RUN_x86_64-apple-darwin=$(2)
CFG_RUN_TARG_x86_64-apple-darwin=$(call CFG_RUN_x86_64-apple-darwin,,$(2))

# i686-apple-darwin configuration
CC_i686-apple-darwin=$(CC)
CXX_i686-apple-darwin=$(CXX)
CPP_i686-apple-darwin=$(CPP)
AR_i686-apple-darwin=$(AR)
CFG_LIB_NAME_i686-apple-darwin=lib$(1).dylib
CFG_STATIC_LIB_NAME_i686-apple-darwin=lib$(1).a
CFG_LIB_GLOB_i686-apple-darwin=lib$(1)-*.dylib
CFG_LIB_DSYM_GLOB_i686-apple-darwin=lib$(1)-*.dylib.dSYM
CFG_CFLAGS_i686-apple-darwin := -m32 -arch i386 $(CFLAGS)
CFG_GCCISH_CFLAGS_i686-apple-darwin := -Wall -Werror -g -fPIC -m32 -arch i386 $(CFLAGS)
CFG_GCCISH_CXXFLAGS_i686-apple-darwin := -fno-rtti $(CXXFLAGS)
CFG_GCCISH_LINK_FLAGS_i686-apple-darwin := -dynamiclib -pthread  -framework CoreServices -m32
CFG_GCCISH_DEF_FLAG_i686-apple-darwin := -Wl,-exported_symbols_list,
CFG_GCCISH_PRE_LIB_FLAGS_i686-apple-darwin :=
CFG_GCCISH_POST_LIB_FLAGS_i686-apple-darwin :=
CFG_DEF_SUFFIX_i686-apple-darwin := .darwin.def
CFG_LLC_FLAGS_i686-apple-darwin :=
CFG_INSTALL_NAME_i686-apple-darwin = -Wl,-install_name,@rpath/$(1)
CFG_EXE_SUFFIX_i686-apple-darwin :=
CFG_WINDOWSY_i686-apple-darwin :=
CFG_UNIXY_i686-apple-darwin := 1
CFG_PATH_MUNGE_i686-apple-darwin := true
CFG_LDPATH_i686-apple-darwin :=
CFG_RUN_i686-apple-darwin=$(2)
CFG_RUN_TARG_i686-apple-darwin=$(call CFG_RUN_i686-apple-darwin,,$(2))

# arm-linux-androideabi configuration
CC_arm-linux-androideabi=$(CFG_ANDROID_CROSS_PATH)/bin/arm-linux-androideabi-gcc
CXX_arm-linux-androideabi=$(CFG_ANDROID_CROSS_PATH)/bin/arm-linux-androideabi-g++
CPP_arm-linux-androideabi=$(CFG_ANDROID_CROSS_PATH)/bin/arm-linux-androideabi-gcc -E
AR_arm-linux-androideabi=$(CFG_ANDROID_CROSS_PATH)/bin/arm-linux-androideabi-ar
CFG_LIB_NAME_arm-linux-androideabi=lib$(1).so
CFG_STATIC_LIB_NAME_arm-linux-androideabi=lib$(1).a
CFG_LIB_GLOB_arm-linux-androideabi=lib$(1)-*.so
CFG_LIB_DSYM_GLOB_arm-linux-androideabi=lib$(1)-*.dylib.dSYM
CFG_CFLAGS_arm-linux-androideabi := -D__arm__ -DANDROID -D__ANDROID__ $(CFLAGS)
CFG_GCCISH_CFLAGS_arm-linux-androideabi := -Wall -g -fPIC -D__arm__ -DANDROID -D__ANDROID__ $(CFLAGS)
CFG_GCCISH_CXXFLAGS_arm-linux-androideabi := -fno-rtti $(CXXFLAGS)
CFG_GCCISH_LINK_FLAGS_arm-linux-androideabi := -shared -fPIC -ldl -g -lm -lsupc++
CFG_GCCISH_DEF_FLAG_arm-linux-androideabi := -Wl,--export-dynamic,--dynamic-list=
CFG_GCCISH_PRE_LIB_FLAGS_arm-linux-androideabi := -Wl,-whole-archive
CFG_GCCISH_POST_LIB_FLAGS_arm-linux-androideabi := -Wl,-no-whole-archive
CFG_DEF_SUFFIX_arm-linux-androideabi := .android.def
CFG_LLC_FLAGS_arm-linux-androideabi :=
CFG_INSTALL_NAME_arm-linux-androideabi =
CFG_EXE_SUFFIX_arm-linux-androideabi :=
CFG_WINDOWSY_arm-linux-androideabi :=
CFG_UNIXY_arm-linux-androideabi := 1
CFG_PATH_MUNGE_arm-linux-androideabi := true
CFG_LDPATH_arm-linux-androideabi :=
CFG_RUN_arm-linux-androideabi=
CFG_RUN_TARG_arm-linux-androideabi=
RUSTC_FLAGS_arm-linux-androideabi :=
RUSTC_CROSS_FLAGS_arm-linux-androideabi :=

# arm-unknown-linux-gnueabihf configuration
CROSS_PREFIX_arm-unknown-linux-gnueabihf=arm-linux-gnueabihf-
CC_arm-unknown-linux-gnueabihf=gcc
CXX_arm-unknown-linux-gnueabihf=g++
CPP_arm-unknown-linux-gnueabihf=gcc -E
AR_arm-unknown-linux-gnueabihf=ar
CFG_LIB_NAME_arm-unknown-linux-gnueabihf=lib$(1).so
CFG_STATIC_LIB_NAME_arm-unknown-linux-gnueabihf=lib$(1).a
CFG_LIB_GLOB_arm-unknown-linux-gnueabihf=lib$(1)-*.so
CFG_LIB_DSYM_GLOB_arm-unknown-linux-gnueabihf=lib$(1)-*.dylib.dSYM
CFG_CFLAGS_arm-unknown-linux-gnueabihf := -D__arm__ $(CFLAGS)
CFG_GCCISH_CFLAGS_arm-unknown-linux-gnueabihf := -Wall -g -fPIC -D__arm__ $(CFLAGS)
CFG_GCCISH_CXXFLAGS_arm-unknown-linux-gnueabihf := -fno-rtti $(CXXFLAGS)
CFG_GCCISH_LINK_FLAGS_arm-unknown-linux-gnueabihf := -shared -fPIC -g
CFG_GCCISH_DEF_FLAG_arm-unknown-linux-gnueabihf := -Wl,--export-dynamic,--dynamic-list=
CFG_GCCISH_PRE_LIB_FLAGS_arm-unknown-linux-gnueabihf := -Wl,-whole-archive
CFG_GCCISH_POST_LIB_FLAGS_arm-unknown-linux-gnueabihf := -Wl,-no-whole-archive
CFG_DEF_SUFFIX_arm-unknown-linux-gnueabihf := .linux.def
CFG_LLC_FLAGS_arm-unknown-linux-gnueabihf :=
CFG_INSTALL_NAME_ar,-unknown-linux-gnueabihf =
CFG_EXE_SUFFIX_arm-unknown-linux-gnueabihf :=
CFG_WINDOWSY_arm-unknown-linux-gnueabihf :=
CFG_UNIXY_arm-unknown-linux-gnueabihf := 1
CFG_PATH_MUNGE_arm-unknown-linux-gnueabihf := true
CFG_LDPATH_arm-unknown-linux-gnueabihf :=
CFG_RUN_arm-unknown-linux-gnueabihf=$(2)
CFG_RUN_TARG_arm-unknown-linux-gnueabihf=$(call CFG_RUN_arm-unknown-linux-gnueabihf,,$(2))
RUSTC_FLAGS_arm-unknown-linux-gnueabihf := -C target-feature=+v6,+vfp2
RUSTC_CROSS_FLAGS_arm-unknown-linux-gnueabihf :=

# arm-unknown-linux-gnueabi configuration
CROSS_PREFIX_arm-unknown-linux-gnueabi=arm-linux-gnueabi-
CC_arm-unknown-linux-gnueabi=gcc
CXX_arm-unknown-linux-gnueabi=g++
CPP_arm-unknown-linux-gnueabi=gcc -E
AR_arm-unknown-linux-gnueabi=ar
CFG_LIB_NAME_arm-unknown-linux-gnueabi=lib$(1).so
CFG_STATIC_LIB_NAME_arm-unknown-linux-gnueabi=lib$(1).a
CFG_LIB_GLOB_arm-unknown-linux-gnueabi=lib$(1)-*.so
CFG_LIB_DSYM_GLOB_arm-unknown-linux-gnueabi=lib$(1)-*.dylib.dSYM
CFG_CFLAGS_arm-unknown-linux-gnueabi := -D__arm__ -mfpu=vfp $(CFLAGS)
CFG_GCCISH_CFLAGS_arm-unknown-linux-gnueabi := -Wall -g -fPIC -D__arm__ -mfpu=vfp $(CFLAGS)
CFG_GCCISH_CXXFLAGS_arm-unknown-linux-gnueabi := -fno-rtti $(CXXFLAGS)
CFG_GCCISH_LINK_FLAGS_arm-unknown-linux-gnueabi := -shared -fPIC -g
CFG_GCCISH_DEF_FLAG_arm-unknown-linux-gnueabi := -Wl,--export-dynamic,--dynamic-list=
CFG_GCCISH_PRE_LIB_FLAGS_arm-unknown-linux-gnueabi := -Wl,-whole-archive
CFG_GCCISH_POST_LIB_FLAGS_arm-unknown-linux-gnueabi := -Wl,-no-whole-archive
CFG_DEF_SUFFIX_arm-unknown-linux-gnueabi := .linux.def
CFG_LLC_FLAGS_arm-unknown-linux-gnueabi :=
CFG_INSTALL_NAME_arm-unknown-linux-gnueabi =
CFG_EXE_SUFFIX_arm-unknown-linux-gnueabi :=
CFG_WINDOWSY_arm-unknown-linux-gnueabi :=
CFG_UNIXY_arm-unknown-linux-gnueabi := 1
CFG_PATH_MUNGE_arm-unknown-linux-gnueabi := true
CFG_LDPATH_arm-unknown-linux-gnueabi :=
CFG_RUN_arm-unknown-linux-gnueabi=$(2)
CFG_RUN_TARG_arm-unknown-linux-gnueabi=$(call CFG_RUN_arm-unknown-linux-gnueabi,,$(2))
RUSTC_FLAGS_arm-unknown-linux-gnueabi :=
RUSTC_CROSS_FLAGS_arm-unknown-linux-gnueabi :=

# mipsel-linux configuration
CC_mipsel-linux=mipsel-linux-gcc
CXX_mipsel-linux=mipsel-linux-g++
CPP_mipsel-linux=mipsel-linux-gcc
AR_mipsel-linux=mipsel-linux-ar
CFG_LIB_NAME_mipsel-linux=lib$(1).so
CFG_STATIC_LIB_NAME_mipsel-linux=lib$(1).a
CFG_LIB_GLOB_mipsel-linux=lib$(1)-*.so
CFG_LIB_DSYM_GLOB_mipsel-linux=lib$(1)-*.dylib.dSYM
CFG_CFLAGS_mipsel-linux := -mips32 -mabi=32 $(CFLAGS)
CFG_GCCISH_CFLAGS_mipsel-linux := -Wall -g -fPIC -mips32 -mabi=32 $(CFLAGS)
CFG_GCCISH_CXXFLAGS_mipsel-linux := -fno-rtti $(CXXFLAGS)
CFG_GCCISH_LINK_FLAGS_mipsel-linux := -shared -fPIC -g -mips32
CFG_GCCISH_DEF_FLAG_mipsel-linux := -Wl,--export-dynamic,--dynamic-list=
CFG_GCCISH_PRE_LIB_FLAGS_mipsel-linux := -Wl,-whole-archive
CFG_GCCISH_POST_LIB_FLAGS_mipsel-linux := -Wl,-no-whole-archive
CFG_DEF_SUFFIX_mipsel-linux := .linux.def
CFG_LLC_FLAGS_mipsel-linux :=
CFG_INSTALL_NAME_mipsel-linux =
CFG_EXE_SUFFIX_mipsel-linux :=
CFG_WINDOWSY_mipsel-linux :=
CFG_UNIXY_mipsel-linux := 1
CFG_PATH_MUNGE_mipsel-linux := true
CFG_LDPATH_mipsel-linux :=
CFG_RUN_mipsel-linux=
CFG_RUN_TARG_mipsel-linux=
RUSTC_FLAGS_mipsel-linux := -C target-cpu=mips32 -C target-feature="+mips32,+o32"


# mips-unknown-linux-gnu configuration
CC_mips-unknown-linux-gnu=mips-linux-gnu-gcc
CXX_mips-unknown-linux-gnu=mips-linux-gnu-g++
CPP_mips-unknown-linux-gnu=mips-linux-gnu-gcc -E
AR_mips-unknown-linux-gnu=mips-linux-gnu-ar
CFG_LIB_NAME_mips-unknown-linux-gnu=lib$(1).so
CFG_STATIC_LIB_NAME_mips-unknown-linux-gnu=lib$(1).a
CFG_LIB_GLOB_mips-unknown-linux-gnu=lib$(1)-*.so
CFG_LIB_DSYM_GLOB_mips-unknown-linux-gnu=lib$(1)-*.dylib.dSYM
CFG_CFLAGS_mips-unknown-linux-gnu := -mips32r2 -msoft-float -mabi=32 -mno-compact-eh $(CFLAGS)
CFG_GCCISH_CFLAGS_mips-unknown-linux-gnu := -Wall -g -fPIC -mips32r2 -msoft-float -mabi=32 -mno-compact-eh $(CFLAGS)
CFG_GCCISH_CXXFLAGS_mips-unknown-linux-gnu := -fno-rtti $(CXXFLAGS)
CFG_GCCISH_LINK_FLAGS_mips-unknown-linux-gnu := -shared -fPIC -g -mips32r2 -msoft-float -mabi=32
CFG_GCCISH_DEF_FLAG_mips-unknown-linux-gnu := -Wl,--export-dynamic,--dynamic-list=
CFG_GCCISH_PRE_LIB_FLAGS_mips-unknown-linux-gnu := -Wl,-whole-archive
CFG_GCCISH_POST_LIB_FLAGS_mips-unknown-linux-gnu := -Wl,-no-whole-archive
CFG_DEF_SUFFIX_mips-unknown-linux-gnu := .linux.def
CFG_LLC_FLAGS_mips-unknown-linux-gnu :=
CFG_INSTALL_NAME_mips-unknown-linux-gnu =
CFG_EXE_SUFFIX_mips-unknown-linux-gnu :=
CFG_WINDOWSY_mips-unknown-linux-gnu :=
CFG_UNIXY_mips-unknown-linux-gnu := 1
CFG_PATH_MUNGE_mips-unknown-linux-gnu := true
CFG_LDPATH_mips-unknown-linux-gnu :=
CFG_RUN_mips-unknown-linux-gnu=
CFG_RUN_TARG_mips-unknown-linux-gnu=
RUSTC_FLAGS_mips-unknown-linux-gnu := -C target-cpu=mips32r2 -C target-feature="+mips32r2,+o32" -C soft-float

# i586-mingw32msvc configuration
CC_i586-mingw32msvc=$(CFG_MINGW32_CROSS_PATH)/bin/i586-mingw32msvc-gcc
CXX_i586-mingw32msvc=$(CFG_MINGW32_CROSS_PATH)/bin/i586-mingw32msvc-g++
CPP_i586-mingw32msvc=$(CFG_MINGW32_CROSS_PATH)/bin/i586-mingw32msvc-cpp
AR_i586-mingw32msvc=$(CFG_MINGW32_CROSS_PATH)/bin/i586-mingw32msvc-ar
CFG_LIB_NAME_i586-mingw32msvc=$(1).dll
CFG_STATIC_LIB_NAME_i586-mingw32msvc=$(1).lib
CFG_LIB_GLOB_i586-mingw32msvc=$(1)-*.dll
CFG_LIB_DSYM_GLOB_i586-mingw32msvc=$(1)-*.dylib.dSYM
CFG_CFLAGS_i586-mingw32msvc := -march=i586 -m32 $(CFLAGS)
CFG_GCCISH_CFLAGS_i586-mingw32msvc := -Wall -Werror -g -march=i586 -m32 $(CFLAGS)
CFG_GCCISH_CXXFLAGS_i586-mingw32msvc := -fno-rtti $(CXXFLAGS)
CFG_GCCISH_LINK_FLAGS_i586-mingw32msvc := -shared -g -m32
CFG_GCCISH_DEF_FLAG_i586-mingw32msvc :=
CFG_GCCISH_PRE_LIB_FLAGS_i586-mingw32msvc :=
CFG_GCCISH_POST_LIB_FLAGS_i586-mingw32msvc :=
CFG_DEF_SUFFIX_i586-mingw32msvc := .mingw32.def
CFG_LLC_FLAGS_i586-mingw32msvc :=
CFG_INSTALL_NAME_i586-mingw32msvc =
CFG_EXE_SUFFIX_i586-mingw32msvc := .exe
CFG_WINDOWSY_i586-mingw32msvc := 1
CFG_UNIXY_i586-mingw32msvc :=
CFG_PATH_MUNGE_i586-mingw32msvc := $(strip perl -i.bak -p \
                             -e 's@\\(\S)@/\1@go;' \
                             -e 's@^/([a-zA-Z])/@\1:/@o;')
CFG_LDPATH_i586-mingw32msvc :=
CFG_RUN_i586-mingw32msvc=
CFG_RUN_TARG_i586-mingw32msvc=

# i686-w64-mingw32 configuration
CROSS_PREFIX_i686-w64-mingw32=i686-w64-mingw32-
CC_i686-w64-mingw32=gcc
CXX_i686-w64-mingw32=g++
CPP_i686-w64-mingw32=gcc -E
AR_i686-w64-mingw32=ar
CFG_LIB_NAME_i686-w64-mingw32=$(1).dll
CFG_STATIC_LIB_NAME_i686-w64-mingw32=$(1).lib
CFG_LIB_GLOB_i686-w64-mingw32=$(1)-*.dll
CFG_LIB_DSYM_GLOB_i686-w64-mingw32=$(1)-*.dylib.dSYM
CFG_CFLAGS_i686-w64-mingw32 := -march=i686 -m32 -D_WIN32_WINNT=0x0600 $(CFLAGS)
CFG_GCCISH_CFLAGS_i686-w64-mingw32 := -Wall -Werror -g -m32 -D_WIN32_WINNT=0x0600 $(CFLAGS)
CFG_GCCISH_CXXFLAGS_i686-w64-mingw32 := -fno-rtti $(CXXFLAGS)
CFG_GCCISH_LINK_FLAGS_i686-w64-mingw32 := -shared -g -m32
CFG_GCCISH_DEF_FLAG_i686-w64-mingw32 :=
CFG_GCCISH_PRE_LIB_FLAGS_i686-w64-mingw32 :=
CFG_GCCISH_POST_LIB_FLAGS_i686-w64-mingw32 :=
CFG_DEF_SUFFIX_i686-w64-mingw32 := .mingw32.def
CFG_LLC_FLAGS_i686-w64-mingw32 :=
CFG_INSTALL_NAME_i686-w64-mingw32 =
CFG_EXE_SUFFIX_i686-w64-mingw32 := .exe
CFG_WINDOWSY_i686-w64-mingw32 := 1
CFG_UNIXY_i686-w64-mingw32 :=
CFG_PATH_MUNGE_i686-w64-mingw32 :=
CFG_LDPATH_i686-w64-mingw32 :=$(CFG_LDPATH_i686-w64-mingw32):$(PATH)
CFG_RUN_i686-w64-mingw32=PATH="$(CFG_LDPATH_i686-w64-mingw32):$(1)" $(2)
CFG_RUN_TARG_i686-w64-mingw32=$(call CFG_RUN_i686-w64-mingw32,$(HLIB$(1)_H_$(CFG_BUILD)),$(2))
# Stop rustc from OOMing when building itself (I think)
RUSTC_FLAGS_i686-w64-mingw32=-C link-args="-Wl,--large-address-aware"
RUSTC_CROSS_FLAGS_i686-w64-mingw32 :=

# x86_64-w64-mingw32 configuration
CROSS_PREFIX_x86_64-w64-mingw32=x86_64-w64-mingw32-
CC_x86_64-w64-mingw32=gcc
CXX_x86_64-w64-mingw32=g++
CPP_x86_64-w64-mingw32=gcc -E
AR_x86_64-w64-mingw32=ar
CFG_LIB_NAME_x86_64-w64-mingw32=$(1).dll
CFG_STATIC_LIB_NAME_x86_64-w64-mingw32=$(1).lib
CFG_LIB_GLOB_x86_64-w64-mingw32=$(1)-*.dll
CFG_LIB_DSYM_GLOB_x86_64-w64-mingw32=$(1)-*.dylib.dSYM
CFG_CFLAGS_x86_64-w64-mingw32 := -m64 -D_WIN32_WINNT=0x0600 $(CFLAGS)
CFG_GCCISH_CFLAGS_x86_64-w64-mingw32 := -Wall -Werror -g -m64 -D_WIN32_WINNT=0x0600 $(CFLAGS)
CFG_GCCISH_CXXFLAGS_x86_64-w64-mingw32 := -fno-rtti $(CXXFLAGS)
CFG_GCCISH_LINK_FLAGS_x86_64-w64-mingw32 := -shared -g -m64
CFG_GCCISH_DEF_FLAG_x86_64-w64-mingw32 :=
CFG_GCCISH_PRE_LIB_FLAGS_x86_64-w64-mingw32 :=
CFG_GCCISH_POST_LIB_FLAGS_x86_64-w64-mingw32 :=
CFG_DEF_SUFFIX_x86_64-w64-mingw32 := .mingw32.def
CFG_LLC_FLAGS_x86_64-w64-mingw32 :=
CFG_INSTALL_NAME_x86_64-w64-mingw32 =
CFG_EXE_SUFFIX_x86_64-w64-mingw32 := .exe
CFG_WINDOWSY_x86_64-w64-mingw32 := 1
CFG_UNIXY_x86_64-w64-mingw32 :=
CFG_PATH_MUNGE_x86_64-w64-mingw32 :=
CFG_LDPATH_x86_64-w64-mingw32 :=$(CFG_LDPATH_x86_64-w64-mingw32):$(PATH)
CFG_RUN_x86_64-w64-mingw32=PATH="$(CFG_LDPATH_x86_64-w64-mingw32):$(1)" $(2)
CFG_RUN_TARG_x86_64-w64-mingw32=$(call CFG_RUN_x86_64-w64-mingw32,$(HLIB$(1)_H_$(CFG_BUILD)),$(2))
RUSTC_CROSS_FLAGS_x86_64-w64-mingw32 :=

# x86_64-unknown-freebsd configuration
CC_x86_64-unknown-freebsd=$(CC)
CXX_x86_64-unknown-freebsd=$(CXX)
CPP_x86_64-unknown-freebsd=$(CPP)
AR_x86_64-unknown-freebsd=$(AR)
CFG_LIB_NAME_x86_64-unknown-freebsd=lib$(1).so
CFG_STATIC_LIB_NAME_x86_64-unknown-freebsd=lib$(1).a
CFG_LIB_GLOB_x86_64-unknown-freebsd=lib$(1)-*.so
CFG_LIB_DSYM_GLOB_x86_64-unknown-freebsd=$(1)-*.dylib.dSYM
CFG_CFLAGS_x86_64-unknown-freebsd := -I/usr/local/include $(CFLAGS)
CFG_GCCISH_CFLAGS_x86_64-unknown-freebsd := -Wall -Werror -g -fPIC -I/usr/local/include $(CFLAGS)
CFG_GCCISH_LINK_FLAGS_x86_64-unknown-freebsd := -shared -fPIC -g -pthread  -lrt
CFG_GCCISH_DEF_FLAG_x86_64-unknown-freebsd := -Wl,--export-dynamic,--dynamic-list=
CFG_GCCISH_PRE_LIB_FLAGS_x86_64-unknown-freebsd := -Wl,-whole-archive
CFG_GCCISH_POST_LIB_FLAGS_x86_64-unknown-freebsd := -Wl,-no-whole-archive
CFG_DEF_SUFFIX_x86_64-unknown-freebsd := .bsd.def
CFG_LLC_FLAGS_x86_64-unknown-freebsd :=
CFG_INSTALL_NAME_x86_64-unknown-freebsd =
CFG_EXE_SUFFIX_x86_64-unknown-freebsd :=
CFG_WINDOWSY_x86_64-unknown-freebsd :=
CFG_UNIXY_x86_64-unknown-freebsd := 1
CFG_PATH_MUNGE_x86_64-unknown-freebsd :=
CFG_LDPATH_x86_64-unknown-freebsd :=
CFG_RUN_x86_64-unknown-freebsd=$(2)
CFG_RUN_TARG_x86_64-unknown-freebsd=$(call CFG_RUN_x86_64-unknown-freebsd,,$(2))

# x86_64-pc-dragonfly-elf configuration
CC_x86_64-unknown-dragonfly=$(CC)
CXX_x86_64-unknown-dragonfly=$(CXX)
CPP_x86_64-unknown-dragonfly=$(CPP)
AR_x86_64-unknown-dragonfly=$(AR)
CFG_LIB_NAME_x86_64-unknown-dragonfly=lib$(1).so
CFG_STATIC_LIB_NAME_x86_64-unknown-dragonfly=lib$(1).a
CFG_LIB_GLOB_x86_64-unknown-dragonfly=lib$(1)-*.so
CFG_LIB_DSYM_GLOB_x86_64-unknown-dragonfly=$(1)-*.dylib.dSYM
CFG_CFLAGS_x86_64-unknown-dragonfly := -I/usr/include -I/usr/local/include $(CFLAGS)
CFG_GCCISH_CFLAGS_x86_64-unknown-dragonfly := -Wall -Werror -g -fPIC -I/usr/include -I/usr/local/include $(CFLAGS)
CFG_GCCISH_LINK_FLAGS_x86_64-unknown-dragonfly := -shared -fPIC -g -pthread  -lrt
CFG_GCCISH_DEF_FLAG_x86_64-unknown-dragonfly := -Wl,--export-dynamic,--dynamic-list=
CFG_GCCISH_PRE_LIB_FLAGS_x86_64-unknown-dragonfly := -Wl,-whole-archive
CFG_GCCISH_POST_LIB_FLAGS_x86_64-unknown-dragonfly := -Wl,-no-whole-archive
CFG_DEF_SUFFIX_x86_64-unknown-dragonfly := .bsd.def
CFG_LLC_FLAGS_x86_64-unknown-dragonfly :=
CFG_INSTALL_NAME_x86_64-unknown-dragonfly =
CFG_EXE_SUFFIX_x86_64-unknown-dragonfly :=
CFG_WINDOWSY_x86_64-unknown-dragonfly :=
CFG_UNIXY_x86_64-unknown-dragonfly := 1
CFG_PATH_MUNGE_x86_64-unknown-dragonfly :=
CFG_LDPATH_x86_64-unknown-dragonfly :=
CFG_RUN_x86_64-unknown-dragonfly=$(2)
CFG_RUN_TARG_x86_64-unknown-dragonfly=$(call CFG_RUN_x86_64-unknown-dragonfly,,$(2))


# The -Qunused-arguments sidesteps spurious warnings from clang
define FILTER_FLAGS
  ifeq ($$(CFG_USING_CLANG),1)
    ifneq ($(findstring clang,$$(shell $(CC_$(1)) -v)),)
      CFG_GCCISH_CFLAGS_$(1) += -Qunused-arguments
      CFG_GCCISH_CXXFLAGS_$(1) += -Qunused-arguments
    endif
  endif
endef

$(foreach target,$(CFG_TARGET), \
  $(eval $(call FILTER_FLAGS,$(target))))


ifeq ($(CFG_CCACHE_CPP2),1)
  CCACHE_CPP2=1
  export CCACHE_CPP
endif

ifdef CFG_CCACHE_BASEDIR
  CCACHE_BASEDIR=$(CFG_CCACHE_BASEDIR)
  export CCACHE_BASEDIR
endif

FIND_COMPILER = $(word 1,$(1:ccache=))

define CFG_MAKE_TOOLCHAIN
  # Prepend the tools with their prefix if cross compiling
  ifneq ($(CFG_BUILD),$(1))
	CC_$(1)=$(CROSS_PREFIX_$(1))$(CC_$(1))
	CXX_$(1)=$(CROSS_PREFIX_$(1))$(CXX_$(1))
	CPP_$(1)=$(CROSS_PREFIX_$(1))$(CPP_$(1))
	AR_$(1)=$(CROSS_PREFIX_$(1))$(AR_$(1))
	RUSTC_CROSS_FLAGS_$(1)=-C linker=$$(call FIND_COMPILER,$$(CC_$(1))) \
	    -C ar=$$(call FIND_COMPILER,$$(AR_$(1))) $(RUSTC_CROSS_FLAGS_$(1))

	RUSTC_FLAGS_$(1)=$$(RUSTC_CROSS_FLAGS_$(1)) $(RUSTC_FLAGS_$(1))
  endif

  CFG_COMPILE_C_$(1) = $$(CC_$(1)) \
        $$(CFG_GCCISH_CFLAGS) \
        $$(CFG_GCCISH_CFLAGS_$(1)) \
        $$(CFG_DEPEND_FLAGS) \
        -c -o $$(1) $$(2)
  CFG_LINK_C_$(1) = $$(CC_$(1)) \
        $$(CFG_GCCISH_LINK_FLAGS) -o $$(1) \
        $$(CFG_GCCISH_LINK_FLAGS_$(1)) \
        $$(CFG_GCCISH_DEF_FLAG_$(1))$$(3) $$(2) \
        $$(call CFG_INSTALL_NAME_$(1),$$(4))
  CFG_COMPILE_CXX_$(1) = $$(CXX_$(1)) \
        $$(CFG_GCCISH_CFLAGS) \
        $$(CFG_GCCISH_CXXFLAGS) \
        $$(CFG_GCCISH_CFLAGS_$(1)) \
        $$(CFG_GCCISH_CXXFLAGS_$(1)) \
        $$(CFG_DEPEND_FLAGS) \
        -c -o $$(1) $$(2)
  CFG_LINK_CXX_$(1) = $$(CXX_$(1)) \
        $$(CFG_GCCISH_LINK_FLAGS) -o $$(1) \
        $$(CFG_GCCISH_LINK_FLAGS_$(1)) \
        $$(CFG_GCCISH_DEF_FLAG_$(1))$$(3) $$(2) \
        $$(call CFG_INSTALL_NAME_$(1),$$(4))

  ifeq ($$(findstring $(HOST_$(1)),arm mips mipsel),)

  # We're using llvm-mc as our assembler because it supports
  # .cfi pseudo-ops on mac
  CFG_ASSEMBLE_$(1)=$$(CPP_$(1)) -E $$(CFG_DEPEND_FLAGS) $$(2) | \
                    $$(LLVM_MC_$$(CFG_BUILD)) \
                    -assemble \
                    -filetype=obj \
                    -triple=$(1) \
                    -o=$$(1)
  else

  # For the ARM and MIPS crosses, use the toolchain assembler
  # FIXME: We should be able to use the LLVM assembler
  CFG_ASSEMBLE_$(1)=$$(CC_$(1)) $$(CFG_GCCISH_CFLAGS_$(1)) \
		    $$(CFG_DEPEND_FLAGS) $$(2) -c -o $$(1)

  endif

endef

$(foreach target,$(CFG_TARGET), \
  $(eval $(call CFG_MAKE_TOOLCHAIN,$(target))))
