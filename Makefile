# Portable GNU Make build for xxd_embed.
#
# Mirrors CMakeLists.txt for environments without CMake. It needs only GNU Make,
# a C11 compiler, and a POSIX shell with sed/awk/od plus one SHA-256 tool
# (sha256sum, shasum or openssl). Works on Linux, macOS, MinGW/MSYS2, Android NDK
# (CC=<ndk>/bin/<triple>-clang) and Emscripten (CC=emcc).
#
# Usage:
#   make                              build libxxd, xxd and the example
#   make run                          build and run the example
#   make XXD_EMBED_ASM=OFF            force the hex-array embedding path
#   make XXD_BUILD_STATIC=OFF         build libxxd as a shared library
#   make CC=emcc AR=emar              WebAssembly build (see README)
#   make clean
#   make help
#
# Do not run an in-source `cmake .` next to this file: CMake would overwrite it.
# Use `cmake -S . -B build` instead.

# ---------------------------------------------------------------------------
# Options (same names and meaning as the CMake options)
# ---------------------------------------------------------------------------
XXD_BUILD_EXECUTABLE ?= ON
XXD_BUILD_STATIC     ?= ON
XXD_BUILD_EXAMPLE    ?= ON
XXD_EMBED_ASM        ?= AUTO

BUILD_DIR            ?= build-make
XXD_EMBED_BINARY_DIR ?= $(BUILD_DIR)
V                    ?= 0

CC     ?= cc
AR     ?= ar
CFLAGS ?= -O2

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
XXD_ROOT    := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
XXD_INC     := $(XXD_ROOT)/include
XXD_GEN_DIR := $(XXD_EMBED_BINARY_DIR)/Generated
OBJ_DIR     := $(BUILD_DIR)/obj

ifeq ($(strip $(BUILD_DIR)),)
$(error BUILD_DIR must not be empty)
endif

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_on = $(if $(filter 1 ON on On TRUE true True YES yes Yes Y y,$(strip $(1))),1)

# Single-quote a string for safe use in a shell command line.
shq = '$(subst ','\'',$(1))'

ifeq ($(V),1)
Q :=
else
Q := @
endif
msg = $(if $(Q),@printf '  %-8s %s\n' '$(1)' $(call shq,$(2)))

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------
UNAME_S := $(shell uname -s 2>/dev/null)

ifneq ($(findstring emcc,$(CC)),)
EMSCRIPTEN := 1
ifeq ($(origin AR),default)
AR := emar
endif
endif

ifneq ($(or $(filter Windows_NT,$(OS)),$(findstring MINGW,$(UNAME_S)),$(findstring MSYS,$(UNAME_S)),$(findstring CYGWIN,$(UNAME_S))),)
TARGET_WINDOWS := 1
endif

ifdef EMSCRIPTEN
EXEEXT ?=
EXAMPLE_EXT ?= .js
SOEXT ?= .so
else ifdef TARGET_WINDOWS
EXEEXT ?= .exe
EXAMPLE_EXT ?= $(EXEEXT)
SOEXT ?= .dll
else ifeq ($(UNAME_S),Darwin)
EXEEXT ?=
EXAMPLE_EXT ?= $(EXEEXT)
SOEXT ?= .dylib
else
EXEEXT ?=
EXAMPLE_EXT ?= $(EXEEXT)
SOEXT ?= .so
endif

# ---------------------------------------------------------------------------
# Resolve options
# ---------------------------------------------------------------------------
BUILD_EXECUTABLE := $(call _on,$(XXD_BUILD_EXECUTABLE))
BUILD_STATIC     := $(call _on,$(XXD_BUILD_STATIC))
BUILD_EXAMPLE    := $(call _on,$(XXD_BUILD_EXAMPLE))

# The xxd executable is skipped under Emscripten, like in CMakeLists.txt.
ifdef EMSCRIPTEN
BUILD_EXECUTABLE :=
ifndef BUILD_STATIC
$(warning Emscripten cannot build a shared libxxd; building a static one)
BUILD_STATIC := 1
endif
endif

# AUTO: Emscripten -> hex/wasm path, GCC/Clang -> .incbin. ON forces .incbin,
# OFF forces the portable path (hex array, or --embed-file under Emscripten).
ifneq ($(filter AUTO auto Auto,$(XXD_EMBED_ASM)),)
  ifdef EMSCRIPTEN
    XXD_USE_ASM :=
  else
    XXD_USE_ASM := 1
  endif
