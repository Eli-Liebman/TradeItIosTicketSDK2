import UIKit

class TradeItLoginViewController: KeyboardViewController {

    let linkedBrokerManager: TradeItLinkedBrokerManager = TradeItLauncher.linkedBrokerManager

    @IBOutlet weak var loginLabel: UILabel!
    @IBOutlet weak var userNameInput: UITextField!
    @IBOutlet weak var passwordInput: UITextField!
    @IBOutlet weak var linkButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    var delegate: TradeItLoginViewControllerDelegate?
    var selectedBroker: TradeItBroker?
    var linkedBrokerToRelink: TradeItLinkedBroker?
    var alertManager = TradeItAlertManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationItem()
        self.userNameInput.becomeFirstResponder()
        self.disableLinkButton()
        self.activityIndicator.hidesWhenStopped = true

        if let brokerName = self.selectedBroker?.brokerLongName {
            self.loginLabel.text = "Log in to \(brokerName)"
            self.userNameInput.placeholder = "\(brokerName) Username"
            self.passwordInput.placeholder = "\(brokerName) Password"
        }
        
        if self.linkedBrokerToRelink != nil {
            linkButton.setTitle("Relink Broker", forState: .Normal)
        }
        else {
            linkButton.setTitle("Link Broker", forState: .Normal)
        }
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField == self.userNameInput {
            self.passwordInput.becomeFirstResponder()
        } else if textField == self.passwordInput {
            self.linkButton.sendActionsForControlEvents(.TouchUpInside)
        }

        return true
    }

    // MARK: IBActions

    @IBAction func linkButtonWasTapped(sender: UIButton) {
        guard let brokerShortName = self.selectedBroker?.brokerShortName else { return }

        self.activityIndicator.startAnimating()

        self.disableLinkButton()
        
        let tradeItAuthenticationInfo = TradeItAuthenticationInfo(id: self.userNameInput.text,
                                                                  andPassword: self.passwordInput.text,
                                                                  andBroker: brokerShortName)
        
        if let linkedBrokerToRelink = self.linkedBrokerToRelink {
            self.linkedBrokerManager.relinkBroker(linkedBrokerToRelink,
                                                  authInfo: tradeItAuthenticationInfo,
                                                  onSuccess: { (linkedBroker: TradeItLinkedBroker) -> Void in
                                                      self.authenticateBroker(linkedBroker)
                                                  },
                                                  onFailure: {(tradeItErrorResult: TradeItErrorResult) -> Void in
                                                      self.activityIndicator.stopAnimating()
                                                      self.enableLinkButton()
                                                      self.alertManager.showGenericError(
                                                          tradeItErrorResult: tradeItErrorResult,
                                                          onViewController: self
                                                      )
                                                  })
        } else {
            self.linkedBrokerManager.linkBroker(authInfo: tradeItAuthenticationInfo,
                                                onSuccess: {(linkedBroker: TradeItLinkedBroker) -> Void in
                                                    self.authenticateBroker(linkedBroker)
                                                },
                                                onFailure: {(tradeItErrorResult: TradeItErrorResult) -> Void in
                                                    self.activityIndicator.stopAnimating()
                                                    self.enableLinkButton()
                                                    self.alertManager.showGenericError(
                                                        tradeItErrorResult: tradeItErrorResult,
                                                        onViewController: self
                                                    )
                                                })
        }
    }

    @IBAction func userNameOnEditingChanged(sender: UITextField) {
        self.updateLinkButton()
    }

    @IBAction func passwordOnEditingChanged(sender: UITextField) {
        self.updateLinkButton()
    }
    
    // MARK: Private

    private func authenticateBroker(linkedBroker: TradeItLinkedBroker) {
        linkedBroker.authenticate(
            onSuccess: { () -> Void in
                self.delegate?.brokerLinked(self, withLinkedBroker: linkedBroker)
                self.activityIndicator.stopAnimating()
                self.enableLinkButton()
            },
            onSecurityQuestion: { (securityQuestion: TradeItSecurityQuestionResult, answerSecurityQuestion: (String) -> Void, cancelSecurityQuestion: () -> Void) -> Void in
                self.activityIndicator.stopAnimating()
                self.enableLinkButton()
                self.alertManager.show(
                    securityQuestion: securityQuestion,
                    onViewController: self,
                    onAnswerSecurityQuestion: answerSecurityQuestion,
                    onCancelSecurityQuestion: cancelSecurityQuestion
                )
            },
            onFailure: { (tradeItErrorResult: TradeItErrorResult) -> Void in
                self.linkedBrokerManager.unlinkBroker(linkedBroker)
                self.activityIndicator.stopAnimating()
                self.enableLinkButton()
                self.alertManager.showGenericError(tradeItErrorResult: tradeItErrorResult, onViewController: self)
            }
        )
    }

    

    private func updateLinkButton() {
        if (self.userNameInput.text != "" && self.passwordInput.text != "" && !self.linkButton.enabled) {
            self.enableLinkButton()
        } else if ( (self.userNameInput.text == "" || self.passwordInput.text == "") && self.linkButton.enabled) {
            self.disableLinkButton()
        }
    }
    
    private func disableLinkButton() {
        self.linkButton.enabled = false
        self.linkButton.alpha = 0.5
    }
    
    private func enableLinkButton() {
        self.linkButton.enabled = true
        self.linkButton.alpha = 1.0
    }
}

protocol TradeItLoginViewControllerDelegate {
    func brokerLinked(fromTradeItLoginViewController: TradeItLoginViewController, withLinkedBroker linkedBroker: TradeItLinkedBroker)
}
