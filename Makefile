BUILD_DIR = .build
RELEASE_BIN = $(BUILD_DIR)/release/TaskBar
APP_NAME = TaskBar.app
APP_DIR = $(BUILD_DIR)/$(APP_NAME)

.PHONY: build release run app clean

build:
	swift build

release:
	swift build -c release

run: build
	$(BUILD_DIR)/debug/TaskBar

# Create a proper .app bundle (optional — for putting in /Applications)
app: release
	rm -rf $(APP_DIR)
	mkdir -p $(APP_DIR)/Contents/MacOS
	mkdir -p $(APP_DIR)/Contents/Resources
	cp $(RELEASE_BIN) $(APP_DIR)/Contents/MacOS/TaskBar
	/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string TaskBar" $(APP_DIR)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.tasks-nvim.taskbar" $(APP_DIR)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleName string TaskBar" $(APP_DIR)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" $(APP_DIR)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1.0" $(APP_DIR)/Contents/Info.plist
	@echo "Built $(APP_DIR)"

install: app
	cp -r $(APP_DIR) /Applications/$(APP_NAME)
	@echo "Installed to /Applications/$(APP_NAME)"

clean:
	swift package clean
	rm -rf $(APP_DIR)
