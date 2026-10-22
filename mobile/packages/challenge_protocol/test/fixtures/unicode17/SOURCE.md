# Official Unicode 17 conformance data

These are public standards test files, not creator or campaign material.
Original bytes and the Unicode license are retained. Tests verify both data
hashes before decoding. Downloads occurred on 2026-10-22.

| File | Source | SHA-256 |
| --- | --- | --- |
| IdnaTestV2.txt | https://www.unicode.org/Public/17.0.0/idna/IdnaTestV2.txt | `beb5d0be20e896189b03209a82fdc34f06351502bbd4b8e2523583fc2954d9cf` |
| NormalizationTest.txt | https://www.unicode.org/Public/17.0.0/ucd/NormalizationTest.txt | `5019ffd530751a741900c849c0e010332f142a3612234639bd200b82138a87db` |
| LICENSE.txt | https://www.unicode.org/license.txt | `e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96` |

`unicode17_test.dart` runs all 6,391 non-comment IdnaTestV2 rows using the
nontransitional ASCII columns and all 20,034 NormalizationTest rows using all
five NFC column invariants. IDNA empty fields inherit the preceding Unicode
result/status as specified by the corpus header. Disabled WHATWG checks ignore
A4_1/A4_2 (DNS length), V2/V3 (hyphens), U1 (STD3), and X4_2 (empty label); all
other reported errors must reject the domain. URL-specific forbidden characters
and IPv4 parsing have separate signed parser/replay regressions.
