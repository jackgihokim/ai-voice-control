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

# Run tests
xcodebuild test -project AIVoiceControl.xcodeproj -scheme AIVoiceControl -destination 'platform=macOS'
```

### Running the App
- Build and run through Xcode (Cmd+R)
- The app will appear in the macOS menu bar, not in the Dock

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

The project follows a step-by-step implementation plan tracked in `Docs/step-list.json`. Each step builds upon the previous one and should be independently testable.

## Development Guidelines

### Writing Code Requirement
- Use Context7 MCP when writing code

### Platform Requirements
- macOS 15.0+
- Swift 6.1+
- SwiftUI framework
- Non-sandboxed app (required for Accessibility API)

### Required System Permissions
- Microphone access
- Accessibility permission
- Automation permission (for AppleScript)

### Key APIs and Frameworks
- Speech Framework (voice recognition)
- AVFoundation (audio processing and TTS)
- Accessibility API (app control)
- AppleScript (terminal control)
- Voice Isolation API (noise reduction, macOS 12+)

## Testing Approach

### Unit Testing
- Test voice recognition accuracy
- Test wake word detection logic
- Test JSON response parsing

### Integration Testing
- Test app activation and control
- Test terminal command execution
- Test end-to-end voice command flow

### Manual Testing
- Test in noisy environments (Voice Isolation)
- Test with different system voices
- Test permission request flows

## Common Development Tasks

### Adding a New Supported App
1. Add app configuration to `Core/Models/ControlledApp.swift`
2. Implement app-specific control logic in `Features/AppControl/`
3. Add wake word configuration
4. Test app activation and text input

### Implementing a New Voice Command
1. Add command pattern to wake word detector
2. Implement command handler
3. Add visual/audio feedback
4. Update user documentation

### Debugging Voice Recognition
- Enable verbose logging in `VoiceRecognitionManager`
- Monitor audio levels in console
- Check microphone permissions
- Verify Voice Isolation status

## Performance Considerations

- Background CPU usage should stay under 5% with Voice Isolation
- Memory usage target: < 250MB in always-listening mode
- Wake word detection latency: < 300ms
- App switching time: < 200ms