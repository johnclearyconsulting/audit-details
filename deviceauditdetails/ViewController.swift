import UIKit
import CoreImage.CIFilterBuiltins

final class ViewController: UIViewController {

    private struct Field {
        let key: String
        let label: String
    }

    private let fields: [Field] = [
        .init(key: "serial", label: "Serial Number"),
        .init(key: "user",   label: "Primary User"),
        .init(key: "upn",    label: "User Principal Name")
    ]

    private enum Section: Int, CaseIterable {
        case serial
        case userUpn
        case summary
    }
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(true, animated: false)

        let hasLogo = (loadLogoImage() != nil)
        
        // Note: Only show title if no logo.
        title = hasLogo ? "" : "Device Details"
        
        let headerLabel = UILabel()
        headerLabel.numberOfLines = 0
        headerLabel.textAlignment = .center
        headerLabel.font = .preferredFont(forTextStyle: .footnote)
        headerLabel.textColor = .secondaryLabel
        
        let urlString = "https://github.com/johnclearyconsulting/device-audit-details"
        
        var fullText = "The details below are provided by your MDM using managed App Preferences.\nDocumentation on preference keys is available here:\n\(urlString)\n"
        
        headerLabel.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(openDocsLink))
        headerLabel.addGestureRecognizer(tap)

        let titleLabel = UILabel()
        titleLabel.text = "Device Details"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.alignment = .center
        headerStack.spacing = 12

        if let logo = hasLogo ? loadLogoImage() : nil {
            let logoView = UIImageView(image: logo)
            logoView.contentMode = .scaleAspectFit
            logoView.backgroundColor = .clear
            logoView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                logoView.heightAnchor.constraint(equalToConstant: 96),
                logoView.widthAnchor.constraint(lessThanOrEqualToConstant: 260)
            ])
            headerStack.addArrangedSubview(logoView)
        }

        headerStack.addArrangedSubview(titleLabel)
        
        if usingSampleData() {
            
            fullText = "Documentation on preference keys is available here:\n\(urlString)\n"

            let sampleLabel = UILabel()
            sampleLabel.text = "⚠️ Currently showing sample details -- no MDM preferences present) ⚠️"
            sampleLabel.numberOfLines = 1
            sampleLabel.textAlignment = .center
            
            let baseFont = UIFont.preferredFont(forTextStyle: .subheadline)
            let boldDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? baseFont.fontDescriptor
            sampleLabel.font = UIFont(descriptor: boldDescriptor, size: 0)
            
            sampleLabel.textColor = .systemOrange
            headerStack.addArrangedSubview(sampleLabel)
        }
        
        let attributed = NSMutableAttributedString(string: fullText)
        let range = (fullText as NSString).range(of: urlString)
        if range.location != NSNotFound {
            attributed.addAttribute(.foregroundColor, value: UIColor.link, range: range)
            attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        headerLabel.attributedText = attributed
        
        headerStack.addArrangedSubview(headerLabel)
        
        let headerContainer = UIView()
        headerContainer.addSubview(headerStack)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            headerStack.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -12)
        ])

        tableView.tableHeaderView = headerContainer
        headerContainer.layoutIfNeeded()
        headerContainer.frame.size.height = headerStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height + 24
        
        view.backgroundColor = .white

        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.dataSource = self
        tableView.estimatedRowHeight = 260
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(AuditCell.self, forCellReuseIdentifier: AuditCell.reuseID)
        tableView.register(TwoUpCell.self, forCellReuseIdentifier: TwoUpCell.reuseID)

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

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
            self.tableView.reloadData()
        }
    }
    
    // --- SamplePrefs.plist fallback (for App Review / unmanaged installs) ---
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

extension ViewController {
    @objc private func openDocsLink() {
        if let url = URL(string: "https://github.com/johnclearyconsulting/device-audit-details") {
            UIApplication.shared.open(url)
        }
    }
}

