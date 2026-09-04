# Localization Style Guide

Status: Current
Validated against: `mobile/lib/l10n/app_*.arb` (22 non-English locales) and the
l10n guards under `mobile/test/l10n/` on 2026-08-31.

This is the source of truth for **what translated copy should sound like**:
how to address the reader in each locale, which variety of a pluricentric
language we ship, which words never get translated, and who signs off.

It does not cover the mechanics of adding a key — `flutter gen-l10n`, ARB
metadata, `context.l10n`, deferring with `_knownUntranslatedDebt`. Those live
in [`.claude/rules/localization.md`](../../.claude/rules/localization.md) and
in `AGENTS.md`. Read this one when you are writing or reviewing the *words*.

The English voice this guide extends is
[`brand-guidelines/TONE_OF_VOICE.md`](../../brand-guidelines/TONE_OF_VOICE.md).

---

## Why this exists

Divine ships 23 locales — English plus 22 translations — from one app. Almost
nobody who reviews a translation PR reads the language it changes, so review
defaults to "the ARB parity guard is green", which proves a key exists, not
that it sounds like Divine.

Individually reasonable choices then accumulate, and they accumulate in a
pattern. **The drift is feature-shaped, not key-shaped**: in five locales the
register that departs from the file's own baseline is concentrated in the same
place, the video editor.

