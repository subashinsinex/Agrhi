# Android release compatibility

The Android project pins NDK **28.2.13676358 (r28c)** and uses AGP **9.0.1** with uncompressed native libraries. Native dependencies already compiled by SDK vendors are not rebuilt by changing the app's NDK version, so check the final artifact for every release.

## Build and inspect

From `App/`, with release signing configured in `android/key.properties`:

```sh
flutter analyze --no-pub
flutter build appbundle --release
python tool/check_android_native.py build/app/outputs/bundle/release/app-release.aab
python -m unittest discover -s tool -p test_check_android_native.py
```

The Python check examines every arm64-v8a and x86_64 library for ELF LOAD alignment and unsafe RELRO boundaries. It does not modify binaries. The tests cover older 4 KB libraries, unsafe RELRO boundaries, linker padding, and Flutter AOT libraries without a RELRO segment.

Using [Google's bundletool](https://github.com/google/bundletool/releases), verify the bundle's packaging configuration:

```sh
java -jar bundletool-all.jar dump config --bundle=build/app/outputs/bundle/release/app-release.aab
```

`optimizations.uncompressNativeLibraries.alignment` must be `PAGE_ALIGNMENT_16K`. The ZIP offsets inside an AAB are not APK offsets. For an APK generated from that bundle, run both the Python check and Android SDK Build-Tools 35+ `zipalign`:

```sh
python tool/check_android_native.py universal.apk
zipalign -c -P 16 4 universal.apk
```

See [Android's 16 KB guide](https://developer.android.com/guide/practices/page-sizes) for device/emulator setup. Confirm `adb shell getconf PAGE_SIZE` prints `16384` before claiming 16 KB runtime coverage. Check startup, model download/inference, translation, image/video uploads, and SQLite access on that device.

## Edge-to-edge

`app/bootstrap.dart` explicitly selects `SystemUiMode.edgeToEdge`. `AppSystemUi.overlayStyle` sets icon brightness without deprecated system-bar color overrides. The gradient paints behind the system bars; the root `SafeArea(top: false)` protects route controls from bottom and side insets. App bars and screen-specific layouts retain responsibility for the top inset.

Check gesture and three-button navigation, keyboard-open forms, camera controls, landscape/cutouts where supported, and scrolling content on Android 15+. Nested `SafeArea` widgets consume the adjusted MediaQuery padding, preventing double bottom padding.

Flutter retains Android-version-guarded deprecated calls for backwards compatibility. Play Console may still flag these in Flutter's embedding even after app-owned color overrides are removed. See [Flutter issue 169810](https://github.com/flutter/flutter/issues/169810). Do not patch Flutter engine binaries or disable edge-to-edge to hide this advisory.

## Upload

Before publishing, set `pubspec.yaml` to an unused build number higher than the one already in Play. Upload the newly built, signed `app-release.aab` and inspect its results in Play Console. Existing warnings attached to **1.1.0+8** do not change when local source code changes. The compatibility validation below used **1.1.1+9**; always check the version of the artifact you actually upload.

## Validation performed for 1.1.1+9

- Signed release AAB built successfully; `jarsigner -verify` passed.
- Dart analysis: no diagnostics; changed Dart files pass formatting checks.
- All 18 arm64/x86-64 native libraries pass LOAD/RELRO checks in both the AAB and generated universal APK.
- Bundle configuration requests `PAGE_ALIGNMENT_16K`; generated APK passes SDK `zipalign -c -P 16 4`.
- Seven checker regression tests pass.
- Generated test APK installed and cold-started on the existing API 37 emulator (4 KB pages), with no fatal/native/Flutter errors in the captured startup log. It reached the application's update-required screen; authenticated flows were not tested.
- A 16 KB runtime test and Google Play's analysis of the uploaded release remain necessary. Local static checks cannot guarantee that all Play advisories disappear.
