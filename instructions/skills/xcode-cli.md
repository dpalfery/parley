# Xcode Command Line Skills

## Project Structure Understanding

### File Priority
- Always use `.xcworkspace` if it exists (even if inside `.xcodeproj`)
- Only use `.xcodeproj` if no workspace is present
- Workspace manages dependencies (CocoaPods, SPM, multiple projects)

### Discovery Commands
```bash
# List all schemes in a project
xcodebuild -list -project Parley.xcodeproj

# List all schemes in a workspace
xcodebuild -list -workspace Parley.xcworkspace

# Show build settings
xcodebuild -showBuildSettings -project .xcodeproj -scheme Parley

# Show SDKs available
xcodebuild -showsdks
```

## Building Projects

### Basic Build Commands
```bash
# Build with workspace
xcodebuild -workspace Parley.xcodeproj/project.xcworkspace \
  -scheme Parley \
  -sdk iphoneos \
  -destination 'platform=iOS,name=iPhone 16' \
  clean build

# Build with project only
xcodebuild -project Parley.xcodeproj \
  -scheme Parley \
  -sdk iphoneos \
  clean build

# Build for simulator
xcodebuild -workspace Parley.xcworkspace \
  -scheme Parley \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  clean build

# Build and run on David's iPhone device
xcodebuild -workspace Parley.xcworkspace \
  -scheme Parley \
  -sdk iphoneos \
  -destination 'platform=iOS,id=<david-iphone-udid>' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="iPhone Developer" \
  PROVISIONING_PROFILE_SPECIFIER="David_iPhone_Dev_Profile" \
  clean build
```

### Common Destinations
```bash
# Physical devices
-destination 'platform=iOS,name=iPhone 16'
-destination 'platform=iOS,id=<device-udid>'

# Simulators
-destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0'
-destination 'generic/platform=iOS Simulator'

# macOS (for Mac Catalyst or macOS apps)
-destination 'platform=macOS'
```

### Build Configurations
- **Debug**: Development builds with symbols
- **Release**: Optimized production builds
- Specify with `-configuration Debug` or `-configuration Release`

## Simulator Management

### List Simulators
```bash
# List all available simulators
xcrun simctl list devices

# List only booted simulators
xcrun simctl list devices | grep Booted

# List available runtimes
xcrun simctl list runtimes
```

### Simulator Operations
```bash
# Boot a simulator
xcrun simctl boot "iPhone 16"

# Shutdown a simulator
xcrun simctl shutdown "iPhone 16"

# Shutdown all simulators
xcrun simctl shutdown all

# Erase a simulator
xcrun simctl erase "iPhone 16"

# Install app on simulator
xcrun simctl install booted path/to/YourApp.app

# Launch app on simulator
xcrun simctl launch booted com.yourcompany.yourapp

# Uninstall app
xcrun simctl uninstall booted com.yourcompany.yourapp
```

### Get Simulator App Path
```bash
# Get container path for debugging
xcrun simctl get_app_container booted com.yourcompany.yourapp
```

## Testing

### Running Tests
```bash
# Run all tests
xcodebuild test \
  -workspace Parley.xcworkspace \
  -scheme Parley \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test
xcodebuild test \
  -workspace Parley.xcworkspace \
  -scheme Parley \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ParleyTests/MyTestClass/testMethod
```

## Code Signing & Archiving

### Create Archive
```bash
# Archive for App Store
xcodebuild archive \
  -workspace Parley.xcworkspace \
  -scheme Parley \
  -archivePath ./build/Parley.xcarchive \
  -configuration Release \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  PROVISIONING_PROFILE_SPECIFIER="YourProvisioningProfile"
```

### Export Archive
```bash
# Export for App Store
xcodebuild -exportArchive \
  -archivePath ./build/Parley.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist exportOptions.plist
```

### Check Code Signing
```bash
# Verify code signature
codesign -dv --verbose=4 path/to/YourApp.app

# Check entitlements
codesign -d --entitlements - path/to/YourApp.app
```

