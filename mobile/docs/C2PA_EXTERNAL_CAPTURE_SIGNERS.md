# Clips signed by other C2PA cameras (#10066)

Status: Current
Validated against: `ClipProvenanceVerifier` and `C2paTrustAnchorService` at `6026bbd56c`, the C2PA Trust List issued 2026-08-05, the C2PA Conforming Products List as of 2026-10-12, and Divine's GA4 export for 2026-09-13 to 2026-10-12.

The clip library, the DM clip import (#9894) and the gallery import (#10062) admit a video only when its C2PA history leads back to recordings signed by Divine's ProofSign service (see [DM_CLIP_SHARING.md](DM_CLIP_SHARING.md#the-c2pa-check)). This document decides whether footage signed by other C2PA capture signers may enter too, for example from a phone or a camera that signs its own recordings.

## Decision

**Not now.** The clip library keeps trusting ProofSign alone.

- Only one phone camera signs video at the assurance level we would require: Google's Pixel Camera. Owners of a Pixel 8, 9 or 10 are 0.8% of Divine's active mobile users, and only videos they recorded after the mid-2026 rollout would qualify.
- No dedicated camera maker is in the C2PA Conformance Program, and neither is Apple or Samsung.
- Admitting other signers safely needs a signer list on the server, a signer check for each manifest in the verifier, new copy in every locale and the same rules in `divine-inquisitor`. For more than 99% of users that work changes nothing.

The rest of this document settles the rules we would apply. Revisiting then becomes an implementation task rather than a new investigation. [When to revisit](#when-to-revisit) says when.

## Which signers

**Never the C2PA Trust List as a whole.** The Trust List issued on 2026-08-05 names 17 organisations. Most of them are commercial certificate authorities, such as DigiCert, SSL.com, TrustAsia, Trufo and Encypher, which certify any product that passes conformance. The rest are vendor CAs: Google, Adobe, Xiaomi, vivo, Huawei, and Whole Earth Labs, the maker of the RealReel capture app. No root from Sony, Canon, Nikon, Leica, Fujifilm, Samsung or Apple is on it. The older interim trust list was frozen on 2026-01-01 and is no longer maintained.

Trusting the list would mean trusting every product those CAs certify:

- The Conforming Products List has 142 generator records that sign video. 102 of them declare no key attestation.
- The list includes generative video services: OpenAI, Runway, Luma, HeyGen, Stability AI and Google Flow.
- A record can name source types its product may not claim (`disallowedSignals`), but only 45 of the 142 video records do, and none from before August 2026. For the other records, a claim that a video is a camera recording would rest on the product labelling itself honestly.
- Anchors are per vendor, not per product. Google LLC holds the records for Pixel Camera, Pixel Studio, Google Flow, Google Photos and YouTube, while the Trust List names only Google's own CAs.

**A curated list of capture products instead.** A product qualifies only when all of these hold:

1. It is a capture product: a camera app or camera firmware, not an editor, platform, signing service or generator.
2. It is in the C2PA Conformance Program at Assurance Level 2, with hardware-backed key attestation in its record.
3. It signs video at capture as MP4 or QuickTime, the only formats the gallery import hands to the C2PA reader, and the footage reaches the phone's gallery with its manifest intact.
4. Its signing certificates can be pinned to the product: an anchor plus the organisation and product name in the certificate subject, so that other products from the same CA stay out.
5. The verifier tests include a real manifest from a real device.

Today only Pixel Camera meets all five:

- vivo Camera and JOVI Camera sign video, but they are Assurance Level 1 and their records name no attestation method.
- Qualcomm's Snapdragon 8 Elite Gen 5 is Assurance Level 2 for video. It is a chipset, though, and reaches users only through a phone maker's camera app. The only one listed, Xiaomi Camera, signs images.
- Sony's Camera Verify has signed MP4 video since March 2026. It is a paid beta outside the Conformance Program.
- Third-party capture apps such as ProofMode, GreenCheckmark, InReality and RealReel sign video too. They are peers of the Divine camera rather than devices, and most are Assurance Level 1.

## Rule

The current rule stays: a clip's history ends in camera recordings, names no other source type anywhere, and every edit and composite in it is signed by ProofSign. Only the recordings at the end change:

- **A recording may also be signed by a listed product.** Its certificate must chain to that entry's anchor, and its subject must match the entry's organisation and product name. The reader reports both for each manifest in `signature_info`: `issuer` holds the subject's organisation, despite its name, and `common_name` holds the product.
- **Only as that product recorded it.** The product's manifest must be a `c2pa.created` capture with no video ingredient. An edit signed by the vendor is rejected, for example a trim in Google Photos or a Video Boost render: those are separate products from Pixel Camera.
- **Edits made in Divine are allowed.** A trim, merge or other edit that Divine signs through ProofSign, with the external recording as its ingredient, passes like an edit of a Divine recording. Without this, almost no phone video would fit a 6-second loop.
- **Each entry names the capture source types it may use.** Pixel Camera labels its photos `computationalCapture` rather than `digitalCapture`, and its videos are expected to follow, so its entry would allow that type. Divine's own recordings keep requiring `digitalCapture`, and generative source types stay rejected everywhere.
- **Each entry has a version floor** for the product's claim generator, taken from its conformance record. A vulnerable release can then be cut off without dropping the product.

The entries would live in their own file next to the ProofSign anchors, fetched and cached under the same rules: refetched after an hour, and unused after seven days offline. `divine-inquisitor` would read the same file, so a post is judged on the server the way its clips were judged on the phone. `allowed_list` keeps naming only ProofSign's self-signed signers.

## Revocation

The check stays offline. It fetches no OCSP response and reads no CRL.

- c2pa-rs knows three sources of revocation status: an OCSP response stapled to the signature when the manifest was signed, an OCSP fetch during validation (`ocsp_fetch`, off by default), and a later `CertificateStatus` assertion. It does not read CRLs. A stapled response cannot report a revocation that came after signing. A fetch would send a request for every clip checked, which the on-device check is built to avoid.
- Revoking single certificates would also protect little. Pixel Camera uses a new key and certificate for every capture, so no certificate stands for a device.
- The failure that has actually happened was product-wide. In September 2025 a Nikon Z6 III firmware path was found to sign arbitrary image data. Nikon revoked every certificate it had issued and suspended its signing service, which has not come back.

So revocation happens per product, in the signer list: withdraw the entry, or raise its version floor. A device picks the change up within an hour when online, and stops using a cached list after seven days offline. That is the same guarantee the ProofSign anchors have. A clip already in someone's library stays there, since it is their footage, but its next check fails, for example when it is sent in a DM.

## Credits

- An external recording carries no Nostr creator binding, so its manifest credits nobody. For your own footage brought back from the gallery, that is already what happens with a Divine recording: nobody is credited as the source of their own footage.
- In a DM, the sender stays the clip's first credit, as for every received clip. For an external recording, that credit rests only on the sender's word. The same is true today of a Divine recording from an account that signs without a binding (NIP-46, NIP-55). That is acceptable: the attach menu tells the sender that they will be credited, and a post made from the clip names them in a clip-source `p` tag.

## Labels

Admitting other cameras breaks a promise the app makes today, so the copy has to change with it:

- Every string that says a clip was shot with the Divine camera becomes a promise about verified camera recordings, in every locale: `dmClipChecking`, `dmClipNotVerified`, `dmClipSendNotVerified`, `libraryGalleryImportExplainerSubtitle`, `libraryGalleryImportItemNotVerified`, and the descriptions of the attach-menu entries.
- The proof record keeps the entry's display name. A clip from another camera then says so wherever it appears: "Captured with Pixel Camera" in the library and on a received DM clip. A Divine recording shows nothing extra.
- A post keeps its Human-Made badge, because the footage is a hardware-attested camera recording and the edit is signed by ProofSign. Its provenance details name the capture product instead of implying the Divine camera. Today `getVerificationLevel` writes `verified_mobile` for every post that carries a C2PA manifest, so that tag needs the capture product next to it.

## Coverage

Devices and apps that sign video at capture today:

| Product | Conformance | Video | Notes |
|---|---|---|---|
| Google Pixel Camera (Pixel 8, 9, 10) | Assurance Level 2, Android Key Attestation, keys in the Titan M2 chip | MP4, conformant since 2026-03-16 | Announced for Pixel 8, 9 and 10 in May 2026. Uses one certificate per capture and labels photos `computationalCapture`. |
| vivo Camera, JOVI Camera | Assurance Level 1, no attestation method recorded | MP4 | |
| Qualcomm Snapdragon 8 Elite Gen 5 | Assurance Level 2 | MP4 | A chipset, so it only matters once a phone maker's camera app uses it. Xiaomi Camera is listed for images only. |
| Sony Camera Verify (α1 II, α9 III, FX3 and others) | Not in the program | MP4 up to 222 Mbps since March 2026 | Paid beta. The footage has to leave the camera unchanged. |
| Nikon Z6 III | Not in the program | Photos only | Every certificate was revoked in September 2025. |
| Leica, Canon, Fujifilm | Not in the program | Photos | No video signing found. |
| Apple, Samsung | Not in the program | None found | No camera signing found. Samsung signs AI-edited images only. |

How many Divine users that reaches: over the 30 days to 2026-10-12, Divine's GA4 export counts 16,584 iOS and 11,317 Android users. 211 of the Android users are on a Pixel 8, 9 or 10, including the `a` models: 1.9% of Android users and 0.8% of mobile users. vivo phones account for another 23 users. GA4 undercounts since the analytics opt-out, but it does so for every device alike. The query:

```sql
SELECT platform,
  COUNT(DISTINCT user_pseudo_id) AS users,
  COUNT(DISTINCT IF(LOWER(device.mobile_brand_name) = "google"
    AND REGEXP_CONTAINS(LOWER(device.mobile_model_name), r"pixel (8|9|10)"),
    user_pseudo_id, NULL)) AS pixel_8_9_10_users
FROM `openvine-co.analytics_505815521.events_*`
WHERE _TABLE_SUFFIX BETWEEN "20260913" AND "20261012"
GROUP BY platform
```

That share is an upper bound. It counts owners of an eligible phone, not people who record with the stock camera, keep the file unedited and then want it in their clips.

## When to revisit

Reopen this decision when either of these happens:

- Phones whose stock camera meets the bar above reach 10% of Divine's monthly active mobile users, measured with the query above. The likeliest trigger is Apple's or Samsung's camera signing video at Assurance Level 2: iOS alone is 59% of Divine's mobile users.
- Product wants footage from outside cameras in co-creation for another reason, such as a newsroom partnership, and accepts the cost.

The work would then be:

1. `proofsign-server`: publish the curated capture-signer file next to the trust anchors.
2. Mobile verifier: load the file, check the signer of each manifest against the rule above, return the capture product, and test with real manifests. The tests cover a recording as captured, one trimmed in Divine, one edited by the vendor (rejected), a generative product from the same CA (rejected) and a withdrawn entry (rejected). They also check that a capture signed weeks earlier still verifies once its one-off certificate has expired, since Pixel's device timestamp is not from a trusted TSA.
3. Mobile UI: the copy changes and "Captured with …" labels above, and the capture product in a post's provenance.
4. `divine-inquisitor`: the same file and rule for posts.

## What this leaves alone

- **Moderation.** `divine-inquisitor` is designed to treat any valid C2PA manifest, and ProofMode captures in particular, as a moderation trust signal (see `C2PA_MODERATION_SIGNAL.md` in that repository). That signal is separate from clip-library admission and is unchanged.
- **Signing.** `C2paSigningService.signEditInPlace` already embeds a source video whose manifest validates even when its signer is not a Divine anchor. Signing an edit therefore does not depend on this decision.

## Sources

- [C2PA Conformance Program public repository](https://github.com/c2pa-org/conformance-public): `trust-list/C2PA-TRUST-LIST.json` and `conforming-products/conforming-products-list.json`
- [C2PA trust lists, CAI open-source docs](https://opensource.contentauthenticity.org/docs/conformance/trust-lists)
- [How Pixel and Android are bringing a new level of trust to your images with C2PA Content Credentials](https://blog.google/security/pixel-android-trusted-images-c2pa-content-credentials/)
- [IPTC: example of a computational capture photo from the Pixel 10](https://iptc.org/news/2025/08)
- [Google Pixel 8, 9 and 10 to add C2PA Content Credentials to video in Pixel Camera](https://jetstream.blog/en/pixel-8-9-10-pixel-camera-c2pa-content-credentials/)
- [Sony's Camera Authenticity Solution now supports video](https://www.newsshooter.com/2026/03/12/sonys-camera-authenticity-solution-now-supports-video/)
- [Nikon can't fully solve the Z6 III's C2PA problems alone](https://petapixel.com/2025/09/22/nikon-cant-fully-solve-the-z6-iiis-c2pa-problems-alone/)
- [c2pa-rs `Verify` settings, revocation order](https://github.com/contentauth/c2pa-rs/blob/main/sdk/src/settings/mod.rs)
