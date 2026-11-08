import AppKit
import EzanCore
import ServiceManagement

struct District: Codable {
    let name: String
    let id: String
    let lat: Double
    let lon: Double
}

struct Province: Codable {
    let name: String
    let districts: [District]
}

private let turkish = Locale(identifier: "tr_TR")
private let turkeyTimeZone = TimeZone(identifier: "Europe/Istanbul")!

private func pretty(_ name: String) -> String { name.capitalized(with: turkish) }

private func dateFormatter(calendar: Calendar.Identifier, format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = turkish
    formatter.calendar = Calendar(identifier: calendar)
    formatter.timeZone = turkeyTimeZone
    formatter.dateFormat = format
    return formatter
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let defaultDistrictID = "9541"  // İstanbul merkez

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let locationMenu = NSMenu()
    private let longDate = dateFormatter(calendar: .gregorian, format: "d MMMM yyyy EEEE")
    private let hijriDate = dateFormatter(calendar: .islamicUmmAlQura, format: "d MMMM y")

    private var provinces: [Province] = []
    private var districtID = AppDelegate.defaultDistrictID
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        provinces = loadProvinces()
        districtID = UserDefaults.standard.string(forKey: "districtID") ?? Self.defaultDistrictID

        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        rebuildLocationMenu()

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self, selector: #selector(tick), name: NSWorkspace.didWakeNotification, object: nil)
        for name in [Notification.Name.NSSystemClockDidChange, .NSCalendarDayChanged] {
            NotificationCenter.default.addObserver(
                self, selector: #selector(tick), name: name, object: nil)
        }
        tick()
    }

    // MARK: Geri sayım

    private func currentDistrict() -> (province: Province, district: District)? {
        for province in provinces {
            if let district = province.districts.first(where: { $0.id == districtID }) {
                return (province, district)
            }
        }
        return nil
    }

    private func schedule(around now: Date) -> Schedule {
        guard let district = currentDistrict()?.district else { return Schedule() }
        return Schedule(
            around: now, at: Coordinate(latitude: district.lat, longitude: district.lon))
    }

    @objc private func tick() {
        timer?.invalidate()
        let now = Date()

        var delay: TimeInterval = 60
        if let next = schedule(around: now).next(after: now) {
            statusItem.button?.title =
                "\(next.prayer.dativeTitle) \(remainingText(from: now, to: next.date))"
            delay = secondsUntilDisplayChange(from: now, to: next.date) + 0.05
        } else {
            statusItem.button?.title = "Ezan –"
        }

        let newTimer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in self?.tick() }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func loadProvinces() -> [Province] {
        guard let url = Bundle.main.url(forResource: "locations", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let list = try? JSONDecoder().decode([Province].self, from: data)
        else { return [] }
        return list
    }

    // MARK: Menü

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        menu.removeAllItems()
        let now = Date()
        let schedule = schedule(around: now)

        if let day = schedule.day(for: now) {
            menu.addItem(infoItem(longDate.string(from: now)))
            menu.addItem(infoItem(hijriDate.string(from: now)))
            menu.addItem(.separator())
            let next = schedule.next(after: now)
            let nextIsToday = next.map { schedule.moment(of: $0.prayer, on: day) == $0.date } ?? false
            for prayer in Prayer.allCases {
                menu.addItem(timeRow(prayer, time: day.time(of: prayer),
                                     highlighted: nextIsToday && next?.prayer == prayer))
            }
        } else {
            menu.addItem(infoItem("Konum okunamadı, listeden yeniden seç."))
        }

        menu.addItem(.separator())
        let location = NSMenuItem(title: currentLocationTitle(), action: nil, keyEquivalent: "")
        location.submenu = locationMenu
        menu.addItem(location)

        let login = NSMenuItem(
            title: "Oturum açılınca başlat", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Çıkış", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func timeRow(_ prayer: Prayer, time: String, highlighted: Bool) -> NSMenuItem {
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: 150)]
        let size = NSFont.menuFont(ofSize: 0).pointSize
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.attributedTitle = NSAttributedString(
            string: "\(prayer.title)\t\(time)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: size, weight: highlighted ? .bold : .regular),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style,
            ])
        // Pasif öğeleri macOS grileştirir; vakitler okunaklı kalsın diye etkin tutulur.
        item.target = self
        item.action = #selector(timeRowClicked)
        return item
    }

    @objc private func timeRowClicked() {}

    private func currentLocationTitle() -> String {
        guard let current = currentDistrict() else { return "Konum seç" }
        let il = pretty(current.province.name)
        let ilce = pretty(current.district.name)
        return il == ilce ? il : "\(ilce), \(il)"
    }

    private func rebuildLocationMenu() {
        locationMenu.removeAllItems()
        for province in provinces {
            let item = NSMenuItem(title: pretty(province.name), action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for district in province.districts {
                let row = NSMenuItem(
                    title: pretty(district.name), action: #selector(selectDistrict(_:)),
                    keyEquivalent: "")
                row.target = self
                row.representedObject = district.id
                row.state = district.id == districtID ? .on : .off
                sub.addItem(row)
            }
            item.submenu = sub
            item.state = province.districts.contains { $0.id == districtID } ? .mixed : .off
            locationMenu.addItem(item)
        }
    }

    @objc private func selectDistrict(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, id != districtID else { return }
        districtID = id
        UserDefaults.standard.set(id, forKey: "districtID")
        rebuildLocationMenu()
        tick()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Başlangıç ayarı değiştirilemedi"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
