ARCHS ?= $(shell uname -m)
MIN_MACOS := 13.0
SIGN_IDENTITY ?= -
TIMESTAMP = $(if $(filter -,$(SIGN_IDENTITY)),,--timestamp)
BUILD := build
APP := $(BUILD)/Rotella.app
MODULE_CACHE ?= $(abspath $(BUILD)/ModuleCache)
SOURCES := $(wildcard Sources/*.swift)

.PHONY: all app package check clean FORCE
all: app
app: $(APP)/Contents/MacOS/Rotella

$(BUILD)/Rotella-%: $(SOURCES)
	mkdir -p "$(BUILD)"
	xcrun swiftc -module-cache-path "$(MODULE_CACHE)/$*" -target "$*-apple-macosx$(MIN_MACOS)" -O $(SOURCES) -o "$@"

$(APP)/Contents/MacOS/Rotella: $(addprefix $(BUILD)/Rotella-,$(ARCHS)) Resources/Rotella.icns Resources/Info.plist Resources/local.rotella.agent.plist Resources/local.rotella.scroll-service.plist FORCE
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources" "$(APP)/Contents/Library/LaunchAgents"
	xcrun lipo -create $(addprefix $(BUILD)/Rotella-,$(ARCHS)) -output "$@"
	cp Resources/Info.plist "$(APP)/Contents/"
	cp "Resources/Rotella.icns" "$(APP)/Contents/Resources/"
	cp Resources/local.rotella.agent.plist Resources/local.rotella.scroll-service.plist "$(APP)/Contents/Library/LaunchAgents/"
	codesign --force --options runtime $(TIMESTAMP) --sign "$(SIGN_IDENTITY)" "$(APP)"

check: app
	plutil -lint "$(APP)/Contents/Info.plist" "$(APP)/Contents/Library/LaunchAgents/local.rotella.agent.plist" "$(APP)/Contents/Library/LaunchAgents/local.rotella.scroll-service.plist"
	codesign --verify --strict --verbose=2 "$(APP)"
	xcrun lipo -info "$(APP)/Contents/MacOS/Rotella"

package: check
	ditto -c -k --keepParent "$(APP)" "$(BUILD)/Rotella-macOS.zip"

clean:
	rm -rf "$(BUILD)"
