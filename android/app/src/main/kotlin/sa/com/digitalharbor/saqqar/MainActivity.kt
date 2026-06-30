package sa.com.digitalharbor.saqqar

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (NOT FlutterActivity) is REQUIRED by local_auth:
// the biometric prompt is hosted in a FragmentManager, so a plain
// FlutterActivity throws "requires FragmentActivity" at authenticate() time.
class MainActivity : FlutterFragmentActivity()
