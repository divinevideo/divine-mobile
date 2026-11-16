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

NOTES = "This update includes the latest tested changes to Divine."
APP_ID = "6747959501"
PACKAGE = "co.openvine.app"


class ProviderError(RuntimeError):
    pass


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


def request_json(method, url, headers=None, body=None):
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
            request, timeout=60
        ) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        status = error.code
        raw = error.read(100000)
        error.close()
        try:
            reasons = [
                d.get("reason")
                for d in json.loads(raw).get("error", {}).get("details", [])
            ]
        except (ValueError, TypeError, AttributeError):
            reasons = []
        if "CHANGES_ALREADY_IN_REVIEW" in reasons:
            raise DeferredReview("CHANGES_ALREADY_IN_REVIEW") from None
        if status == 404:
            raise NotFound("Provider resource not found (HTTP 404)") from None
        raise ProviderError(
            f"Provider request failed (HTTP {status}); inspect credentials, agreements, metadata or rate limits"
        ) from None
    except (OSError, ValueError, TimeoutError, urllib.error.URLError):
        raise ProviderError(
            "Provider response unavailable; reconcile any mutation before retrying"
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
        return self.request(method, self.base + path, self.headers, body)

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

    def track(self, edit, track, number):
        return self.call(
            "PUT",
            f"/edits/{edit}/tracks/{track}",
            {
                "track": track,
                "releases": [
                    {
                        "status": "completed",
                        "versionCodes": [str(number)],
                        "releaseNotes": [{"language": "en-US", "text": NOTES}],
                    }
                ],
            },
        )

    def promote(self, number):
        edit = self.edit()
        self.track(edit, "production", number)
        return self.commit(edit)

    def upload(self, path, number, digest):
        verify_bundle(path, digest)
        edit = self.edit()
        url = (
            "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/"
            + PACKAGE
            + f"/edits/{edit}/bundles?uploadType=media"
        )
        with open(path, "rb") as stream:
            raw = stream.read()
        bundle = self.request(
            "POST",
            url,
            self.headers | {"Content-Type": "application/octet-stream"},
            raw,
        )
        if str(bundle.get("versionCode")) != str(number):
            raise ProviderError(
                "Uploaded AAB versionCode differs from authenticated release identity"
            )
        self.track(edit, "internal", number)
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
        found = []
        seen = set()
        while path:
            if path in seen or len(seen) >= 1000:
                raise ProviderError("Apple pagination incomplete")
            seen.add(path)
            page = self.call("GET", path)
            found.extend(page["data"])
            link = page.get("links", {}).get("next")
            if link and not link.startswith(self.base + "/"):
                raise ProviderError("Unexpected Apple pagination origin")
            path = link[len(self.base) :] if link else None
        return found

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

    def submit_beta(self, build, notes):
        localizations = self.pages("/builds/" + build["id"] + "/betaBuildLocalizations")
        if localizations:
            for loc in localizations:
                self.call(
                    "PATCH",
                    "/betaBuildLocalizations/" + loc["id"],
                    self.resource(
                        "betaBuildLocalizations", loc["id"], {"whatsNew": notes[:4000]}
                    ),
                )
        else:
            self.call(
                "POST",
                "/betaBuildLocalizations",
                self.resource(
                    "betaBuildLocalizations",
                    attributes={"locale": "en-US", "whatsNew": notes[:4000]},
                    relationships={"build": self.relationship("builds", build["id"])},
                ),
            )
        if build.get("external") not in {"READY_FOR_BETA_TESTING", "IN_BETA_TESTING"}:
            self.call(
                "POST",
                "/betaAppReviewSubmissions",
                self.resource(
                    "betaAppReviewSubmissions",
                    relationships={"build": self.relationship("builds", build["id"])},
                ),
            )
        for group in self.groups:
            self.call(
                "POST",
                f"/betaGroups/{group}/relationships/builds",
                {"data": [{"type": "builds", "id": build["id"]}]},
            )

    def submit_store(self, build, versions, acknowledged):
        editable = [
            v
            for v in versions
            if v["state"] == "PREPARE_FOR_SUBMISSION"
            or (
                v["state"]
                in {
                    "REJECTED",
                    "METADATA_REJECTED",
                    "INVALID_BINARY",
                    "DEVELOPER_REJECTED",
                }
                and "ios-version:" + v["id"] in acknowledged
            )
        ]
        if len(editable) > 1:
            raise ProviderError(
                "Multiple editable App Store versions; reconcile in console"
            )
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
        for loc in self.pages(
            f"/appStoreVersions/{identifier}/appStoreVersionLocalizations"
        ):
            self.call(
                "PATCH",
                "/appStoreVersionLocalizations/" + loc["id"],
                self.resource(
                    "appStoreVersionLocalizations", loc["id"], {"whatsNew": NOTES}
                ),
            )
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
        self.call(
            "POST",
            "/reviewSubmissionItems",
            self.resource(
                "reviewSubmissionItems",
                relationships={
                    "reviewSubmission": self.relationship("reviewSubmissions", review),
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
