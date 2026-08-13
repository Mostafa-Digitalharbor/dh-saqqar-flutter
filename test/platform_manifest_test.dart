// The two native manifests, checked against what the Dart code actually does.
//
// Everything here is invisible to `flutter analyze` and to every widget test:
// a missing permission, a missing usage-description string or a missing
// declared localization compiles perfectly and fails only on a real device —
// often only on one platform, often only for users who never touch a setting.
//
// Each rule below is a bug this project either shipped or came within one
// edit of shipping.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/network/api_endpoints.dart';

/// Reads a native project file at load time.
///
/// Throws rather than `expect`ing: these run in `main`'s declaration body,
/// outside any test, where `expect` is illegal. A missing file therefore
/// fails the whole suite loudly — which is the right outcome, since it means
/// the native project no longer looks like what this file checks.
String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      '$path is missing — the native project no longer matches '
      'platform_manifest_test.',
    );
  }
  return file.readAsStringSync();
}

/// Every string under a `<key>…</key><array>…</array>` entry in a plist.
///
/// Deliberately a regex rather than a plist parser: the point is to read the
/// file that actually ships, comments and all.
///
/// Collects across **all** occurrences of the key, not just the first —
/// `CFBundleURLSchemes` appears once per URL type, so reading only the first
/// would report the share-extension scheme and miss `saqqar://` entirely.
List<String> _plistArray(String plist, String key) => [
      for (final block in RegExp(
        '<key>$key</key>\\s*<array>(.*?)</array>',
        dotAll: true,
      ).allMatches(plist))
        for (final s
            in RegExp('<string>(.*?)</string>').allMatches(block.group(1)!))
          s.group(1)!,
    ];

