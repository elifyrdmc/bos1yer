# Photo privacy processing

Before a parking photo is uploaded, the app processes it on the device:

- EXIF/GPS metadata is removed by decoding and re-encoding the image.
- ML Kit face detection and Latin text recognition mask faces and likely plate text.
- Face and likely plate detection is best-effort. Detection errors do not block photo upload; the user is warned to review the image.
- Detection is heuristic: it can miss or misclassify content, so it is not a guarantee that every identifying detail is removed.

## iOS build requirements

The Flutter ML Kit plugins require iOS 15.0 or later, Xcode 15.3 or later, and a 64-bit device or simulator. The Runner target uses the required -ObjC and -all_load linker flags.

The Xcode build phase downloads the two ML Kit resource bundles required by face detection and Latin OCR. It verifies pinned SHA-256 checksums, caches them in DerivedData, then places them in the compiled app. The first build on a machine or CI runner needs network access to GitHub; users do not download model files separately or change phone settings. Updating the ML Kit SwiftPM release requires updating both the bundle version and checksums in ios/scripts/prepare_mlkit_resources.sh.

## Runtime limits

The models run locally; the photo is not sent to a separate ML service. The app still needs its existing camera/location permissions for the photo and location flows. A minimum iOS version of 15.0 means older iPhones that cannot run iOS 15 will not be eligible to install the app.
