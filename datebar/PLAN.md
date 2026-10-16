# DateBar: the current date in the Android status bar

Plan for a small Android app that keeps today's date visible in the status
bar next to the clock, correct at all times, on this phone and on future
phones and Android versions with as few changes as possible.

## 1. The one hard constraint, and the design it forces

The status bar is drawn by the system process (SystemUI). A normal app cannot
edit the clock text or place a view inside the status bar. The ways to get a
date there are:

| Approach | Works without root | Survives OS updates | Verdict |
| --- | --- | --- | --- |
| Built-in option of the phone maker (Samsung Good Lock "QuickStar", Xiaomi, OnePlus...) | yes | yes, maintained by the maker | Check first. On Samsung it puts the date literally next to the clock. |
| Ongoing notification whose small icon is a bitmap of the date | yes | yes, this mechanism has been stable since Android 5 | **The plan.** |
| Overlay window drawn on top of the status bar | yes, with "draw over other apps" | no, breaks with cutouts, One UI changes, lock screen | Rejected. |
| Root or Xposed module editing SystemUI | no | no, breaks on every update | Rejected. |

The notification approach: the app keeps one silent, ongoing notification
whose small icon is generated at runtime and contains the day of month
(optionally also the weekday). Notification icons sit immediately to the right
of the clock on Pixel and Samsung One UI phones, which both put the clock on
the left. The icon is monochrome and about 24 dp, so two digits are legible,
a full date is not. The same mechanism is what the "Date in Status Bar" apps on
Google Play use. Reviews of those apps complain that the icon disappears after
updates or at midnight. That is exactly what Section 3 is designed to prevent.

## 2. Architecture

Everything funnels through one idempotent function, `refresh()`:

1. read the current instant from the system clock;
2. read the time zone and locale **at that moment**, never cached;
3. compute today's local date;
4. render the icon bitmap for that date;
5. post (or re-post) the notification;
6. compute the next local midnight and schedule one alarm for it;
7. write "last refresh, next refresh" to the settings store for display.

Because every trigger simply calls `refresh()`, a missed trigger is harmless:
the next one repairs the display. The triggers:

| Component | Registered where | Fires on |
| --- | --- | --- |
| `BootReceiver` | manifest | `BOOT_COMPLETED`, `LOCKED_BOOT_COMPLETED` |
| `TimeReceiver` | manifest (exempt from the implicit-broadcast ban) | `TIME_SET`, `TIMEZONE_CHANGED`, `LOCALE_CHANGED` |
| `PackageReceiver` | manifest | `MY_PACKAGE_REPLACED` (after an app update) |
| `MidnightAlarmReceiver` | manifest, explicit intent from AlarmManager | the alarm set for next midnight |
| `DateService` (foreground service) | started by all of the above and by the app | registers at runtime for `TIME_TICK` (every minute), `DATE_CHANGED`, `SCREEN_ON`, `USER_PRESENT`; owns the notification |
| `NotificationDismissReceiver` | manifest, explicit `deleteIntent` | user swiped the notification away (possible since Android 14) |

`DATE_CHANGED` and `TIME_TICK` cannot be received from the manifest, which is
why a long-lived service exists at all. The service's mandatory notification
is the date notification itself, so the service costs nothing extra.

Packages:

```
app/src/main/java/.../datebar/
  DateBarApp.kt             application class, notification channel
  core/TodayProvider.kt     instant + zone + locale -> LocalDate, next midnight
  core/DateIconRenderer.kt  LocalDate -> Icon (bitmap, white on transparent)
  core/DateNotification.kt  builds and posts the ongoing notification
  core/MidnightScheduler.kt AlarmManager wrapper, exact if permitted
  core/Refresher.kt         refresh(), the single entry point
  service/DateService.kt    foreground service, runtime receivers
  receivers/*.kt            the manifest receivers listed above
  ui/MainActivity.kt        Compose settings screen
  ui/Permissions.kt         notification, exact alarm, battery exemption flows
  settings/Settings.kt      DataStore: enabled, what to show, last/next refresh
```

## 3. Event matrix

