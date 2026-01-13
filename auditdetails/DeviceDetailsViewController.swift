import UIKit
import CoreImage.CIFilterBuiltins

// MAIN INTERFACE
final class DeviceDetailsViewController: UIViewController {

    private struct Field {
        let key: String
        let label: String
    }

    private let fields: [Field] = [
        .init(key: "serial", label: "Serial Number"),
        .init(key: "user",   label: "Primary User"),
        .init(key: "upn",    label: "User Principal Name")
    ]

    private enum DetailsTableSections: Int, CaseIterable {
        case serial
        case userUpn
        case summary
    }
    
    private let detailsTable = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        
        // This lets UIViewController do its baseline setup. In UIKit, skipping this is usually a bug.
        super.viewDidLoad()
        
        // Hide the nav bar (because we're building our own header)
        navigationController?.setNavigationBarHidden(true, animated: false)

        
        // If there's a logo, import it
        let headingLogo: UIImageView? = {
            guard let image = loadLogoImage() else { return nil }
            return UIImageView(image: image)
        }()
        
        if let headingLogo {
            headingLogo.contentMode = .scaleAspectFit
            headingLogo.backgroundColor = .clear
            headingLogo.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                headingLogo.heightAnchor.constraint(equalToConstant: 96),
                headingLogo.widthAnchor.constraint(lessThanOrEqualToConstant: 260)
            ])
        }
        
        // Set Heading Text
        let headingLabel = UILabel()
        headingLabel.text = "Device Details"
        headingLabel.font = .preferredFont(forTextStyle: .title2)
        headingLabel.textAlignment = .center
        headingLabel.numberOfLines = 1
                    
        // Set Documentation
        let documentationLabel = UILabel()
        documentationLabel.numberOfLines = 0
        documentationLabel.textAlignment = .center
        documentationLabel.font = .preferredFont(forTextStyle: .footnote)
        documentationLabel.textColor = .secondaryLabel
        documentationLabel.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(openDocsLink))
        documentationLabel.addGestureRecognizer(tap)
        
        // Set Documentation URL
        let githubURLString = "https://github.com/johnclearyconsulting/audit-details"
        
        // Set Default Text for Documentation Label
        let documentationText = "Documentation on preference keys is available here:\n\(githubURLString)\n"

        let dataSourceLabel = UILabel()
        dataSourceLabel.numberOfLines = 1
        dataSourceLabel.textAlignment = .center
        let baseFont = UIFont.preferredFont(forTextStyle: .subheadline)
        let boldDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? baseFont.fontDescriptor
        dataSourceLabel.font = UIFont(descriptor: boldDescriptor, size: 0)
       
        // Check if using sample data, and update dataSourceLabel Text
        if usingSampleData() {
            dataSourceLabel.text = "⚠️ No MDM preferences present. Sample details displayed. ⚠️"
            dataSourceLabel.textColor = .systemOrange
       } else {
            dataSourceLabel.text = "✅ The details below are provided by your MDM using managed App Preferences. ✅"
            dataSourceLabel.textColor = .systemGreen
        }

        let attributed = NSMutableAttributedString(string: documentationText)
        let range = (documentationText as NSString).range(of: githubURLString)
        if range.location != NSNotFound {
            attributed.addAttribute(.foregroundColor, value: UIColor.link, range: range)
            attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        
        documentationLabel.attributedText = attributed

        
        // Build Header Stack
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.alignment = .center
        // headerStack.spacing = 12

        // Add Logo if exists to headerStack
        if let headingLogo { headerStack.addArrangedSubview(headingLogo) }
        
        // Add heading text to headerStack
        headerStack.addArrangedSubview(headingLabel)
        
        // Add documentation text to headerStack
        headerStack.addArrangedSubview(documentationLabel)

        // Add dataSourceLabel to headerStack
        headerStack.addArrangedSubview(dataSourceLabel)
        
        
        
        // Create a container for the headerStack (for spacing / sizing etc.)
        let headerContainer = UIView()
        headerContainer.addSubview(headerStack)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            headerStack.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -12)
        ])

        
        
        // Set the table's header view to headerContainer
        detailsTable.tableHeaderView = headerContainer
        headerContainer.layoutIfNeeded()
        headerContainer.frame.size.height = headerStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height + 24
        
        detailsTable.backgroundColor = .white
        detailsTable.separatorStyle = .none
        detailsTable.allowsSelection = true // JWC TO DO: Set to False before release
        detailsTable.dataSource = self
        detailsTable.estimatedRowHeight = 260
        detailsTable.rowHeight = UITableView.automaticDimension
        detailsTable.register(DeviceDetailsRowCell.self, forCellReuseIdentifier: DeviceDetailsRowCell.reuseID)


        // Set DeviceDetailsViewController properties
        view.backgroundColor = .white

        // Add detailsTable to view
        view.addSubview(detailsTable)

        // Set detailsTable properties (e.g. sizing)
        detailsTable.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            detailsTable.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            detailsTable.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            detailsTable.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            detailsTable.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Not sure what this is for yet!
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func defaultsChanged() {
        DispatchQueue.main.async {
            self.detailsTable.reloadData()
        }
    }
    
    // --- Read SamplePrefs.plist fallback (for App Review / unmanaged installs) ---
    private lazy var samplePrefs: [String: Any] = {
        guard
            let url = Bundle.main.url(forResource: "SamplePrefs", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = obj as? [String: Any]
        else { return [:] }
        return dict
    }()

    private func sampleValue(forKey key: String) -> String {
        if let s = samplePrefs[key] as? String { return s }
        if let n = samplePrefs[key] as? NSNumber { return n.stringValue }
        if let b = samplePrefs[key] as? Bool { return b ? "true" : "false" }
        return ""
    }

    private func configValueRaw(forKey key: String) -> String {
        #if targetEnvironment(macCatalyst)
        return UserDefaults.standard.string(forKey: key) ?? ""
        #else
        let dict = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed") ?? [:]
        if let s = dict[key] as? String { return s }
        if let n = dict[key] as? NSNumber { return n.stringValue }
        return dict[key].map { String(describing: $0) } ?? ""
        #endif
    }

    private func usingSampleData() -> Bool {
        // If none of the primary keys have an MDM-supplied value, assume sample mode.
        let keys = ["serial", "user", "upn"]
        let anyMDM = keys.contains {
            !configValueRaw(forKey: $0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !anyMDM
    }
    
    private func configValue(forKey key: String) -> String {
        let v = configValueRaw(forKey: key)
        if !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return v }
        return sampleValue(forKey: key)
    }
    
    private func configBool(forKey key: String) -> Bool {
        let v = configValue(forKey: key).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return v == "true" || v == "1" || v == "yes" || v == "y"
    }
    
    private func loadLogoImage() -> UIImage? {
        let base64 = configValue(forKey: "logo_base64")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base64.isEmpty,
              let data = Data(base64Encoded: base64),
              let image = UIImage(data: data)
        else { return nil }
        return image
    }
    
    private func summaryJSON() -> String {
        var d: [String: String] = [:]
        for f in fields { d[f.key] = configValue(forKey: f.key) }
        guard JSONSerialization.isValidJSONObject(d),
              let data = try? JSONSerialization.data(withJSONObject: d, options: []),
              let json = String(data: data, encoding: .utf8)
        else { return "" }

        return json
    }
}

extension DeviceDetailsViewController {
    @objc private func openDocsLink() {
        if let url = URL(string: "https://github.com/johnclearyconsulting/audit-details") {
            UIApplication.shared.open(url)
        }
    }
}



// GENERATAE QR CODE
enum QR {
    private static let context = CIContext()
    private static let filter = CIFilter.qrCodeGenerator()

    static func make(from string: String, size: CGFloat) -> UIImage? {
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        let extent = output.extent.integral
        let scale = min(size / extent.width, size / extent.height)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgimg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgimg)
    }
}



