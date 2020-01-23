import UIKit
import MBProgressHUD
import SafariServices
import AuthenticationServices

@objc public protocol LinkBrokerUIFlow {
    func pushLinkBrokerFlow(
        onNavigationController navController: UINavigationController,
        asRootViewController: Bool,
        showWelcomeScreen: Bool,
        showOpenAccountButton: Bool,
        oAuthCallbackUrl: URL
    )

    func presentLinkBrokerFlow(
        fromViewController viewController: UIViewController,
        showWelcomeScreen: Bool,
        showOpenAccountButton: Bool,
        oAuthCallbackUrl: URL
    )

    func presentRelinkBrokerFlow(
        inViewController viewController: UIViewController,
        linkedBroker: TradeItLinkedBroker,
        oAuthCallbackUrl: URL
    )

    // @optional func setOnLinkedCallback()
}

class TradeItLinkBrokerUIFlow: NSObject, TradeItWelcomeViewControllerDelegate, LinkBrokerUIFlow {
    let viewControllerProvider: TradeItViewControllerProvider = TradeItViewControllerProvider()
    var onFlowAbortedCallback: ((UINavigationController) -> Void)?
    private var _alertManager: TradeItAlertManager?
    private var alertManager: TradeItAlertManager {
        get { // Need this to avoid infinite constructor loop
            self._alertManager ??= TradeItAlertManager()
            return self._alertManager!
        }
    }

    var oAuthCallbackUrl: URL?
    var showOpenAccountButton: Bool = true

    private var webAuthSession: ASWebAuthenticationSession? = nil

    override internal init() {
        super.init()
    }

    func pushLinkBrokerFlow(
        onNavigationController navController: UINavigationController,
        asRootViewController: Bool,
        showWelcomeScreen: Bool,
        showOpenAccountButton: Bool = true,
        oAuthCallbackUrl: URL
    ) {
        self.oAuthCallbackUrl = oAuthCallbackUrl
        self.showOpenAccountButton = showOpenAccountButton
        
        let initialViewController = self.getInitialViewController(showWelcomeScreen: showWelcomeScreen)

        if (asRootViewController) {
            navController.setViewControllers([initialViewController], animated: true)
        } else {
            navController.pushViewController(initialViewController, animated: true)
        }
    }

    func presentLinkBrokerFlow(
        fromViewController viewController: UIViewController,
        showWelcomeScreen: Bool,
        showOpenAccountButton: Bool = true,
        oAuthCallbackUrl: URL
    ) {
        self.oAuthCallbackUrl = oAuthCallbackUrl
        self.showOpenAccountButton = showOpenAccountButton
        
        let initialViewController = self.getInitialViewController(showWelcomeScreen: showWelcomeScreen)

        let navController = UINavigationController()
        navController.setViewControllers([initialViewController], animated: true)

        viewController.present(navController, animated: true, completion: nil)
    }

    func presentRelinkBrokerFlow(
        inViewController viewController: UIViewController,
        linkedBroker: TradeItLinkedBroker,
        oAuthCallbackUrl: URL
    ) {
        let activityView = MBProgressHUD.showAdded(to: viewController.view, animated: true)
        activityView.label.text = "Launching broker relinking"
        activityView.show(animated: true)

        TradeItSDK.linkedBrokerManager.getOAuthLoginPopupForTokenUpdateUrl(
            forLinkedBroker: linkedBroker,
            oAuthCallbackUrl: oAuthCallbackUrl,
            onSuccess: { [weak self] url in
                if let self = self {
                    self.webAuthSession = ASWebAuthenticationSession.init(url: url, callbackURLScheme: oAuthCallbackUrl.absoluteString, completionHandler: { (callBack:URL?, error:Error?) in
                        guard error == nil, let successURL = callBack else { return }
                    })

                    if #available(iOS 13.0, *) {
                        self.webAuthSession?.presentationContextProvider = self
                    }
                    self.webAuthSession?.start()
                    activityView.hide(animated: true)
                }
            },
            onFailure: { errorResult in
                self.alertManager.showError(errorResult, onViewController: viewController)
                activityView.hide(animated: true)
            }
        )
    }

    // MARK: Private

    private func getInitialViewController(showWelcomeScreen: Bool) -> UIViewController {
        let initialStoryboardId: TradeItStoryboardID = showWelcomeScreen ? .welcomeView : .selectBrokerView

        let initialViewController = self.viewControllerProvider.provideViewController(forStoryboardId: initialStoryboardId)

        if let welcomeViewController = initialViewController as? TradeItWelcomeViewController {
            welcomeViewController.delegate = self
            welcomeViewController.oAuthCallbackUrl = oAuthCallbackUrl
        } else if let selectBrokerViewController = initialViewController as? TradeItSelectBrokerViewController {
            selectBrokerViewController.oAuthCallbackUrl = oAuthCallbackUrl
            selectBrokerViewController.showOpenAccountButton = self.showOpenAccountButton
        }
        
        return initialViewController
    }
    
    // MARK: TradeItWelcomeViewControllerDelegate

    func getStartedButtonWasTapped(_ fromWelcomeViewController: TradeItWelcomeViewController) {
        let selectBrokerViewController = self.viewControllerProvider.provideViewController(forStoryboardId: TradeItStoryboardID.selectBrokerView) as! TradeItSelectBrokerViewController

        selectBrokerViewController.oAuthCallbackUrl = self.oAuthCallbackUrl
        selectBrokerViewController.showOpenAccountButton = self.showOpenAccountButton

//        fromWelcomeViewController.navigationController!.pushViewController(selectBrokerViewController, animated: true)
        fromWelcomeViewController.navigationController!.setViewControllers([selectBrokerViewController], animated: true)
    }
}

extension TradeItLinkBrokerUIFlow: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {

        return UIApplication.shared.windows.first ?? UIWindow()
    }
}
