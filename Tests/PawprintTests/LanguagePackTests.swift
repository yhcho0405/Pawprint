import XCTest
import PawprintCore
@testable import Pawprint

/// What every language pack has to be true of, whatever state its translation is in.
///
/// The packs are hand-written JSON, and the two mistakes that matter are silent: a translation that
/// drops a `%@` renders the wrong number of values into the wrong places, and a key that exists in
/// no pack shows a raw hash to somebody. Both are cheap to check and impossible to notice by
/// reading.
final class LanguagePackTests: XCTestCase {

    /// Read from the repository rather than through `loadPackFile`, which searches `Bundle.main` —
    /// and `Bundle.main` under `swift test` is the test runner, which carries no packs. The files
    /// are the thing being checked, so reading them is also the more direct question.
    private static let packDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // PawprintTests
        .deletingLastPathComponent()      // Tests
        .deletingLastPathComponent()      // repository root
        .appendingPathComponent("Sources/Pawprint/Resources/Localization")

    private func pack(_ code: String) throws -> [String: String] {
        let url = Self.packDirectory.appendingPathComponent("\(code).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: String].self, from: data)
    }

    /// Every language the picker offers has a file behind it.
    func testEveryOfferedLanguageHasAPack() throws {
        for language in AppLanguage.allCases {
            guard let code = language.code else { continue }
            XCTAssertTrue(AppLanguage.availableCodes.contains(code),
                          "\(language) is offered but not in availableCodes")
            XCTAssertFalse(try pack(code).isEmpty, "\(code).json is empty")
        }
    }

    /// A translation must render exactly the values its English original does. One `%@` too few
    /// silently drops a number; one too many renders garbage into the sentence.
    func testPlaceholdersMatchEnglish() throws {
        let english = try pack("en")
        for code in AppLanguage.availableCodes where code != "en" {
            for (key, translated) in try pack(code) {
                guard let original = english[key] else { continue }
                XCTAssertEqual(translated.components(separatedBy: "%@").count,
                               original.components(separatedBy: "%@").count,
                               "\(code) \(key): '%@' count differs from English")
                for specifier in ["%.0f", "%.1f", "%d"] {
                    XCTAssertEqual(translated.contains(specifier), original.contains(specifier),
                                   "\(code) \(key): '\(specifier)' differs from English")
                }
            }
        }
    }

    /// A literal percent sign is written `%%`, and only `%%`.
    ///
    /// These templates reach `String(format:)` exactly once — `L10n.t` only substitutes `%@` — so
    /// `%%` collapses to one percent and `%%%%` collapses to two. English shipped `%.2f%%%%` from
    /// the beginning and rendered "about 0.0035%% of the Earth's circumference"; Japanese and
    /// German inherited it when they were translated from the English pack.
    func testALiteralPercentIsWrittenExactlyTwice() throws {
        for code in AppLanguage.availableCodes {
            for (key, text) in try pack(code) {
                XCTAssertFalse(text.contains("%%%"), "\(code) \(key): renders more than one percent")
            }
        }
    }

    /// Every language marks a percentage in the same places as the base pack does.
    func testPercentSignsMatchTheBasePack() throws {
        let korean = try pack("ko")
        for code in AppLanguage.availableCodes where code != "ko" {
            for (key, text) in try pack(code) {
                guard let original = korean[key] else { continue }
                XCTAssertEqual(text.components(separatedBy: "%%").count,
                               original.components(separatedBy: "%%").count,
                               "\(code) \(key): '%%' count differs from the base pack")
            }
        }
    }

    /// A pack may be incomplete — that is what the English fallback is for — but it may not contain
    /// keys that exist nowhere else, which are typos rather than translations.
    func testNoPackInventsKeys() throws {
        let korean = try pack("ko")
        for code in AppLanguage.availableCodes where code != "ko" {
            let unknown = try pack(code).keys.filter { korean[$0] == nil }.sorted()
            XCTAssertTrue(unknown.isEmpty, "\(code) has keys no other pack knows: \(unknown.prefix(5))")
        }
    }

    /// Korean is the canonical key set and terminal fallback, while English is the first display
    /// fallback for non-English packs. Both therefore have to remain complete and in sync.
    func testTheBasePackIsComplete() throws {
        let korean = try pack("ko")
        let english = try pack("en")
        XCTAssertEqual(Set(korean.keys), Set(english.keys),
                       "the base and English packs have drifted apart")
    }

    /// Adventure is a user-facing mode in every language offered by Settings. Falling back to
    /// English for the whole feature makes the language picker misleading even though partial
    /// packs remain valid for unrelated, newly introduced strings.
    func testAdventureNamespaceIsCompleteInEveryLanguage() throws {
        let expected = Set(
            try pack("ko").keys.filter { $0.hasPrefix("adventure.") }
        )
        for code in AppLanguage.availableCodes {
            let actual = Set(
                try pack(code).keys.filter { $0.hasPrefix("adventure.") }
            )
            XCTAssertEqual(
                actual,
                expected,
                "\(code) is missing adventure UI translations"
            )
        }
    }

    /// Reports where each translation stands, so its coverage is a number rather than an
    /// impression. Not an assertion — a partial pack is a valid state, it just needs to be visible.
    func testCoverageIsReported() throws {
        let korean = try pack("ko")
        for code in AppLanguage.availableCodes.sorted() {
            let table = try pack(code)
            let covered = korean.keys.filter { table[$0] != nil }.count
            print("\(code): \(covered)/\(korean.count) keys "
                  + "(\(covered * 100 / max(1, korean.count))%)")
        }
    }
}
