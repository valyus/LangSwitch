# LangSwitch

A macOS menu bar utility for correcting text typed with the wrong keyboard layout and switching input languages.

## Features

- Convert text with a configurable global keyboard shortcut (default: Control + Option + Shift + Space).
- Press the shortcut again to undo the last conversion.
- Configure language pairs and exclude individual applications.
- Includes English pairings with Russian, Ukrainian, German, and French.

## Build and run

1. On macOS 13 or later, open `LangSwitch/LangSwitch.xcodeproj` in Xcode.
2. Select the LangSwitch scheme and your Mac as the run destination.
3. Select your own signing team in Signing & Capabilities if required.
4. Build and run the app.
5. Follow onboarding and grant Accessibility access in System Settings so LangSwitch can replace text in other applications.

Configure your language pair and shortcut from the menu bar settings. Enable the relevant keyboard input sources in macOS settings.

## Project layout

- `LangSwitch/LangSwitch/`: Swift application source.
- `LangSwitch/LangSwitch.xcodeproj/`: Xcode project.
- `LangSwitch/generate_xcodeproj.py`: Xcode project generation script.