extension ViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let s = Section(rawValue: section) else { return 0 }
        switch s {
        case .serial: return 1
        case .userUpn: return 1
        case .summary: return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let debugging = configBool(forKey: "debugging")

        guard let s = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch s {
        case .serial:
            let cell = tableView.dequeueReusableCell(withIdentifier: AuditCell.reuseID, for: indexPath) as! AuditCell
            let v = configValue(forKey: "serial")
            cell.configure(title: "Serial Number", subtitle: "Serial", value: v, qrText: v, showSubtitle: debugging)
            return cell

        case .userUpn:
            let cell = tableView.dequeueReusableCell(withIdentifier: TwoUpCell.reuseID, for: indexPath) as! TwoUpCell
            let userVal = configValue(forKey: "user")
            let upnVal  = configValue(forKey: "upn")
            cell.configure(
                left: (title: "Primary User", subtitle: "user", value: userVal),
                right: (title: "User Principal Name", subtitle: "upn", value: upnVal),
                showSubtitle: debugging
            )
            return cell

        case .summary:
            let cell = tableView.dequeueReusableCell(withIdentifier: AuditCell.reuseID, for: indexPath) as! AuditCell
            let json = summaryJSON()
            cell.configure(
                title: "Summary",
                subtitle: "JSON",
                value: json,
                qrText: "\(json)",
                isSummary: true,
                showSubtitle: debugging
            )
            return cell
        }
    }
}

final class TwoUpCell: UITableViewCell {

    static let reuseID = "TwoUpCell"

    private let container = UIView()
    private let stack = UIStackView()

    private let leftCard = MiniCardView()
    private let rightCard = MiniCardView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        contentView.backgroundColor = .clear

        container.backgroundColor = .clear
        contentView.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 12

        stack.addArrangedSubview(leftCard)
        stack.addArrangedSubview(rightCard)

        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),

            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        leftCard.reset()
        rightCard.reset()
    }

    func configure(
        left: (title: String, subtitle: String, value: String),
        right: (title: String, subtitle: String, value: String),
        showSubtitle: Bool
    ) {
        leftCard.configure(title: left.title, subtitle: left.subtitle, value: left.value, showSubtitle: showSubtitle)
        rightCard.configure(title: right.title, subtitle: right.subtitle, value: right.value, showSubtitle: showSubtitle)
    }
}

final class MiniCardView: UIView {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueLabel = UILabel()

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
        valueLabel.font = UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)

        let header = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        header.axis = .vertical
        header.alignment = .center
        header.spacing = 2

        let stack = UIStackView(arrangedSubviews: [header, valueLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reset() {
        titleLabel.text = nil
        subtitleLabel.text = nil
        valueLabel.text = nil
    }

    func configure(title: String, subtitle: String, value: String, showSubtitle: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = !showSubtitle

        if value.isEmpty {
            valueLabel.text = "—"
            valueLabel.textColor = .secondaryLabel
        } else {
            valueLabel.textColor = .label
            valueLabel.text = value
        }
    }
}

final class AuditCell: UITableViewCell {

    static let reuseID = "AuditCell"

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueLabel = UILabel()
    private let qrImageView = UIImageView()
    private let container = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        contentView.backgroundColor = .clear

        container.backgroundColor = .white
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.black.withAlphaComponent(0.08).cgColor

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 1

        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.setContentHuggingPriority(.required, for: .horizontal)

        valueLabel.numberOfLines = 0

        qrImageView.contentMode = .scaleAspectFit
        qrImageView.layer.magnificationFilter = .nearest
        qrImageView.backgroundColor = .white

        contentView.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), subtitleLabel])
        header.axis = .horizontal
        header.alignment = .top
        header.spacing = 8

        let stack = UIStackView(arrangedSubviews: [header, valueLabel, qrImageView])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8

        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),

            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            qrImageView.widthAnchor.constraint(equalToConstant: 144),
            qrImageView.heightAnchor.constraint(equalToConstant: 144),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        qrImageView.image = nil
        valueLabel.text = nil
    }
    
    func configure(title: String, subtitle: String, value: String, qrText: String, isSummary: Bool = false, showSubtitle: Bool = true) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = !showSubtitle
        
        if value.isEmpty {
            valueLabel.text = "—"
            valueLabel.textColor = .secondaryLabel
            valueLabel.font = UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
            qrImageView.image = placeholderQR()
        } else {
            valueLabel.textColor = isSummary ? .secondaryLabel : .label
            valueLabel.font = isSummary
                ? UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .regular)
                : UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)

            valueLabel.text = value
            qrImageView.image = QR.make(from: qrText, size: 144) ?? placeholderQR()
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