- **Spanish** ships two dialects. Its baseline is Rioplatense *voseo* —
  `Revisá tu Wi-Fi`, `Ingresá tu código`, `No tenés permiso` — present since
  the original l10n commit (#2930). *Tuteo* (`Inténtalo de nuevo`) arrived
  later through feature work and clusters in the video editor. Counting only
  markers that actually discriminate, 233 keys are voseo and 75 are
  unambiguously tuteo — and 41 of those 75 are the same sentence,
  `Inténtalo de nuevo`, copied across error copy.
- **Turkish** answers the same action two ways: `publishErrorServerUnreachable`
  says `Lütfen birazdan tekrar dene` (informal) and `videoEditorSplitFailed`
  says `Lütfen tekrar deneyin` (formal).
- **Romanian** and **Portuguese** drift in the same corner — `ro`'s polite
  2nd-person plural and `pt`'s European forms both cluster in the video editor
  and chroma-key screens.
- **Japanese** mixes casual sentence-final よ/ね — `ネットに接続できないよ。` —
  with a large corpus of です/ます polite copy.
- **Bulgarian** switches inside a single string:
  `Докосни произволно място, за да започнете да записвате` opens with a
  familiar imperative and closes with a polite one.

None of these is a bad translation. Each is a different app's voice arriving
one PR at a time, and the fact that five unrelated languages drift in the same
feature points at one upstream pipeline rather than five translators. This
guide exists so the next pass has an answer to check itself against, and so a
reviewer who does not speak the language still has something to review.

---

## What we ship

The locale contract, from the code:

- 22 ARB files, all **bare language codes** — `es`, not `es-419` or `es-ES`;
  `pt`, not `pt-BR`; `zh`, not `zh-Hans`
  (`mobile/lib/l10n/`, `mobile/l10n.yaml`).
- Each is advertised to users under **one native name** in the in-app language
  picker: `'es': 'Español'`, `'pt': 'Português'`, `'zh': '简体中文'`
  (`mobile/lib/services/locale_preference_service.dart`).
- Anything unmatched falls back to English
  (`mobile/lib/l10n/resolve_app_ui_locale.dart`).

**The consequence that drives every decision below: there is no second file to
send anyone to.** One `es` serves Montevideo, Mexico City and Madrid. One `pt`
serves São Paulo and Lisbon. So each pluricentric language gets **one base
variety, picked on purpose** — Rioplatense for `es`, Brazilian for `pt` — and
the rest of that language's readers get it.

Picking one is not the same as writing for nobody. Committee-neutral Spanish
is itself a dialect: the one no user actually speaks, and the one that makes
an app sound like a bank. We would rather sound like the people who build
Divine and the places most of our users are. Readers outside the base variety
will notice, and that cost is taken knowingly rather than sanded off.

What a translator must not do is *mix*. A second variety inside the shared
file is drift, not range. Adding a region-qualified locale (`zh-Hant`
alongside `zh`) is a product decision — raise it as an issue.

---

## Register: how to address the reader

**Principle: sound friendly in that language, which is not the same as
sounding informal in English.** The target is the register a person uses with
someone they like — and in several of our languages that register is a polite
one.

German `du`, Japanese です/ます and Urdu آپ are all correct answers to the
same question. Copying English's T-form instinct into Urdu or Japanese does
not read as warm, it reads as rude, which is the opposite of the goal.
Politeness there is not stiffness; it is how friendliness is spelled.

How to *refer* to people, as opposed to addressing them, is
[Gender](#gender-never-the-masculine-default) below.

| Locale | Address the reader as | Current tree | Notes |
|---|---|---|---|
| `am` Amharic | Polite እርስዎ / -ዎ; avoid gendered singular | **split** | Familiar and polite forms both appear, and they flip per verb: `ሰርዝ` 55 / `ይሰርዙ` 4 for delete, but `ተመልከት` 4 / `ይመልከቱ` 40 for watch. Adjacent keys disagree — `authCreateNewAccount` is polite, `authCreateNewAccountShort` familiar. Every familiar form is **masculine**; the feminine is used zero times, so those strings address every reader as male. That is the reason to prefer the polite form or a verbal noun, not tidiness. |
| `ar` Arabic | MSA; impersonal phrasing and the verbal noun, so no gender is chosen — see [Gender](#gender-never-the-masculine-default) | consistent | No feminine or plural address anywhere in the file today, so every verb that does address the reader addresses a man — a known gap, not the target. Prefer the verbal noun (الإرسال) to a command (أرسل) in new copy. No dialect. |
| `bg` Bulgarian | `ти` + familiar imperatives | **split** | The pronoun `Вие` is absent, but courtesy in Bulgarian is the 2nd-person **plural verb**, and it appears — including inside single strings: `Докосни ... за да започнете` and `Докосни за редактиране. Задръжте и плъзнете`. Checking the pronoun alone reports this file as clean. |
| `de` German | `du` | consistent | A handful of `Sie`/`Ihr` hits are pronoun ambiguity, not courtesy address. |
| `es` Spanish | `vos` (Rioplatense voseo) | **split** | The register the file has used since #2930 (233 keys), and the dialect our own Spanish-speaking team writes, Uruguayan — decided in #7908. The 75 tuteo keys are the drift. No *vosotros*. See [Variety and dialect](#variety-and-dialect). |
| `fil` Filipino | Informal — no `po`/`kayo` | consistent | Taglish is the register: ~750 keys carry an English tech noun. Do not "purify" those into coined Filipino. |
| `fr` French | `tu` | **36 keys use `vous`** | Almost all are genuine vouvoiement drift, not plural. Only `userPickerEmptyFollowListBody` ("vous pouvez collaborer" = you-and-them) is a true plural; the two `minorAccountReview*EmailBody` keys are email templates the user sends to support, where formal is correct. The rest cluster in the video editor, recorder and database-failure copy. |
| `id` Indonesian | `kamu` | mostly consistent | ~13 keys use formal `Anda`, and `feedForYouEmpty` manages both in one sentence: `Feed Untuk Anda kamu kosong.` |
| `it` Italian | `tu` | consistent | Zero courtesy forms — a case-sensitive sweep for `Lei`/`Suo`/`Sua`/`Voi` returns nothing. Lowercase `suo`/`sua` appears but is third-person ("il **suo** profilo" = *their* profile), so do not grep case-insensitively here. |
| `ja` Japanese | です/ます polite; noun form for labels | **split** | No だ / よ / ね sentence endings. Politeness is the neutral register, not stiffness. |
| `ko` Korean | 해요체 | **split** | ~117 keys use 합니다체 across product surfaces, not just developer screens (`videoEngagementLikersEmpty`, `videoErrorVerifyAgeFailed`); ~17 use 반말 (`네 크루는 밖에 있어`), which is never correct in product copy. |
| `ms` Malay | `anda` | consistent | Deliberately different from Indonesian: `anda` is Malay's unmarked form. |
| `nl` Dutch | `je` | consistent | Never `u`. |
| `pl` Polish | `ty` + 2nd-person singular imperatives | consistent | Never `Pan`/`Pani`. |
| `pt` Portuguese | `você` | **split** | Brazilian always — that is where our Portuguese-reading users are, and there is no `pt-PT` to send anyone to. At least 16 keys carry European forms — `tu`-imperatives (`Verifica a tua ligação`), `utilizador`, and the chroma-key and people-lists screens; `userPickerConfirmSemanticLabel` says `utilizadores` beside `userPickerUnavailable`'s `usuários`, on one screen. Those are drift to fix, not a precedent. See [Variety and dialect](#variety-and-dialect). |
| `ro` Romanian | `tu` | mostly consistent | `dumneavoastră` is absent, but Romanian politeness also lives in the verb: at least 7 keys use polite 2nd-person plural (`încercați`, `vă rugăm`), again clustered in the video editor. |
| `sv` Swedish | `du` | consistent | Sweden is du-reformed; `ni` reads as archaic. |
| `te` Telugu | Polite-neutral `మీరు`; prefer respectful plural verb forms | **first pass** | The initial complete locale is machine-assisted. #8473 tracks fluent-speaker linguistic and visual review and is the release-quality gate. |
| `tr` Turkish | `sen` | **split** | Register lives in the suffix, not the pronoun. At least 26 keys use formal 2nd-person plural forms, clustered in the video editor, sound-sync, database-failure and auth copy. Direct collision for the same action: `publishErrorServerUnreachable` = `...tekrar dene`, `videoEditorSplitFailed` = `...tekrar deneyin`. |
| `ur` Urdu | `آپ` | consistent | `آپ` is the neutral form. `تم` reads as brusque, not friendly. |
| `vi` Vietnamese | `bạn` | consistent | |
| `zh` Chinese | `你` | consistent | Never `您`. Simplified script and matching vocabulary; whether we also ship Traditional for readers outside the mainland is open — see [Variety and dialect](#variety-and-dialect) and [#7940](https://github.com/divinevideo/divine-mobile/issues/7940). |

The unreconciled `split` rows are tracked separately so their native-speaker
review cannot disappear into this guide: [`am` #7906](https://github.com/divinevideo/divine-mobile/issues/7906),
[`bg` #7907](https://github.com/divinevideo/divine-mobile/issues/7907),
[`es` #7908](https://github.com/divinevideo/divine-mobile/issues/7908),
[`ja` #7909](https://github.com/divinevideo/divine-mobile/issues/7909),
[`ko` #7910](https://github.com/divinevideo/divine-mobile/issues/7910),
[`pt` #7911](https://github.com/divinevideo/divine-mobile/issues/7911), and
[`tr` #7912](https://github.com/divinevideo/divine-mobile/issues/7912).
The Spanish dialect question those trackers waited on is now settled — voseo,
decided in #7908 — so its reconciliation moves 75 keys toward the file's own
majority rather than rewriting the corpus.

"Current tree" is the shape of today's corpus, measured with the checks in
[Checks you can run](#checks-you-can-run-without-speaking-the-language) —
counts are floors, since a wider marker list finds more. Where it says
**split**, the decision in this table is the target and the file has not been
reconciled yet. Several rows read "consistent" only until someone greps the
verb instead of the pronoun; see
[Where a pronoun grep lies](#where-a-pronoun-grep-lies) before trusting a
clean result.

**When the table and the file disagree, follow the table for the keys you are
touching.** Do not reconcile the rest of the file in the same PR — a 400-key
register sweep buried in a feature PR is not reviewable. Reconciling a locale
is its own change, with its own issue and its own native-speaker review.

---

## Gender: never the masculine default

Where a language forces a gender onto a word that refers to a person, English
hides the problem and every gendered locale inherits it. "Use the standard
form" is not an answer here, because the standard form is masculine. Prefer
the construction with no gender in it; where the language makes you choose,
prefer the non-gendered innovation over the masculine default, and accept
that some readers will dislike it — the same trade the `es` row makes.

In order of preference:

1. **Reword so gender never comes up.** Usually possible, and usually better
   copy. `authWelcomeToDivine` is the worked example: Spanish
   `¡Bienvenido a Divine!`, Portuguese `Bem-vindo ao Divine!` and Italian
   `Benvenuto su Divine!` greet every reader as a man, while French
   `Bienvenue sur Divine !` and Polish `Witaj w Divine!` say the same thing
   with no gender at all. German has the same fix available for the 44 keys
   that name a `Nutzer` or `Benutzer` — address the person (`wenn du jemanden
   blockierst`) rather than naming the noun.
2. **When the language makes you choose, take the non-gendered form** —
   Spanish and Portuguese `-e` — over the masculine, and over the
   parenthesis-and-slash pile-up. **34 keys across six locales currently
   pile up**: `fr` `invité(e)`, `ro` `invitat(ă)`, `pt` `convidado(a)`, `it`
   `bloccato/a`, `es` `eliminado/a`, and 10 Polish keys — 8 of them
   notification lines like `{actorName} polubił(a) Twoje wideo`.
3. **When the person's gender is genuinely unknown, do not guess and do not
   offer both.** The Polish notification strings are the hard case: the actor
   is any user in the world. The fix is a construction that does not inflect
   for them at all, not a slash.
4. **Never address the reader as male by default.** `app_am.arb` does exactly
   that today — every familiar verb form in the file is masculine and the
   feminine is used zero times, which is why the `am` row prefers the polite,
   ungendered forms. Arabic does it in `authSignInOptionsHintPrefix`
   (`لست متأكدًا`).
5. **Agreement travels past the noun.** A neutral noun does not rescue a
   sentence whose adjective or participle still agrees. Read the whole string.

`fil`, `id`, `ms`, `ja`, `ko`, `tr`, `vi` and `zh` have no grammatical gender
to fight. The rest need this section, hardest in `ar`, `am`, `es`, `pt`, `fr`,
`it`, `ro` and `pl`.

---

## Variety and dialect

### Spanish — Rioplatense voseo

One `es` file serves every Spanish-speaking market we ship to, and it is
written in the dialect Divine's own Spanish-speaking team members speak:
Rioplatense *voseo*, as it is written in Uruguay. @rabble decided that in
#7908 — it is a product decision, so it changes there, not in a translation
PR.

The decision keeps the file's baseline rather than replacing it.
`git log -S'Probá' -- mobile/lib/l10n/app_es.arb` traces voseo to #2930, the
original l10n commit; tuteo (`Inténtalo`) enters later, at #3142 and other
video-editor work. So the 233 voseo keys are the house style and the 75 tuteo
keys are the drift — the opposite of what a quick read suggests.

- **Address: `vos`.** Voseo forms throughout — `tenés`, `podés`, `sos`, and
  the accent-final imperatives `Revisá`, `Probá`, `Elegí`, `Compartí`. Not
  `tienes`/`puedes`, not `Inténtalo de nuevo`. The possessive is `tu`/`tus` in
  both dialects, so it needs no change.
- **The regional cost is accepted, not overlooked.** Voseo reads as marked
  outside the Río de la Plata, and there is no second `es` file for the
  readers who see it that way. We take that cost to ship copy the team can
  vouch for, in the voice they actually write in, rather than a register
  assembled to offend no one and belong to no one.
- **No *vosotros*** — it is Spain-only, and the corpus already contains none.
- **Reconciling the 75 tuteo keys is its own PR (#7908)**, not something to
  fold into a feature. They cluster in error copy and the video editor, and 41
  of them are the same sentence, `Inténtalo de nuevo`. `categoryDiy` carries
  both dialects in one string — `Hazlo vos mismo`, a tuteo imperative with a
  voseo pronoun.
- **Vocabulary: the word the team would use.** Where varieties split, take
  the Rioplatense one — `celular`, not `móvil`; `computadora`, not
  `ordenador` — instead of hunting for a compromise noun nobody says out
  loud. The only limit is comprehension: a word other Spanish speakers would
  not *recognise* is worth avoiding, one they simply do not use themselves is
  not.
- **Spelling: `video`, not `vídeo`.** Both are correct Spanish; `video` is the
  Latin-American form and the majority in the current file, though 24 keys
  still carry `vídeo`. This is the single most repeated noun in the app, so it
  is worth pinning.
- Keep `enlace`/`link`, `correo`/`email` consistent *within the file* — see
  [Terminology](#terminology).

### Portuguese — Brazilian, deliberately

One `pt` file serves Brazil and Portugal, and it is Brazilian: `usuário`,
`arquivo`, `tela`, `celular`, with no European counterpart (`utilizador`,
`ficheiro`, `ecrã`, `telemóvel`) anywhere in the file. That is a decision, not
an accident of who translated first — Brazil is where our Portuguese-reading
users are, and Portugal reads Brazilian Portuguese perfectly well.

- **Address: `você`.** At least 16 keys currently use European `tu` forms or
  vocabulary — `Verifica a tua ligação`, `o teu comentário`, `Adiciona tags`.
  They are drift to fix ([#7911](https://github.com/divinevideo/divine-mobile/issues/7911)),
  not a precedent.
- **Where the varieties split, take the Brazilian form.** Do not reach for a
  third phrasing that dodges the split; dodging is how copy stops sounding
  like anyone.
- Colloquial contractions are welcome — the invite copy already says `pro`
  and `pra`.

### Chinese — Simplified today, with the audience question open

The picker advertises **简体中文**, and the file is Simplified with mainland
vocabulary (`视频`, `账号`, `设置`, `上传`) rather than Taiwan/HK forms
(`影片`, `帳號`, `設定`). Keep it that way *within this file* — the script and
the vocabulary have to agree, and half-converting either is worse than
neither.

What is genuinely open is who this file is for. We should not plan around
mainland distribution, which puts a lot of our likely Chinese-reading audience
in Taiwan and Hong Kong, where Traditional is the norm — so `zh-Hant` beside
`zh` is a real possibility rather than a nicety. That is a product decision:
[#7940](https://github.com/divinevideo/divine-mobile/issues/7940).

Mixed script inside one file is a bug either way, and
`arb_script_integrity_test.dart` will not catch it — both scripts are `CJK` to
that guard.

### Malay and Indonesian are not the same locale

`ms` and `id` are separate files on purpose. Do not translate one by copying
the other: `unggah`/`unduh`/`akun`/`pengaturan` are Indonesian;
`muat naik`/`muat turun`/`akaun`/`tetapan` are Malay.

### Slang and loanwords are allowed

- **Use the slang your readers actually use.** The bar is that it is current
  and ordinary in the variety we ship, not that it is safe. A translation with
  every edge filed off is not the neutral option; it is a different product.
- **Keep the English loanword wherever speakers keep it.** `fil` is the
  clearest case: Taglish *is* the register, and ~750 keys carry an English
  tech noun. Coining a pure Filipino word for `upload` would be translating
  something nobody says. French keeping `relay` in 54 of its 72 relay keys is
  the same instinct — it just has to settle on one rendering, per
  [Terminology](#terminology).
- **What to avoid is dated slang and coinages**, not informality. Something
  that was funny in 2019, or a phrase you invented because the English pun
  would not go over, ages badly in a file nobody re-reads.
- **The limit is load-bearing copy** — safety, consent, deletion, age and
  money strings say exactly what they say.

---

## Voice: making the English tone survive

[`brand-guidelines/TONE_OF_VOICE.md`](../../brand-guidelines/TONE_OF_VOICE.md)
sets the dial — in-app UI is low-rebel, high-playful; error
messages are low-rebel, medium-playful; legal is neither. That dial applies to
translations too.

Start from what Divine is: silly, weird, eccentric social media. Not business
software, and not an app auditioning for respectability. A translation that
comes back correct and lifeless has failed at the only thing this section is
about — and no guard will ever flag it, which is exactly why it is written
down here.

**Translate the intent, not the words.** The brand guide's own no-results
example — "Nada. Try something different?" — is an instruction about register,
not a lexical puzzle. The target should be as light in its own language as the
English is in ours.

**When the joke does not travel, find the joke that does.** Every language
has its own way of being funny — reach for that rather than flattening the
string into a statement. A joke that lands in Polish beats the Polish for a
joke that only works in English.

Two things to keep hold of while doing it, and `authWelcomeToDivine` misses
both. English "Welcome to Divine!" became Japanese `やった！入れたよ！` ("Yes!
I'm in!"): charming, but casual beside a large polite corpus, and it drops
both the product name and the "Welcome Home" arrival the brand guide asks
for. Be funny **in the register the rest of that locale uses**, and **keep
what the string had to say**. Restoring the missing product name across
affected locales is tracked in
[#7913](https://github.com/divinevideo/divine-mobile/issues/7913).

**Never soften a load-bearing word.** Safety, consent, money, deletion and age
copy carry meaning that a friendlier synonym destroys. The repo already treats
this as a first-class reason to *defer* rather than approximate — see the
comment on `exploreFeaturedSponsoredBy` in
`mobile/test/l10n/arb_consistency_test.dart`, held out of machine translation
because it must remain an unmistakable commercial disclosure rather than
soften into an editorial credit.

**Match the source's energy, not its punctuation.** Exclamation marks and
ALL CAPS are one language's way of spelling emphasis, and copying the marks
across is not the same as carrying the feeling across. Spanish opens with `¡`,
Japanese has `！`, French puts a space before `!`.

The corpus says the failure this rule normally guards against is not the one
we have. Across all 21 locales, exactly **one** key adds an exclamation mark
English did not have — Japanese `了解！` for "Got it" — and none drop one.
Spanish uses `¡` in exactly the 36 keys where English chose `!` and in no
others, while handling `¿` by itself in 69 of its 70 questions. So the file
knows its own punctuation and never once makes an emphasis decision with it.
That is not restraint, it is punctuation traced from English; `了解！` is the
single place someone made the call locally, and it is the right call.

Raise the energy where that language would raise it, and keep it level where
the brand dial says level: legal, safety, consent, deletion, age and money
copy is neither rebel nor playful in any locale.

**Emoji are the one exception, and not for tone reasons.** The same glyph
carries different meaning by region, so an emoji added into a locale is a
different kind of risk from an exclamation mark. Add one only if you know how
it reads there. English currently uses emoji in two keys —
`videoFeedLoopCountLabel` and `deleteAccountFinalConfirmationTitle`.

---

## Terminology

### Locked terms — never translated, never transliterated

These are names and protocol tokens. Translating them breaks recognition; a
transliteration breaks it and cannot be typed back.

| Term | Why |
|---|---|
| `Divine` | Product name. Always this casing — never `DiVine` or `diVine` in copy. |
| `Nostr`, `NIP-XX` | Protocol names. |
| `npub`, `nsec`, `nevent`, `nprofile` | Bech32 prefixes users copy and paste. |
| `nostr:`, `bunker://`, `wss://`, `https://` | URI schemes. A translated or capitalized scheme is not typeable. |
| `Blossom`, `Keycast` | Service names. |

Bare Latin script is allowed in every locale precisely so these survive —
that is what `_allowedScripts` in `arb_script_integrity_test.dart` encodes.

The casing rule is currently broken at the source: seven keys in `app_en.arb`
(`nostrInfoIntroBuiltOn`, `listCollaboratorSearchHint`,
`collaboratorInviteDmBody`, `collaboratorInviteDmBodyUntitled`,
`invitesShareWithPeople`, `invitesShareMessage`, `invitesShareSubject`) write
`DiVine` or `diVine`, and every locale faithfully mirrored it. Fix that in
English first — a translator copying the source is doing the right thing.
The source-side correction and locale mirrors are tracked in
[#7904](https://github.com/divinevideo/divine-mobile/issues/7904).

### Everything else: consistent within a locale

Words like *loop*, *relay*, *repost*, *feed* are common nouns describing what
the product does. Whether a locale keeps the English word, adapts it, or
translates it is the translator's call — but **one rendering per term per
locale, used in every key.**

The current tree shows what the absence of that rule costs. `Loops` is the
label on a profile stat and the unit in a count, and today:

- Italian says `Loops` on the label and `{count} loop` in the count.
- Bulgarian says `Лупове` on the label and `{count} лупа` in the count.
- French translates *relay* in 18 of the 72 keys that use it and keeps the
  English word in the other 54.

Nobody chose that. Each key was individually fine.

When you introduce a term into a locale for the first time, grep the file for
how the same English word was rendered before, and match it.

---

## Reviewing a translation you cannot read

Most translation PRs here will be reviewed by someone who does not speak the
target language. That is the normal case, not a failure, and the review model
is built around it. Sort every finding into one of three tiers.

**Tier 1 — mechanical. Machine-checked; no language knowledge needed.**
Key parity, placeholder integrity, ICU plural arms, script contamination,
values shared across unrelated scripts. Already guarded — see
[What is enforced](#what-is-enforced-and-what-is-not). If CI is green, Tier 1
is done; do not re-check it by eye.

**Tier 2 — style-guide conformance. Any reviewer can check this.**
Register matches the table above. No gendered both-forms pile-up
(`invité(e)`, `bloccato/a`). No locked term was translated. A term introduced
into a locale matches how that locale already renders it. An emoji the source
does not have is worth asking about — it is not automatically wrong, but it
is the one mark whose meaning moves between regions. Every check in this tier has a
command in the next section, and **none of them require reading the language.**
This tier is where a non-speaking reviewer adds real value, and it is exactly
where the drift in this repo has come from.

**Tier 3 — naturalness. A native speaker, or the people using the app.**
Idiom, humor, whether the copy sounds like a person. No command finds this,
and for most of our locales no reviewer here finds it either.

### The review we actually have

We have native speakers for a few of the 21 locales and nobody for the rest.
So any rule beginning "a native speaker must" resolves in practice to one of
two things: it gets ignored, or that locale stops shipping. Neither is review.

What we actually have is three loops, and the third one is not a fallback:

1. the guards, on every push;
2. a non-speaking reviewer running the Tier 2 checks;
3. **users telling us when a string is wrong.**

Ask a native speaker when there is one to ask, and spend that scarce attention
on a new locale, onboarding and first-run copy, safety / consent / deletion /
age-gate / money copy, and changes to this guide's register and variety
tables. Everything else — a typo, a setting label, a restored key, a joke —
ships on Tier 1 + Tier 2.

### When nobody speaks the language — the normal case

1. **Ship it.** A playful string that turns out slightly off is a smaller
   problem than a locale frozen at English or flattened into a register
   nobody enjoys reading. Being unreviewable is not a reason to be boring
   (see [Voice](#voice-making-the-english-tone-survive)).
2. **Except for load-bearing copy.** If a safety, consent, deletion, age or
   money string cannot be checked by anyone, defer it rather than guess:
   leave the key out of that locale, add it to `_knownUntranslatedDebt` in
   `mobile/test/l10n/arb_consistency_test.dart` with a comment naming the
   reason and a tracking issue, and let it fall back to English. English is a
   worse experience; a confidently wrong safety string is a worse outcome.
3. **Never block a bug fix on review that cannot happen.** Approve on Tier 1 +
   Tier 2 and say in the review that naturalness was not assessed.

### How a user reports bad copy

Settings → Support Center (`/support-center`) → Bug Report. A report naming a
screen and a language is a Tier 3 finding with a source behind it — the thing
this repo otherwise cannot generate. Treat it as an ordinary bug, fix the key,
and if it overturns a decision in this file, change the file too.

The report carries platform, device model, OS and app version, and the
**resolved app UI locale** — the language the app was actually rendering —
plus the device locale when it differs (`bug_report_service.dart`, #7939). So a
copy report already names the language to route it by; a resolved locale that is
English while the device asked for another language is itself a signal (a
missing translation forcing the fallback), not a bad string in that language.

### Who signs off

`.github/CODEOWNERS` routes every ARB change to `@divinevideo/reviewers`;
there is no per-locale owner today. So:

- **The reviewer of record** is whoever the team assignment picks. Their job is
  Tier 1 (read CI) and Tier 2 (run the checks). Approving with "looks fine" on
  a language you do not read is not a review — the parity guard already told
  you that much.
- **Tier 3 sign-off**, where a speaker exists, is that named person in a
  review comment. If they are not a repo reviewer, quote their verdict in the
  PR and link the source. Where no speaker exists, nobody signs off on
  naturalness — say so in the review and let the user reports do that job.
- **This guide's decisions** are changed by a PR to this file, not by a
  translation PR that quietly disagrees with it.

---

## Checks you can run without speaking the language

Run from `mobile/`. Each maps to a Tier 2 rule.

```bash
# Tier 1 — the guards. Everything they cover is off your plate.
flutter test test/l10n/
```

```bash
# Register: does this locale mix address forms?  (example: fr)
python3 - <<'PY'
import json, re
d = json.load(open('lib/l10n/app_fr.arb'))
vals = {k: v for k, v in d.items() if not k.startswith('@') and isinstance(v, str)}
formal = [k for k, v in vals.items() if re.search(r'\b(vous|votre|vos)\b', v)]
print(len(formal), 'keys use vous/votre/vos'); print(formal[:20])
PY
```

Swap the pattern for the locale you are reviewing: `de` `\b(Sie|Ihnen|Ihre?)\b`,
`nl` `\b(u|uw)\b`, `it` `\b(Lei|Suo|Sua)\b` **case-sensitively**, `es`
`\b(tú|tienes|puedes|quieres|Inténtalo)\b` — tuteo is the drift there, since
the target is voseo — `ja` `(だよ|してね|するよ|ないよ)`, `ko` `(습니다|ㅂ니다)` and
`(있어|없어|이야)`, `zh` `您`, `id` `\bAnda\b`. The Korean 반말 pattern is
deliberately unanchored: real values carry punctuation, and this command is a
candidate finder rather than a claim that every occurrence is sentence-final.

The gender pile-up has an exact detector, and it needs no language knowledge
at all — every one of its 34 current hits is a real one:

```bash
# Gendered both-forms: invité(e), invitat(ă), convidado(a), bloccato/a
grep -nE '\((e|a|o|ă)\)|[a-z]/[ao][^a-z]' lib/l10n/app_*.arb
```

It finds nothing in the locales that reword instead, which is the point —
see [Gender](#gender-never-the-masculine-default).

### Where a pronoun grep lies

The snippet above is a starting point, and in five of our locales it is not
enough. Every one of these produced a wrong answer during the audit that wrote
this guide, so treat a clean pronoun grep as *no information*, not as a pass:

- **Register can live in the verb, not the pronoun.** Turkish, Bulgarian,
  Romanian and Amharic all carry politeness in the verb ending. Bulgarian's
  courtesy pronoun `Вие` appears **zero** times in a file that nonetheless
  switches register mid-sentence. Grep the imperative — `dene` vs `deneyin`,
  `Докосни` vs `Докоснете`, `încearcă` vs `încercați`.
- **A possessive can belong to both registers.** Spanish `tu`/`tus` is shared
  by tuteo *and* voseo — there is no `vuestro` in voseo — so counting `tu` as a
  tuteo marker scores voseo strings as tuteo. 72 keys carry both. Use only
  markers the other register cannot produce: accented `tú`, `tienes`/`puedes`,
  or the accent-final imperatives `Revisá`/`Probá`.
- **`\b` does not travel, and this guide's own gender command proved it.**
  Written as `[a-z]/[ao]\b`, that command returns its 34 real hits under GNU
  and BSD `grep` and something else entirely under `git grep`, which reads
  `\b` in an ERE as a literal `b`. It then reports `https://divine.video/video/abc123`
  in five locales with no gendered copy in them at all, and misses every
  `bloccato/a` — because a closing quote is not a `b`. The published pattern
  anchors on an explicit non-letter instead, and returns the same 34 under
  both engines and under `LC_ALL=C`.
- **A masculine default is invisible to a register grep.** Nothing above
  notices that `¡Bienvenido a Divine!` greets every reader as a man; the
  string has no pronoun in it and no register problem. Gender is a separate
  pass, with its own command above.
- **Case-insensitive matching invents findings.** Italian `Suo`/`Sua` is
  courtesy; lowercase `suo`/`sua` is ordinary third person. Matching without
  case reports 15 offenders in a file that has none.
- **Short words match inside longer ones in unspaced scripts.** Urdu `تم`
  looks like the informal pronoun and appears in 51 keys — every one of them
  inside `ختم`, `تمام`, `مشتمل` or `تمباکو`. Word-boundary matching finds
  zero. Amharic `ህ` behaves the same way. Anchor on whole words or whole
  imperative forms.
- **`str.lower()` is not safe in Turkish.** Python lowercases `İ` to `i` plus
  a combining dot, so `'İptal Et'.lower()` does not contain `iptal et`. Use
  `re.IGNORECASE` rather than pre-lowering.
- **The same character is correct in one locale and a defect in the next.**
  Turkish `ş`/`ţ` are cedilla (U+015F / U+0163); Romanian `ș`/`ț` are
  comma-below (U+0219 / U+021B). They look identical and **neither NFC nor NFD
  unifies them**. `app_tr.arb` holds 1,312 cedilla characters and zero
  comma-below; `app_ro.arb` holds 1,681 comma-below and exactly one cedilla —
  which is a real corruption. A lint that bans one codepoint globally would
  flag 976 correct Turkish keys; a lint that allows it globally cannot see the
  Romanian defect. Any diacritic rule has to be per-locale. The Romanian
  corrections are tracked in
  [#7914](https://github.com/divinevideo/divine-mobile/issues/7914).

If the locale you are reviewing is in that list and you only ran the pronoun
grep, say so in the review rather than reporting the file as clean.

```bash
# Locked terms: did a translation drop a name or a protocol token?
python3 - <<'PY'
import json, glob, os
base = 'lib/l10n'
en = {k: v for k, v in json.load(open(f'{base}/app_en.arb')).items()
      if not k.startswith('@') and isinstance(v, str)}
for term in ['Divine', 'Nostr', 'npub', 'nsec', 'bunker://', 'wss://', 'Blossom']:
    keys = [k for k, v in en.items() if term.lower() in v.lower()]
    for f in sorted(glob.glob(f'{base}/app_*.arb')):
        loc = os.path.basename(f)[4:-4]
        if loc == 'en':
            continue
        d = json.load(open(f))
        missing = [k for k in keys
                   if isinstance(d.get(k), str) and term.lower() not in d[k].lower()]
        if missing:
            print(f'{loc}: {term!r} absent in {len(missing)} key(s): {missing[:4]}')
PY
```

```bash
# Term consistency: how does this locale render one English word? (example: relay in fr)
python3 - <<'PY'
import json
base = 'lib/l10n'
en = json.load(open(f'{base}/app_en.arb'))
fr = json.load(open(f'{base}/app_fr.arb'))
keys = [k for k, v in en.items()
        if not k.startswith('@') and isinstance(v, str) and 'relay' in v.lower()]
kept = [k for k in keys if isinstance(fr.get(k), str) and 'relay' in fr[k].lower()]
print(f'{len(kept)}/{len(keys)} keys keep the English word — the rest translate it')
PY
```

A non-zero result is not automatically a bug: French `vous` is correct as a
real plural, and a locale may legitimately keep an English word in some
grammatical positions. It is a **list of things to look at**, which is
precisely what a reviewer who does not read the language otherwise lacks.

---

## What is enforced and what is not

| Rule | Enforced by |
|---|---|
| Every locale defines every English key | `arb_consistency_test.dart` (+ `_knownUntranslatedDebt`) |
| Every placeholder the English value actually substitutes survives translation | `arb_consistency_test.dart` (selector-only arguments are deliberately exempt — see below) |
| No plural arm hardcodes a literal number, in any locale | `plural_arm_number_test.dart` |
| A named list of countable keys inflects **in English** | `countable_plural_test.dart` |
| `listVideoCount` / `profileFollowerCountUsers` keep their arms in `pl` and `ro` | `countable_plural_test.dart` (those two locales, those keys) |
| **A non-English value has a plural block at all** | **nothing — see below** |
| No wrong-script characters in a locale | `arb_script_integrity_test.dart` |
| No value shared across unrelated scripts (stale/wrong-language paste) | `arb_script_integrity_test.dart` |
| Named disclosures survive translation (`Divine`, `Nostr`, CSAM, Bluesky, Keycast) | `arb_consistency_test.dart`, per-key |
| Copy never reveals a block/mute relationship | `disclosure_invariant_test.dart` |
| Shipped locales match the Android/iOS declarations | `platform_locale_declarations_test.dart` |
| **Register matches this guide's table** | **review only** |
| **Locked terms survive in every key** | **review only** — a general guard is proposed in #7248 |
| **One rendering per term per locale** | **review only** |
| **No gendered both-forms pile-up** | **review only** — exact command in [Checks](#checks-you-can-run-without-speaking-the-language) |
| **Naturalness** | **review only** — a native speaker where one exists, and user reports where none does |

A green CI proves the top half. It says nothing about the bottom half, which
is the half this guide is about.

Two gaps are worth knowing about, because both look like Tier 1 problems and
neither is.

**A partly-translated value passes every guard.** It has the key, the
placeholders and the right script, so nothing fires.
`collaboratorInviteDmBody` still ends in the English sentence
`Open diVine to review and accept.` in 19 of the 22 non-English locales. The
translation pass is tracked in
[#7905](https://github.com/divinevideo/divine-mobile/issues/7905).

**A flattened plural passes every guard outside English.** `countable_plural_test.dart`
proves the *English* value inflects, and spot-checks two keys in `pl` and one
in `ro`; nothing asserts that the other locales kept a plural block. Seven keys
that pair an int selector with a display string — `analyticsViewsCount`,
`analyticsCommentsCount`, `analyticsRepostsCount`, `analyticsInteractionsCount`,
`categoryVideoCount`, `messageRequestVideosCount`, `relaySettingsEventsSummary` —
are flat in **all 21** non-English locales, so they render the plural noun at
`n = 1`:

```
en  1 view          es  1 visualizaciones   de  1 Aufrufe
fr  1 vues          pl  1 wyświetleń        pt  1 visualizações
```

`listVideoCount` is the control: it is one of the keys the `pl`/`ro`
assertions cover, and it correctly renders `1 film` / `1 videoclip`. The bug
sits exactly where the guard does not reach.

The placeholder guard does not catch it either, and for a defensible reason.
It exempts selector-only arguments — the `count` in `{count, plural, …}`
substitutes no text of its own — because "a language without that distinction
may legitimately render a bare noun instead". That is right for Japanese,
Korean, Chinese and Vietnamese. It is not right for Polish, Spanish, German,
French or Portuguese, which all have the distinction and lost it anyway. The
exemption is sound; its blast radius is wider than its reason.

Fixing the copy needs per-language plural categories (Polish one/few/many,
Romanian one/few/other, Arabic six), so it is a translation change per the
rules above, not a mechanical sweep.

Related open work, so this guide does not duplicate it: #3633 (keys with no
plural syntax at all), #7248 (stale English revisions and wrong-language values
that survive the parity guard), #7755 (ICU plural categories missing per CLDR),
#6913 (orphaned ARB keys), #7632 (remaining deferred translation debt).

---

## Changing a decision here

Every row in the register table and every entry in the locked-term list is a
default, not a verdict. If a native speaker says a locale's row is wrong, they
are almost certainly right — open a PR against this file that changes the row
and says who assessed it. Reconciling the existing copy to the new row is a
separate PR with its own issue.
