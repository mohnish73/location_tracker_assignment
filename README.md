# Background Location Tracker (Flutter + Kotlin)

An Android app that records the device location in a **Kotlin foreground service** using
`FusedLocationProviderClient`, stores every fix in **SQLite through native Kotlin code**, and
shows it live in a **Flutter UI built with GetX**. Flutter talks to Android only through one
MethodChannel (commands) and one EventChannel (live stream).

No Flutter plugins are used for location, background work or storage. The only added package is `get`.

## Submission details

| | |
|---|---|
| Start time | _fill in_ |
| End time | _fill in_ |
| Test device | _fill in (model)_, Android _fill in_ |
| APK | _Google Drive link_ |
| Screen recording | _link_ |

## Versions

| Tool | Version |
|---|---|
| Flutter | 3.41.6 (stable) |
| Dart | 3.11.4 (null safety) |
| Kotlin | 2.2.20 |
| Android Gradle Plugin | 8.11.1 |
| Gradle | 8.14 |
| JDK | 17 |
| GetX (`get`) | 4.7.3 |
| play-services-location | 21.3.0 |
| minSdk / targetSdk | 24 / 35 |

## Setup

```bash
flutter pub get
flutter run                      # debug on a connected device
flutter test                     # unit tests
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
```

**Release signing:** `android/key.properties` and `android/app/upload-keystore.jks` are git-ignored.
To sign with your own key, create both:

```properties
# android/key.properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=upload-keystore.jks
```

Without `key.properties` the release build falls back to the debug key. The repository contains no secrets or API keys.

## Architecture

Data flows one way:

```
FusedLocationProviderClient
        │  (LocationCallback on a background HandlerThread)
        ▼
LocationService (foreground, type=location)
        ├─► LocationDao.insert()          → SQLite (locations table)
        ├─► TrackingNotification.update() → lat / lng / time on every fix
        └─► LocationStreamHandler.emit()  → EventChannel (dropped safely if Flutter isn't running)
                                                  ▼
                                   TrackerChannel.events (Dart Stream)
                                                  ▼
                              TrackingController (Rx state) → Obx widgets
```

Flutter only **reads** (via MethodChannel → `LocationDao`) and **sends commands**. It never opens the database.

### Android (Kotlin): `android/app/src/main/kotlin/com/example/assignmentproject/`

| File | Responsibility |
|---|---|
| `MainActivity.kt` | Registers the MethodChannel + EventChannel; forwards permission results; detaches the stream when the engine is destroyed |
| `service/LocationService.kt` | Foreground service, `FusedLocationProviderClient`, `PRIORITY_HIGH_ACCURACY`, `START_STICKY`, restarts itself from the persisted flag after a kill |
| `service/TrackingNotification.kt` | Notification channel + persistent notification (latitude, longitude, accuracy, time, "Stop tracking" action) |
| `data/LocationDbHelper.kt` | `SQLiteOpenHelper`, schema version, WAL, `onUpgrade` migration hook |
| `data/LocationDao.kt` | Database controller: insert / latest / history / count / clear |
| `data/TrackingPrefs.kt` | SharedPreferences: tracking ON flag, interval, permission-asked flags |
| `data/CsvExporter.kt` | CSV export shared through `FileProvider` |
| `bridge/ChannelContract.kt` | Channel names, method names, error codes |
| `bridge/TrackerMethodHandler.kt` | MethodChannel handler. DB work runs on a background executor and replies on the main thread |
| `bridge/LocationStreamHandler.kt` | EventChannel handler. Posts to the main thread and is a no-op without a listener |
| `receiver/BootReceiver.kt` | Restarts tracking after reboot / app update if it was ON |
| `util/PermissionUtils.kt` | Permission, GPS-switch and battery-optimisation checks |

### Flutter (GetX): `lib/app/`

| Path | Responsibility |
|---|---|
| `data/tracker_channel.dart` | The only class that touches the channels; every call returns `ChannelResult<T>` |
| `data/channel_result.dart` | `ChannelSuccess` / `ChannelFailure(NativeError code, message, details)` |
| `data/models/` | `LocationRecord`, `TrackingStatus`, `PermissionSnapshot`, `TrackerEvent` |
| `controllers/tracking_controller.dart` | Status, last location, live stream, start/stop, interval, catch-up on resume |
| `controllers/permission_controller.dart` | Fine → background → notification flow, Settings fallbacks, GPS-off prompt |
| `controllers/history_controller.dart` | Last 50 records, live prepend, clear (with confirmation), CSV export |
| `bindings/` | `InitialBinding` (`Get.put` permanent channel), `HomeBinding` / `HistoryBinding` (`Get.lazyPut`) |
| `routes/` | `GetPage` routes `/` and `/history` |
| `ui/` | `GetView` + `Obx` widgets only. No `setState` |

## Database schema (version 1)

```sql
CREATE TABLE locations (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    latitude  REAL    NOT NULL,
    longitude REAL    NOT NULL,
    accuracy  REAL    NOT NULL,   -- metres
    timestamp INTEGER NOT NULL    -- epoch ms
);
CREATE INDEX idx_locations_timestamp ON locations(timestamp DESC);
```

**Concurrency:** one process-wide `SQLiteOpenHelper` instance (one connection pool) is shared by the service
and the MethodChannel handler, so SQLite serialises writes. WAL lets reads run while the service writes.

**Migrations:** bump `DB_VERSION` and add an `if (oldVersion < N)` step in `onUpgrade` (e.g. `ALTER TABLE … ADD COLUMN`), so existing rows are kept.

## Channel contract

