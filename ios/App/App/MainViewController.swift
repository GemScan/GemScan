import UIKit
import Capacitor

/// `CAPBridgeViewController` subclass that registers in-app Capacitor plugins.
///
/// Capacitor 6's plugin auto-discovery only finds classes shipped in CocoaPods
/// pods — plugins compiled directly into the App target (like ``GemmaPlugin``)
/// must be registered explicitly. The bridge isn't available until
/// `capacitorDidLoad()` fires on the host view controller, which is why this
/// subclass exists.
///
/// Wired up via `Main.storyboard` where the root view controller's custom
/// class is `MainViewController` (module `App`) instead of the default
/// `CAPBridgeViewController` from the Capacitor module.
class MainViewController: CAPBridgeViewController {

    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        bridge?.registerPluginInstance(GemmaPlugin())
    }
}
