# WheelDrop — Network Policy

## Summary

WheelDrop makes **zero network connections**. All file conversion is local.

## Detail

| Category | Behavior |
|---|---|
| File conversion | 100% local. ImageIO, CoreGraphics, AVFoundation, PDFKit, shell subprocesses. |
| Telemetry | None. No analytics, crash reporting, or usage tracking of any kind. |
| Update checks | None. No auto-update mechanism. |
| Account / login | None required. |
| Cloud services | None. Files never leave the Mac. |
| External APIs | None. |

## ffmpeg dependency (optional, for video/audio tools)

If ffmpeg tools are enabled, WheelDrop launches a locally-installed `ffmpeg`
binary via `Process` with a fixed executable URL. No network call is made by
WheelDrop itself. Whether the ffmpeg binary itself phones home depends on
the specific build you install — check the build's own documentation.

WheelDrop does NOT download ffmpeg automatically. You install it separately
(e.g. `brew install ffmpeg`) or point the app to an existing binary.

## Outbound connections checklist

| Connection | Made? | Notes |
|---|---|---|
| Conversion API | No | — |
| License server | No | — |
| Analytics endpoint | No | — |
| Update server | No | — |
| iCloud / CloudKit | No | — |
| App Store receipt validation | No | Not distributed via App Store |

## Development / diagnostic build

The diagnostic app (Phase 0) adds nothing beyond what is listed above.
No additional network activity.
