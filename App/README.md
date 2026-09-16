# AGRHI Flutter app

Smart farming app with offline storage, synchronization, community posts and on-device disease detection.

## Code structure

```text
lib/
  main.dart                     Entry point
  app/
    bootstrap.dart              Platform, storage and notification initialization
    app.dart                    Root widget, providers and app theme
  models/                       Data objects, API results and state enums
  views/
    auth/                       Authentication screens
    features/                   Screens grouped by feature
    components/                 Reusable UI components
    shared/                     Shared widgets and startup screens
  controllers/                  Application state and user-action coordination
  services/                     API, authentication, downloads and platform integrations
    ml/                         Inference workers, preprocessing and model validation
  data/database/                SQLite access and migrations
  core/utils/                   Routes, colors, validation and shared utilities
```

## MVC conventions

- **Models** describe data independently of widgets: chat sessions/messages, feedback, subsidies, API/auth results, downloadable model metadata and upload tasks.
- **Views** render widgets and own UI lifecycle state such as text fields, animations, tabs, focus, dialogs and navigation.
- **Controllers** coordinate actions and observable application state. `LanguageController`, `ConnectivityController`, `ModelManagerController` and `PostUploadController` use the existing `ChangeNotifier`/Provider mechanism. `FeedbackController` handles feedback submission, history parsing and session refresh without a `BuildContext`.
- **Services** perform reusable infrastructure work. Model downloads belong in `services/model_download_service.dart`; ML inference belongs in `services/ml/`, distinct from MVC data models.

The root app registers language and model-management controllers with `ChangeNotifierProvider(create: ...)`. The connectivity controller retains its singleton and uses `ChangeNotifierProvider.value`; post uploads also retain their singleton lifetime. Screens must not dispose shared singleton controllers.

For a new feature, add its data classes under `models/`, put API/storage work in a service, coordinate its workflows in a controller, and build its screens under `views/features/`. Import application libraries using `package:agrhi/...` so moving a screen does not require recalculating relative paths.

Example flow:

```text
FeedbackScreen -> FeedbackController -> ApiService / AuthService / StorageHelper
                       |
                       +-> FeedbackItem -> FeedbackScreen
```

This reorganization preserves existing feature implementations. Some older screens still call services directly and retain workflow state; move those workflows into feature controllers when refactoring them. UI-only configuration objects and presentation helpers can remain alongside their widgets.

## Development

From this directory:

```sh
flutter pub get
flutter analyze --no-pub
flutter run
```

Before publishing Android releases, follow [the native alignment and edge-to-edge checks](docs/android-release-checks.md).

For recovery screens, quiet background failures, and safe user messages, see [error handling](docs/error-handling.md).

After moving Dart libraries or changing Provider types, stop and restart the app rather than relying on hot reload. The entry point remains `lib/main.dart`; assets, API endpoints, database schemas and native project paths are unchanged by the MVC reorganization.
