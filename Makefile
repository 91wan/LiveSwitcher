PKG_PATH      := Sources/AnnualMeetingSwitcher
BUILD_SCRIPT  := $(PKG_PATH)/build_v33.sh
APP_NAME      := LiveSwitcher.app
INSTALL_SRC   := $(HOME)/Downloads/$(APP_NAME)
INSTALL_DST   := /Applications/$(APP_NAME)

.PHONY: all build run install test hygiene clean version

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

hygiene:
	@./script/check_release_hygiene.sh

clean:
	@rm -rf .build $(PKG_PATH)/.build dist

version:
	@grep -m1 -E -o 'LiveSwitcher-macOS-v[0-9][0-9.]*[.]zip' README.md | sed 's/LiveSwitcher-macOS-v//; s/[.]zip//'
