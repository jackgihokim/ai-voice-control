# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS native application called "AI Voice Control" that enables voice-controlled interaction with various AI desktop applications and terminal-based tools. The app runs as a menu bar application and uses Apple's Speech Framework for voice recognition.

## Build and Development Commands

### Building the Project
```bash
# Open project in Xcode
open AIVoiceControl.xcodeproj

# Build from command line
xcodebuild -project AIVoiceControl.xcodeproj -scheme AIVoiceControl -configuration Debug build

# Clean build
xcodebuild -project AIVoiceControl.xcodeproj -scheme AIVoiceControl -configuration Debug clean build

# Run tests
xcodebuild test -project AIVoiceControl.xcodeproj -scheme AIVoiceControl -destination 'platform=macOS'
```

### Development Scripts
```bash
# Reset app state (UserDefaults, caches, etc.)
./reset-app.sh

# Full development build with permission reset (권장)
./Shells/dev-build-and-test.sh

# Xcode 빌드 후 권한 문제 해결
./fix-xcode-build.sh

# Reset app state (UserDefaults, caches, etc.)
./reset-app.sh

# Debug with reset flag
# In Xcode: Product → Scheme → Edit Scheme → Arguments
# Add: -reset-defaults
```

### Development Workflow
1. **전체 테스트**: `./Shells/dev-build-and-test.sh` 사용
2. **Xcode 개발**: 
   - Xcode에서 빌드 (Cmd+R)
   - 권한 다이얼로그가 필요하면 `./fix-xcode-build.sh` 실행
   - 앱 다시 실행

### Running the App
- Build and run through Xcode (Cmd+R)
- The app will appear in the macOS menu bar, not in the Dock
- Debug builds include "Reset All Settings" in the context menu
- **중요**: Xcode 빌드 후 권한 다이얼로그가 안 나오면 `./fix-xcode-build.sh` 실행

## Architecture Overview

### Project Structure
The application follows a modular architecture based on the implementation guide:

```
AIVoiceControl/
├── App/                    # Application lifecycle and configuration
├── Core/                   # Shared models, managers, and utilities
│   ├── Models/            # Data models
│   ├── Managers/          # Core service managers
│   └── Utilities/         # Helper functions and extensions
├── Features/              # Feature-specific modules
│   ├── MenuBar/          # Menu bar UI and management
│   ├── VoiceRecognition/ # Speech recognition engine
│   ├── AppControl/       # External app control via Accessibility API
│   ├── TerminalControl/  # Terminal integration (iTerm2, Terminal.app)
│   ├── VoiceOutput/      # Text-to-speech functionality
│   └── WaveformUI/       # Voice level visualization
└── Resources/            # Assets and configuration files
```

### Key Technical Components

1. **Menu Bar App**: SwiftUI-based menu bar application without Dock presence
2. **Voice Recognition**: Uses Apple Speech Framework with Voice Isolation API (macOS 12+)
3. **App Control**: Accessibility API for controlling external applications
4. **Terminal Integration**: AppleScript API for iTerm2 control
5. **TTS Engine**: AVSpeechSynthesizer for voice output

### Implementation Status

The project follows a step-by-step implementation plan tracked in `Docs/step-list.json`. Each step builds upon the previous one and should be independently testable. Completed steps: 1, 2, 16.

## Development Guidelines

### Critical Rules
- **NEVER use standard SwiftUI TextField** - Always use `UltraSimpleTextField` to prevent ViewBridge errors
- **App-specific voice settings are only editable in Edit mode** - This is intentional UX design
- **AVSpeechSynthesizer must be retained as @State** - Prevents early deallocation and audio cutoff

### Platform Requirements
- macOS 15.0+
- Swift 6.1+
- SwiftUI framework
- Non-sandboxed app (required for Accessibility API)

### Required System Permissions
- Microphone access (`com.apple.security.device.microphone`)
- Accessibility permission (`com.apple.security.accessibility`)
- Automation permission for AppleScript (`com.apple.security.automation.apple-events`)
- **CRITICAL**: App sandbox must be disabled (`com.apple.security.app-sandbox = false`) for Accessibility API access

### Key APIs and Frameworks
- Speech Framework (voice recognition)
- AVFoundation (audio processing and TTS)
- Accessibility API (app control)
- AppleScript (terminal control)
- Voice Isolation API (noise reduction, macOS 12+)

### Critical Implementation Details

