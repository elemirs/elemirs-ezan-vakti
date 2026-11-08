import XCTest

@testable import EzanCore

final class ScheduleTests: XCTestCase {
    private let day1 = DayTimes(
        date: "08.11.2026", imsak: "06:10", gunes: "07:36", ogle: "12:53",
        ikindi: "15:35", aksam: "18:00", yatsi: "19:21")
    private let day2 = DayTimes(
        date: "09.11.2026", imsak: "06:11", gunes: "07:37", ogle: "12:53",
        ikindi: "15:34", aksam: "17:59", yatsi: "19:20")

    private func at(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: text + "+03:00")!
    }

    func testPicksNextPrayerOfToday() {
        let next = Schedule(days: [day1, day2]).next(after: at("2026-11-08T17:39:23"))
        XCTAssertEqual(next?.prayer, .aksam)
        XCTAssertEqual(next?.date, at("2026-11-08T18:00:00"))
    }

    func testSkipsSunriseBecauseItHasNoAdhan() {
        let next = Schedule(days: [day1, day2]).next(after: at("2026-11-08T07:00:00"))
        XCTAssertEqual(next?.prayer, .ogle)
    }

    func testAfterYatsiCountsToTomorrowImsak() {
        let next = Schedule(days: [day1, day2]).next(after: at("2026-11-08T23:30:00"))
        XCTAssertEqual(next?.prayer, .imsak)
        XCTAssertEqual(next?.date, at("2026-11-09T06:11:00"))
    }

    func testExactAdhanMomentMovesToFollowingPrayer() {
        let next = Schedule(days: [day1, day2]).next(after: at("2026-11-08T18:00:00"))
        XCTAssertEqual(next?.prayer, .yatsi)
    }

    func testMissingDataReturnsNil() {
        XCTAssertNil(Schedule(days: [day1]).next(after: at("2026-11-08T23:30:00")))
        XCTAssertNil(Schedule(days: [day2]).next(after: at("2026-11-08T12:00:00")))
    }

    func testDayBoundaryUsesTurkeyTime() {
        // 21:30 UTC = Türkiye'de ertesi gün 00:30
        let now = ISO8601DateFormatter().date(from: "2026-11-08T21:30:00Z")!
        XCTAssertEqual(Schedule(days: [day1, day2]).next(after: now)?.date, at("2026-11-09T06:11:00"))
    }

    func testRemainingText() {
        let target = at("2026-11-08T18:00:00")
        XCTAssertEqual(remainingText(from: at("2026-11-08T17:59:30"), to: target), "1 dk")
        XCTAssertEqual(remainingText(from: at("2026-11-08T17:39:23"), to: target), "21 dk")
        XCTAssertEqual(remainingText(from: at("2026-11-08T17:00:00"), to: target), "1 sa")
        XCTAssertEqual(remainingText(from: at("2026-11-08T15:44:30"), to: target), "2 sa 16 dk")
    }

    func testDisplayChangesExactlyWhenRoundedMinuteDrops() {
        let target = at("2026-11-08T18:00:00")
        XCTAssertEqual(secondsUntilDisplayChange(from: at("2026-11-08T17:39:23"), to: target), 37)
        XCTAssertEqual(secondsUntilDisplayChange(from: at("2026-11-08T17:58:00"), to: target), 60)
    }

    func testDativeTitles() {
        XCTAssertEqual(
            [Prayer.imsak, .ogle, .ikindi, .aksam, .yatsi].map(\.dativeTitle),
            ["İmsake", "Öğleye", "İkindiye", "Akşama", "Yatsıya"])
    }

    /// Beklenen değerler Diyanet'in 2026 İstanbul takviminden alındı. Diyanet'in referans
    /// noktası bizim koordinatla birebir aynı olmadığından 1 dakikaya kadar fark olabilir.
    func testCalculatorStaysWithinOneMinuteOfDiyanet() {
        let istanbul = Coordinate(latitude: 41.01, longitude: 28.9603)
        let expected = [
            (2026, 11, 8, ["06:09", "07:36", "12:53", "15:34", "18:00", "19:21"]),
            (2026, 7, 20, ["03:50", "05:42", "13:15", "17:13", "20:39", "22:22"]),
            (2026, 12, 21, ["06:46", "08:18", "13:07", "15:25", "17:46", "19:12"]),
        ]
        func minutes(_ text: String) -> Int {
            let parts = text.split(separator: ":").map { Int($0)! }
            return parts[0] * 60 + parts[1]
        }
        for (year, month, day, times) in expected {
            let result = PrayerCalculator.times(year: year, month: month, day: day, at: istanbul)
            for (prayer, time) in zip(Prayer.allCases, times) {
                XCTAssertLessThanOrEqual(
                    abs(minutes(result.time(of: prayer)) - minutes(time)), 1,
                    "\(day).\(month) \(prayer.title)")
            }
        }
    }

    func testCalculatedScheduleCountsToTomorrowAfterYatsi() {
        let istanbul = Coordinate(latitude: 41.01, longitude: 28.9603)
        let next = Schedule(around: at("2026-11-08T23:30:00"), at: istanbul)
            .next(after: at("2026-11-08T23:30:00"))
        XCTAssertEqual(next?.prayer, .imsak)
        XCTAssertEqual(next?.date, at("2026-11-09T06:10:00"))
    }
}
