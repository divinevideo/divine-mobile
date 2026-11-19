import SwiftUI
import XCTest
@testable import Runner

/// Renders the post Live Activity presentations and checks their copy, using
/// the widget extension's own bundle so strings resolve as they do on device.
@available(iOS 16.2, *)
@MainActor
final class PostActivityViewsTests: XCTestCase {
    private var widgetBundle: Bundle!

    override func setUpWithError() throws {
        let url = try XCTUnwrap(Bundle.main.builtInPlugInsURL)
            .appendingPathComponent("CameraQuickActionWidget.appex")
        widgetBundle = try XCTUnwrap(Bundle(url: url), "widget extension not embedded")
    }

    private let attributes = PostActivityAttributes(
        ownerPubkey: String(repeating: "cd", count: 32),
        postCoordinate: "34236:\(String(repeating: "cd", count: 32)):post",
        postEventId: String(repeating: "ab", count: 32),
        thumbnailFileName: nil,
        postedAt: Date(timeIntervalSince1970: 1_800_000_000)
    )

    private func state(
        _ phase: PostActivityPhase,
        views: Int? = nil,
        likes: Int? = nil,
        comments: Int? = nil
    ) -> PostActivityContentState {
        PostActivityContentState(
            phase: phase,
            views: views,
            likes: likes,
            comments: comments,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_600),
            showFirstRunNote: false
        )
    }

    /// One state per headline, in the mapping's own terms.
    private var statesByHeadline: [(PostActivityHeadline, PostActivityContentState)] {
        [
            (.posting, state(.posting)),
            (.live, state(.live, views: 48, likes: 9, comments: 2)),
            (.noViewsYet, state(.live, views: 0, likes: 0, comments: 0)),
            (.cantFind, state(.notFound)),
            (.firstHour, state(.summary, views: 212, likes: 31, comments: 6)),
            (.noViewsFirstHour, state(.summary, views: 0, likes: 0, comments: 0)),
        ]
    }

    private func lockScreen(_ state: PostActivityContentState) -> PostActivityLockScreenView {
        PostActivityLockScreenView(
            attributes: attributes,
            display: PostActivityDisplay.make(state: state, isStale: false),
            state: state,
            thumbnail: nil,
            bundle: widgetBundle
        )
    }

    private func render<V: View>(_ view: V) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage
    }

    func testLockScreenRendersEveryHeadlineInDarkAndLight() throws {
        for (headline, state) in statesByHeadline {
            XCTAssertEqual(PostActivityDisplay.make(state: state, isStale: false).headline, headline)
            for scheme in [ColorScheme.dark, .light] {
                let image = try XCTUnwrap(
                    render(lockScreen(state).frame(width: 360).environment(\.colorScheme, scheme)),
                    "\(headline) in \(scheme) did not render"
                )
                XCTAssertGreaterThan(image.size.width, 0)
                XCTAssertGreaterThan(image.size.height, 0)
            }
        }
    }

    func testCompactTrailingFitsWithLargeGermanCount() throws {
        // Int.max is long even in compact form, so this fails if the
        // trailing view stops capping its width.
        let big = state(.live, views: 9_876_543, likes: Int.max)
        let view = PostActivityCompactTrailingView(
            display: PostActivityDisplay.make(state: big, isStale: false),
            updatedAt: big.updatedAt,
            bundle: widgetBundle
        )
        .environment(\.locale, Locale(identifier: "de_DE"))
        let image = try XCTUnwrap(render(view))
        XCTAssertLessThanOrEqual(image.size.width, 64)
    }

    /// Height of a headline laid out in the Lock Screen's headline width.
    private func headlineHeight(
        _ headline: PostActivityHeadline,
        locale: String,
        typeSize: DynamicTypeSize = .large
    ) throws -> CGFloat {
        let view = PostActivityHeadlineText(
            headline: headline,
            postedAt: Date(),
            bundle: widgetBundle
        )
        .font(.headline)
        .frame(width: 265, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.locale, Locale(identifier: locale))
        .environment(\.dynamicTypeSize, typeSize)
        return try XCTUnwrap(render(view)).size.height
    }

    /// The messages that matter most are the longest ones; they must wrap to
    /// a second line rather than be cut off mid-word.
    func testLongHeadlineWrapsInsteadOfTruncating() throws {
        let oneLine = try headlineHeight(.firstHour, locale: "fr")
        let long = try headlineHeight(.cantFind, locale: "fr")
        XCTAssertGreaterThan(long, oneLine * 1.5)
    }

    func testHeadlineWrapsAtAccessibilityTextSize() throws {
        let oneLine = try headlineHeight(.firstHour, locale: "en", typeSize: .accessibility3)
        let long = try headlineHeight(.cantFind, locale: "en", typeSize: .accessibility3)
        XCTAssertGreaterThan(long, oneLine * 1.5)
    }

    func testEveryKeyResolvesInEnglish() throws {
        let path = try XCTUnwrap(widgetBundle.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: nil,
            forLocalization: "en"
        ))
        let table = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
        for key in PostActivityStrings.keys {
            let value = try XCTUnwrap(table[key], "missing English string for \(key)")
            XCTAssertNotEqual(value, key)
            XCTAssertFalse(value.isEmpty, key)
        }
    }

    // MARK: - Translations

    private var widgetLocalizations: [String] {
        widgetBundle.localizations.filter { $0 != "Base" }.sorted()
    }

    private func table(_ type: String, for localization: String) -> [String: Any]? {
        guard let path = widgetBundle.path(
            forResource: "Localizable",
            ofType: type,
            inDirectory: nil,
            forLocalization: localization
        ) else { return nil }
        return NSDictionary(contentsOfFile: path) as? [String: Any]
    }

    /// The widget's .strings files have no other guard, so this is it: every
    /// key in every localization the widget ships.
    func testEveryKeyExistsInEveryWidgetLocale() {
        XCTAssertEqual(
            widgetLocalizations,
            ["am", "ar", "bg", "de", "en", "es", "fil", "fr", "id", "it",
             "ja", "ko", "nl", "pl", "pt", "ro", "sv", "tr"]
        )
        for localization in widgetLocalizations {
            let strings = table("strings", for: localization) ?? [:]
            for key in PostActivityStrings.keys {
                let value = strings[key] as? String
                XCTAssertNotNil(value, "\(localization) is missing \(key)")
                XCTAssertNotEqual(value, key, "\(localization) leaves \(key) untranslated")
            }
            let plurals = table("stringsdict", for: localization) ?? [:]
            for key in PostActivityStrings.pluralKeys {
                XCTAssertNotNil(plurals[key], "\(localization) is missing plural \(key)")
            }
        }
    }

    func testPluralsReadCorrectlyInEnglish() throws {
        let english = try XCTUnwrap(
            widgetBundle.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
        )
        let format = english.localizedString(
            forKey: PostActivityStrings.pluralKeys[0],
            value: nil,
            table: nil
        )
        let locale = Locale(identifier: "en")
        XCTAssertEqual(String(format: format, locale: locale, 1), "1 view")
        XCTAssertEqual(String(format: format, locale: locale, 2), "2 views")
    }

    func testPlaceholdersSurviveTranslation() {
        let placeholderKeys = PostActivityStrings.keys.filter { $0.contains("%@") }
        XCTAssertFalse(placeholderKeys.isEmpty)
        for localization in widgetLocalizations {
            let strings = table("strings", for: localization) ?? [:]
            for key in placeholderKeys {
                guard let value = strings[key] as? String else { continue }
                XCTAssertEqual(
                    value.components(separatedBy: "%@").count - 1,
                    1,
                    "\(localization) \(key) must keep exactly one %@"
                )
            }
        }
    }

    func testAppDeclaresLiveActivitySupport() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool,
            true
        )
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivitiesFrequentUpdates"))
    }
}
