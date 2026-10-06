import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct MysticTests {
    private func date(_ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    @Test func signsFollowTheSun() {
        let calendar = Calendar(identifier: .gregorian)
        #expect(ZodiacSign.sign(on: date(3, 21), calendar: calendar) == .aries)
        #expect(ZodiacSign.sign(on: date(3, 20), calendar: calendar) == .pisces)
        #expect(ZodiacSign.sign(on: date(9, 26), calendar: calendar) == .libra)
        #expect(ZodiacSign.sign(on: date(12, 25), calendar: calendar) == .capricorn)
        #expect(ZodiacSign.sign(on: date(1, 5), calendar: calendar) == .capricorn)
        #expect(ZodiacSign.sign(on: date(1, 20), calendar: calendar) == .aquarius)
    }

    @Test func everyConstellationIsDrawable() {
        for sign in ZodiacSign.allCases {
            let figure = sign.constellation
            #expect(figure.stars.count >= 4, "\(sign)")
            #expect(figure.stars.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) }, "\(sign)")
            #expect(figure.lines.allSatisfy { $0.0 < figure.stars.count && $0.1 < figure.stars.count }, "\(sign)")
        }
    }

    @Test func oneCardAndAuraPerDay() {
        let calendar = Calendar(identifier: .gregorian)
        #expect(TarotCard.deck.count == 22)
        #expect(TarotCard.deck.map(\.number) == Array(0..<22))
        let morning = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: date(5, 4))!
        let night = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: date(5, 4))!
        #expect(TarotCard.card(for: morning, calendar: calendar) == TarotCard.card(for: night, calendar: calendar))
        #expect(AuraReading.reading(for: morning, calendar: calendar) == AuraReading.reading(for: night, calendar: calendar))
        // Across a month, the draws vary.
        let cards = Set((1...30).map { TarotCard.card(for: date(6, $0), calendar: calendar).number })
        #expect(cards.count >= 10)
    }

    @Test func newWidgetsAreInTheGallery() {
        #expect(WidgetCatalog.entries(in: .mystic).count >= 5)
        for kind in [WidgetKind.spiral, .charm, .label, .aura, .tarot, .zodiac, .eightBall, .candle] {
            #expect(WidgetCatalog.entries.contains { $0.kind == kind }, "\(kind)")
        }
        // Saved before these options existed.
        let old = try? JSONDecoder().decode(WidgetOptions.self, from: Data("{}".utf8))
        #expect(old?.charm == .heart)
        #expect(old?.zodiac == .leo)
    }
}