## Swift Package Manager

### Common SPM Operations
```bash
# Resolve package dependencies
xcodebuild -resolvePackageDependencies \
  -workspace Parley.xcworkspace \
  -scheme Parley

# Update packages
# (Usually done through Xcode: File > Packages > Update to Latest Package Versions)
```

## Derived Data Management

### Clean Build Artifacts
```bash
# Clean derived data for specific project
rm -rf ~/Library/Developer/Xcode/DerivedData/Parley-*

# Clean all derived data (nuclear option)
rm -rf ~/Library/Developer/Xcode/DerivedData

# Clean with xcodebuild
xcodebuild clean -workspace Parley.xcworkspace -scheme Parley
```

## Common Patterns

### Full Clean Build Pipeline
```bash
# Complete clean build for simulator
xcodebuild clean build \
  -workspace Parley.xcworkspace \
  -scheme Parley \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug \
  | xcpretty  # Optional: pretty output formatting
```

### Build and Run on Simulator
```bash
# 1. Build
xcodebuild build \
  -workspace Parley.xcworkspace \
  -scheme Parley \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath ./build

# 2. Boot simulator if not running
xcrun simctl boot "iPhone 16" || true

# 3. Install app
xcrun simctl install booted ./build/Build/Products/Debug-iphonesimulator/Parley.app

# 4. Launch app
xcrun simctl launch booted com.yourcompany.yourapp
```

## Troubleshooting

### Common Issues and Solutions

**"No scheme named X found"**
- Run `xcodebuild -list` to see available schemes
- Scheme names are case-sensitive
- Ensure you're using `-workspace` if a workspace exists

**Build failures with dependencies**
- Always use `.xcworkspace` when CocoaPods/SPM is involved
- Try cleaning derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Resolve packages: `xcodebuild -resolvePackageDependencies`

**Simulator not found**
- List available simulators: `xcrun simctl list devices`
- Use exact name from the list (case-sensitive)
- Ensure Xcode Command Line Tools are installed: `xcode-select --install`

**Code signing errors**
- Check available identities: `security find-identity -v -p codesigning`
- Verify provisioning profiles in: `~/Library/MobileDevice/Provisioning Profiles/`
- For development builds, add `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`

## Environment Variables

### Useful Xcode Environment Variables
```bash
# Use specific Xcode version
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Show all build commands
export XCODE_XCCONFIG_FILE=path/to/custom.xcconfig

# Increase build parallelism
-parallelizeTargets
-jobs 8
```

## Tips for Claude Code

1. **Always check for workspace first** - Use `ls -la` to see if `.xcworkspace` exists
2. **List schemes before building** - Run `xcodebuild -list` to discover available schemes
3. **Use full paths** - Relative paths can cause issues; use absolute paths when possible
4. **Check simulator availability** - Run `xcrun simctl list devices` before targeting a specific simulator
5. **Default to Debug configuration** - Unless specifically building for release
6. **Handle spaces in names** - Use quotes around simulator names and scheme names with spaces
7. **Verify Xcode CLI tools** - Run `xcode-select -p` to confirm tools are installed

## iOS Version and Device Reference

### Current iOS Versions (as of late 2024/early 2025)
- iOS 26.x - Current release
- iOS 25.x - Previous major version
- iOS 24.x - Still supported

### Common Device Names for Simulators
- iPhone 16 Pro Max
- iPhone 16 Pro
- iPhone 16 Plus
- iPhone 16
- iPad Pro (12.9-inch)
- iPad Air

### SDK Names
- `iphoneos` - Physical iOS devices
- `iphonesimulator` - iOS Simulator
- `macosx` - macOS apps
- `appletvos` - tvOS devices
- `appletvsimulator` - tvOS Simulator
- `watchos` - watchOS devices
- `watchsimulator` - watchOS Simulator