// UNIFIED CELL: renders any number of displayCards horizontally
final class DeviceDetailsRowCell: UITableViewCell {

    static let reuseID = "DeviceDetailsRowCell"

    // MARK: - Model
    struct CardModel {
        let title: String
        let subtitle: String
        let value: String?       // nil => hide value label entirely
        let qrText: String?      // nil => hide QR entirely
        let isSummary: Bool      // affects value styling
        let showSubtitle: Bool

        init(
            title: String,
            subtitle: String,
            value: String? = nil,
            qrText: String? = nil,
            isSummary: Bool = false,
            showSubtitle: Bool = true
        ) {
            self.title = title
            self.subtitle = subtitle
            self.value = value
            self.qrText = qrText
            self.isSummary = isSummary
            self.showSubtitle = showSubtitle
        }
    }

    private let container = UIView()
    private let rowStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        contentView.backgroundColor = .clear

        container.backgroundColor = .clear
        contentView.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        rowStack.axis = .horizontal
        rowStack.alignment = .fill
        rowStack.distribution = .fillEqually
        rowStack.spacing = 12

        container.addSubview(rowStack)
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),

            rowStack.topAnchor.constraint(equalTo: container.topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        clearCards()
    }

    // MARK: - Configure
    func configure(cards: [CardModel]) {
        clearCards()

        for model in cards {
            let card = DeviceDetailsRowCellCard()
            card.apply(model: model)
            rowStack.addArrangedSubview(card)
        }
    }

    private func clearCards() {
        for v in rowStack.arrangedSubviews {
            rowStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }
}

// DeviceDetailsRowCellCard (used by DeviceDetailsRowCell)
final class DeviceDetailsRowCellCard: UIView {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueLabel = UILabel()
    private let qrImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .white
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.black.withAlphaComponent(0.08).cgColor

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center

        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center

