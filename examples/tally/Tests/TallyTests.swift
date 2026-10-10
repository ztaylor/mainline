import Testing
@testable import Tally

struct CounterTests {
    @Test func startsAtZero() {
        #expect(Counter(name: "Water").count == 0)
    }

    @Test func incrementAndDecrement() {
        let counter = Counter(name: "Push-ups")
        counter.increment()
        counter.increment(by: 5)
        #expect(counter.count == 6)
        counter.decrement()
        #expect(counter.count == 5)
    }

    @Test func neverGoesNegative() {
        let counter = Counter(name: "Coffee", count: 1)
        counter.decrement(by: 3)
        #expect(counter.count == 0)
        #expect(Counter(name: "Bad input", count: -4).count == 0)
    }

    @Test func reset() {
        let counter = Counter(name: "Pages", count: 128)
        counter.reset()
        #expect(counter.count == 0)
    }

    @Test(arguments: CounterColor.allCases)
    func colorRoundTrips(_ color: CounterColor) {
        let counter = Counter(name: "c", color: color)
        #expect(counter.color == color)
        #expect(counter.colorName == color.rawValue)
    }

    @Test func unknownStoredColorFallsBack() {
        let counter = Counter(name: "c")
        counter.colorName = "chartreuse"
        #expect(counter.color == .orange)
    }
}
