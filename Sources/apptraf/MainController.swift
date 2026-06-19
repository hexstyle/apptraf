import AppKit
import AppTrafCore

enum Period: Int, CaseIterable {
    case h1, h6, h24, d7

    var title: String {
        switch self {
        case .h1:  return "Last hour"
        case .h6:  return "Last 6 hours"
        case .h24: return "Last 24 hours"
        case .d7:  return "Last 7 days"
        }
    }

    var hours: Int {
        switch self {
        case .h1:  return 1
        case .h6:  return 6
        case .h24: return 24
        case .d7:  return 168
        }
    }
}

enum SortMetric: String {
    case app, bytesIn, bytesOut, total

    static func from(_ key: String?) -> SortMetric {
        switch key {
        case "app":   return .app
        case "in":    return .bytesIn
        case "out":   return .bytesOut
        case "total": return .total
        default:      return .total
        }
    }

    func value(of row: AggRow) -> UInt64 {
        switch self {
        case .app:      return 0
        case .bytesIn:  return row.bytesIn
        case .bytesOut: return row.bytesOut
        case .total:    return row.bytesIn + row.bytesOut
        }
    }

    var label: String {
        switch self {
        case .app:      return "Application"
        case .bytesIn:  return "Download"
        case .bytesOut: return "Upload"
        case .total:    return "Total"
        }
    }

    var chartFallback: SortMetric { self == .app ? .total : self }
}

final class MainController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let view: NSView
    private let periodPopup = NSPopUpButton()
    private let totalLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let chart = BarChartView()
    private let tableView = NSTableView()
    private var data: [AggRow] = []
    private var period: Period = .h24
    private var refreshTimer: Timer?
    private var db: DB?

    override init() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 840, height: 620))
        view.autoresizingMask = [.width, .height]
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        super.init()
        buildLayout()
        configureTable()

        do {
            db = try DB(path: Paths.dbURL.path)
        } catch {
            statusLabel.stringValue = "DB error: \(error.localizedDescription)"
        }

        periodPopup.target = self
        periodPopup.action = #selector(periodChanged(_:))

        reload()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.reload()
        }
    }

    private func buildLayout() {
        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        let periodLabel = NSTextField(labelWithString: "Period:")
        periodLabel.font = .systemFont(ofSize: 12)
        periodLabel.translatesAutoresizingMaskIntoConstraints = false

        for p in Period.allCases { periodPopup.addItem(withTitle: p.title) }
        periodPopup.selectItem(at: Period.h24.rawValue)
        periodPopup.translatesAutoresizingMaskIntoConstraints = false

        totalLabel.font = .systemFont(ofSize: 12, weight: .medium)
        totalLabel.alignment = .right
        totalLabel.translatesAutoresizingMaskIntoConstraints = false

        toolbar.addSubview(periodLabel)
        toolbar.addSubview(periodPopup)
        toolbar.addSubview(totalLabel)

        chart.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.documentView = tableView

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toolbar)
        view.addSubview(chart)
        view.addSubview(scrollView)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44),

            periodLabel.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 14),
            periodLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            periodPopup.leadingAnchor.constraint(equalTo: periodLabel.trailingAnchor, constant: 8),
            periodPopup.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            periodPopup.widthAnchor.constraint(equalToConstant: 180),

            totalLabel.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -14),
            totalLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            chart.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            chart.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chart.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chart.heightAnchor.constraint(equalToConstant: 240),

            scrollView.topAnchor.constraint(equalTo: chart.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -4),

            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            statusLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
        ])
    }

    private func configureTable() {
        let cols: [(String, String, CGFloat)] = [
            ("app",   "Application", 320),
            ("in",    "Download",    150),
            ("out",   "Upload",      150),
            ("total", "Total",       160),
        ]
        for (id, title, width) in cols {
            let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            c.title = title
            c.width = width
            c.minWidth = 80
            c.sortDescriptorPrototype = NSSortDescriptor(key: id, ascending: id == "app")
            tableView.addTableColumn(c)
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 22
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = []
        tableView.style = .inset

        tableView.sortDescriptors = [NSSortDescriptor(key: "total", ascending: false)]
    }

    @objc private func periodChanged(_ sender: NSPopUpButton) {
        if let p = Period(rawValue: sender.indexOfSelectedItem) {
            period = p
            reload()
        }
    }

    private func reload() {
        guard let db = db else { return }
        let now = Int64(Date().timeIntervalSince1970)
        let curHour = (now / 3600) * 3600
        let from = curHour - Int64(period.hours - 1) * 3600
        do {
            data = try db.aggregate(fromHour: from, toHour: curHour)
        } catch {
            data = []
            statusLabel.stringValue = "Query error: \(error.localizedDescription)"
        }
        let total = data.reduce(UInt64(0)) { $0 + $1.bytesIn + $1.bytesOut }
        totalLabel.stringValue = "Total: \(humanBytes(total))"

        applySortAndRefresh()

        if data.isEmpty {
            statusLabel.stringValue = "No data yet — daemon needs ~2 minutes after first start to build a baseline."
        } else {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .medium
            statusLabel.stringValue = "\(data.count) apps · updated \(df.string(from: Date()))"
        }
    }

    private func applySortAndRefresh() {
        let descriptor = tableView.sortDescriptors.first
        let metric = SortMetric.from(descriptor?.key)
        let ascending = descriptor?.ascending ?? false

        switch metric {
        case .app:
            data.sort {
                let cmp = $0.app.localizedCaseInsensitiveCompare($1.app)
                return ascending ? cmp == .orderedAscending : cmp == .orderedDescending
            }
        case .bytesIn, .bytesOut, .total:
            data.sort {
                let a = metric.value(of: $0)
                let b = metric.value(of: $1)
                return ascending ? a < b : a > b
            }
        }

        let chartMetric = metric.chartFallback
        let topByMetric = data.sorted { chartMetric.value(of: $0) > chartMetric.value(of: $1) }
        chart.metric = chartMetric
        chart.entries = Array(topByMetric.prefix(10))
        chart.needsDisplay = true

        tableView.reloadData()
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { data.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let r = data[row]
        let cell = NSTextField(labelWithString: "")
        cell.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        cell.lineBreakMode = .byTruncatingTail
        switch tableColumn?.identifier.rawValue {
        case "app":
            cell.font = .systemFont(ofSize: 12)
            cell.stringValue = r.app
        case "in":
            cell.stringValue = humanBytes(r.bytesIn)
        case "out":
            cell.stringValue = humanBytes(r.bytesOut)
        case "total":
            cell.stringValue = humanBytes(r.bytesIn + r.bytesOut)
        default:
            cell.stringValue = ""
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        applySortAndRefresh()
    }
}
