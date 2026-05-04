---

**Context:** This is a Flutter mobile app. A production-readiness audit has already been run. The HTTP/TLS issue is intentionally deferred. Fix all remaining critical, high, medium, and low issues below.

---

### 🔴 Critical — Fix First

**1. Fix syntax error (app cannot build)**
- File: `lib/features/task_execution/presentation/pages/tasks_page.dart:89`
- Fix the syntax error so `flutter analyze` passes with zero errors.

**2. Android release keystore**
- File: `android/app/build.gradle:53`
- Replace the debug keystore with a proper release keystore.
- Add `key.properties` to `.gitignore`.
- Wire `signingConfigs.release` using `key.properties` values for `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
- Show the complete updated `build.gradle` signingConfigs and buildTypes block.

---

### 🟠 High — Fix After Critical

**3. Secure token & credential storage**
- File: `lib/core/session/session_manager.dart:48`
- Replace all `SharedPreferences` usage for auth token, refresh token, user identifiers, and permissions with `flutter_secure_storage`.
- Show the complete rewritten `SessionManager` class.

**4. Secure device signing key storage**
- File: `lib/core/security/device_signing_service.dart:13`
- Move the device signing private key from `SharedPreferences` to `flutter_secure_storage`.
- Show the complete rewritten `DeviceSigningService` class.

**5. Global crash handler**
- File: `lib/main.dart:12`
- Wrap `main()` with `runZonedGuarded`.
- Add `FlutterError.onError` handler.
- Add `PlatformDispatcher.instance.onError` handler.
- Integrate with a crash reporter (use `FirebaseCrashlytics` as default, or make it pluggable).
- Show the complete updated `main.dart`.

**6. Fix notification error handling**
- File: `lib/features/notifications/data/datasources/remote_notifications_datasource.dart:17`
- Do not silently return empty list on failure.
- Throw a proper `Failure` or rethrow the exception so the UI can show an error state.
- Show the complete rewritten datasource method.

**7. Fix error handling in work-order repository**
- File: `lib/features/work_order/data/repositories/work_order_repository_impl.dart:18`
- Stop collapsing all exceptions into `ClientFailure(..., 400)`.
- Distinguish between: network/timeout errors, HTTP 4xx client errors, HTTP 5xx server errors, and unknown errors.
- Map each to the correct `Failure` subtype.
- Show the complete rewritten repository error handling block.

**8. Activate environment-based config**
- Files: `lib/core/config/app_config.dart:15`, `lib/core/network/api_endpoints.dart:5`
- Make `ApiEndpoints` consume `AppConfig` instead of hardcoded host/IP.
- Ensure `--dart-define=BASE_URL=...` actually drives the runtime endpoint.
- Show the complete updated `AppConfig` and `ApiEndpoints`.

---

### 🟡 Medium — Fix Next

**9. Add request cancellation**
- File: `lib/core/network/api_client.dart`
- Add `CancelToken` support to all `ApiClient` methods (GET, POST, PUT, DELETE).
- Show how to wire `CancelToken` in a feature datasource and dispose it on screen close.

**10. Add retry/backoff for feature APIs**
- File: `lib/core/network/api_client.dart:120`
- Add a retry interceptor with exponential backoff for transient failures (timeout, 503).
- Exclude 4xx errors from retry.
- Show the complete interceptor implementation.

**11. Fix force-update CTA**
- File: `lib/features/auth/presentation/pages/splash_page.dart:349`
- Replace the retry-device-init action with a proper store redirect.
- Use `url_launcher` to open Play Store / App Store URL.
- Show the updated force-update UI block.

**12. Fix N+1 monitoring requests**
- File: `lib/features/monitoring/data/datasources/remote_monitoring_datasource.dart:17`
- Replace sequential per-unit/per-division calls with a single batched API call or parallel `Future.wait()`.
- Show the complete rewritten datasource method.

**13. Add image caching**
- Files: `warehouse_request_page.dart:851`, `view_task_card.dart:299`
- Replace `Image.network` with `CachedNetworkImage` (use `cached_network_image` package).
- Add appropriate `memCacheWidth`/`memCacheHeight` resize hints.
- Show the updated widget code for both files.

**14. Fix wakelock usage**
- File: `lib/main.dart:20`
- Remove global wakelock at startup.
- Enable wakelock only on specific screens/workflows that require it (e.g., active task execution screen).
- Show the updated `main.dart` and an example screen using scoped wakelock.

**15. Fix largeHeap**
- File: `android/app/src/main/AndroidManifest.xml:15`
- Remove `android:largeHeap="true"`.
- Identify likely memory pressure sources (image caching, large lists) and address them properly instead.

**16. Improve input validation**
- File: `lib/features/auth/presentation/pages/login_page.dart:52`
- Add proper client-side validation: email format, password minimum length, sanitize whitespace.
- Show the complete updated validation logic.

---

### 🟢 Low — Clean Up

**17. Fix all analyzer warnings**
- Run `flutter analyze` and fix all unused imports, dead fields, dead methods, and deprecated API usage.
- Target: zero warnings, zero hints.

**18. Remove debugPrint from production code**
- File: `lib/core/services/fcm_service.dart:90` and all other occurrences.
- Replace `debugPrint` with a proper logger (use `logger` package or a custom `AppLogger` wrapper).
- In release builds, logger should be a no-op or write to crash reporter only.
- Show the `AppLogger` implementation.

**19. Restrict Firebase API key**
- File: `android/app/google-services.json`
- Go to Firebase Console → Project Settings → API restrictions.
- Restrict the Web API key to Android app package name + SHA-1.
- Add `google-services.json` to `.gitignore` and use CI secret injection instead.

**20. Fix AppConfig/dart-define drift**
- File: `lib/core/config/app_config.dart:1`
- Ensure `--dart-define` variables are consistently documented and consumed.
- Remove any dead config keys.
- Show the final clean `AppConfig`.

---

**Output format for each fix:**
- Brief explanation of why it is a problem
- Complete corrected code (no truncation)
- Any new dependencies to add to `pubspec.yaml`
- Any follow-up steps (e.g., run `flutter pub get`, add to `.gitignore`, Firebase console steps)

---