else ifneq ($(call _on,$(XXD_EMBED_ASM)),)
  ifdef EMSCRIPTEN
    $(error xxd_embed: XXD_EMBED_ASM=ON is not supported with Emscripten (wasm-ld has no .incbin). Use AUTO or OFF)
  endif
  XXD_USE_ASM := 1
else ifneq ($(filter 0 OFF off Off FALSE false False NO no No N n,$(XXD_EMBED_ASM)),)
  XXD_USE_ASM :=
else
  $(error XXD_EMBED_ASM must be AUTO, ON or OFF (got '$(XXD_EMBED_ASM)'))
endif

ifdef XXD_USE_ASM
XXD_MODE := ASM
else ifdef EMSCRIPTEN
XXD_MODE := WASM
else
XXD_MODE := HEX
endif

# ---------------------------------------------------------------------------
# Outputs and flags
# ---------------------------------------------------------------------------
XXD_BIN := $(BUILD_DIR)/xxd$(EXEEXT)

ifdef BUILD_STATIC
LIBXXD      := $(BUILD_DIR)/libxxd.a
LIBXXD_LINK := $(LIBXXD)
else
LIBXXD      := $(BUILD_DIR)/libxxd$(SOEXT)
LIBXXD_LINK := -L$(BUILD_DIR) -lxxd
ifndef TARGET_WINDOWS
LIBXXD_LINK += -Wl,-rpath,$(abspath $(BUILD_DIR))
endif
endif

EXAMPLE_BIN := $(BUILD_DIR)/example/xxd_example$(EXAMPLE_EXT)

# gnu11 matches CMake's default (C_STANDARD 11 with extensions on).
XXD_CPPFLAGS := -I$(XXD_INC) $(if $(BUILD_STATIC),-DXXD_STATIC)
XXD_CFLAGS   := -std=gnu11 $(CFLAGS)

LIB_CPPFLAGS :=
LIB_CFLAGS   :=
LIB_LDFLAGS  :=
ifndef BUILD_STATIC
LIB_CPPFLAGS += -DXXD_EXPORTS
ifndef TARGET_WINDOWS
LIB_CFLAGS += -fPIC
endif
ifeq ($(UNAME_S),Darwin)
LIB_LDFLAGS += -dynamiclib -install_name @rpath/libxxd$(SOEXT)
else
LIB_LDFLAGS += -shared
ifndef TARGET_WINDOWS
LIB_LDFLAGS += -Wl,-soname,libxxd$(SOEXT)
endif
endif
endif

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------
.PHONY: all lib xxd example run clean help
.DEFAULT_GOAL := all

all: lib $(if $(BUILD_EXECUTABLE),xxd) $(if $(BUILD_EXAMPLE),example)

lib: $(LIBXXD)
xxd: $(XXD_BIN)
example: $(EXAMPLE_BIN)

run: $(EXAMPLE_BIN)
	$(if $(EMSCRIPTEN),node) $(EXAMPLE_BIN)

clean:
	rm -rf -- $(call shq,$(BUILD_DIR)) $(call shq,$(XXD_GEN_DIR))

help:
	@echo 'Targets: all (default) lib xxd example run clean help'
	@echo 'Options (VAR=value):'
	@echo '  XXD_BUILD_EXECUTABLE=ON|OFF  build the xxd executable        [$(XXD_BUILD_EXECUTABLE)]'
	@echo '  XXD_BUILD_STATIC=ON|OFF      static (ON) or shared libxxd     [$(XXD_BUILD_STATIC)]'
	@echo '  XXD_BUILD_EXAMPLE=ON|OFF     build the example                [$(XXD_BUILD_EXAMPLE)]'
	@echo '  XXD_EMBED_ASM=AUTO|ON|OFF    embedding strategy               [$(XXD_EMBED_ASM)]'
	@echo '  BUILD_DIR=<dir>              output directory                 [$(BUILD_DIR)]'
	@echo '  XXD_EMBED_BINARY_DIR=<dir>   where Generated/ files are put   [$(XXD_EMBED_BINARY_DIR)]'
	@echo '  CC, AR, CFLAGS, LDFLAGS      toolchain                        [$(CC)]'
	@echo '  V=1                          echo full commands'
	@echo 'Embedding mode in use: $(XXD_MODE)'

