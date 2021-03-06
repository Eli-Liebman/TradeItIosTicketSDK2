class CryptoPreviewCellFactory: PreviewCellFactory {
    private let linkedBrokerAccount: TradeItLinkedBrokerAccount
    private let orderCapabilities: TradeItInstrumentOrderCapabilities?
    private let previewOrderResult: TradeItCryptoPreviewTradeResult
    var placeOrderResult: TradeItPlaceOrderResult?
    private weak var delegate: PreviewMessageDelegate?

    init(
        previewMessageDelegate delegate: PreviewMessageDelegate,
        linkedBrokerAccount: TradeItLinkedBrokerAccount,
        previewOrderResult: TradeItCryptoPreviewTradeResult
    ) {
        self.delegate = delegate
        self.linkedBrokerAccount = linkedBrokerAccount
        self.previewOrderResult = previewOrderResult
        self.orderCapabilities = self.linkedBrokerAccount.orderCapabilities.filter { $0.instrument == "crypto" }.first
    }

    func generateCellData() -> [PreviewCellData] {
        let orderDetails = previewOrderResult.orderDetails

        var cells = [PreviewCellData]()

        cells += [
            ValueCellData(label: "Account", value: linkedBrokerAccount.getFormattedAccountName())
        ] as [PreviewCellData]

        let orderDetailsPresenter = TradeItOrderDetailsPresenter(
            orderAction: orderDetails.orderAction,
            orderExpiration: orderDetails.orderExpiration,
            orderCapabilities: orderCapabilities
        )

        if let orderNumber = self.placeOrderResult?.orderNumber {
            cells += [
                ValueCellData(label: "Order #", value: orderNumber)
            ] as [PreviewCellData]
        }

        cells += [
            ValueCellData(label: "Action", value: orderDetailsPresenter.getOrderActionLabel()),
            ValueCellData(label: "Symbol", value: orderDetails.orderPair),
            ValueCellData(
                label: labelForQuantity(symbolPair: orderDetails.orderPair, orderQuantityTypeString: orderDetails.orderQuantityType),
                value: formatQuantity(rawQuantityType: orderDetails.orderQuantityType, quantity: orderDetails.orderQuantity)
            )
        ]

        if let estimatedOrderValue = orderDetails.estimatedOrderValue {
            cells.append(
                ValueCellData(label: "Price", value: NumberFormatter.formatCurrency(estimatedOrderValue))
            )
        }

        cells.append(ValueCellData(label: "Time in force", value: orderDetailsPresenter.getOrderExpirationLabel()))

        if let estimatedOrderCommission = orderDetails.estimatedOrderCommission {
            cells.append(ValueCellData(label: orderDetails.orderCommissionLabel, value: self.formatCurrency(estimatedOrderCommission)))
        }

        if let estimatedTotalValue = orderDetails.estimatedTotalValue {
            let action = TradeItOrderAction(value: orderDetails.orderAction)
            let title = "Estimated \(TradeItOrderActionPresenter.SELL_ACTIONS.contains(action) ? "proceeds" : "cost")"
            cells.append(ValueCellData(label: title, value: formatCurrency(estimatedTotalValue)))
        }

        if self.placeOrderResult == nil {
            cells += generateMessageCellData()
        }

        return cells
    }

    // MARK: Private

    private func labelForQuantity(symbolPair: String, orderQuantityTypeString: String) -> String {
        if let symbol = symbolFor(symbolPair: symbolPair, orderQuantityTypeString: orderQuantityTypeString) {
            return "Amount in \(symbol)"
        } else {
            return "Amount"
        }
    }

    private func symbolFor(symbolPair: String, orderQuantityTypeString: String) -> String? {
        let symbolPair = symbolPair.split(separator: "/")
        guard let quantityType = OrderQuantityType.init(rawValue: orderQuantityTypeString),
            let baseSymbol = symbolPair.first,
            let quoteSymbol = symbolPair.last,
            symbolPair.count == 2
            else { return nil }

        switch quantityType {
        case .baseCurrency: return String(baseSymbol)
        case .quoteCurrency: return String(quoteSymbol)
        default: return nil
        }
    }

    private func generateMessageCellData() -> [PreviewCellData] {
        guard let messages = previewOrderResult.orderDetails.warnings else { return [] }
        return messages.map(MessageCellData.init)
    }

    private func formatCurrency(_ value: NSNumber) -> String {
        return NumberFormatter.formatCurrency(value, currencyCode: self.linkedBrokerAccount.accountBaseCurrency)
    }

    private func formatQuantity(rawQuantityType: String, quantity: NSNumber) -> String {
        if let quantityType = OrderQuantityType(rawValue: rawQuantityType),
            let maxDecimal = orderCapabilities?.maxDecimalPlacesFor(orderQuantityType: quantityType) {
            return NumberFormatter.formatQuantity(quantity, maxDecimalPlaces: maxDecimal)
        } else {
            return quantity.stringValue
        }
    }
}