#### ViewBridge Error Prevention (VIEWBRIDGE_NUCLEAR_SOLUTION.md)
The app implements an aggressive "Nuclear Option" to prevent ViewBridge errors:
- Uses `UltraSimpleTextField` instead of standard SwiftUI TextField
- Implements `SimpleViewBridgeKiller.activateNuclearOption()` in AppDelegate
- Disables window restoration system completely
- All text input fields use custom NSTextField implementation
- **IMPORTANT**: Avoids disabling `NSTextInputContextKeyboardLayoutName` and `AppleLanguagePreferences` as these interfere with speech synthesis

#### Voice Command Architecture
- **Wake Words**: Arrays of trigger words per app (e.g., ["Claude", "클로드"])
- **Execution Words**: Arrays of completion words (e.g., ["Execute", "Run", "Go"])
- **App Configuration**: `AppConfiguration` model handles app-specific settings including wake/execution words
- **Settings Persistence**: Uses UserDefaults with JSON encoding via `UserSettings.save()`
- **App-Specific Voice Settings**: Each app can have custom voice settings (selectedVoiceId, speechRate, voiceOutputVolume)
- **Voice Fallback**: When app-specific settings are nil, global voice settings are used

#### Voice Settings Error Handling
To prevent "FactoryInstall Unable to query results, error: 5" errors:
- Voice settings tab loads basic voices by default (`getBasicVoices()`)
- Uses common voice identifiers and language-based fallbacks
- Avoids calling `AVSpeechSynthesisVoice.speechVoices()` on startup
- Provides optional "Load All System Voices" button for advanced users
- **CRITICAL**: This approach prevents system-level speech service conflicts

#### UI Design Patterns
- **Compact Keyword UI**: Uses `LazyVGrid` with 3 columns for space-efficient keyword display
- **Delete Buttons**: Positioned at top-right corner of keyword rectangles using `ZStack` and `offset`
- **Menu Bar App**: No Dock presence, lives entirely in menu bar with popover interface

## Testing Approach

### Unit Testing
- Test voice recognition accuracy
- Test wake word detection logic
- Test execution word detection logic
- Test JSON response parsing

### Integration Testing
- Test app activation and control
- Test terminal command execution
- Test end-to-end voice command flow with execution words

### Manual Testing
- Test in noisy environments (Voice Isolation)
- Test with different system voices
- Test permission request flows

## Data Models and Persistence

### Core Models
- **`AppConfiguration`**: Manages individual app settings with wake/execution words arrays
- **`UserSettings`**: Global app settings with JSON persistence via UserDefaults
- **`VoiceLanguage`**: Enum supporting Korean ("ko-KR") and English ("en-US")
- **`LogLevel`**: Debug levels for development and troubleshooting

### Settings Management
- Settings auto-save when modified through the UI
- Default execution words: ["Execute", "Run", "Go"]
- Each app can have multiple wake words and inherits default execution words
- App installations are detected via `NSWorkspace.shared.urlForApplication`

## Important Technical Notes

### Text Field Implementation
Always use `UltraSimpleTextField` for text input instead of standard SwiftUI TextField to prevent ViewBridge errors. This custom implementation:
- Disables all advanced text features (spell check, auto-correction, etc.)
- Uses custom delegate methods for proper text change detection
- Supports Enter key callbacks via `onReturn` parameter

### Menu Bar Integration
The app uses `NSStatusItem` with a popover interface. Key implementation details:
- Left-click toggles the main popover
- Right-click shows context menu (About, Preferences, Quit)
- Settings window is managed by `SettingsWindowController`
- App launches without Dock icon (LSUIElement = YES)

## Performance Considerations

- Background CPU usage should stay under 5% with Voice Isolation
- Memory usage target: < 250MB in always-listening mode
- Wake word detection latency: < 300ms
- App switching time: < 200ms

## Debugging and Troubleshooting

### UserDefaults Persistence Issues
If settings changes aren't appearing:
1. Run `./reset-app.sh` to clear all app state
2. Or use debug menu: Right-click menu bar icon → "Reset All Settings (Debug)"
3. Or add `-reset-defaults` argument in Xcode scheme

### AVSpeechSynthesizer Audio Cutoff
- Ensure synthesizer is stored as @State property, not local variable
- Call `stopSpeaking(at: .immediate)` before starting new speech
- Clean up in `onDisappear` to prevent memory leaks

### App Loading Errors
- Check console output for detailed error messages
- Verify app bundle identifiers match installed apps
- Some system apps may not be accessible due to permissions