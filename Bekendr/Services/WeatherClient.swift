import Foundation
import Observation

/// Het weer van nu bij een locatie, van Open-Meteo (gratis, zonder sleutel; CC BY 4.0).
struct CurrentWeather: Equatable {
    let temperature: Double
    let code: Int
    let isDay: Bool

    var symbol: String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 61...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    var description: String {
        switch code {
        case 0: "Onbewolkt"
        case 1: "Licht bewolkt"
        case 2: "Half bewolkt"
        case 3: "Bewolkt"
        case 45, 48: "Mist"
        case 51...57: "Motregen"
        case 61...65: "Regen"
        case 66, 67: "IJzel"
        case 71...77: "Sneeuw"
        case 80...82: "Buien"
        case 85, 86: "Sneeuwbuien"
        case 95...99: "Onweer"
        default: "Wisselend"
        }
    }

    var temperatureText: String { "\(Int(temperature.rounded()))°" }
}

@MainActor
@Observable
final class WeatherStore {
    static let shared = WeatherStore()
    private(set) var byKey: [String: CurrentWeather] = [:]
    private var fetched: [String: Date] = [:]

    func weather(for key: String) -> CurrentWeather? { byKey[key] }

    func load(key: String, latitude: Double, longitude: Double) async {
        if let at = fetched[key], Date().timeIntervalSince(at) < 1800 { return }
        fetched[key] = Date()
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            .init(name: "latitude", value: String(format: "%.3f", latitude)),
            .init(name: "longitude", value: String(format: "%.3f", longitude)),
            .init(name: "current", value: "temperature_2m,weather_code,is_day"),
            .init(name: "timezone", value: "Europe/Amsterdam"),
        ]
        guard let url = c.url, let (data, _) = try? await URLSession.shared.data(from: url),
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cur = o["current"] as? [String: Any],
              let t = (cur["temperature_2m"] as? NSNumber)?.doubleValue,
              let code = (cur["weather_code"] as? NSNumber)?.intValue else {
            fetched[key] = nil
            return
        }
        byKey[key] = CurrentWeather(temperature: t, code: code, isDay: ((cur["is_day"] as? NSNumber)?.intValue ?? 1) == 1)
    }
}
