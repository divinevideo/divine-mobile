"""Small explicit store clients. Never retry a mutation after an ambiguous response."""

from __future__ import annotations

import base64
import hashlib
import json
import re
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from release_train.coordinator import unresolved_review_is_acknowledged, version_ack_key

APP_ID = "6747959501"
PACKAGE = "co.openvine.app"


class ProviderError(RuntimeError):
    def __init__(self, message, *, diagnostic=None):
        super().__init__(message)
        # Provider response details are private diagnostic data, never log text.
        self.diagnostic = diagnostic



class BeforeStoreMutationError(ProviderError):
    """Preparation failed before any store write was attempted."""


class DeferredReview(ProviderError):
    pass


class NotFound(ProviderError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class ArtifactRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urllib.parse.urlsplit(newurl)
        if parsed.scheme != "https" or parsed.username or parsed.password:
            raise ProviderError("Refusing insecure retained artifact redirect")
        # A signed storage URL may be returned by the authenticated provider.
        # No provider credentials accompany that redirect, including same-origin.
        return urllib.request.Request(newurl, method="GET")


def request_json(method, url, headers=None, body=None, *, timeout=60):
    headers = dict(headers or {})
    if isinstance(body, bytes):
        data = body
    elif body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    else:
        data = None
    request = urllib.request.Request(url, headers=headers, data=data, method=method)
    try:
        with urllib.request.build_opener(NoRedirect).open(
            request, timeout=timeout
        ) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        status = error.code
        raw = error.read(100000)
        error.close()
        diagnostic = None
        try:
            detail = json.loads(raw).get("error", {})
            reasons = [
                d.get("reason")
                for d in detail.get("details", []) + detail.get("errors", [])
                if isinstance(d, dict)
            ]
            # Retain only error fields; no headers, request bodies or metadata.
            diagnostic = {
                "code": status,
                "status": str(detail.get("status", ""))[:100],
                "message": str(detail.get("message", ""))[:2000],
                "reasons": [r[:100] for r in reasons if isinstance(r, str)][:20],
            }
        except (ValueError, TypeError, AttributeError):
            reasons = []
        if "CHANGES_ALREADY_IN_REVIEW" in reasons:
            raise DeferredReview("CHANGES_ALREADY_IN_REVIEW", diagnostic=diagnostic) from None
        if status == 404:
            raise NotFound("Provider resource not found (HTTP 404)", diagnostic=diagnostic) from None
        raise ProviderError(
            f"Provider request failed (HTTP {status}); inspect credentials, agreements, metadata or rate limits",
            diagnostic=diagnostic,
        ) from None
    except (OSError, ValueError, urllib.error.URLError) as error:
        timed_out = isinstance(error, TimeoutError) or isinstance(
            getattr(error, "reason", None), TimeoutError
        )
        detail = "Provider request timed out" if timed_out else "Provider response unavailable"
        raise ProviderError(
            detail + "; reconcile any mutation before retrying"
        ) from None


def b64(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode()


def signed_jwt(key, header, payload):
    """OpenSSL keeps private keys out of argv, logs and inherited environment."""
    text = (
        b64(json.dumps(header, separators=(",", ":")).encode())
        + "."
        + b64(json.dumps(payload, separators=(",", ":")).encode())
    )
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "key.pem"
        path.write_text(key.replace("\\n", "\n"))
        path.chmod(0o600)
        result = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", str(path)],
            input=text.encode(),
            capture_output=True,
            check=False,
        )
        if result.returncode:
            raise ProviderError("Could not sign provider authentication token")
        signature = result.stdout
    if header["alg"] == "ES256":
        # OpenSSL returns DER SEQUENCE(INTEGER r, INTEGER s); JWT uses fixed raw r||s.
        if signature[0] != 48 or signature[2] != 2:
            raise ProviderError("Invalid ECDSA signature")
        size = signature[3]
        r = signature[4 : 4 + size]
        position = 4 + size
        if signature[position] != 2:
            raise ProviderError("Invalid ECDSA signature")
        s = signature[position + 2 : position + 2 + signature[position + 1]]
        signature = r.lstrip(b"\0").rjust(32, b"\0") + s.lstrip(b"\0").rjust(32, b"\0")
        if len(signature) != 64:
            raise ProviderError("Invalid ECDSA signature length")
    return text + "." + b64(signature)


def apple_token(env):
    now = int(time.time())
    return signed_jwt(
        env["APP_STORE_CONNECT_PRIVATE_KEY"],
        {"alg": "ES256", "kid": env["APP_STORE_CONNECT_KEY_ID"], "typ": "JWT"},
        {
            "iss": env["APP_STORE_CONNECT_ISSUER_ID"],
            "iat": now,
            "exp": now + 1190,
            "aud": "appstoreconnect-v1",
        },
    )


def play_token(credentials, request=request_json):
    credentials = json.loads(credentials)
    now = int(time.time())
    assertion = signed_jwt(
        credentials["private_key"],
        {"alg": "RS256", "typ": "JWT"},
        {
            "iss": credentials["client_email"],
            "scope": "https://www.googleapis.com/auth/androidpublisher",
            "aud": "https://oauth2.googleapis.com/token",
            "iat": now,
            "exp": now + 3500,
        },
    )
    body = urllib.parse.urlencode(
        {
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        }
    ).encode()
    result = request(
        "POST",
        "https://oauth2.googleapis.com/token",
        {"Content-Type": "application/x-www-form-urlencoded"},
        body,
    )
    if not result.get("access_token"):
        raise ProviderError("Play authentication returned no access token")
    return result["access_token"]


def verify_bundle(path, digest):
    if not isinstance(digest, str) or not re.fullmatch("[0-9a-f]{64}", digest):
        raise ProviderError("Missing build-recorded AAB digest")
    try:
        with open(path, "rb") as stream:
            actual = hashlib.file_digest(stream, "sha256").hexdigest()
    except OSError:
        raise ProviderError(
            "Retained signed AAB is missing or expired; queue stopped"
        ) from None
    if actual != digest:
        raise ProviderError(
            "Retained signed AAB digest differs from build-recorded identity; queue stopped"
        )


class Play:
    def __init__(self, token, request=request_json):
        self.request = request
        self.headers = {"Authorization": "Bearer " + token}
        self.base = (
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
            + PACKAGE
        )

    def call(self, method, path, body=None):
        try:
            return self.request(method, self.base + path, self.headers, body)
        except DeferredReview:
            raise
        except ProviderError as error:
            # Fixed operation labels locate failures without exposing edit IDs.
            operation = (
                "commit edit" if ":commit" in path else
                "validate edit" if ":validate" in path else
                "internal track" if path.endswith("/tracks/internal") else
                "production track" if path.endswith("/tracks/production") else
                "bundle inventory" if path.endswith("/bundles") else
                "track inventory" if path.endswith("/tracks") else "edit"
            )
            raise ProviderError(
                f"Google Play {operation} failed: {error}", diagnostic=error.diagnostic
            ) from None

    def diagnose_upload(self, *, notes):
        """Validate retained notes against an existing bundle; never commit/upload."""
        from release_train.release_notes import PLAY_LOCALES, validate_localizations

        notes = validate_localizations(notes, limit=500, required=PLAY_LOCALES)
        report = {"stage": "create temporary edit"}
        edit = None
        try:
            edit = self.edit()
            report["stage"] = "inventory tracks"
            tracks = self.call("GET", f"/edits/{edit}/tracks")["tracks"]
            report["tracks"] = {
                track["track"]: [
                    {"status": release["status"], "versionCodes": release.get("versionCodes", [])}
                    for release in track.get("releases", [])
                ] for track in tracks
            }
            report["stage"] = "inventory bundles"
            report["bundles"] = sorted(int(bundle["versionCode"]) for bundle in
                                       self.call("GET", f"/edits/{edit}/bundles").get("bundles", []))
            report["stage"] = "validate current edit"
            self.call("POST", f"/edits/{edit}:validate")
            internal = [int(code) for release in report["tracks"].get("internal", [])
                        for code in release["versionCodes"]]
            if not internal:
                raise ProviderError("No existing internal bundle available to validate retained notes")
            report["notes_validation_build"] = max(internal)
            report["stage"] = "set retained notes in temporary edit"
            self.track(edit, "internal", max(internal), notes=notes)
            report["stage"] = "validate retained notes"
            self.call("POST", f"/edits/{edit}:validate")
            report["stage"] = "complete"
        except ProviderError as error:
            report["error"] = error.diagnostic or {"message": str(error)}
        finally:
            if edit is not None:
                try:
                    self.call("DELETE", f"/edits/{edit}")
                except ProviderError as error:
                    report["cleanup_error"] = str(error)
        return report

    def edit(self):
        return self.call("POST", "/edits", {})["id"]

    def commit(self, edit):
        return self.call(
            "POST", f"/edits/{edit}:commit?changesInReviewBehavior=ERROR_IF_IN_REVIEW"
        )

    def tracks(self):
        edit = self.edit()
        try:
            return self.call("GET", f"/edits/{edit}/tracks")["tracks"]
        finally:
            self.call("DELETE", f"/edits/{edit}")

    def track(self, edit, track, number, *, notes):
        from release_train.release_notes import PLAY_LOCALES, validate_localizations

        notes = validate_localizations(notes, limit=500, required=PLAY_LOCALES)
        return self.call(
            "PUT",
            f"/edits/{edit}/tracks/{track}",
            {
                "track": track,
                "releases": [
                    {
                        "status": "completed",
                        "versionCodes": [str(number)],
                        "releaseNotes": notes,
                    }
                ],
            },
        )

    def promote(self, number, *, notes):
        from release_train.release_notes import PLAY_LOCALES, validate_localizations

        notes = validate_localizations(notes, limit=500, required=PLAY_LOCALES)
        edit = self.edit()
        self.track(edit, "production", number, notes=notes)
        return self.commit(edit)

    def upload(self, path, number, digest, *, notes):
        from release_train.release_notes import PLAY_LOCALES, validate_localizations

        notes = validate_localizations(notes, limit=500, required=PLAY_LOCALES)
        verify_bundle(path, digest)
        edit = self.edit()
        url = (
            "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/"
            + PACKAGE
            + f"/edits/{edit}/bundles?uploadType=media"
        )
        with open(path, "rb") as stream:
            raw = stream.read()
        try:
            # Large AAB uploads need more time than small metadata requests.
            # Google recommends at least two minutes for edits.bundles.upload.
            bundle = self.request(
                "POST",
                url,
                self.headers | {"Content-Type": "application/octet-stream"},
                raw,
                timeout=300,
            )
        except ProviderError as error:
            raise ProviderError("Google Play bundle upload failed: " + str(error), diagnostic=error.diagnostic) from None
        if str(bundle.get("versionCode")) != str(number):
            raise ProviderError(
                "Uploaded AAB versionCode differs from authenticated release identity"
            )
        self.track(edit, "internal", number, notes=notes)
        return self.commit(edit)


class Apple:
    def __init__(self, token, group, request=request_json):
        self.request = request
        self.headers = {"Authorization": "Bearer " + token}
        self.group = group
        self.base = "https://api.appstoreconnect.apple.com/v1"
        self.groups = [group]

    def call(self, method, path, body=None):
        return self.request(method, self.base + path, self.headers, body)

    def pages(self, path):
        return self.pages_including(path)[0]

    def pages_including(self, path):
        found = []
        included = {}
        seen = set()
        while path:
            if path in seen or len(seen) >= 1000:
                raise ProviderError("Apple pagination incomplete")
            seen.add(path)
            page = self.call("GET", path)
            found.extend(page["data"])
            for resource in page.get("included", []):
                included[(resource["type"], resource["id"])] = resource
            link = page.get("links", {}).get("next")
            if link and not link.startswith(self.base + "/"):
                raise ProviderError("Unexpected Apple pagination origin")
            path = link[len(self.base) :] if link else None
        return found, included

    def beta_detail(self, build_id, included):
        if included is not None:
            return included
        return self.call("GET", "/builds/" + build_id + "/buildBetaDetail").get("data")

    def resource(self, kind, identifier=None, attributes=None, relationships=None):
        data = {"type": kind}
        if identifier:
            data["id"] = identifier
        if attributes is not None:
            data["attributes"] = attributes
        if relationships:
            data["relationships"] = relationships
        return {"data": data}

    def relationship(self, kind, identifier):
        return {"data": {"type": kind, "id": identifier}}

    def set_beta_notes(self, build, notes):
        """Update translated beta copy without submitting review or changing groups."""
        from release_train.release_notes import validate_localizations

        try:
            notes = validate_localizations(notes, limit=4000)
            localizations = self.pages("/builds/" + build["id"] + "/betaBuildLocalizations")
            required = self.localization_languages(localizations)
            notes = validate_localizations(notes, limit=4000, required=required)
        except ProviderError as error:
            raise BeforeStoreMutationError(str(error)) from None
        by_language = {note["language"]: note["text"] for note in notes}
        existing = {loc["attributes"]["locale"]: loc for loc in localizations}
        for language, text in by_language.items():
            if language in existing:
                identifier = existing[language]["id"]
                self.call(
                    "PATCH", "/betaBuildLocalizations/" + identifier,
                    self.resource("betaBuildLocalizations", identifier, {"whatsNew": text}),
                )
            else:
                self.call(
                    "POST", "/betaBuildLocalizations",
                    self.resource(
                        "betaBuildLocalizations",
                        attributes={"locale": language, "whatsNew": text},
                        relationships={"build": self.relationship("builds", build["id"])},
                    ),
                )

    def localization_languages(self, localizations):
        languages = [loc.get("attributes", {}).get("locale") for loc in localizations]
        if any(not isinstance(locale, str) or not locale for locale in languages):
            raise ProviderError("Apple localization inventory has no verifiable locale")
        if len(languages) != len(set(languages)):
            raise ProviderError("Apple localization inventory has duplicate locales")
        return languages

    def submit_beta(self, build, notes):
        self.set_beta_notes(build, notes)
        if build.get("beta_detail_id"):
            identifier = build["beta_detail_id"]
            self.call(
                "PATCH", "/buildBetaDetails/" + identifier,
                self.resource("buildBetaDetails", identifier, {"autoNotifyEnabled": True}),
            )
        if build.get("external") not in {
            "BETA_APPROVED",
            "READY_FOR_BETA_TESTING",
            "IN_BETA_TESTING",
            "WAITING_FOR_BETA_REVIEW",
            "IN_BETA_REVIEW",
        }:
            self.call(
                "POST",
                "/betaAppReviewSubmissions",
                self.resource(
                    "betaAppReviewSubmissions",
                    relationships={"build": self.relationship("builds", build["id"])},
                ),
            )
        self.attach_groups(build)

    def attach_groups(self, build):
        for group in self.groups:
            if group in build.get("groups", []):
                continue
            self.call(
                "POST",
                f"/betaGroups/{group}/relationships/builds",
                {"data": [{"type": "builds", "id": build["id"]}]},
            )

    def submit_store(self, build, versions, acknowledged, *, notes, reviews=None):
        from release_train.release_notes import validate_localizations

        # These checks only read provider state. Failure cannot imply an
        # ambiguous submission; writes start below, outside this classification.
        try:
            if build.get("version") == "1.0.30" and str(build.get("number")) == "916":
                raise ProviderError("iOS 1.0.30+916 is prohibited from App Store submission")
            notes = validate_localizations(notes, limit=4000)
            editable = [
                v
                for v in versions
                if v["state"] == "PREPARE_FOR_SUBMISSION"
                or (
                    v["state"] == "READY_FOR_REVIEW"
                    and v.get("build_id") == build["id"]
                    and v["version"] == build["version"]
                )
                or (
                    v["state"]
                    in {
                        "REJECTED",
                        "METADATA_REJECTED",
                        "INVALID_BINARY",
                        "DEVELOPER_REJECTED",
                    }
                    and version_ack_key(v) in acknowledged
                )
            ]
            if len(editable) > 1:
                raise ProviderError(
                    "Multiple editable App Store versions; reconcile in console"
                )
            reviews = reviews or []
            unresolved = [
                r for r in reviews if r["attributes"]["state"] == "UNRESOLVED_ISSUES"
            ]
            if len(unresolved) > 1 or any(
                not unresolved_review_is_acknowledged(r, versions, acknowledged)
                for r in unresolved
            ):
                raise ProviderError(
                    "Resolve unrelated or unacknowledged review items in App Store Connect before resubmitting"
                )
            existing_review = unresolved[0] if unresolved else None
            if existing_review and (
                not editable
                or existing_review["items"][0].get("version_id") != editable[0]["id"]
            ):
                raise ProviderError(
                    "Rejected review ownership does not match the editable App Store version"
                )
            drafts = [r for r in reviews if r["attributes"]["state"] == "READY_FOR_REVIEW"]
            if len(drafts) + len(unresolved) > 1:
                raise ProviderError(
                    "Multiple unfinished App Store submissions; reconcile their ownership in console"
                )
            if drafts:
                draft = drafts[0]
                items = draft.get("items")
                if (
                    items is None
                    or len(items) > 1
                    or (
                        items
                        and (
                            not editable
                            or items[0].get("version_id") != editable[0]["id"]
                            or items[0].get("state") != "READY_FOR_REVIEW"
                        )
                    )
                ):
                    raise ProviderError(
                        "Unrelated draft review items require App Store Connect reconciliation"
                    )
                existing_review = draft
            # Read every existing locale before any version, build or rollout mutation.
            if editable:
                localizations = self.pages(
                    f"/appStoreVersions/{editable[0]['id']}/appStoreVersionLocalizations"
                )
                required = self.localization_languages(localizations)
                if not required:
                    raise ProviderError("Apple storefront locale inventory is empty")
            else:
                localizations = None
                infos = self.pages(f"/apps/{APP_ID}/appInfos")
                required = set()
                for info in infos:
                    required.update(self.localization_languages(self.pages(
                        f"/appInfos/{info['id']}/appInfoLocalizations"
                    )))
                if not required:
                    raise ProviderError("Apple configured storefront locale inventory is empty")
            notes = validate_localizations(notes, limit=4000, required=required)
            by_language = {note["language"]: note["text"] for note in notes}
        except ProviderError as error:
            raise BeforeStoreMutationError(str(error)) from None
        attrs = {"versionString": build["version"], "releaseType": "AFTER_APPROVAL"}
        if editable:
            identifier = editable[0]["id"]
            self.call(
                "PATCH",
                "/appStoreVersions/" + identifier,
                self.resource("appStoreVersions", identifier, attrs),
            )
        else:
            result = self.call(
                "POST",
                "/appStoreVersions",
                self.resource(
                    "appStoreVersions",
                    attributes=attrs | {"platform": "IOS"},
                    relationships={"app": self.relationship("apps", APP_ID)},
                ),
            )
            identifier = result["data"]["id"]
        if localizations is None:
            localizations = self.pages(
                f"/appStoreVersions/{identifier}/appStoreVersionLocalizations"
            )
            if not localizations:
                raise ProviderError("New Apple version has no storefront localizations")
            validate_localizations(
                notes, limit=4000, required=self.localization_languages(localizations)
            )
        self.call(
            "PATCH",
            f"/appStoreVersions/{identifier}/relationships/build",
            self.relationship("builds", build["id"]),
        )
        try:
            phased = self.call(
                "GET", f"/appStoreVersions/{identifier}/appStoreVersionPhasedRelease"
            ).get("data")
        except NotFound:
            phased = None
        if phased:
            self.call(
                "PATCH",
                "/appStoreVersionPhasedReleases/" + phased["id"],
                self.resource(
                    "appStoreVersionPhasedReleases",
                    phased["id"],
                    {"phasedReleaseState": "INACTIVE"},
                ),
            )
        for loc in localizations:
            self.call(
                "PATCH",
                "/appStoreVersionLocalizations/" + loc["id"],
                self.resource(
                    "appStoreVersionLocalizations", loc["id"], {"whatsNew": by_language[loc["attributes"]["locale"]]}
                ),
            )
        if existing_review:
            review = existing_review["id"]
            items = existing_review.get("items", [])
        else:
            result = self.call(
                "POST",
                "/reviewSubmissions",
                self.resource(
                    "reviewSubmissions",
                    attributes={"platform": "IOS"},
                    relationships={"app": self.relationship("apps", APP_ID)},
                ),
            )
            review = result["data"]["id"]
            items = []
        if items:
            item = items[0]
            if item["state"] == "REJECTED":
                self.call(
                    "PATCH",
                    "/reviewSubmissionItems/" + item["id"],
                    self.resource(
                        "reviewSubmissionItems", item["id"], {"resolved": True}
                    ),
                )
        else:
            self.call(
                "POST",
                "/reviewSubmissionItems",
                self.resource(
                    "reviewSubmissionItems",
                    relationships={
                        "reviewSubmission": self.relationship(
                            "reviewSubmissions", review
                        ),
                        "appStoreVersion": self.relationship(
                            "appStoreVersions", identifier
                        ),
                    },
                ),
            )
        self.call(
            "PATCH",
            "/reviewSubmissions/" + review,
            self.resource("reviewSubmissions", review, {"submitted": True}),
        )
        return identifier