# --- library ---------------------------------------------------------------
$(OBJ_DIR)/xxd_embed.o: $(XXD_ROOT)/src/xxd_embed.c
	$(call msg,CC,$<)
	@mkdir -p $(call shq,$(@D))
	$(Q)$(CC) $(XXD_CPPFLAGS) $(LIB_CPPFLAGS) $(CPPFLAGS) $(XXD_CFLAGS) $(LIB_CFLAGS) -MMD -MP -c -o $@ $<

ifdef BUILD_STATIC
$(LIBXXD): $(OBJ_DIR)/xxd_embed.o
	$(call msg,AR,$@)
	$(Q)rm -f $@ && $(AR) rcs $@ $^
else
$(LIBXXD): $(OBJ_DIR)/xxd_embed.o
	$(call msg,LD,$@)
	$(Q)$(CC) $(LIB_LDFLAGS) $(LDFLAGS) -o $@ $^
endif

# --- xxd executable --------------------------------------------------------
$(XXD_BIN): $(XXD_ROOT)/src/xxd.c
	$(call msg,CCLD,$@)
	@mkdir -p $(call shq,$(@D))
	$(Q)$(CC) $(CPPFLAGS) $(XXD_CFLAGS) $(LDFLAGS) -o $@ $<

# --- example ---------------------------------------------------------------
$(OBJ_DIR)/example.o: $(XXD_ROOT)/example/example.c
	$(call msg,CC,$<)
	@mkdir -p $(call shq,$(@D))
	$(Q)$(CC) $(XXD_CPPFLAGS) $(CPPFLAGS) $(XXD_CFLAGS) -MMD -MP -c -o $@ $<

# ---------------------------------------------------------------------------
# xxd_embed: embed a file into one target as a registered resource.
#
#   $(call xxd_embed,<FILE_KEY>,<FILE_PATH>,<MIME>,<TARGET>)
#
# Generates $(XXD_GEN_DIR)/<FILE_KEY>.c (+ .o) and appends the object to
# <TARGET>_EMBED_OBJS. Link that list into the target's executable; for the
# Emscripten path also pass <TARGET>_EMBED_LDFLAGS (the --embed-file flags).
# Objects are linked directly, so their startup constructors are always kept
# (the CMake build achieves the same with WHOLE_ARCHIVE).
# ---------------------------------------------------------------------------
XXD_SHA256 := $(shell if command -v sha256sum >/dev/null 2>&1; then echo sha256sum; \
	elif command -v shasum >/dev/null 2>&1; then echo shasum -a 256; \
	elif command -v openssl >/dev/null 2>&1; then echo openssl dgst -sha256 -r; fi)

