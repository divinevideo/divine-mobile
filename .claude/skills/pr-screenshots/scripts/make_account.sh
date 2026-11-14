#!/usr/bin/env bash
# ABOUTME: Mints a throwaway Nostr account on the LOCAL relay only, so the app has someone to message or view.
# ABOUTME: Usage: bash make_account.sh "Display Name"; prints the npub. The secret is written to $SCRATCH/keys/<pubkey>.sec.
set -euo pipefail

NAME="${1:?usage: make_account.sh \"Display Name\"}"
RELAY=ws://localhost:47777
KEY_DIR="${SCRATCH:?set SCRATCH to the scratch folder for this run, see SKILL.md}/keys"
mkdir -p "$KEY_DIR"

SECRET=$(nak key generate)
PUBKEY=$(nak key public "$SECRET")
NPUB=$(nak encode npub "$PUBKEY")
echo "$SECRET" > "$KEY_DIR/$PUBKEY.sec"

PROFILE=$(python3 -c 'import json, sys; print(json.dumps({"name": sys.argv[1], "display_name": sys.argv[1]}))' "$NAME")
# Deliberately no kind 10050: an inbox relay of ws://localhost is refused by the app,
# so DMs to it fail. With none advertised, DMs fall back to the local relay.
# perl alarm: nak can wait forever for an OK the relay never sends.
perl -e 'alarm 30; exec @ARGV' nak event -k 0 -c "$PROFILE" --sec "$SECRET" "$RELAY" > /dev/null
echo "$NPUB"
