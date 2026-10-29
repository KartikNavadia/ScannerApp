# Scanner App

Turns the phone camera into a hands-free QR / barcode finder. Tap **Start** to
capture photos continuously, tap **Stop** to review them in a gallery. Codes
are detected on the device (nothing is uploaded). Filter photos with or without
codes, open a photo to see its decoded text, copy it, or open links.

## Approach

1. **Capture** – the camera's live frame stream is used instead of "take
   picture", so the preview never freezes. Each frame is converted to a JPEG on
   a background isolate (max two at once; extra frames are dropped) and saved to
   a temporary folder.
2. **Detect** – while capturing, each photo gets a quick ML Kit pass. After
   Stop, photos with no code get extra passes on small, smoothed,
   contrast-stretched copies (helps blurry or screen photos).
3. **Review** – the Gallery shows All / QR Detected / No QR. Tapping a photo
   with a code opens a dialog with the photo, the decoded text, Copy, and
   Open Link (for web links).
4. **State** – Provider holds the state; screens only display it
   (`ScanningProvider` for camera/capture, `BarcodeScanProvider` for results).

Portrait only. Camera is the only permission requested.

## Packages

| Package | Used for |
|---|---|
| `camera` | Live preview, frame stream, flashlight (torch). |
| `permission_handler` | Asking for camera permission and sending the user to Settings if it is permanently denied. |
| `google_mlkit_barcode_scanning` | On-device QR / barcode detection and decoding. |
| `image` | Converting camera frames to JPEG (rotate, YUV/BGRA → RGB) and building the enhanced copies for the fallback scan. |
| `provider` | State management (replaces `setState`). |
| `url_launcher` | Opening a detected web link from the "Open Link" button. |
| `cupertino_icons` | Template default; not used by the app code. |
| `flutter_lints` (dev) | Lint rules run by `flutter analyze`. |
| `flutter_test` (dev) | Unit tests in `test/`. |

The Geist font is bundled as an asset (see `pubspec.yaml`).

## Project layout

- `lib/scanning_page.dart` – Capture screen.
- `lib/captured_images_page.dart` – Gallery screen and dialogs.
- `lib/providers/` – `scanning_provider.dart`, `barcode_scan_provider.dart`.
- `lib/utils/` – `frame_encoder.dart`, `barcode_detector.dart`, colours, text styles.
- `docs/HOW_IT_WORKS.md` – longer write-up of how the app works.

## Run

```
flutter pub get
flutter run            # debug
flutter run --release  # release
```
