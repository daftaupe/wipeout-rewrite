CC ?= gcc
EMCC ?= emcc
UNAME_S := $(shell uname -s)
RENDERER ?= GL
DEBUG ?= false

L_FLAGS ?= -lm -rdynamic
C_FLAGS ?= -std=gnu99 -Wall -Wno-unused-variable

ifeq ($(DEBUG), true)
	C_FLAGS := $(C_FLAGS) -g
else
	C_FLAGS := $(C_FLAGS) -O3
endif


# Rendeder ---------------------------------------------------------------------

ifeq ($(RENDERER), GL)
	RENDERER_SRC = src/render_gl.c
	C_FLAGS := $(C_FLAGS) -DRENDERER_GL
else
$(error Unknown RENDERER)
endif




# macOS ------------------------------------------------------------------------

ifeq ($(UNAME_S), Darwin)
	C_FLAGS := $(C_FLAGS) -x objective-c -I/opt/homebrew/include -D_THREAD_SAFE -w
	L_FLAGS := $(L_FLAGS) -L/opt/homebrew/lib -framework Foundation

	ifeq ($(RENDERER), GL)
		L_FLAGS := $(L_FLAGS) -lGLEW -GLU -framework OpenGL
	endif

	L_FLAGS_SDL = -lSDL2
	L_FLAGS_SOKOL = -framework Cocoa -framework QuartzCore -framework AudioToolbox


# Linux ------------------------------------------------------------------------

else ifeq ($(UNAME_S), Linux)
	ifeq ($(RENDERER), GL)
		L_FLAGS := $(L_FLAGS) -lGLEW -lGL
	endif

	L_FLAGS_SDL = -lSDL2
	L_FLAGS_SOKOL = -lX11 -lXcursor -pthread -lXi -ldl -lasound

# DragonFly --------------------------------------------------------------------

else ifeq ($(UNAME_S), DragonFly)
	ifeq ($(RENDERER), GL)
		C_FLAGS := $(C_FLAGS)  -I/usr/local/include
		L_FLAGS := $(L_FLAGS)  -L/usr/local/lib -lGLEW -lGL
	endif

	L_FLAGS_SDL = -lSDL2

# Windows ----------------------------------------------------------------------

else ifeq ($(OS), Windows_NT)
$(error TODO: FLAGS for windows have not been set up. Please modify this makefile and send a PR!)



else
$(error Unknown environment)
endif



# Source files -----------------------------------------------------------------

TARGET_NATIVE ?= wipegame
BUILD_DIR = build/obj/native
BUILD_DIR_WASM = build/obj/wasm

WASM_RELEASE_DIR ?= build/wasm
TARGET_WASM ?= $(WASM_RELEASE_DIR)/wipeout.js
TARGET_WASM_MINIMAL ?= $(WASM_RELEASE_DIR)/wipeout-minimal.js

COMMON_SRC = \
	src/wipeout/race.c \
	src/wipeout/camera.c \
	src/wipeout/object.c \
	src/wipeout/droid.c \
	src/wipeout/ui.c \
	src/wipeout/hud.c \
	src/wipeout/image.c \
	src/wipeout/game.c \
	src/wipeout/menu.c \
	src/wipeout/main_menu.c \
	src/wipeout/ingame_menus.c \
	src/wipeout/title.c \
	src/wipeout/intro.c \
	src/wipeout/scene.c \
	src/wipeout/ship.c \
	src/wipeout/ship_ai.c \
	src/wipeout/ship_player.c \
	src/wipeout/track.c \
	src/wipeout/weapon.c \
	src/wipeout/particle.c \
	src/wipeout/sfx.c \
	src/utils.c \
	src/types.c \
	src/system.c \
	src/mem.c \
	src/input.c \
	$(RENDERER_SRC)


# Targets native ---------------------------------------------------------------

COMMON_OBJ = $(patsubst %.c, $(BUILD_DIR)/%.o, $(COMMON_SRC))

sdl: $(BUILD_DIR)/src/platform_sdl.o
sdl: $(COMMON_OBJ)
	$(CC) $^ -o $(TARGET_NATIVE) $(L_FLAGS) $(L_FLAGS_SDL)

sokol: $(BUILD_DIR)/src/platform_sokol.o
sokol: $(COMMON_OBJ)
	$(CC) $^ -o $(TARGET_NATIVE) $(L_FLAGS) $(L_FLAGS_SOKOL)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: %.c
	mkdir -p $(dir $@)
	$(CC) $(C_FLAGS) -c $< -o $@


# Targets wasm -----------------------------------------------------------------

COMMON_OBJ_WASM = $(patsubst %.c, $(BUILD_DIR_WASM)/%.o, $(COMMON_SRC))
wasm: wasm_full wasm_minimal
	cp src/wasm-index.html $(WASM_RELEASE_DIR)/game.html


wasm_full: $(BUILD_DIR_WASM)/src/platform_sokol.o
wasm_full: $(COMMON_OBJ_WASM)
	mkdir -p $(WASM_RELEASE_DIR)
	$(EMCC) $^ -o $(TARGET_WASM) -lGLEW -lGL \
		-s ALLOW_MEMORY_GROWTH=1 \
		-s ENVIRONMENT=web \
		--preload-file wipeout

wasm_minimal: $(BUILD_DIR_WASM)/src/platform_sokol.o
wasm_minimal: $(COMMON_OBJ_WASM)
	mkdir -p $(WASM_RELEASE_DIR)
	$(EMCC) $^ -o $(TARGET_WASM_MINIMAL) -lGLEW -lGL \
		-s ALLOW_MEMORY_GROWTH=1 \
		-s ENVIRONMENT=web \
		--preload-file wipeout \
		--exclude-file wipeout/music \
		--exclude-file wipeout/intro.mpeg
	
$(BUILD_DIR_WASM):
	mkdir -p $(BUILD_DIR_WASM)

$(BUILD_DIR_WASM)/%.o: %.c
	mkdir -p $(dir $@)
	$(EMCC) $(C_FLAGS) -c $< -o $@






.PHONY: clean
clean:
	$(RM) -rf $(BUILD_DIR) $(BUILD_DIR_WASM) $(WASM_RELEASE_DIR)