# Shell prelude shared by all generators: key/mime/path variables, key hash and
# escaping helpers (sed replacement text, C string literal).
define _xxd_prelude
mkdir -p $(call shq,$(@D)); \
key=$(call shq,$(XXD_KEY)); mime=$(call shq,$(XXD_MIME)); src=$(call shq,$(XXD_SRC)); \
hash=$$(printf '%s' "$$key" | $(XXD_SHA256) | cut -d' ' -f1); \
sedesc() { printf '%s' "$$1" | sed -e 's/[\\&|]/\\&/g'; }; \
cesc() { printf '%s' "$$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
endef

define _xxd_sed_args
-e "s|@FILE_KEY_HASH@|$$hash|g" \
	-e "s|@FILE_KEY@|$$(sedesc "$$key")|g" \
	-e "s|@FILE_MIME@|$$(sedesc "$$mime")|g" \
	-e "s|@FILE_PATH_ESCAPED@|$$(sedesc "$$(cesc "$$src")")|g"
endef

# GCC/Clang: inline __asm__ .incbin (include/xxd_gas.c.in).
define _xxd_gen_ASM
$(call msg,EMBED,$(XXD_KEY))
$(Q)$(_xxd_prelude); \
	sed $(_xxd_sed_args) $(call shq,$(XXD_INC)/xxd_gas.c.in) > $@
endef

# Emscripten: --embed-file + fopen at startup (include/xxd_wasm.c.in).
define _xxd_gen_WASM
$(call msg,EMBED,$(XXD_KEY))
$(Q)$(_xxd_prelude); \
	sed $(_xxd_sed_args) $(call shq,$(XXD_INC)/xxd_wasm.c.in) > $@
endef

# Portable: hex array (include/xxd.c.in). $< is the .hex file produced by xxd -I.
define _xxd_gen_HEX
$(call msg,EMBED,$(XXD_KEY))
$(Q)$(_xxd_prelude); \
	sed $(_xxd_sed_args) $(call shq,$(XXD_INC)/xxd.c.in) | \
	XXD_HEXFILE=$(call shq,$<) awk '{ \
		i = index($$0, "@CONTENT_HEX@"); \
		if (i) { \
			printf "%s", substr($$0, 1, i - 1); \
			while ((getline l < ENVIRON["XXD_HEXFILE"]) > 0) print l; \
			printf "%s\n", substr($$0, i + 13); \
		} else print }' > $@
endef

# Hex generation: prefer the xxd executable (fast); otherwise od + awk, which
# produces the same layout (12 bytes per line, "0" for an empty file).
ifdef BUILD_EXECUTABLE
_xxd_hex_dep := $(XXD_BIN)
define _xxd_hex_cmd
$(XXD_BIN) -I $< $@
endef
else
_xxd_hex_dep :=
define _xxd_hex_cmd
od -An -v -tx1 $< | awk '{ for (i = 1; i <= NF; i++) { \
		if (n > 0) printf (n % 12 == 0 ? ",\n  " : ", "); else printf "  "; \
		printf "0x%s", $$i; n++ } } END { if (n) print ""; else print "0" }' > $@
endef
endif

_xxd_gen = $(_xxd_gen_$(XXD_MODE))

define _xxd_rules_common
$(XXD_GEN_DIR)/$(1).c: XXD_KEY  := $(1)
$(XXD_GEN_DIR)/$(1).c: XXD_MIME := $(3)
$(XXD_GEN_DIR)/$(1).c: XXD_SRC  := $(abspath $(2))
$(4)_EMBED_OBJS += $(XXD_GEN_DIR)/$(1).o
endef

define _xxd_rules_ASM
$(XXD_GEN_DIR)/$(1).c: $(2) $(XXD_INC)/xxd_gas.c.in
	$$(_xxd_gen)
endef

define _xxd_rules_WASM
$(XXD_GEN_DIR)/$(1).c: $(2) $(XXD_INC)/xxd_wasm.c.in
	$$(_xxd_gen)
$(4)_EMBED_LDFLAGS += --embed-file $(call shq,$(abspath $(2))@/xxd/$(1))
endef

define _xxd_rules_HEX
$(XXD_GEN_DIR)/$(1).hex: $(2) $(_xxd_hex_dep)
	$$(call msg,HEX,$(1))
	@mkdir -p $$(call shq,$$(@D))
	$$(Q)$$(_xxd_hex_cmd)
$(XXD_GEN_DIR)/$(1).c: $(XXD_GEN_DIR)/$(1).hex $(XXD_INC)/xxd.c.in
	$$(_xxd_gen)
endef

xxd_embed = $(if $(XXD_SHA256),,$(error xxd_embed: need sha256sum, shasum or openssl))\
	$(eval $(call _xxd_rules_common,$(1),$(2),$(3),$(4)))\
	$(eval $(call _xxd_rules_$(XXD_MODE),$(1),$(2),$(3),$(4)))

# Generated sources are compiled without optimization: they are large arrays.
$(XXD_GEN_DIR)/%.o: $(XXD_GEN_DIR)/%.c
	$(call msg,CC,$<)
	$(Q)$(CC) $(XXD_CPPFLAGS) $(CPPFLAGS) $(XXD_CFLAGS) -O0 -MMD -MP -c -o $@ $<

# ---------------------------------------------------------------------------
# Example resources (see example/CMakeLists.txt)
# ---------------------------------------------------------------------------
ifdef BUILD_EXAMPLE
$(call xxd_embed,text,$(XXD_ROOT)/example/text.txt,text/plain,xxd_example)
$(call xxd_embed,rect,$(XXD_ROOT)/example/rect.svg,image/svg+xml,xxd_example)

$(EXAMPLE_BIN): $(OBJ_DIR)/example.o $(xxd_example_EMBED_OBJS) $(LIBXXD)
	$(call msg,CCLD,$@)
	@mkdir -p $(call shq,$(@D))
	$(Q)$(CC) $(LDFLAGS) -o $@ $(OBJ_DIR)/example.o $(xxd_example_EMBED_OBJS) $(LIBXXD_LINK) $(xxd_example_EMBED_LDFLAGS)
endif

-include $(wildcard $(OBJ_DIR)/*.d) $(wildcard $(XXD_GEN_DIR)/*.d)