void main() {
  final androidManifest =
      _read('android/app/src/main/AndroidManifest.xml');
  final infoPlist = _read('ios/Runner/Info.plist');
  final releaseEntitlements = _read('ios/Runner/RunnerRelease.entitlements');

  group('iOS declares the languages the app ships', () {
    test('CFBundleLocalizations matches AppStrings.supported', () {
      // The bug this pins: iOS filters `NSLocale.preferredLanguages` down to
      // the localizations a bundle DECLARES, and Flutter reads
      // `platformDispatcher.locale` from that filtered list. With no
      // CFBundleLocalizations the OS reported English to an Arabic iPhone, so
      // every first launch on an Arabic device — the app's primary market —
      // came up in English until the user found the language switch.
      //
      // Adding a locale to `AppStrings.supported` without adding it here
      // reproduces exactly that, silently, for the new language.
      final declared = _plistArray(infoPlist, 'CFBundleLocalizations');
      final shipped =
          AppStrings.supported.map((l) => l.languageCode).toList();

      expect(
        declared..sort(),
        equals(shipped..sort()),
        reason: 'ios/Runner/Info.plist CFBundleLocalizations must list every '
            'locale in AppStrings.supported, or iOS hides that language from '
            'the app and the system-locale default silently falls back to '
            'English.',
      );
    });
  });

  group('Every permission the app uses is declared, on both platforms', () {
    // The pairs below are the runtime capabilities this app actually
    // exercises. Android needs the `<uses-permission>`; iOS needs a usage
    // string, and ships a build that CRASHES on first use without one —
    // App Review rejects for it before a user ever sees that.
    const androidPermissions = {
      'INTERNET': 'every Dio request',
      'ACCESS_NETWORK_STATE': 'connectivity_plus → OfflineBanner',
      'POST_NOTIFICATIONS': 'FCM push on Android 13+',
      'RECORD_AUDIO': 'composer mic → /transcribe/',
      'USE_BIOMETRIC': 'local_auth app lock',
    };

    for (final entry in androidPermissions.entries) {
      test('Android declares ${entry.key}', () {
        expect(
          androidManifest,
          contains('android.permission.${entry.key}'),
          reason: '${entry.key} is needed for ${entry.value}.',
        );
      });
    }

    const iosUsageStrings = {
      'NSMicrophoneUsageDescription': 'composer mic → /transcribe/',
      'NSCameraUsageDescription': 'camera attachment',
      'NSPhotoLibraryUsageDescription': 'photo attachment',
      'NSFaceIDUsageDescription': 'local_auth app lock',
    };

    for (final entry in iosUsageStrings.entries) {
      test('iOS declares ${entry.key}', () {
        final match = RegExp(
          '<key>${entry.key}</key>\\s*<string>(.*?)</string>',
          dotAll: true,
        ).firstMatch(infoPlist);

        expect(
          match,
          isNotNull,
          reason: '${entry.key} is required for ${entry.value}. Without it '
              'iOS terminates the app the first time the API is touched.',
        );
        // A present-but-empty string passes App Store validation and then
        // shows the user a blank permission prompt.
        expect(match!.group(1)!.trim().length, greaterThan(20));
      });
    }

    test('Android requests no media permission it does not use', () {
      // Photos and Files both go through the system picker (no permission
      // needed); image_picker is used only for the camera. Declaring
      // READ_MEDIA_IMAGES trips Google Play's Photo & Video Permissions
      // policy and forces a declaration this app cannot justify — so the
      // manifest strips what the plugin injects, and that strip has to stay.
      for (final name in const [
        'READ_MEDIA_IMAGES',
        'READ_MEDIA_VIDEO',
        'READ_MEDIA_AUDIO',
      ]) {
        expect(
          androidManifest,
          contains(
            '<uses-permission android:name="android.permission.$name" '
            'tools:node="remove"/>',
          ),
          reason: '$name must stay removed from the merged manifest.',
        );
      }
    });
  });

  group('The OS permission prompts are translated', () {
    // These four sentences are drawn by iOS, not by us, in a dialog that
    // appears before the user has seen a single Saqqar screen — so nothing in
    // `AppStrings` can reach them. Without an `InfoPlist.strings` per
    // language the prompt shows the Info.plist value verbatim, which means an
    // Arabic user was being asked for their microphone in English.
    //
    // This only started working at all once `CFBundleLocalizations` declared
    // Arabic (see the first group): iOS will not look for `ar.lproj` in a
    // bundle that claims not to speak Arabic.
    final usageKeys = RegExp(r'<key>(NS\w+UsageDescription)</key>')
        .allMatches(infoPlist)
        .map((m) => m.group(1)!)
        .toList();

    for (final locale in const ['en', 'ar']) {
      test('$locale translates every usage description', () {
        final strings = _read('ios/Runner/$locale.lproj/InfoPlist.strings');
        for (final key in usageKeys) {
          expect(
            strings,
            contains('"$key"'),
            reason: '$key is requested by the app but has no $locale string — '
                'iOS will fall back to the English Info.plist value.',
          );
        }
      });
    }

    test('there is at least one usage description to translate', () {
      // Guards the loop above: an Info.plist that stopped declaring usage
      // strings would make both tests pass vacuously.
      expect(usageKeys, isNotEmpty);
    });

    test('the Xcode project actually ships the .strings files', () {
      // The step everything above depends on and none of it can see.
      //
      // A `.strings` file Xcode does not reference is not in the bundle, so
      // the two tests above would pass on a build where iOS still shows the
      // English Info.plist values. This checks the four objects Xcode writes
      // for a localized resource — the two file references, the variant group
      // that pairs them, and its entry in the Runner target's Resources
      // phase — plus `ar` in `knownRegions`, without which Xcode drops the
      // Arabic variant on the next project write.
      final pbx = _read('ios/Runner.xcodeproj/project.pbxproj');

      for (final locale in const ['en', 'ar']) {
        expect(
          pbx,
          contains('path = $locale.lproj/InfoPlist.strings'),
          reason: '$locale.lproj/InfoPlist.strings has no PBXFileReference.',
        );
      }
      expect(
        RegExp(r'isa = PBXVariantGroup;[\s\S]{0,400}?name = InfoPlist\.strings')
            .hasMatch(pbx),
        isTrue,
        reason: 'the two .strings files are not paired into a variant group, '
            'so Xcode treats them as unrelated loose files.',
      );
      expect(
        pbx,
        contains('InfoPlist.strings in Resources */,'),
        reason: 'the variant group is not in a Resources build phase — the '
            'files exist in the project but never reach the bundle.',
      );
      expect(
        RegExp(r'knownRegions = \([^)]*\bar\b[^)]*\)').hasMatch(pbx),
        isTrue,
        reason: '`ar` is missing from knownRegions; Xcode will drop the '
            'Arabic variant the next time it rewrites the project.',
      );
    });
  });

  group('Push is wired for the store build, not just for debug', () {
    test('the release entitlement targets PRODUCTION APNs', () {
      // A TestFlight/App Store build carrying `development` registers against
      // the APNs sandbox while the server pushes to production: tokens are
      // rejected and notifications simply never arrive, with nothing failing
      // at build time to say so.
      expect(
        RegExp(
          r'<key>aps-environment</key>\s*<string>production</string>',
        ).hasMatch(releaseEntitlements),
        isTrue,
      );
    });

    test('iOS keeps the remote-notification background mode', () {
      expect(
        _plistArray(infoPlist, 'UIBackgroundModes'),
        contains('remote-notification'),
      );
    });
  });

  group('Deep links agree across the two platforms and the API host', () {
    final host = Uri.parse(ApiEndpoints.baseUrl).host;

    test('iOS associated domain names the API host', () {
      expect(
        _plistArray(releaseEntitlements, 'com.apple.developer.associated-domains'),
        contains('applinks:$host'),
      );
    });

    test('Android App Links name the same host', () {
      expect(androidManifest, contains('android:host="$host"'));
    });

    test('both platforms keep the legacy saqqar:// scheme', () {
      // Push notification payloads still carry custom-scheme URLs.
      expect(androidManifest, contains('android:scheme="saqqar"'));
      expect(
        _plistArray(infoPlist, 'CFBundleURLSchemes'),
        contains('saqqar'),
      );
    });

    test('the Flutter engine does not double-handle links on either side', () {
      // app_links is the single handler. With the engine's own deep-linking
      // left on, a tapped URL reaches go_router twice and a path go_router
      // has no route for (/privacy, /new) flashes an error page.
      expect(
        androidManifest,
        contains('android:name="flutter_deeplinking_enabled"'),
      );
      expect(
        RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<false/>')
            .hasMatch(infoPlist),
        isTrue,
      );
    });
  });

  group('The credential-holding posture stays put', () {
    test('Android does not back the app up', () {
      // The app holds live Odoo credentials and bearer tokens. Cloud backup /
      // adb backup / device-to-device transfer would carry them off the
      // device.
      expect(androidManifest, contains('android:allowBackup="false"'));
      expect(
        androidManifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
    });

    test('Android pins a no-cleartext network policy', () {
      expect(
        androidManifest,
        contains('android:networkSecurityConfig="@xml/network_security_config"'),
      );
      final policy = _read(
        'android/app/src/main/res/xml/network_security_config.xml',
      );
      expect(policy, contains('cleartextTrafficPermitted="false"'));
    });
  });
}
