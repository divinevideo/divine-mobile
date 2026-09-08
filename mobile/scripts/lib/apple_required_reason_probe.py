#!/usr/bin/env python3
"""Compare Apple's live required-reason catalogue with the pinned catalogue."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

CATALOGUE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    "data",
    "apple_required_reason_catalogue.json",
)


class PayloadError(ValueError):
    """Apple's payload could not be interpreted safely."""


def _pointer_reference(path: str) -> str | None:
    prefix = "/references/"
    suffix = "/title"
    if not path.startswith(prefix) or not path.endswith(suffix):
        return None
    encoded = path[len(prefix) : -len(suffix)]
    return encoded.replace("~1", "/").replace("~0", "~")


def _objective_c_titles(payload: dict) -> dict[str, str]:
    overrides = payload.get("variantOverrides", [])
    for override in overrides:
        patch = override.get("patch", [])
        if any(
            item.get("path") == "/identifier/interfaceLanguage"
            and item.get("value") == "occ"
            for item in patch
        ):
            titles = {}
            for item in patch:
                reference = _pointer_reference(item.get("path", ""))
                if reference and item.get("op") == "replace":
                    titles[reference] = item["value"]
            return titles
    raise PayloadError("Objective-C (occ) variant override is missing")


def _symbol(item: dict, references: dict, title_overrides: dict[str, str]) -> str:
    try:
        inline = item["content"][0]["inlineContent"][0]
    except (KeyError, IndexError, TypeError) as error:
        raise PayloadError("API list item has an unknown shape") from error
    if inline.get("type") == "codeVoice":
        return inline["code"].split("(", 1)[0]
    if inline.get("type") != "reference":
        raise PayloadError("API list item is neither code nor a reference")
    identifier = inline["identifier"]
    try:
        return title_overrides.get(identifier, references[identifier]["title"])
    except KeyError as error:
        raise PayloadError(f"unresolved symbol reference: {identifier}") from error


def extract(payload: dict) -> list[dict]:
    """Return comparable category, symbol, and reason-code data."""
    references = payload.get("references")
    if not isinstance(references, dict):
        raise PayloadError("references map is missing")
    objective_c_titles = _objective_c_titles(payload)
    sections = [
        section
        for section in payload.get("primaryContentSections", [])
        if section.get("kind") == "possibleValues"
    ]
    if len(sections) != 1:
        raise PayloadError("expected exactly one possibleValues section")

    values = sections[0].get("values")
    if not isinstance(values, list):
        raise PayloadError("category values list is missing")
    categories = []
    for value in values:
        lists = {part.get("type"): part for part in value.get("content", [])}
        try:
            api_items = lists["unorderedList"]["items"]
            reason_items = lists["termList"]["items"]
            category_id = value["name"]
        except (KeyError, TypeError) as error:
            raise PayloadError("category content has an unknown shape") from error

        swift = [_symbol(item, references, {}) for item in api_items]
        objective_c = [
            _symbol(item, references, objective_c_titles) for item in api_items
        ]
        reasons = []
        for item in reason_items:
            try:
                reasons.append(item["term"]["inlineContent"][0]["code"])
            except (KeyError, IndexError, TypeError) as error:
                raise PayloadError("reason-code item has an unknown shape") from error
        categories.append(
            {
                "id": category_id,
                "symbols": {
                    "swift": sorted(swift),
                    "objectiveC": sorted(objective_c),
                },
                "reasons": sorted(reasons),
            }
        )
    return sorted(categories, key=lambda category: category["id"])


def expected(catalogue: dict) -> list[dict]:
    result = []
    for category in catalogue["categories"]:
        result.append(
            {
                "id": category["id"],
                "symbols": {
                    "swift": sorted(category["symbols"]["swift"]),
                    "objectiveC": sorted(category["symbols"]["objectiveC"]),
                },
                "reasons": sorted(category["reasons"]),
            }
        )
    return sorted(result, key=lambda category: category["id"])


def _describe_delta(pinned: list[dict], apple: list[dict]) -> None:
    pinned_by_id = {category["id"]: category for category in pinned}
    apple_by_id = {category["id"]: category for category in apple}
    for category_id in sorted(set(pinned_by_id) | set(apple_by_id)):
        if category_id not in pinned_by_id:
            print(f"+ category {category_id}")
            continue
        if category_id not in apple_by_id:
            print(f"- category {category_id}")
            continue
        for language in ("swift", "objectiveC"):
            old = set(pinned_by_id[category_id]["symbols"][language])
            new = set(apple_by_id[category_id]["symbols"][language])
            for symbol in sorted(new - old):
                print(f"+ {category_id} {language} symbol {symbol}")
            for symbol in sorted(old - new):
                print(f"- {category_id} {language} symbol {symbol}")
        old_reasons = set(pinned_by_id[category_id]["reasons"])
        new_reasons = set(apple_by_id[category_id]["reasons"])
        for reason in sorted(new_reasons - old_reasons):
            print(f"+ {category_id} reason {reason}")
        for reason in sorted(old_reasons - new_reasons):
            print(f"- {category_id} reason {reason}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", help="read a saved DocC payload instead of fetching")
    args = parser.parse_args()
    try:
        with open(CATALOGUE_PATH, encoding="utf-8") as handle:
            catalogue = json.load(handle)
        if args.input:
            with open(args.input, encoding="utf-8") as handle:
                payload = json.load(handle)
        else:
            request = urllib.request.Request(
                catalogue["source"], headers={"User-Agent": "divine-mobile-ci/1"}
            )
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = json.load(response)
        pinned = expected(catalogue)
        apple = extract(payload)
    except (
        OSError, json.JSONDecodeError, PayloadError, urllib.error.URLError,
        KeyError, IndexError, TypeError, AttributeError,
    ) as error:
        # DocC shape changes are not evidence of a semantic catalogue delta.
        print(f"OPERATIONAL ERROR: could not verify Apple's catalogue: {error}")
        return 2

    if apple != pinned:
        print("CATALOGUE DRIFT: Apple's required-reason API list changed")
        _describe_delta(pinned, apple)
        return 1
    print("Apple's required-reason API catalogue matches the pinned data")
    return 0


if __name__ == "__main__":
    sys.exit(main())