**MethodChannel** `com.example.assignmentproject/tracker`

| Method | Arguments | Success result |
|---|---|---|
| `startTracking` | – | `{isRunning, trackingEnabled, intervalMs}` |
| `stopTracking` | – | `{isRunning, trackingEnabled, intervalMs}` |
| `getTrackingStatus` | – | `{isRunning, trackingEnabled, intervalMs}` |
| `setTrackingInterval` | `{intervalMs: int}` (5 000 – 3 600 000) | `{isRunning, trackingEnabled, intervalMs}` |
| `getLastLocation` | – | `{id, latitude, longitude, accuracy, timestamp}` or `null` |
| `getHistory` | `{limit: int}` (default 50, max 500) | `List<{id, latitude, longitude, accuracy, timestamp}>`, newest first |
| `getRecordCount` | – | `int` |
| `clearHistory` | – | `int` (deleted rows) |
| `exportCsv` | – | `{rows, path}` (also opens the share sheet) |
| `getPermissionStatus` | – | `{location, backgroundLocation, notification, locationServicesEnabled, ignoringBatteryOptimizations, sdkInt}` |
| `requestLocationPermission` | – | permission map (above) |
| `requestBackgroundLocationPermission` | – | permission map |
| `requestNotificationPermission` | – | permission map |
| `requestIgnoreBatteryOptimizations` | – | `bool` |
| `openAppSettings` | – | `bool` |
| `openLocationSettings` | – | `bool` |

Permission values: `granted` · `denied` · `permanentlyDenied` · `notRequired`.

**Errors**: `PlatformException(code, message)` with code in
`PERMISSION_DENIED`, `LOCATION_DISABLED`, `INVALID_ARGUMENT`, `DATABASE_ERROR`, `SERVICE_ERROR`,
`EXPORT_FAILED`, `REQUEST_IN_PROGRESS`, `SETTINGS_UNAVAILABLE`, `UNEXPECTED`.
Dart converts these (plus `NOT_IMPLEMENTED` and `INVALID_RESPONSE`) into `ChannelFailure` and shows them in a GetX snackbar.

**EventChannel** `com.example.assignmentproject/location_stream`. Each event is a map with `type`:

| `type` | Fields |
|---|---|
| `location` | `id, latitude, longitude, accuracy, timestamp` (already saved in SQLite) |
| `status` | `isRunning` (also fired when stopped from the notification) |
| `locationServices` | `enabled` (device location switch changed) |

## Background reliability

- Foreground service with `foregroundServiceType="location"` and `FOREGROUND_SERVICE_LOCATION`, started via `startForegroundService` / `ServiceCompat.startForeground`.
- `stopWithTask="false"`: swiping the app from recents doesn't stop the service.
- `START_STICKY` + the tracking flag persisted in SharedPreferences: if the system kills the process, it recreates the service with a `null` intent and tracking resumes.
- The service never depends on the Flutter engine. When the engine is gone, `LocationStreamHandler` has no sink and silently drops events. Data is already in SQLite.
- When the UI reopens or resumes, it reads the last fix and status from SQLite/Kotlin. If tracking was ON but an OEM killed the service, the UI restarts it.
- The app can request an exemption from battery optimisation, which aggressive OEM skins (MIUI, ColorOS) need. On those devices, "Autostart" may also need to be enabled manually.
- Note: **Force stop** from system Settings stops everything until the user opens the app again. Android enforces this for all apps.

## Permission flow

1. `ACCESS_FINE_LOCATION` (+ coarse) on the first Start tap.
2. `POST_NOTIFICATIONS` on Android 13+.
3. `ACCESS_BACKGROUND_LOCATION` as a **separate** step after an explanation dialog (Android 10+; on 11+ the system opens the "Allow all the time" settings page).
4. Denied → snackbar with **Open Settings**. Permanently denied → the setup card shows an **Open Settings** button. Nothing crashes. Tracking still works while the service is alive if background location is denied.

## Status

### Done: core
- [x] GetX controllers, bindings, routes, reactive `Obx` UI (no `setState`)
- [x] Own MethodChannel + EventChannel in Kotlin
- [x] Kotlin foreground service (type location) that survives minimise / swipe / process kill
- [x] Every fix stored in SQLite even when Flutter is not running
- [x] Last stored location shown on launch
- [x] Live updates through the EventChannel while in the foreground (stored at the same time)
- [x] `FusedLocationProviderClient` used directly
- [x] Native `SQLiteOpenHelper` + DAO with schema versioning

### Done: additional
- [x] Runtime permissions: fine → background (separate) → notifications, with Settings fallback
- [x] Start / Stop buttons, Running / Stopped status that stays correct after reopening
- [x] Notification with latest latitude, longitude and time, updated on every fix
- [x] Schema: id, latitude, longitude, accuracy, timestamp (epoch ms)
- [x] History: last 50 records, newest first, from Kotlin
- [x] Structured errors → GetX snackbar

### Done: bonus
- [x] Restart after reboot (`BOOT_COMPLETED`, also after app update) if tracking was ON
- [x] Configurable interval (10 s / 30 s / 1 min / 5 min) saved natively, applied to the running service
- [x] GPS-off detection (on start and live while tracking) with a prompt to open location settings
- [x] Clear history with confirmation dialog **and** export to CSV (share sheet)
- [x] Unit tests for `TrackingController` and the channel error mapping (`flutter test`)

### Pending / possible improvements
- Kotlin DAO instrumentation test (needs a device/emulator or Robolectric)
- Optional OEM-specific "Autostart" deep links for MIUI / ColorOS
