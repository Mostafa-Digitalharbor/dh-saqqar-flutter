package sa.com.digitalharbor.saqqar

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (NOT FlutterActivity) is REQUIRED by local_auth:
// the biometric prompt is hosted in a FragmentManager, so a plain
// FlutterActivity throws "requires FragmentActivity" at authenticate() time.
//
// FLAG_SECURE was set here and has been removed on request: screenshots and
// screen recording are allowed again, and the app-switcher (recents) thumbnail
// shows the live screen instead of a blank. The optional in-app biometric lock
// (see features/security) is now the only thing standing between a picked-up
// phone and the account's Odoo data on Android.
class MainActivity : FlutterFragmentActivity()
