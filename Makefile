APP_NAME = Battery Monitor
SCHEME = BatteryMonitor
VERSION ?= 1.2.0

BUILD_DIR = .build
STAGING_DIR = .staging
DMG_OUTPUT = BatteryMonitor-$(VERSION).dmg

SVG_PATH = Resources/AppIcon.svg
ICONSET_DIR = Resources/AppIcon.iconset
ICNS_OUTPUT = Resources/AppIcon.icns

.PHONY: all clean check-deps icons build dmg

all: dmg

clean:
	@echo "🧹 Cleaning up..."
	@rm -rf $(BUILD_DIR) $(STAGING_DIR) $(ICONSET_DIR) BatteryMonitor.xcodeproj 
	@rm -f $(DMG_OUTPUT)

check-deps:
	@echo "🔍 Checking dependencies..."
	@command -v xcodegen >/dev/null || (echo "❌ xcodegen not found. Install with: brew install xcodegen" && exit 1)
	@command -v xcodebuild >/dev/null || (echo "❌ xcodebuild not found. Install Xcode from the App Store." && exit 1)

icons:
	@echo "🎨 Generating AppIcon.icns from SVG..."
	@if python3 -c "import cairosvg" 2>/dev/null; then \
		echo "📐 Using cairosvg"; \
		mkdir -p $(ICONSET_DIR); \
		python3 -c "import cairosvg; \
cairosvg.svg2png(url='$(SVG_PATH)', write_to='$(ICONSET_DIR)/icon_16x16.png', output_width=16, output_height=16); \
cairosvg.svg2png(url='$(SVG_PATH)', write_to='$(ICONSET_DIR)/icon_16x16@2x.png', output_width=32, output_height=32); \
cairosvg.svg2png(url='$(SVG_PATH)', write_to='$(ICONSET_DIR)/icon_32x32.png', output_width=32, output_height=32); \
cairosvg.svg2png(url='$(SVG_PATH)', write_to='$(ICONSET_DIR)/icon_32x32@2x.png', output_width=64, output_height=64); \
cairosvg.svg2png(url='$(SVG_PATH)', write_to='$(ICONSET_DIR)/icon_128x128.png', output_width=128, output_height=128); \
cairosvg.svg2png(url='$(SVG_PATH)', write_to='$(ICONSET_DIR)/icon_128x128@2x.png', output_width=256, output_height=256); \
cairosvg.svg2png(url='$(SVG_PATH)', write_to='$(ICONSET_DIR)/icon_256x256.png', output_width=256, output_height=256); \
cairosvg.svg2png(url='$(SVG_PATH)', write_to='$(ICONSET_DIR)/icon_256x256@2x.png', output_width=512, output_height=512); \
cairosvg.svg2png(url='$(SVG_PATH)', write_to='$(ICONSET_DIR)/icon_512x512.png', output_width=512, output_height=512); \
cairosvg.svg2png(url='$(SVG_PATH)', write_to='$(ICONSET_DIR)/icon_512x512@2x.png', output_width=1024, output_height=1024)"; \
	elif command -v rsvg-convert >/dev/null; then \
		echo "📐 Using rsvg-convert"; \
		mkdir -p $(ICONSET_DIR); \
		rsvg-convert -w 16 -h 16 -o $(ICONSET_DIR)/icon_16x16.png $(SVG_PATH); \
		rsvg-convert -w 32 -h 32 -o $(ICONSET_DIR)/icon_16x16@2x.png $(SVG_PATH); \
		rsvg-convert -w 32 -h 32 -o $(ICONSET_DIR)/icon_32x32.png $(SVG_PATH); \
		rsvg-convert -w 64 -h 64 -o $(ICONSET_DIR)/icon_32x32@2x.png $(SVG_PATH); \
		rsvg-convert -w 128 -h 128 -o $(ICONSET_DIR)/icon_128x128.png $(SVG_PATH); \
		rsvg-convert -w 256 -h 256 -o $(ICONSET_DIR)/icon_128x128@2x.png $(SVG_PATH); \
		rsvg-convert -w 256 -h 256 -o $(ICONSET_DIR)/icon_256x256.png $(SVG_PATH); \
		rsvg-convert -w 512 -h 512 -o $(ICONSET_DIR)/icon_256x256@2x.png $(SVG_PATH); \
		rsvg-convert -w 512 -h 512 -o $(ICONSET_DIR)/icon_512x512.png $(SVG_PATH); \
		rsvg-convert -w 1024 -h 1024 -o $(ICONSET_DIR)/icon_512x512@2x.png $(SVG_PATH); \
	else \
		echo "❌ No SVG→PNG converter found. Install with: pip3 install cairosvg or brew install librsvg" && exit 1; \
	fi
	@echo "🗜 Compiling .icns with iconutil..."
	@iconutil -c icns $(ICONSET_DIR) -o $(ICNS_OUTPUT)
	@echo "✅ AppIcon.icns created → $(ICNS_OUTPUT)"

build: check-deps
	@echo "📐 Generating Xcode project from project.yml..."
	@xcodegen generate --quiet
	@echo "🔨 Building $(APP_NAME) v$(VERSION) (Release)..."
	@if command -v xcpretty >/dev/null; then \
		xcodebuild -project BatteryMonitor.xcodeproj -scheme $(SCHEME) -configuration Release -derivedDataPath $(BUILD_DIR) CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES build | xcpretty; \
	else \
		xcodebuild -project BatteryMonitor.xcodeproj -scheme $(SCHEME) -configuration Release -derivedDataPath $(BUILD_DIR) CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES build; \
	fi
	@echo "✅ Build completed!"

dmg: build
	@echo "📦 Packaging DMG..."
	@rm -rf $(STAGING_DIR)
	@mkdir -p $(STAGING_DIR)
	@APP_PATH=$$(find $(BUILD_DIR) -name "*.app" -type d 2>/dev/null | head -1); \
	if [ -z "$$APP_PATH" ]; then \
		echo "❌ Build failed — .app bundle not found under $(BUILD_DIR)"; \
		exit 1; \
	fi; \
	cp -R "$$APP_PATH" "$(STAGING_DIR)/$(APP_NAME).app"
	@ln -s /Applications "$(STAGING_DIR)/Applications"
	@if [ -f "$(ICNS_OUTPUT)" ]; then \
		cp "$(ICNS_OUTPUT)" "$(STAGING_DIR)/.VolumeIcon.icns"; \
		if command -v SetFile >/dev/null; then SetFile -a C "$(STAGING_DIR)" 2>/dev/null || true; fi; \
	fi
	@rm -f $(DMG_OUTPUT)
	@hdiutil create -volname "$(APP_NAME)" -srcfolder $(STAGING_DIR) -ov -format UDBZ $(DMG_OUTPUT)
	@echo "🧹 Cleaning up temporary Xcode project..."
	@rm -rf BatteryMonitor.xcodeproj
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "✅ Done! → $(DMG_OUTPUT)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
