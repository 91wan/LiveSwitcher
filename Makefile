PKG_PATH      := Sources/AnnualMeetingSwitcher
BUILD_SCRIPT  := $(PKG_PATH)/build_v33.sh
APP_NAME      := LiveSwitcher.app
INSTALL_SRC   := $(HOME)/Downloads/$(APP_NAME)
INSTALL_DST   := /Applications/$(APP_NAME)

.PHONY: all build run install test clean version

all: build

build:
	@echo "Building release app..."
	@bash $(BUILD_SCRIPT)
	@echo "Artifact: $(INSTALL_SRC)"

run: build
	@echo "Launching..."
	@open "$(INSTALL_SRC)"

install: build
	@echo "Installing to /Applications..."
	@rm -rf "$(INSTALL_DST)"
	@cp -R "$(INSTALL_SRC)" "$(INSTALL_DST)"
	@echo "Installed: $(INSTALL_DST)"

test:
	@swift test

clean:
	@rm -rf .build $(PKG_PATH)/.build dist

version:
	@grep -m1 "Version:" README.md | sed 's/.*`\\([^`]*\\)`.*/\\1/'
