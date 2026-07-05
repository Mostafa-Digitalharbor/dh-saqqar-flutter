import Flutter
import UIKit
import receive_sharing_intent

class SceneDelegate: FlutterSceneDelegate {
    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        var handledShareURL = false

        for context in URLContexts {
            if SwiftReceiveSharingIntentPlugin.instance.hasMatchingSchemePrefix(url: context.url) {
                _ = SwiftReceiveSharingIntentPlugin.instance.application(
                    UIApplication.shared,
                    didFinishLaunchingWithOptions: [
                        UIApplication.LaunchOptionsKey.url: context.url
                    ]
                )
                handledShareURL = SwiftReceiveSharingIntentPlugin.instance.application(
                    UIApplication.shared,
                    open: context.url,
                    options: [:]
                ) || handledShareURL
            }
        }

        if !handledShareURL {
            super.scene(scene, openURLContexts: URLContexts)
        }
    }

    override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if SwiftReceiveSharingIntentPlugin.instance.application(
            UIApplication.shared,
            continue: userActivity,
            restorationHandler: { _ in }
        ) {
            return
        }

        super.scene(scene, continue: userActivity)
    }
}
