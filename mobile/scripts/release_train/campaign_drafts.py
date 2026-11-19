"""Optional drafts for provider-confirmed store releases, retried every tick.

Play production-track observations do not prove public availability, even when
marked completed. Android is deliberately disabled in the coordinator until a
trusted provider reader implements PlayAvailability with version-specific public
availability evidence for co.openvine.app. That reader must not infer availability
from track membership, submission acceptance, deployment audit state, or an env
flag. No such reliable reader exists in the current release providers. The typed
adapter allows a future verified reader without treating snapshot flags as proof.

Draft creation is independent of store actions and never changes their outcome.
The receiving API deduplicates platform/channel/version across ticks and restarts.
"""

from __future__ import annotations

import http.client
import json
import re
import urllib.error
import urllib.parse
import urllib.request
from typing import Protocol

from release_train.providers import NoRedirect


class PlayAvailability(Protocol):
    """Trusted provider confirmation of the currently available public version."""

    def confirmed_version(self) -> str | None: ...


def _version(value):
    if not isinstance(value, str) or not re.fullmatch(
        r"(?:0|[1-9][0-9]{0,5})\.(?:0|[1-9][0-9]{0,5})\.(?:0|[1-9][0-9]{0,5})", value
    ):
        return None
    return tuple(int(part) for part in value.split("."))


def _draft(platform, channel, version):
    store = "the App Store" if platform == "ios" else "Google Play"
    eligibility = {"platform": platform, "channel": channel, "version": version}
    title = f"Divine {version} is available"
    return {
        "sourceType": "app_release",
        "sourceId": f"{platform}:{channel}",
        "sourceRevision": version,
        "title": title,
        "body": f"Update Divine from {store}.",
        "details": {
            "title": title,
            "body": f"Divine {version} is available from {store}.",
            "action": {"type": "update_app", **eligibility},
        },
        "releaseEligibility": eligibility,
    }


def publish_release_drafts(
    snapshot,
    env,
    levels,
    *,
    dry_run=False,
    play_availability: PlayAvailability | None = None,
):
    """Return safe summary messages. Missing configuration/dry runs make no calls."""
    if dry_run:
        return []
    base = env.get("ENGAGEMENT_DRAFT_API_URL", "")
    client = env.get("ENGAGEMENT_DRAFT_ACCESS_CLIENT_ID", "")
    secret = env.get("ENGAGEMENT_DRAFT_ACCESS_CLIENT_SECRET", "")
    if not all((base, client, secret)):
        return []
    try:
        parsed = urllib.parse.urlsplit(base)
        valid = (
            parsed.scheme == "https"
            and parsed.hostname
            and not parsed.username
            and not parsed.password
            and parsed.path in {"", "/"}
            and not parsed.query
            and not parsed.fragment
        )
        # Also reject malformed port configuration before any request.
        parsed.port
    except ValueError:
        valid = False
    if not valid:
        return ["Release campaign drafts skipped: invalid API origin configuration."]

    drafts = []
    messages = []
    ios = snapshot.get("ios", {})
    if levels.get("ios") == "app-store" and not ios.get("error"):
        available = {
            entry["version"]
            for entry in ios.get("versions", [])
            if entry.get("state") in {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION"}
            and _version(entry.get("version")) is not None
        }
        if available:
            drafts.append(_draft("ios", "app_store", max(available, key=_version)))

    android = snapshot.get("android", {})
    if (
        levels.get("android") == "production"
        and not android.get("error")
        and play_availability is not None
    ):
        try:
            version = play_availability.confirmed_version()
            if _version(version) is not None and any(
                build.get("version") == version
                for build in android.get("production", [])
            ):
                drafts.append(_draft("android", "google_play", version))
        except Exception:
            # Optional provider evidence must not turn a successful release into failure.
            messages.append("Release campaign draft skipped: Play availability unconfirmed.")

    for draft in drafts:
        request = urllib.request.Request(
            base.rstrip("/") + "/api/internal/campaign-drafts",
            method="POST",
            data=json.dumps(draft).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "CF-Access-Client-Id": client,
                "CF-Access-Client-Secret": secret,
            },
        )
        try:
            with urllib.request.build_opener(NoRedirect).open(request, timeout=10) as response:
                if not 200 <= response.status < 300:
                    raise OSError("Draft API did not accept request")
            messages.append("Release campaign draft accepted: " + draft["sourceId"] + ".")
        except urllib.error.HTTPError as error:
            error.close()
            messages.append("Release campaign draft unavailable; will retry next tick.")
        except (http.client.HTTPException, OSError, ValueError):
            messages.append("Release campaign draft unavailable; will retry next tick.")
    return messages
