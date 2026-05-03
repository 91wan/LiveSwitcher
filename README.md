# LiveSwitcher

LiveSwitcher is a native macOS live-event switching console for small stages,
meetups, presentations, and event rooms. It combines a program playlist,
external-display output, local HTML presentation output, background music
control, emergency blackout, wallpapers, and lightweight overlays in one
SwiftUI app.

Version: `v0.1.0`  
Platform: macOS 14.0+ on Apple Silicon  
Distribution: source available, no license granted

## Features

- Program playlist for video, audio, Keynote, PPTX, and local HTML files.
- External display output with wallpaper fallback and emergency blackout.
- Program monitor with live/preview-oriented switching state.
- Background music playlist, master volume, media volume, and BGM volume.
- Presenter mode to reduce BGM while keeping the program source active.
- HTML full-screen output through `WKWebView` with local asset access.
- Lower-third, ticker, and countdown overlays.
- Page-clicker interception mode for presentation workflows.

## Requirements

- macOS 14.0 or later
- Apple Silicon Mac
- Xcode 15 or Command Line Tools
- Accessibility permission for page-clicker interception mode
- Apple Events permission when controlling presentation apps

## Build, Test, Run

```bash
git clone https://github.com/91wan/LiveSwitcher.git
cd LiveSwitcher

swift build
swift test

./script/build_and_run.sh --verify
```

Daily shortcuts:

```bash
make build
make run
make test
bash Sources/AnnualMeetingSwitcher/build_v33.sh
```

`./script/build_and_run.sh --verify` builds `dist/LiveSwitcher.app`, launches it,
and verifies that the app process remains running.

## Release Install Notes

The first public release ships as `LiveSwitcher-macOS-v0.1.0.zip` containing
`LiveSwitcher.app`.

The app is ad-hoc signed and not notarized. On first launch, macOS Gatekeeper may
show a warning. Open it from **System Settings → Privacy & Security → Open
Anyway**, or build from source locally.

## Permissions

Page-clicker interception mode requires Accessibility permission:

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Add `LiveSwitcher.app`.
3. Enable the permission.
4. Restart the app.

Presentation automation may also request Apple Events permission when controlling
Keynote or compatible presentation apps.

## Repository Shape

```text
.
├── Package.swift
├── Makefile
├── script/build_and_run.sh
├── Sources/AnnualMeetingSwitcher/
│   ├── Package.swift
│   ├── build_v33.sh
│   ├── LiveSwitcher.entitlements
│   └── Sources/AnnualMeetingSwitcher/
│       ├── App.swift
│       ├── AppConfiguration.swift
│       ├── ContentView.swift
│       ├── ViewModel.swift
│       ├── Engines/
│       ├── Models/
│       ├── Output/
│       └── Views/
└── .github/workflows/
    ├── smoke-tests.yml
    └── release.yml
```

## No License

No open-source license is provided. The code is publicly visible, but all rights
are reserved by the repository owner unless a license is added later.