        valueLabel.numberOfLines = 0
        valueLabel.textAlignment = .center

        qrImageView.contentMode = .scaleAspectFit
        qrImageView.layer.magnificationFilter = .nearest
        qrImageView.backgroundColor = .white

        let header = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        header.axis = .vertical
        header.alignment = .center
        header.spacing = 2

        let stack = UIStackView(arrangedSubviews: [header, valueLabel, qrImageView])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        qrImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            qrImageView.heightAnchor.constraint(equalToConstant: 144)
        ])

        reset()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reset() {
        titleLabel.text = nil
        subtitleLabel.text = nil
        subtitleLabel.isHidden = false

        valueLabel.text = nil
        valueLabel.textColor = .label
        valueLabel.isHidden = true

        qrImageView.image = nil
        qrImageView.isHidden = true
    }

    func apply(model: DeviceDetailsRowCell.CardModel) {
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        subtitleLabel.isHidden = !model.showSubtitle

        // VALUE (optional)
        if let v = model.value {
            valueLabel.isHidden = false

            if v.isEmpty {
                valueLabel.text = "—"
                valueLabel.textColor = .secondaryLabel
                valueLabel.font = UIFont.monospacedSystemFont(
                    ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                    weight: .regular
                )
            } else {
                valueLabel.textColor = model.isSummary ? .secondaryLabel : .label
                valueLabel.font = model.isSummary
                    ? UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .regular)
                    : UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
                valueLabel.text = v
            }
        } else {
            valueLabel.isHidden = true
            valueLabel.text = nil
        }

        // QR (optional)
        if let qrText = model.qrText {
            qrImageView.isHidden = false
            if let v = model.value, v.isEmpty {
                qrImageView.image = placeholderQR()
            } else {
                qrImageView.image = QR.make(from: qrText, size: 144) ?? placeholderQR()
            }
        } else {
            qrImageView.isHidden = true
            qrImageView.image = nil
        }
    }

    private func placeholderQR() -> UIImage? {
        let r = UIGraphicsImageRenderer(size: CGSize(width: 144, height: 144))
        return r.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 144, height: 144))

            let rect = CGRect(x: 4, y: 4, width: 136, height: 136)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
            UIColor.secondaryLabel.setStroke()
            let dash: [CGFloat] = [6, 6]
            path.setLineDash(dash, count: dash.count, phase: 0)
            path.lineWidth = 1
            path.stroke()

            let text = "No value"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .caption1),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let size = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: (144 - size.width)/2, y: (144 - size.height)/2), withAttributes: attrs)
        }
    }
}





// LOADING DATA
extension DeviceDetailsViewController: UITableViewDataSource {

    // UITableView expects to be able to call methods called: numberOfSections; numberOfRowsInSection and cellForRowAt to load data.
    // UIKit will take care of which sections / rows are visible at a given time.
    
    // First UIKit calls numberOfSections
    func numberOfSections(in tableView: UITableView) -> Int {
        DetailsTableSections.allCases.count
    }

    // Then numberOfRowsInSection gets called by UIKit for a given section (from above)
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let s = DetailsTableSections(rawValue: section) else { return 0 }
        switch s {
        case .serial: return 1
        case .userUpn: return 1
        case .summary: return 1
        }
    }

    // To load data, cellForRowAt gets called by UIKit for each row in a given section (from above)
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let debugging = configBool(forKey: "debugging")

        guard let s = DetailsTableSections(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch s {
        case .serial:
            let cell = tableView.dequeueReusableCell(withIdentifier: DeviceDetailsRowCell.reuseID, for: indexPath) as! DeviceDetailsRowCell
            let v = configValue(forKey: "serial")
            cell.configure(cards: [
                .init(title: "Serial Number", subtitle: "Serial", value: v, qrText: v, showSubtitle: debugging)
            ])
            return cell

        case .userUpn:
            let cell = tableView.dequeueReusableCell(withIdentifier: DeviceDetailsRowCell.reuseID, for: indexPath) as! DeviceDetailsRowCell
            let userVal = configValue(forKey: "user")
            let upnVal  = configValue(forKey: "upn")
            cell.configure(cards: [
                .init(title: "Primary User", subtitle: "user", value: userVal, showSubtitle: debugging),
                .init(title: "User Principal Name", subtitle: "upn", value: upnVal, showSubtitle: debugging)
            ])
            return cell

        case .summary:
            let cell = tableView.dequeueReusableCell(withIdentifier: DeviceDetailsRowCell.reuseID, for: indexPath) as! DeviceDetailsRowCell
            let json = summaryJSON()
            cell.configure(cards: [
                .init(title: "Summary", subtitle: "JSON", value: json, qrText: json, isSummary: true, showSubtitle: debugging)
            ])
            return cell
        }
    }
}
