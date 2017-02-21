protocol OAuthCompletionListener {
    func onOAuthCompleted(linkedBroker: TradeItLinkedBroker)
}

@objc public class TradeItLauncher: NSObject {
    let linkBrokerUIFlow = TradeItLinkBrokerUIFlow()
    let tradingUIFlow = TradeItTradingUIFlow()
    let accountSelectionUIFlow = TradeItAccountSelectionUIFlow()
    let oAuthCompletionUIFlow = TradeItOAuthCompletionUIFlow()
    let viewControllerProvider = TradeItViewControllerProvider()
    let deviceManager = TradeItDeviceManager()
    let alertManager = TradeItAlertManager()

    override internal init() {}

    public func handleOAuthCallback(onViewController viewController: UIViewController, oAuthCallbackUrl: URL) {
        print("=====> LAUNCHER.handleOAuthCallback: \(oAuthCallbackUrl.absoluteString)")

        let oAuthCallbackUrlParser = TradeItOAuthCallbackUrlParser(oAuthCallbackUrl: oAuthCallbackUrl)

        self.oAuthCompletionUIFlow.presentOAuthCompletionFlow(
            fromViewController: viewController,
            withOAuthCallbackUrlParser: oAuthCallbackUrlParser)
    }

    public func launchPortfolio(fromViewController viewController: UIViewController) {
        // Show Welcome flow for users who have never linked before
        if (TradeItSDK.linkedBrokerManager.linkedBrokers.count == 0) {
            var oAuthCallbackUrl = TradeItSDK.oAuthCallbackUrl

            if var urlComponents = URLComponents(url: oAuthCallbackUrl,
                                                 resolvingAgainstBaseURL: false) {
                urlComponents.addOrUpdateQueryStringValue(
                    forKey: OAuthCallbackQueryParamKeys.tradeItDestination.rawValue,
                    value: OAuthCallbackDestinationValues.portfolio.rawValue)

                oAuthCallbackUrl = urlComponents.url ?? oAuthCallbackUrl
            }
            
            self.linkBrokerUIFlow.presentLinkBrokerFlow(
                fromViewController: viewController,
                showWelcomeScreen: true,
                oAuthCallbackUrl: oAuthCallbackUrl
            )
        } else {
            let account = TradeItSDK.linkedBrokerManager.linkedBrokers.first?.accounts.first
            self.launchPortfolio(fromViewController: viewController, forLinkedBrokerAccount: account)
        }
    }

    public func launchPortfolio(fromViewController viewController: UIViewController,
                                forLinkedBrokerAccount linkedBrokerAccount: TradeItLinkedBrokerAccount?) {
        deviceManager.authenticateUserWithTouchId(
            onSuccess: {
                let navController = self.viewControllerProvider.provideNavigationController(withRootViewStoryboardId: TradeItStoryboardID.portfolioView)

                guard let portfolioViewController = navController.viewControllers.last as? TradeItPortfolioViewController else { return }

                portfolioViewController.initialAccount = linkedBrokerAccount

                viewController.present(navController, animated: true, completion: nil)
            }, onFailure: {
                print("TouchId access denied")
            }
        )
    }

    public func launchPortfolio(fromViewController viewController: UIViewController, forAccountNumber accountNumber: String) {
        let accounts = TradeItSDK.linkedBrokerManager.linkedBrokers.flatMap { $0.accounts }.filter { $0.accountNumber == accountNumber }

        if accounts.isEmpty {
            print("WARNING: No linked broker accounts found matching the account number " + accountNumber)
        } else {
            if accounts.count > 1 {
                print("WARNING: there are several linked broker accounts with the same account number... taking the first one")
            }

            self.launchPortfolio(fromViewController: viewController, forLinkedBrokerAccount: accounts[0])
        }
    }

