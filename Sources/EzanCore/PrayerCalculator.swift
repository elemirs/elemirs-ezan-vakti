import Foundation

public struct Coordinate: Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Diyanet usulüyle namaz vakti hesabı.
///
/// - İmsak: Güneş ufkun 18° altında. Yatsı: 17° altında.
/// - Güneş ve akşam: Güneş'in üst kenarı ufukta (kırılma dahil 0,8333°).
/// - İkindi: gölge boyu, öğle gölgesi + cismin boyu (asr-ı evvel).
/// - Temkin: güneş −7, öğle +5, ikindi +4, akşam +7 dakika.
/// - Güneş'in deklinasyonu ve zaman denklemi gün boyu sabittir; o günün 00:00 UT değeri kullanılır.
///   Diyanet'in 2026 vakitleriyle ölçülünce akşam ve yatsıdaki mevsimsel sapmayı bu kural kaldırıyor.
public enum PrayerCalculator {
    private static let utcOffsetHours = 3.0
    private static let imsakAngle = -18.0
    private static let yatsiAngle = -17.0
    private static let horizonAngle = -0.8333

    public static func times(
        year: Int, month: Int, day: Int, at coordinate: Coordinate
    ) -> DayTimes {
        let sun = solarPosition(julianDay: julianDay(year: year, month: month, day: day))
        let latitude = coordinate.latitude * .pi / 180
        let noon = 12 + utcOffsetHours - coordinate.longitude / 15 - sun.equationOfTimeMinutes / 60

        func hours(altitudeDegrees: Double) -> Double {
            let altitude = altitudeDegrees * .pi / 180
            let cosine =
                (sin(altitude) - sin(latitude) * sin(sun.declination))
                / (cos(latitude) * cos(sun.declination))
            return acos(min(1, max(-1, cosine))) * 180 / .pi / 15
        }

        let asrAltitude = atan(1 / (1 + tan(abs(latitude - sun.declination)))) * 180 / .pi

        return DayTimes(
            date: String(format: "%02d.%02d.%04d", day, month, year),
            imsak: clock(noon - hours(altitudeDegrees: imsakAngle), temkin: 0),
            gunes: clock(noon - hours(altitudeDegrees: horizonAngle), temkin: -7),
            ogle: clock(noon, temkin: 5),
            ikindi: clock(noon + hours(altitudeDegrees: asrAltitude), temkin: 4),
            aksam: clock(noon + hours(altitudeDegrees: horizonAngle), temkin: 7),
            yatsi: clock(noon + hours(altitudeDegrees: yatsiAngle), temkin: 0))
    }

    private static func clock(_ hours: Double, temkin: Int) -> String {
        let minutes = Int((hours * 60).rounded()) + temkin
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// Verilen miladi günün 00:00 UT anının Jülyen günü (Meeus).
    private static func julianDay(year: Int, month: Int, day: Int) -> Double {
        let y = month <= 2 ? year - 1 : year
        let m = month <= 2 ? month + 12 : month
        let a = y / 100
        let b = 2 - a + a / 4
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1))
            + Double(day + b) - 1524.5
    }

    /// Güneş'in deklinasyonu (radyan) ve zaman denklemi (dakika); NOAA/Meeus formülleri.
    private static func solarPosition(
        julianDay: Double
    ) -> (declination: Double, equationOfTimeMinutes: Double) {
        let t = (julianDay - 2451545.0) / 36525
        let meanLongitude = (280.46646 + t * (36000.76983 + t * 0.0003032))
            .truncatingRemainder(dividingBy: 360)
        let meanAnomaly = (357.52911 + t * (35999.05029 - 0.0001537 * t)) * .pi / 180
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let center =
            sin(meanAnomaly) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * meanAnomaly) * (0.019993 - 0.000101 * t)
            + sin(3 * meanAnomaly) * 0.000289
        let omega = (125.04 - 1934.136 * t) * .pi / 180
        let apparentLongitude =
            (meanLongitude + center - 0.00569 - 0.00478 * sin(omega)) * .pi / 180
        let meanObliquity =
            23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquity = (meanObliquity + 0.00256 * cos(omega)) * .pi / 180

        let declination = asin(sin(obliquity) * sin(apparentLongitude))

        let y = pow(tan(obliquity / 2), 2)
        let l0 = meanLongitude * .pi / 180
        let equation =
            y * sin(2 * l0)
            - 2 * eccentricity * sin(meanAnomaly)
            + 4 * eccentricity * y * sin(meanAnomaly) * cos(2 * l0)
            - 0.5 * y * y * sin(4 * l0)
            - 1.25 * eccentricity * eccentricity * sin(2 * meanAnomaly)
        return (declination, 4 * equation * 180 / .pi)
    }
}
