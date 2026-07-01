package sa.com.digitalharbor.saqqar

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (NOT FlutterActivity) is REQUIRED by local_auth:
// the biometric prompt is hosted in a FragmentManager, so a plain
// FlutterActivity throws "requires FragmentActivity" at authenticate() time.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // FLAG_SECURE: blanks the app-switcher (recents) thumbnail and blocks
        // screenshots / screen-recording. The app holds the user's live Odoo
        // credentials, so this keeps a glance at recents (or an over-the-
        // shoulder screenshot) from exposing them — security without the
        // biometric lock's per-glance friction.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
    }
}
