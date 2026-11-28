import Flutter
import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    #if canImport(GoogleSignIn)
    let unhandledContexts = URLContexts.filter { !GIDSignIn.sharedInstance.handle($0.url) }
    if unhandledContexts.isEmpty {
      return
    }
    super.scene(scene, openURLContexts: unhandledContexts)
    #else
    super.scene(scene, openURLContexts: URLContexts)
    #endif
  }
}