    public func launchTrading(fromViewController viewController: UIViewController,
                              withOrder order: TradeItOrder = TradeItOrder()) {
        // Show Welcome flow for users who have never linked before
        if (TradeItSDK.linkedBrokerManager.linkedBrokers.count == 0) {
            var oAuthCallbackUrl = TradeItSDK.oAuthCallbackUrl

            if var urlComponents = URLComponents(url: oAuthCallbackUrl,
                                                 resolvingAgainstBaseURL: false) {
                urlComponents.addOrUpdateQueryStringValue(
                    forKey: OAuthCallbackQueryParamKeys.tradeItDestination.rawValue,
                    value: OAuthCallbackDestinationValues.trading.rawValue)

                urlComponents.addOrUpdateQueryStringValue(
                    forKey: OAuthCallbackQueryParamKeys.tradeItOrderSymbol.rawValue,
                    value: order.symbol)

                if order.action != .unknown {
                    urlComponents.addOrUpdateQueryStringValue(
                        forKey: OAuthCallbackQueryParamKeys.tradeItOrderAction.rawValue,
                        value: TradeItOrderActionPresenter.labelFor(order.action))
                }

                oAuthCallbackUrl = urlComponents.url ?? oAuthCallbackUrl
            }

            self.linkBrokerUIFlow.presentLinkBrokerFlow(
                fromViewController: viewController,
                showWelcomeScreen: true,
                oAuthCallbackUrl: oAuthCallbackUrl
            )
        } else {
            deviceManager.authenticateUserWithTouchId(
                onSuccess: {
                    self.tradingUIFlow.presentTradingFlow(fromViewController: viewController, withOrder: order)
                },
                onFailure: {
                    print("TouchId access denied")
                }
            )
        }
    }

    public func launchAccountManagement(fromViewController viewController: UIViewController) {
        deviceManager.authenticateUserWithTouchId(
            onSuccess: {
                let navController = self.viewControllerProvider.provideNavigationController(withRootViewStoryboardId: TradeItStoryboardID.brokerManagementView)

                viewController.present(navController, animated: true, completion: nil)
            }, onFailure: {
                print("TouchId access denied")
            }
        )
    }

    public func launchBrokerLinking(fromViewController viewController: UIViewController) {
        let showWelcomeScreen = TradeItSDK.linkedBrokerManager.linkedBrokers.count > 0
        let oAuthCallbackUrl = TradeItSDK.oAuthCallbackUrl
        // TODO: Once callback is NSURL, add destination to query params AND LAUNCH LINK SUCCESS SCREEN

        self.linkBrokerUIFlow.presentLinkBrokerFlow(fromViewController: viewController,
                                                    showWelcomeScreen: showWelcomeScreen,
                                                    oAuthCallbackUrl: oAuthCallbackUrl)
    }

    public func launchBrokerCenter(fromViewController viewController: UIViewController) {
        let navController = self.viewControllerProvider.provideNavigationController(withRootViewStoryboardId: TradeItStoryboardID.brokerCenterView)
        viewController.present(navController, animated: true, completion: nil)
    }

    public func launchAccountSelection(fromViewController viewController: UIViewController,
                                       title: String? = nil,
                                       onSelected: @escaping (TradeItLinkedBrokerAccount) -> Void) {
        if (TradeItSDK.linkedBrokerManager.linkedBrokers.count == 0) {
            let oAuthCallbackUrl = TradeItSDK.oAuthCallbackUrl
            // TODO: Once callback is NSURL, add destination to query params

            self.linkBrokerUIFlow.presentLinkBrokerFlow(
                fromViewController: viewController,
                showWelcomeScreen: true,
                oAuthCallbackUrl: oAuthCallbackUrl
            )
        } else {
            self.accountSelectionUIFlow.presentAccountSelectionFlow(
                fromViewController: viewController,
                title: title,
                onSelected: { presentedNavController, linkedBrokerAccount in
                    presentedNavController.dismiss(animated: true, completion: nil)
                    onSelected(linkedBrokerAccount)
                },
                onFlowAborted: { presentedNavController in
                    presentedNavController.dismiss(animated: true, completion: nil)
                }
            )
        }
    }
}