| Situation | What catches it | What refresh() does |
| --- | --- | --- |
| Midnight | alarm set for the exact instant of next local midnight; `DATE_CHANGED` and `TIME_TICK` in the service as backups | new icon, new alarm for the following midnight |
| Daylight saving change | next midnight is computed from zone rules (`LocalDate.plusDays(1).atStartOfDay(zone)`), so a 23 or 25 hour day is handled; the alarm is set on an instant, not a delay | the date switches at the real local midnight |
| Time zone change (travel, airplane, manual) | `TIMEZONE_CHANGED` | recompute with the new zone; the midnight alarm is cancelled and set again |
| Time set manually or by network sync | `TIME_SET` | same |
| Phone reboot | `LOCKED_BOOT_COMPLETED` (service is directBootAware, so the icon appears before the first unlock) and `BOOT_COMPLETED` | start service, refresh |
| App updated | `MY_PACKAGE_REPLACED` | start service, refresh |
| Locale change (digits, weekday names) | `LOCALE_CHANGED` | re-render icon |
| Process killed by the system | the notification itself survives in the notification manager; the next alarm or broadcast restarts the service | refresh |
| Doze / deep sleep | alarm uses `setExactAndAllowWhileIdle` (or `setAlarmClock`); `SCREEN_ON` triggers a refresh the moment the screen lights up, so a late alarm is invisible to the user | refresh |
| User swipes the notification away (Android 14+) | `deleteIntent` | re-post immediately; the app's own switch is the way to turn it off |
| Too many icons on Samsung | Samsung hides notification icons beyond 3 by default | user sets "Show all notification icons" in Samsung notification settings; the app's setup screen explains it |
| User force-stops the app | nothing: Android blocks every receiver of a force-stopped app until it is opened again | documented limitation, same for every app |

## 4. Permissions and manifest

| Permission | Why | How obtained |
| --- | --- | --- |
| `POST_NOTIFICATIONS` | required on Android 13+ to show any notification | runtime prompt on first launch |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE` | the long-lived service; Android 14 requires a declared type, and `specialUse` is the honest one for "status bar indicator" | manifest; the `<service>` carries a `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` property explaining the use |
| `RECEIVE_BOOT_COMPLETED` | restart after reboot | manifest |
| `SCHEDULE_EXACT_ALARM` | exact midnight alarm; denied by default on Android 14+ for new installs | settings screen offers the system page to grant it; without it the app falls back to a windowed alarm and the minute-tick, so the switch is still at most a minute late while the screen is on |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | keeps aggressive makers (Samsung, Xiaomi) from killing the service; also allows restarting the service from the background | settings screen offers the system dialog; optional |

Service declaration (sketch):

```xml
<service
    android:name=".service.DateService"
    android:exported="false"
    android:directBootAware="true"
    android:foregroundServiceType="specialUse">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="Keeps a date indicator in the status bar" />
</service>
```

Build settings: `minSdk 26` (Android 8, the first with notification channels
and `java.time`), `targetSdk` always the latest stable API at build time,
Kotlin, Jetpack Compose for the one settings screen, no third-party
libraries beyond AndroidX.

## 5. Core computations

Today's date and next midnight, nothing cached:

```kotlin
object TodayProvider {
    fun now(clock: Clock = Clock.systemDefaultZone()): ZonedDateTime =
        ZonedDateTime.now(clock)            // zone read from the system each call

