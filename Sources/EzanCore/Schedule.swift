import Foundation

public enum Prayer: CaseIterable {
    case imsak, gunes, ogle, ikindi, aksam, yatsi

    public var title: String {
        switch self {
        case .imsak: return "İmsak"
        case .gunes: return "Güneş"
        case .ogle: return "Öğle"
        case .ikindi: return "İkindi"
        case .aksam: return "Akşam"
        case .yatsi: return "Yatsı"
        }
    }

    /// Üst bardaki geri sayım için yönelme hali. Vakit adları cins isim olduğundan
    /// kesme işareti almaz; imsak ince k ile okunduğu için ek de incedir (TDK: imsa:ki).
    public var dativeTitle: String {
        switch self {
        case .imsak: return "İmsake"
        case .gunes: return "Güneşe"
        case .ogle: return "Öğleye"
        case .ikindi: return "İkindiye"
        case .aksam: return "Akşama"
        case .yatsi: return "Yatsıya"
        }
    }

    /// Güneş vakti için ezan okunmaz, geri sayımda atlanır.
    public var hasAdhan: Bool { self != .gunes }
}

/// Bir günün vakitleri; saatler "SS:dd" biçimindedir.
public struct DayTimes: Equatable {
    public let date: String  // gg.aa.yyyy
    public let imsak, gunes, ogle, ikindi, aksam, yatsi: String

    public init(
        date: String, imsak: String, gunes: String, ogle: String, ikindi: String, aksam: String,
        yatsi: String
    ) {
        self.date = date
        self.imsak = imsak
        self.gunes = gunes
        self.ogle = ogle
        self.ikindi = ikindi
        self.aksam = aksam
        self.yatsi = yatsi
    }

    public func time(of prayer: Prayer) -> String {
        switch prayer {
        case .imsak: return imsak
        case .gunes: return gunes
        case .ogle: return ogle
        case .ikindi: return ikindi
        case .aksam: return aksam
        case .yatsi: return yatsi
        }
    }
}

public struct NextPrayer: Equatable {
    public let prayer: Prayer
    public let date: Date
}

/// Vakitler Türkiye saatiyle yayımlanır; Mac başka saat dilimindeyse de kalan süre doğru kalır.
public struct Schedule {
    public let days: [String: DayTimes]
    private let calendar: Calendar

    public init(days: [DayTimes] = []) {
        self.calendar = Schedule.turkeyCalendar
        self.days = Dictionary(days.map { ($0.date, $0) }, uniquingKeysWith: { _, new in new })
    }

    /// Bugünün ve yarının vakitlerini verilen konum için hesaplar.
    public init(around now: Date, at coordinate: Coordinate) {
        let calendar = Schedule.turkeyCalendar
        let days = (0...1).map { offset -> DayTimes in
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            return PrayerCalculator.times(year: c.year!, month: c.month!, day: c.day!, at: coordinate)
        }
        self.init(days: days)
    }

    private static let turkeyCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    public func day(for date: Date) -> DayTimes? {
        let c = calendar.dateComponents([.day, .month, .year], from: date)
        return days[String(format: "%02d.%02d.%04d", c.day!, c.month!, c.year!)]
    }

    public func moment(of prayer: Prayer, on day: DayTimes) -> Date? {
        let d = day.date.split(separator: ".").compactMap { Int($0) }
        let t = day.time(of: prayer).split(separator: ":").compactMap { Int($0) }
        guard d.count == 3, t.count == 2 else { return nil }
        return calendar.date(
            from: DateComponents(year: d[2], month: d[1], day: d[0], hour: t[0], minute: t[1]))
    }

    /// Ezanı okunacak ilk vakit. Bugünün veya gerekli olan yarının verisi yoksa nil döner.
    public func next(after now: Date) -> NextPrayer? {
        for offset in 0...1 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: now),
                let day = day(for: date)
            else { return nil }
            for prayer in Prayer.allCases where prayer.hasAdhan {
                if let moment = moment(of: prayer, on: day), moment > now {
                    return NextPrayer(prayer: prayer, date: moment)
                }
            }
        }
        return nil
    }
}

/// Kalan süre yukarı yuvarlanır: 30 saniye kaldıysa "1 dk" görünür.
public func remainingText(from now: Date, to target: Date) -> String {
    let minutes = Int((target.timeIntervalSince(now) / 60).rounded(.up))
    if minutes < 60 { return "\(minutes) dk" }
    let rest = minutes % 60
    return rest == 0 ? "\(minutes / 60) sa" : "\(minutes / 60) sa \(rest) dk"
}

/// Gösterilen dakikanın değişmesine kalan saniye.
public func secondsUntilDisplayChange(from now: Date, to target: Date) -> TimeInterval {
    let rest = target.timeIntervalSince(now).truncatingRemainder(dividingBy: 60)
    return rest > 0 ? rest : 60
}
