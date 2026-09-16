# Error handling and recovery

## What users see

| Failure | Behavior |
| --- | --- |
| Local database cannot open | Startup retry screen; the main app does not start with unusable storage. |
| Secure session cannot be read during routing | Retry screen; a storage exception is not treated as logout. |
| Widget build or non-silent rendering error | Recovery screen with an explicit **Reopen app** action. Saved data stays on disk; unsaved screen state may be lost. |
| Model library cannot load | Retry screen within the model library; its loading indicator always clears. |
| Download, delete, camera, or form action fails | A safe message in the existing screen. Successful downloads are not reported as failed if their notification or size refresh fails. |
| Optional cache, notification, or connectivity initialization fails | Quiet diagnostic reporting; unrelated UI continues. |
| Unhandled asynchronous Dart error | Last-resort reporting without terminating the app. The originating operation still needs its own local recovery when it controls a spinner or form. |

`AppFailure` owns user-safe messages. Do not put exception strings, server response bodies, tokens, or filesystem paths in UI messages. Known validation failures should construct an `AppFailure` with explicit user-facing copy rather than throwing a raw string.

## Startup and background work

`bootstrap.dart` installs handlers before rendering or initializing application services. Flutter's binding and `runApp` stay in the same zone. `StartupGate` prevents duplicate retries while initialization is active.

Database opening/migrations are shared across concurrent callers. Startup waits up to 20 seconds; a retry attaches to the same pending open instead of starting another migration. No recovery path deletes or resets the database.

Optional system UI, translation-cache and notification setup run concurrently with 10-second waiting limits. Their initialization future is reused during UI recovery. A timeout ends the wait, not the underlying platform operation. Late results cannot navigate the user to another screen.

Use `ErrorReporter.background` only for optional work. Do not use it to hide a failed save, purchase, account change, deletion or other user action. Handle those errors locally and always restore busy state in `finally`.

## Diagnostics and efficiency

- Release mode disables existing `debugPrint` diagnostics; legacy Dart `print` calls in storage/authentication/database code now use that logger.
- `ErrorReporter` records only operation and exception type in release mode. Debug mode retains error and stack details. Repeated reports are limited to one per operation/type per 30 seconds, with at most 64 tracked keys.
- There is no remote crash-reporting service configured. Native/plugin logs are outside the Dart logger's control.
- API request deadlines include headers and response-body reads; the HTTP client closes on completion or timeout to release request resources. Mutations are not blindly retried on network errors.
- Concurrent model-library refreshes share one disk scan. The total for initial loading is calculated from that scan, and progress notifications are limited to meaningful percentage changes.

## Verification

Run `flutter test --no-pub` and `flutter analyze --no-pub` from `App/`. Tests inject startup failures, a widget build failure, file errors, cancellation, repeated refreshes, and disposal while work is pending. They also check that public messages exclude private error content.

These safeguards handle recoverable Dart/framework failures. Native crashes, exhausted device memory, forced OS termination and every third-party SDK failure cannot be caught by Dart handlers. Device testing of camera, inference, upload, offline sync and low-storage conditions remains necessary before release. See [Flutter's error-handling guide](https://docs.flutter.dev/testing/errors).