    fun nextMidnight(now: ZonedDateTime): Instant =
        now.toLocalDate().plusDays(1)
           .atStartOfDay(now.zone)          // DST gaps and overlaps resolved by zone rules
           .toInstant()
}
```

Icon rendering: a square bitmap, say 96 x 96 px, transparent background,
white text drawn with a bold sans-serif at a size that fills the square for
two digits. The system tints status bar icons, so white on transparent gives
a correct dark or light icon automatically. Digits come from
`NumberFormat` for the current locale so a Hebrew or Arabic locale shows
what the user expects. Optional second notification with the three-letter
weekday, same renderer. The bitmap is handed to
`Icon.createWithBitmap` and `Notification.Builder.setSmallIcon(icon)`.

Notification: channel importance `LOW` (an icon in the status bar, no sound;
`MIN` would hide the icon), `setOngoing(true)`, `setSilent(true)`,
`setShowWhen(false)`, `setVisibility(VISIBILITY_PUBLIC)` so it shows on the
lock screen, content text "Friday, 16 October 2026" for the shade, tapping
opens the settings screen, `deleteIntent` to the dismiss receiver.

Scheduling:

```kotlin
fun schedule(at: Instant) {
    val pi = PendingIntent.getBroadcast(ctx, 0, Intent(ctx, MidnightAlarmReceiver::class.java),
        FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT)
    am.cancel(pi)
    if (am.canScheduleExactAlarms())
        am.setExactAndAllowWhileIdle(RTC_WAKEUP, at.toEpochMilli(), pi)
    else
        am.setWindow(RTC_WAKEUP, at.toEpochMilli(), 10 * 60_000L, pi)
}
```

`RTC_WAKEUP` alarms are on wall-clock time, so a time or zone change is
followed by a re-schedule from the receivers above.

## 6. Rules that keep the app generic

1. Public SDK APIs only, nothing from OEM SDKs, no reflection into SystemUI,
   no overlay windows, no root.
2. Target the latest stable Android on every build and read its behaviour
   changes page; the only parts that have changed in recent years are
   foreground service rules, exact alarm rules and notification permission,
   and each has a fallback in this design.
3. Every runtime permission is optional with a degraded mode, so a future
   restriction cannot make the app useless, only less precise.
4. One source of truth, `refresh()`, and many redundant triggers, so a
   future OS that drops one trigger still works through the others.
5. No cached zone, locale, or date anywhere.
6. Unit tests of `TodayProvider` with fixed clocks around DST transitions in
   Asia/Jerusalem, Europe/London and America/New_York, and around year end.

## 7. Settings screen

One scrollable screen:

- master switch "Show the date in the status bar";
- what to show: day of month only (default), day plus weekday icon;
- live preview of the icon at status bar size;
- three setup rows with a status mark and a button: notifications allowed,
  exact alarms allowed, battery optimisation disabled; on Samsung, a text
  pointing to "Show all notification icons";
- diagnostics: last refresh time, next scheduled refresh, current zone.

## 8. Test plan on the phone

| Test | How | Expected |
| --- | --- | --- |
| Midnight | Settings, turn off automatic time, set 23:59, wait | icon changes within a minute while the screen is on; exact at 00:00 when exact alarms are allowed |
| DST | set a zone and a date just before a transition, repeat the midnight test | switch at the local midnight of that zone |
| Zone change | change the time zone manually; also toggle airplane mode on a trip | icon shows the new local date immediately |
| Time set by network | re-enable automatic time after a manual change | refresh fires |
| Reboot | restart the phone, look before unlocking | icon present on the lock screen before first unlock |
| Update | `adb install -r app.apk` | icon present after install without opening the app |
| Process kill | Developer options, "Don't keep activities" is irrelevant; use `adb shell am kill <package>` | notification stays, service returns at next trigger |
| Doze | `adb shell dumpsys deviceidle force-idle`, then wake the screen | correct date on wake |
| Dismissal | swipe the notification away in the shade (Android 14+) | it returns at once |
| Force stop | Settings, Apps, Force stop | icon gone until the app is opened; documented |
| Icon limit | Samsung: post 4 other notifications | icon hidden unless "Show all notification icons" is on |

Unit tests run on the Linux server with Gradle; the device tests need the
phone over USB or Wireless debugging as set up earlier.

## 9. Milestones

1. Project skeleton, channel, renderer, notification, a "Refresh now" button.
   Visible result on the phone in the first session.
2. `TodayProvider` with unit tests, midnight scheduler, manifest receivers.
3. Foreground service with runtime receivers, boot and update handling,
   dismiss handling.
4. Settings screen with permission flows and diagnostics, Samsung note.
5. Device test pass through the table above, then a signed release build
   installed over ADB.

## 10. Decisions for you

- Which phone model and Android version? If it is a Samsung, Good Lock's
  QuickStar "Show Date" toggle may already give you the date next to the
  clock with no app at all, and the app becomes a fallback.
- Day of month only, or also a weekday icon?
- Should the app also offer a "pause until tomorrow" action on the
  notification, or is the master switch enough?
