# DivineSticker provenance

This file records where every sticker in `assets/divine_stickers/` came from. Each one was generated from a text prompt written for Divine: no photograph, drawing or other image was given to the generator. The artwork is dedicated to the public domain under CC0 1.0; see [LICENSE](LICENSE).

## How a sticker was made

1. **Prompt.** Each prompt is the sticker's Subject, listed below, followed by one of the two style blocks. The Subjects describe generic objects: products are described without their brands, and no Subject asks for a real person, a logo or an existing artwork.
2. **Generation.** The prompts were run on 11 and 12 November 2026 (UTC) in an OpenAI Codex session, through its built-in image generation tool, with two attempts per prompt. The generator received the prompt text and nothing else. Every original is a PNG carrying a C2PA manifest signed by OpenAI's media service. The manifest records the action `c2pa.created` by the software agent ChatGPT `gpt-image`, with the digital source type `trainedAlgorithmicMedia`. The generation time listed for each sticker is that action's `when`.
3. **Choice.** A person picked one of the two attempts for each sticker. Where neither attempt kept the sticker's meaning, the Subject was rewritten and run again. Only the chosen attempt is listed.
4. **Processing.** `tools/process_divine_sticker.dart` turned each original into the shipped file with fixed settings: alpha below 8 cleared, a crop to the pixels with alpha above 32 plus a margin of 2% of the long side (at least 2 px), a Lanczos-3 downscale on premultiplied alpha to 512 px on the long edge (never an upscale), then `cwebp -near_lossless 60 -z 9 -mt -metadata none` with cwebp 1.6.0 (libsharpyuv 0.4.2).

The encoder strips metadata, so the shipped WebP files do not carry the C2PA manifest; the originals do. The originals, both attempts for every prompt, are archived by Divine outside this repository together with the generation records of the session. Each sticker below names its original's path in that archive and its sha256.

To rebuild a sticker from its original, run this from `mobile/` with cwebp 1.6.0 on the path:

```bash
dart run tools/process_divine_sticker.dart <original.png> <sticker.webp>
```

With that cwebp version, rerunning the tool on each original reproduced the shipped file byte for byte.

## Style blocks

**Style A** was used in the first two runs (73 of the stickers here). **Style B** revised it so a Subject may spell out exact text, group several items, ask for a close-up, or include people who are not identifiable (107 stickers).

### Style A

```text
Style: a photograph of a real, physical object, shot for a glossy colour pop magazine published between 1997 and 2003, printed on coated magazine paper and then cut out by hand with scissors. Photorealistic materials and textures, bright saturated late-90s pop colour, crisp flash or bright studio lighting with natural highlights and soft shading on the object itself. Subtle magazine print grain and a very fine halftone texture, with slight ink softness. The scissor cut follows the object's outline closely but not perfectly, with a mildly irregular edge and an occasional thin sliver of white paper; no uniform white sticker border.
Composition: exactly one subject, shown whole and centred, with a small transparent margin on every side; it must stay readable at 128 pixels.
Background: true PNG alpha transparency everywhere outside the cut line. No backdrop, floor, cast shadow, glow, frame, rectangle or checkerboard pattern.
Never include: text, letters, numbers, logos, brand names, labels, trademarks, watermarks, or a design that copies a recognisable commercial product; real or identifiable people or faces; 3D render, CGI, clay, vector, emoji, cartoon or illustration styles; sepia, vintage ageing or heavy damage.
```

### Style B

```text
Style: a photograph of a real, physical subject, shot for a glossy colour pop magazine published between 1997 and 2003, printed on coated magazine paper and then cut out by hand with scissors. Photorealistic materials and textures, bright saturated late-90s pop colour, crisp flash or bright studio lighting with natural highlights and soft shading on the subject itself. Subtle magazine print grain and a very fine halftone texture, with slight ink softness. The scissor cut follows the subject's outline closely but not perfectly, with a mildly irregular edge and an occasional thin sliver of white paper; no uniform white sticker border.
Composition: the subject described above, centred with a small transparent margin on every side, shown whole unless the Subject asks for a close-up; it must stay readable at 128 pixels. When the Subject names more than one item, they form one tight group that reads as a single sticker.
Background: true PNG alpha transparency everywhere outside the cut line. No backdrop, floor, cast shadow, glow, frame, rectangle or checkerboard pattern.
Never include: any text, letters or numbers other than exactly what the Subject spells out, and spell those exactly; logos, brand names, trademarks, watermarks, or a design that copies a recognisable commercial product; people or faces unless the Subject asks for them, and never a real or identifiable person; 3D render, CGI, clay, vector, emoji, cartoon or illustration styles, except printed or hand-drawn artwork that is part of the subject itself when the Subject asks for it; sepia toning of the whole image, or heavy damage.
```

## Not in this set

- `art`, `trollFace`, `tapedBanana` and `spaceInvader` were held back in review over their resemblance to existing works, and were not regenerated.
- `bobRoss` depicted a real person and was left out.
- `shockedMan` and `idLicense` were unused and removed.
- `grandfather`, the last variant still drawn from an OpenMoji SVG, was removed rather than regenerated. Its two prompts now use `videoClapBoard` and `secureVault`.

## Stickers

Each prompt is `Subject: ` followed by the text below, a blank line, and the named style block.

### `ac_remote.webp`

a white plastic air-conditioner remote control seen from the front at a slight angle, with a small grey LCD screen at the top showing a snowflake symbol and the number 22; below it four rounded grey buttons in two rows of two, two of them marked with simple up and down arrows and the other two labelled Mode and Swing in small dark grey letters; and at the bottom one big round orange button with a white power symbol, a circle broken at the top by a short vertical line, centred on it. No other text, letters, numbers or logos.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T12:15:29.279032832Z
- Original: `sticker-regeneration-new3/originals/ac_remote-2.png`, 976 × 1611 PNG, sha256 `f6a138392046d89533837b2b02bbeed29a7612a87b1cb68d631667ef929e10a9`
- Shipped: 277 × 512 WebP, 91,716 bytes, sha256 `98df1135d4b20cd779dca3d17a905eabe1fd30175e1c749e5166632d4e3c61d1`

### `alert.webp`

a real yellow triangular warning sign with rounded corners and a thick black border, with one large black exclamation mark printed in the centre as its only symbol. A thin rigid sign seen at a gentle three-quarter angle, so it does not look perfectly flat-on, with light scuffs from use. No pole, bracket or wall.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T18:59:43.407136127Z
- Original: `sticker-regeneration-pilot/originals/alert-2.png`, 1322 × 1190 PNG, sha256 `1ea9db499725b034153db8704ebc5a727915b746197d2f05f2ba28346663b359`
- Shipped: 495 × 512 WebP, 123,934 bytes, sha256 `83a74438b05d137f2527c051adcde64e0fcc3fde2772dcb66df9e205563659bd`

### `ashtray.webp`

a heavy round clear glass ashtray seen from slightly above, holding three crushed cigarette butts with orange filters and a little grey ash. No cigarette packet, lighter or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:24:12.119597148Z
- Original: `sticker-regeneration-new/originals/ashtray-1.png`, 1536 × 1024 PNG, sha256 `512572d12cf4976dc984c3769e32449a1bc3cf9b687fa1db3600047dc09c7c70`
- Shipped: 512 × 416 WebP, 187,686 bytes, sha256 `0ebdbbfe294e300b8e687dd912683d32e413d68b5fa3d873302ebe2cd0742427`

### `avocado.webp`

half of a ripe avocado with its large brown pit in place, showing creamy pale-green flesh and dark green skin, seen at a slight angle. No knife, board or other half.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T20:40:38.465096044Z
- Original: `sticker-regeneration-full/originals/avocado-2.png`, 1536 × 1024 PNG, sha256 `ac040221b5da4ce8accc12ad9d2f3617fa1d34f423875c7e4df823c58c2a5212`
- Shipped: 512 × 432 WebP, 161,210 bytes, sha256 `4b872902c2c31ddae610560e0bda3b7b36ca5b2db4a8d2a1b5684ab589a9a5b9`

### `baby_bottle.webp`

a baby's feeding bottle full of milk, in clear plastic with a pale blue screw ring and a soft silicone teat under a clear dome cap, with printed measuring ticks but no numbers. No logo or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T09:56:20.574608484Z
- Original: `sticker-regeneration-new/originals/baby_bottle-2.png`, 1024 × 1536 PNG, sha256 `ac89af63c2866f81edeee5053459c20411d8a40f96373d88ff9b21a28902fe22`
- Shipped: 216 × 512 WebP, 70,628 bytes, sha256 `3072d31ad5d981508fb8cf0f4c5be69f3c4528f2098baad141635f2fed8112bc`

### `baby_car_seat.webp`

an empty infant car seat carrier with a carrying handle arched over the top, grey fabric padding in a black plastic shell, a five-point harness with a red buckle and a folded-back sun canopy, seen from a front three-quarter angle. No baby, logos or labels.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:25:30.397890226Z
- Original: `sticker-regeneration-new/originals/baby_car_seat-1.png`, 1263 × 1246 PNG, sha256 `2b428e3a1c33e82253c4f92f513e4c3ccf6fee580825e2d3a093fe8b98a06b16`
- Shipped: 489 × 512 WebP, 152,720 bytes, sha256 `02c732969f80d78a6a1c187efef7066df034e47558957957406e2fe65c0e7ba4`

### `balloon_dog.webp`

a real party balloon animal shaped like a small dog, twisted from long glossy bright red latex balloons, with visible twist points, a knot and soft natural highlights. Ordinary latex, not mirror-polished metal and not a sculpture.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T03:54:28.671079311Z
- Original: `sticker-regeneration-redo/originals/balloon_dog-1.png`, 1536 × 1024 PNG, sha256 `bfea93955db6ec590558e5cc8e0228447230bf61ec036d86dfe4af7648ab8de0`
- Shipped: 512 × 432 WebP, 95,376 bytes, sha256 `0752c1ea108a40709be62dd245332f510b8279e64ee2df8b1c484a0e4a63a6dc`

### `banana.webp`

a ripe yellow banana, half-peeled and standing upright, with three strips of peel hanging down around it and the pale creamy fruit showing at the top. No sticker or label.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T03:54:52.644945783Z
- Original: `sticker-regeneration-redo/originals/banana-1.png`, 1024 × 1536 PNG, sha256 `488907c02e649062c3f3dfe0105569023ad7a448c5e762e749f56dea3da96cf5`
- Shipped: 346 × 512 WebP, 74,140 bytes, sha256 `c160ebc6c73825a6afdea86b2bd40314ac6fdeb798801061cfbeff9ae64427fd`

### `baseball_bat.webp`

a wooden baseball bat in pale natural ash wood with black grip tape wrapped around the handle end, lying diagonally from lower left to upper right. No logo, branding or text burned into the wood.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:26:06.021371878Z
- Original: `sticker-regeneration-new/originals/baseball_bat-1.png`, 1536 × 1024 PNG, sha256 `a1e1667fc998ed208840992aa711be84220ec42f7100eae79f2144872dfdc2f6`
- Shipped: 512 × 345 WebP, 27,534 bytes, sha256 `98afa983e5b628d981fe8d6321be1606c29fb98590cdc4132a93c5d635cb3573`

### `basketball.webp`

an orange basketball with a pebbled leather surface and black seam lines, slightly scuffed from use. No logos, text or numbers.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:26:37.060226533Z
- Original: `sticker-regeneration-new/originals/basketball-1.png`, 1269 × 1240 PNG, sha256 `26fb769b39d3811b9a7cbf57fcf4015fc91b456d7e8549458368b03f2bf92a9a`
- Shipped: 500 × 512 WebP, 261,922 bytes, sha256 `a55cf03e92c62748eb263c0826f2821165f3b80c3136c8a2d51773efa6c328c3`

### `beach_ball.webp`

a classic inflatable beach ball with alternating panels of bright red, yellow, blue and white vinyl and a small white valve, glossy and fully inflated. No printing.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T20:41:59.892964664Z
- Original: `sticker-regeneration-full/originals/beach_ball-2.png`, 1254 × 1254 PNG, sha256 `321244f815e11e6bc3cd329a18705c9e6cfa63dea2ae7363cf862478839ff2b0`
- Shipped: 501 × 512 WebP, 152,660 bytes, sha256 `94ccb2b1a0bce864cf2d7bdd4ec3d73963df97ac0de6a856ea3ceb4547137e22`

### `beer_can.webp`

a cold aluminium beer can beaded with condensation, printed with an invented design: bright tangerine orange all over, with a cream oval in the upper half holding a simple black emblem of a hop cone; below the oval, the words Premium Beer in flowing black script lettering; and lower down a cream band that runs all the way around the can, with the word LAGER in bold, stylised black serif capitals on it. Only those three words, spelled exactly; no barcode, other text, or design that resembles a real beer brand.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T12:15:53.204692542Z
- Original: `sticker-regeneration-new3/originals/beer_can-2.png`, 1024 × 1536 PNG, sha256 `2b08d9ccfe7dada47420cf54121c01a3ff4e195c6af62cb962ac6b944dbaa3a6`
- Shipped: 266 × 512 WebP, 122,666 bytes, sha256 `85a06250aa288a7d6cdc35ca6dc5d6df1ef265ad5016b86d1ab5f375877ab4ea`

### `bicep.webp`

one adult arm flexed to show a strong bicep, from the shoulder to a closed fist, seen from the side. Medium, warm golden-tan skin with natural texture. No face, torso, sleeve, tattoo or jewellery.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T19:48:01.750349141Z
- Original: `sticker-regeneration-full/originals/bicep-1.png`, 1297 × 1212 PNG, sha256 `c23fadc4e6ef47d927a51773479211228e72d878ccf1937f14f39bfd1dec4c24`
- Shipped: 496 × 512 WebP, 96,446 bytes, sha256 `69d275104d051df20b9412e97d53c21ca21c4240323172104a975c23e1883274`

### `binoculars.webp`

a pair of compact black rubber-armoured binoculars with a central focus wheel and glinting lenses, seen at a three-quarter angle. No strap and no markings.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T20:43:01.619527406Z
- Original: `sticker-regeneration-full/originals/binoculars-2.png`, 1536 × 1024 PNG, sha256 `daa336a074bc773429981d42261e8e9a3aab0645afa739c44cdb50ff68d698f0`
- Shipped: 512 × 395 WebP, 112,640 bytes, sha256 `3e359d961f28c259b4e20913fdfb42e5f655b23ea41374360ba0ed54bce11489`

### `biohazard_sign.webp`

a square red metal warning plate with rounded corners and a small screw hole in each corner, with a large black biohazard symbol printed in the centre: three open interlocking crescents around a small central ring. Seen almost straight on, with light scuffs. No text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:27:53.560266181Z
- Original: `sticker-regeneration-new/originals/biohazard_sign-1.png`, 1254 × 1254 PNG, sha256 `32c7e3cdf124391a427774a2aedf4c0cba1a35dd1a68f7553479ee4289d8c55c`
- Shipped: 512 × 509 WebP, 198,144 bytes, sha256 `9617b2eb7ef9e30d494b0fbfeccda8dc86a0ab3636efce10879245375abe51c5`

### `blocked.webp`

a round metal safety sign that means "no access for unauthorised persons", seen almost straight on: a white face with a thick red border and a red diagonal bar from top left to bottom right. In the lower left of the white face, below the bar, a minimal black line drawing shows a person's head and shoulders in profile, facing right, wearing a rounded hard hat, with the mouth open in a small round O as if shouting; the red border cuts the figure off on the left, as if the person stands behind the sign. From the shoulder, an outlined arm reaches up and to the right to a huge solid black open hand, palm out and fingers spread upwards, that dominates the sign: it is more than half as tall as the whole sign, fills most of the upper right of the white face with its fingertips close to the red border, and sits in front of the red bar, covering its middle. Light scuffs from use. No pole, bracket or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T09:59:43.044000041Z
- Original: `sticker-regeneration-new/originals/blocked-2.png`, 1254 × 1254 PNG, sha256 `20eef1a3db8a1b6d7ad59ea40b5ae21efb491c2cc123cc506e1d861bff86f0a7`
- Shipped: 503 × 512 WebP, 175,410 bytes, sha256 `c742016eed7d58b1c2ca15c0e00b8652a5e351abb23b76735991a175751c8a6d`

### `bomb.webp`

a classic round black bomb with a short lit fuse throwing off bright orange sparks, made as a real glossy physical prop with a small metal cap. The sparks stay close to the fuse. No explosion, smoke cloud or words.

- Prompt: the first one written for `boom`, which described a bomb. This result became its own sticker, and `boom` got a new Subject.
- Style A, attempt 1 of 2
- Generated: 2026-11-11T19:48:52.943846696Z
- Original: `sticker-regeneration-full/originals/boom-1.png`, 1263 × 1245 PNG, sha256 `b0dd5d27684e8fad1a04e48d1fe5814885c7b7e33cd50bcdae8b88bea772049b`
- Shipped: 371 × 512 WebP, 115,752 bytes, sha256 `61cc4c18cd87fb8c98ff9047024addb96475bfc58b6550460f19fd0e9fbb95db`

### `boom.webp`

a die-cut cardboard comic-book sound-effect sign, photographed as a real printed object: a jagged yellow starburst inside a larger cyan burst, with a thin white cardboard edge, printed with the word BOOM! in bold slanted red comic capitals with a black outline and drop shadow. Only that word.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T03:55:49.478358618Z
- Original: `sticker-regeneration-redo/originals/boom-1.png`, 1536 × 1024 PNG, sha256 `c8c6bcfdeaad7c8ad31ad240e64ad40c5fc2851614a59a45786983cb080140b6`
- Shipped: 512 × 347 WebP, 135,570 bytes, sha256 `603acb00c9d8c578dec79c7e6ceb3546d0488c318c1488e0cdd11eef7763bbbc`

### `broken_heart.webp`

a glossy red ceramic heart broken into two pieces along a jagged zigzag crack, the two halves slightly apart, with small chips along the break.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T19:49:11.606546378Z
- Original: `sticker-regeneration-full/originals/broken_heart-1.png`, 1336 × 1177 PNG, sha256 `0c6fc3cf1b10f3b5a437f28146c002d9cc76d00bd706b0093c072d89ab8cc1dd`
- Shipped: 512 × 444 WebP, 135,776 bytes, sha256 `9af9f66e4f7e7f2c2e71d711341dea2bfda9ec4b4c162dd1e93648134441c328`

### `cactus_vase.webp`

a handmade ceramic bud vase shaped like a cactus, with a tall central trunk and two raised arms, the top of the trunk and of each arm ending in a small round opening. Speckled cream-white glaze with tiny brown flecks. Empty, with no flowers or plants.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:26:21.728306580Z
- Original: `sticker-regeneration-redo/originals/cactus_vase-2.png`, 1289 × 1220 PNG, sha256 `41ad56720c9b9b674415468d4421fae928f3ff6dc8e4225abda1c12066438a36`
- Shipped: 401 × 512 WebP, 115,530 bytes, sha256 `07806815841c8e42526ccb9a58e3f9812c4e96b61e3438cc2f82b6c7792eb7d8`

### `car_keys.webp`

a set of car keys on a silver metal key ring: a black plastic flip-key fob with its metal blade folded out and three rubber buttons marked with simple lock, unlock and boot symbols, plus one plain brass door key. No brand logo, letters or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:00:01.869422133Z
- Original: `sticker-regeneration-new/originals/car_keys-2.png`, 1536 × 1024 PNG, sha256 `bea7044e56cdf5269414d1b8e311e18738a5c980c1e126368b2b5b80ef72db2d`
- Shipped: 512 × 357 WebP, 79,312 bytes, sha256 `0855bd3a819f2c8b0a814f0e0586b6e6231120a6a03da22e4f74377b335686a9`

### `cassette_tape.webp`

an audio cassette tape inside its clear plastic case, seen at a slight angle, with the tape's two reels visible through the case. The printed card inside the case has a bold blue band and a white stripe, and its only text is C60 in large white letters. No brand names or other text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:26:38.132207663Z
- Original: `sticker-regeneration-redo/originals/cassette_tape-2.png`, 1536 × 1024 PNG, sha256 `fa9938c3577e1c19a94f4793dd2b7d42bb42f442e8fb14b0c7654b2bb53831e9`
- Shipped: 512 × 377 WebP, 155,194 bytes, sha256 `cfbd8c5218da7023eb2e2de1ab5900efad2477519a8049636d4d5a1f3a28262b`

### `cat.webp`

a fluffy grey cat with small folded-down ears and big round orange eyes, sitting upright on its bottom like a person, with its hind legs stretched out in front and its belly showing, staring at the camera with a startled, comical expression. No collar, toys or ground.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:27:31.020913881Z
- Original: `sticker-regeneration-redo/originals/cat-2.png`, 1237 × 1272 PNG, sha256 `144826624c34f1d726ca11cd224dd3043f03ee4023669499189c97cfbed899f4`
- Shipped: 499 × 512 WebP, 159,732 bytes, sha256 `868ee31a91ce7c698ee456bed3aa698f677067cf5574d44267020ff877396fd9`

### `cd.webp`

a single compact disc seen at a slight angle, its data side shimmering with rainbow iridescence and its clear centre ring visible. No printed label, text or case.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T20:45:40.610802296Z
- Original: `sticker-regeneration-full/originals/cd-2.png`, 1536 × 1024 PNG, sha256 `15b4582d72753666bdc79e8dc7dd49260a47ad6d00e54d36742a3f1e0fc8dfe4`
- Shipped: 512 × 368 WebP, 119,704 bytes, sha256 `5ad927ecde9c33ec428136e00e70e400868089ab5068392e9b88cca633166045`

### `cell_phone.webp`

a late-1990s candybar mobile phone in translucent dark blue plastic, with a short stubby antenna, a small greenish monochrome screen, curved navigation keys and rows of rubbery number keys printed with the digits 0 to 9, * and #, seen at a slight angle. Its shape must not copy any real phone model. No brand name or other text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T03:57:40.512110505Z
- Original: `sticker-regeneration-redo/originals/cell_phone-1.png`, 1024 × 1536 PNG, sha256 `ce25e28a18558d3405d0ddcb6d12e19f8bc3d8badccc112df925f91cd1d5f29f`
- Shipped: 250 × 512 WebP, 78,754 bytes, sha256 `5cbad8dbfc3de32253275da78de09a2c02d75ecfa2e773c98ce9253a63c450bc`

### `ceramic_hands.webp`

a pair of matte white ceramic hand sculptures, a left and a right hand, standing upright on their wrists side by side with their little fingers hooked together in a pinky promise and the other fingers loosely curled. Smooth glaze with no cracks.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T03:58:18.483002666Z
- Original: `sticker-regeneration-redo/originals/ceramic_hands-1.png`, 1439 × 1093 PNG, sha256 `e767b2acb9f393125dd04fbc80843c21cd562a435856e6d26f63fb73b06d0fcc`
- Shipped: 512 × 401 WebP, 98,354 bytes, sha256 `8b8bc1243989e32aa076e710c412f7d80bcc1edef308c450eea36cb0148340da`

### `chat.webp`

a pair of overlapping speech bubbles cut from thick glossy acrylic, shown as one object with visible thickness: in front, a bright blue bubble with a short pointed tail at the bottom left and three white round dots raised on its face; behind it and lower right, a smaller clear bubble with a white back and its tail at the bottom right, like a reply.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:28:52.602134732Z
- Original: `sticker-regeneration-redo/originals/chat-2.png`, 1536 × 1024 PNG, sha256 `b43d340d8a0691f4ef1d6e16061fba0ac1847730ca0b86d02ed36467f195cb48`
- Shipped: 512 × 387 WebP, 117,130 bytes, sha256 `9fe5f29d4acf87ac1614b8d4dd9188844f48ca904d21af1b2ec0078c9055c80a`

### `chattering_teeth.webp`

a wind-up novelty chattering teeth toy: big white plastic teeth set in pink gums, standing on two small orange feet, with a metal wind-up key on the side. No packaging or text.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T20:47:26.559714189Z
- Original: `sticker-regeneration-full/originals/chattering_teeth-2.png`, 1312 × 1199 PNG, sha256 `ee60acf03e025628f392f464eaba71cbd8a9bc6892e2688cd84c8e4b270881bb`
- Shipped: 512 × 471 WebP, 151,256 bytes, sha256 `ced270d27247613b2bf79dde1146ba1f076cbfa2b903294c2702e34de0d0d977`

### `cherries.webp`

two glossy dark-red cherries joined at the top by their green stems, with a single small leaf. No bowl or water drops.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T20:49:05.002602917Z
- Original: `sticker-regeneration-full/originals/cherries-2.png`, 1281 × 1228 PNG, sha256 `e680324c35fa4da9acff728aba36765a2aa9a9aa5bbfdb3ad0f853a0ba95162c`
- Shipped: 504 × 512 WebP, 136,704 bytes, sha256 `023a1b680c079a850fd88f95183cf366ef5d0803c2911ba2ccdbe0a537aaa58b`

### `chili_pepper.webp`

a single shiny red chili pepper with a curled tip and a green stem. No other peppers.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T19:53:21.362179691Z
- Original: `sticker-regeneration-full/originals/chili_pepper-1.png`, 2172 × 724 PNG, sha256 `be7896f5cf24aa7afc34dedd71009df98ca071f4595ade7677a0bd64e8d8dfd4`
- Shipped: 512 × 179 WebP, 43,906 bytes, sha256 `a8d67be1ad9c08d466f13199dd214fdf2837f4a73a3b0fb00743c56b19c99c5b`

### `clover.webp`

a single fresh four-leaf clover with bright green heart-shaped leaves and a short stem. No other plants.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T19:53:48.409942549Z
- Original: `sticker-regeneration-full/originals/clover-1.png`, 1268 × 1240 PNG, sha256 `275e9a142f9cf45f2114f0aac1b93fc552e57281a769b81c3f7a6ab15331897e`
- Shipped: 437 × 512 WebP, 142,438 bytes, sha256 `d00be24aa2dc4f467e25a9fc9ab6584a58c4810b0873d16682c4dd61ba29a04f`

### `confetti.webp`

a paper party popper cone, yellow with printed red, blue and green stars, held point-down at an angle and bursting from its open end with a spray of colourful confetti squares and curly paper and metallic streamers. No hand.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T03:59:05.990274062Z
- Original: `sticker-regeneration-redo/originals/confetti-1.png`, 1312 × 1199 PNG, sha256 `9975132673d8dc7183d5f3ae13d1b38a921a85e73e4ed02e1524d2a563ac7ab0`
- Shipped: 512 × 479 WebP, 120,726 bytes, sha256 `b30fd63c75e2ba838889b9af3e5cc4568b3884b0be8176cd4f257ddf27fdef5d`

### `cordless_vacuum.webp`

a compact cordless handheld vacuum cleaner in glossy white plastic with mint-green accents, shaped like a short wide cylinder with a carrying handle on top, a clear dust cup at the front ending in a short crevice nozzle, and the battery at the back, seen from the side. It must not copy any real brand's design: no cyclone cones, no purple, yellow, red or nickel finish, and no logos or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:00:34.406487526Z
- Original: `sticker-regeneration-new/originals/cordless_vacuum-2.png`, 1902 × 827 PNG, sha256 `1f4ef8f0afc127e3664c31281c1ff6071c4d91f5b158d33e5c3724ec5a87fb4f`
- Shipped: 512 × 230 WebP, 61,706 bytes, sha256 `4c42daab484cdbaa79fdd8756cbc5a82c6cd926975c66b920da1df4ee67f7e77`

### `cracked_phone_screen.webp`

a generic black rectangular smartphone seen straight from the front, its dark glass screen shattered with a spiderweb crack spreading from one corner. Plain rounded body with no visible camera, notch, buttons, logos or icons.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T20:52:14.681439863Z
- Original: `sticker-regeneration-full/originals/cracked_phone_screen-2.png`, 959 × 1640 PNG, sha256 `0d333443f3fd83d4a6871375afbd09bb391ab0b90180a986935e26e649effc64`
- Shipped: 266 × 512 WebP, 124,098 bytes, sha256 `779d8e1a93db4ac0edb8bd0552a1ba200c5ccf142a502b4792374083b204613f`

### `credit_card.webp`

a generic plastic payment card in a glossy purple-to-blue gradient with a subtle wave pattern and a gold metal contact chip on the left, seen at a slight angle with a soft highlight. No numbers, name, contactless symbol, bank or card-network logo, or any other text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:30:10.291437545Z
- Original: `sticker-regeneration-new/originals/credit_card-1.png`, 1536 × 1024 PNG, sha256 `025ed88f899443459242be3edaec7eebed70b7f95b94d6fde200386a209fe7c0`
- Shipped: 512 × 344 WebP, 112,512 bytes, sha256 `d4d14038e72cd8d03795e66894f53806c53bf3f5aea76723c4aa39bec8b4b42f`

### `crt_monitor.webp`

a beige 1990s CRT computer monitor seen at a three-quarter angle, with a deep boxy back, a slightly curved glass screen glowing plain blue and a small round power button. No text, icons, keyboard or brand.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T19:55:18.191732869Z
- Original: `sticker-regeneration-full/originals/crt_monitor-1.png`, 1333 × 1180 PNG, sha256 `e786f9f6e269cc6c123605c106fd424634abcccce6dcd28a1937be23b728b828`
- Shipped: 512 × 475 WebP, 139,836 bytes, sha256 `1473829910f11c59b61cc6bda2991df107284bbbe00751b5b433a83c261426c4`

### `d20_die.webp`

a large twenty-sided gaming die in translucent amber-orange resin, with the numbers 1 to 20 engraved deep into its triangular faces, seen at an angle so several faces and their numbers show. No text other than those numbers.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:30:04.986605262Z
- Original: `sticker-regeneration-redo/originals/d20_die-2.png`, 1278 × 1230 PNG, sha256 `e630dab2503610cc4b8eba689059f53a08a4defdcd0a14973bfd057fa78c67ae`
- Shipped: 455 × 512 WebP, 157,000 bytes, sha256 `84cfcf6e1bfe8cc1cc1cfd12abd4f47b27ed3adfbcd77d82cf24b5874ee9befc`

### `delivery_backpack.webp`

a well-used food-delivery backpack seen from a front three-quarter angle: a large cube-shaped insulated box bag in plain black fabric with a silver reflective strip around it, padded shoulder straps and a zipped top lid, with scuffs, a few stains and slightly frayed corners. Printed large in white on the front panel is an invented flat, stylised cartoon logo: a motorbike speeding to the right with motion lines behind it, a stack of pizza boxes strapped on the back with wavy lines of steam rising from them, ridden by a cheerful cartoon pizza cook with a big moustache and a tall chef's hat, who holds up one hand making the OK sign, thumb and index finger touching in a circle and the other three fingers raised. The logo is white only and must not resemble any real delivery or pizza brand's logo; no words, letters or other text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T11:40:52.956325829Z
- Original: `sticker-regeneration-new2/originals/delivery_backpack-2.png`, 1312 × 1199 PNG, sha256 `7bd63240fc40c06a016652d45d89b67231cb1b0c34ca12cd7c89c6c739834e4d`
- Shipped: 512 × 481 WebP, 184,632 bytes, sha256 `a074f23fc1ea1885a8225a94a741df536bdb8e698fa44c20d354f4ff892d9485`

### `detergent_pod.webp`

a single soft laundry detergent capsule with a glossy translucent film and two swirled gel compartments in teal and lilac, slightly squishy. No packaging or text.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T20:53:55.967540689Z
- Original: `sticker-regeneration-full/originals/detergent_pod-2.png`, 1262 × 1246 PNG, sha256 `58206d94ccbb3f7dc83d59b8eac56862ca19cd8e7fbc6c49bdf66d337ef8c3d8`
- Shipped: 502 × 512 WebP, 189,638 bytes, sha256 `33c5cc5f29aa5b9c8d78e833ef6feb5db935db39782e3c6e5f7cbcb9ff009881`

### `devil_horns_hand.webp`

a polished chrome-silver sculpture of a hand making the rock-and-roll horns sign, with the index and little fingers raised and the middle and ring fingers folded down under the thumb, standing on its wrist. Mirror-like metal reflecting soft studio light.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T03:59:58.923822072Z
- Original: `sticker-regeneration-redo/originals/devil_horns_hand-1.png`, 1024 × 1536 PNG, sha256 `935863e611d6f9494510799fc48c6119aaa181d54694769c55ab7cee29b5a5cf`
- Shipped: 279 × 512 WebP, 95,216 bytes, sha256 `182031be98c0fab3efc8891ba900436df97e5ba3bb6d9e61d7bf3391c1f41ae2`

### `digital_pet.webp`

a small rounded-square keychain digital pet toy in glossy bubblegum-pink plastic, with a tiny monochrome screen showing a simple pixel creature made of a few blocks, three small round buttons below it and a short metal ball chain. Not egg-shaped. No logos or text.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T19:57:08.393208983Z
- Original: `sticker-regeneration-full/originals/digital_pet-1.png`, 1278 × 1230 PNG, sha256 `c66fc1c8826c2d8aae7d87519bae0e4f19c98c11c8c251a5ec7a71d233c84bea`
- Shipped: 495 × 512 WebP, 168,672 bytes, sha256 `9770b1c962f0f4a169d50f304601c7e796e611524d43b5454262c4246eb5494f`

### `disco_ball.webp`

a large mirror disco ball covered in hundreds of small square mirror tiles, blazing with reflected light: a bright white flare at its centre and scattered sparks of blue, magenta and amber from 1970s nightclub spotlights, all on the tiles themselves. No chain, ceiling or room.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:31:27.734600636Z
- Original: `sticker-regeneration-redo/originals/disco_ball-2.png`, 1261 × 1247 PNG, sha256 `c6f032da3e66ef507e31fe669342e73890c107e948f48701e4e587c00d1edd8f`
- Shipped: 504 × 512 WebP, 239,690 bytes, sha256 `7c638afb01e71f0600febeaa6879ce568135215c42df153dc2d20d5579c112e7`

### `disco_helmet.webp`

a full-face motorcycle-style helmet completely covered in small square mirror tiles, like a wearable disco ball, with a plain dark smoked visor, a chin bar and a visible rounded neck opening at the bottom, seen at a three-quarter angle and resting upright on its bottom rim. No lights, no person or mannequin.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:01:08.266894855Z
- Original: `sticker-regeneration-redo/originals/disco_helmet-1.png`, 1289 × 1221 PNG, sha256 `8b9a40447521ef7f38a04139a9a4ffdee00b6ca28c70da5dd7de6b22484730b5`
- Shipped: 501 × 512 WebP, 226,604 bytes, sha256 `505ed07a8c187cf9c39995749a414c82e07cfd5c9e900c6e8f022cbc184fc144`

### `dj_controller.webp`

a two-deck DJ controller seen from above at an angle: a black plastic body with a large silver jog wheel on each side, a mixer section in the middle with rows of knobs, two upfaders and a crossfader, and two rows of rubber performance pads glowing pink, blue and green. No logos, letters, numbers or labels.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:02:11.711004067Z
- Original: `sticker-regeneration-new/originals/dj_controller-2.png`, 1773 × 887 PNG, sha256 `4aa662fed4f7e8fc3d2a794ece1691702e71cd55a672c07986655c5159f18f1e`
- Shipped: 512 × 267 WebP, 100,412 bytes, sha256 `4cc43efa8de27c62fbec668873d95d5f7c0e561fab4803aa24b71c0db74d7edf`

### `dog_corgi.webp`

a real Pembroke Welsh corgi standing side-on with its head turned to the camera, big upright ears, a tan-and-white coat and a happy open mouth. No collar, clothing or ground.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T19:58:20.698277800Z
- Original: `sticker-regeneration-full/originals/dog_corgi-1.png`, 1536 × 1024 PNG, sha256 `eb64690d84352cc70e82f7f56c2ef26719c4538fd58fe58ccc44e5e68c9d0305`
- Shipped: 512 × 440 WebP, 113,702 bytes, sha256 `095c13ca9cfea75e8feb97b4c55abbc298429022e16e0867c382a6e03516396d`

### `dog_in_hoodie.webp`

a fawn French bulldog wearing a bright yellow hoodie with a white hood, seen from behind and slightly to the side, sitting and looking back over its shoulder at the camera with its big ears up. No logo, text or print on the hoodie.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:01:25.564313239Z
- Original: `sticker-regeneration-redo/originals/dog_in_hoodie-1.png`, 1117 × 1408 PNG, sha256 `af5c85db9ab85bf54fc6be895adbf6cb36e13a976d8d5b23320f7f6466ee7582`
- Shipped: 355 × 512 WebP, 95,466 bytes, sha256 `40fe27198da6cc470142290f23c5ab41635168834ec442ae3c82707f64a2cefe`

### `dog_leash.webp`

a retractable dog leash: a chunky turquoise plastic handle with a thumb brake button on top, a round flat side panel printed in the centre with a simple white pictogram of a dog squatting to poop, and a thin grey cord coming out of the front, ending in a metal clip, with a small black bone-shaped poop-bag dispenser clipped to the handle and one green poop bag pulled half out and hanging from it. No other logos or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T11:32:52.205518530Z
- Original: `sticker-regeneration-new2/originals/dog_leash-1.png`, 1536 × 1024 PNG, sha256 `7b1ca33acbe2d8f91f6255d17102e47afad5d1497f8826bc1edcaab5bf78d141`
- Shipped: 512 × 387 WebP, 112,798 bytes, sha256 `06cbd915877c637d22d05bfc2728bd82f373832902a89d4fe23ac2085af67a64`

### `dog_shiba_inu.webp`

a real red-coated Shiba Inu standing in profile, head up and looking forward calmly, with its curled tail over its back. No collar, clothing or ground.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T19:59:13.455073977Z
- Original: `sticker-regeneration-full/originals/dog_shiba_inu-1.png`, 1355 × 1160 PNG, sha256 `cb9872c616b5f24b0b21e150bf25ebe031649b8fce33f2a03bfe575168a0f206`
- Shipped: 512 × 481 WebP, 112,408 bytes, sha256 `41b94f729f2673cd46189965919790d5a684debfd6dc939246f8b1d731078050`

### `donut.webp`

a ring doughnut with glossy strawberry-pink icing and multicoloured sprinkles, seen at a slight angle. No plate, box or bite.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T20:57:31.072678774Z
- Original: `sticker-regeneration-full/originals/donut-2.png`, 1317 × 1194 PNG, sha256 `3123e7d678539498320648460ce5d35fcdee439bf9160a38d7c545b0bb23ef2c`
- Shipped: 512 × 458 WebP, 157,830 bytes, sha256 `c89ecfa4ce3fab6a8e7ae0500832f8963f1a1b71b3e8f77862a13ac040dbf369`

### `double_cheeseburger.webp`

a double cheeseburger on a sesame-seed bun with two grilled patties, melted cheese, lettuce, tomato and pickles, seen from the front. No wrapper, box, flag pick or plate.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T20:58:15.964525352Z
- Original: `sticker-regeneration-full/originals/double_cheeseburger-2.png`, 1312 × 1199 PNG, sha256 `11a6c8aa5ac76381409141703816a29bf2c8efa17df991ac18269cfc85ef0f45`
- Shipped: 512 × 460 WebP, 196,256 bytes, sha256 `c3be7a71b232e142cd43c62989d50b692b1eb65170204682ab78148752567a74`

### `ear.webp`

a single adult human ear seen from the side, with natural folds and soft lighting. Medium, warm golden-tan skin. No hair, earring, face or head beyond the ear.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T20:58:41.598963518Z
- Original: `sticker-regeneration-full/originals/ear-2.png`, 1122 × 1402 PNG, sha256 `26224e230ea61f958377abe0138523039b7353be5b7ee0636557fe68752360be`
- Shipped: 317 × 512 WebP, 93,416 bytes, sha256 `2d9c6b753ba63ea64c150263b6ca0eac07a7d184bb37ef497dd467c8eda58560`

### `earth_globe.webp`

planet Earth seen whole from space, a sharp blue sphere with white swirling cloud bands, deep blue oceans and brown-green continents, lit from one side. No stars, space background, moon, or glow beyond the planet's edge.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:02:16.742374552Z
- Original: `sticker-regeneration-redo/originals/earth_globe-1.png`, 1263 × 1246 PNG, sha256 `b4eab4cfe3665eefad24c7996dfcd3498f0cd74328d67622a1c51ad5b7dcd31a`
- Shipped: 512 × 511 WebP, 258,736 bytes, sha256 `aba4a3a92067a0f95c15c77bb21ef36c77a2d81f1bd13a69890dcc37ec1e1fc6`

### `eggplant.webp`

a single glossy deep-purple eggplant with a green leafy cap, lying on a slight diagonal.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T20:59:27.465184533Z
- Original: `sticker-regeneration-full/originals/eggplant-2.png`, 1536 × 1024 PNG, sha256 `d26b102825b4e8e8950d1f18400bc547f699ea89bc1fbe16903728052d9b7cad`
- Shipped: 512 × 341 WebP, 82,172 bytes, sha256 `c7ad955355c526968060b5578076a6ae67135964c49d39f2d6963d8f74a0c204`

### `electric_scooter.webp`

a folding electric kick scooter standing upright, seen from the side, with a glossy cherry-red stem and frame, a black deck, a T-shaped handlebar with black grips, and two small solid black wheels with a hub motor in the front one. It must not copy any real scooter model; no logos or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:03:10.114275610Z
- Original: `sticker-regeneration-new/originals/electric_scooter-2.png`, 1312 × 1199 PNG, sha256 `9d38066ffc99052ef4b142d1d88ce9fca5cf02633a446392c2a233042782da8d`
- Shipped: 491 × 512 WebP, 65,748 bytes, sha256 `5bf1af5428d224dd8ea4dae46ac4e8df4d58085791e7ccefb14b80fe64f5e12e`

### `email.webp`

an open cream paper envelope seen from the back, its top flap lifted and a folded letter pulled halfway out, with a round red wax seal pressed with a small heart where the lower flaps meet. Visible paper fibres and soft creases. No stamp, writing, address or @ symbol.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:34:46.254070373Z
- Original: `sticker-regeneration-redo/originals/email-2.png`, 1312 × 1199 PNG, sha256 `7f8ec2c533564bb84c076516401bc75a6659a9a117a798ea0c1b55caa476d9f3`
- Shipped: 512 × 476 WebP, 129,154 bytes, sha256 `4ab79a034b1558e72015672d6d3dbc005e5ebe72c96eb7115584040cada636c4`

### `empty_toilet_roll.webp`

an empty toilet roll: the bare brown cardboard tube standing upright, with only a small torn strip of white tissue still stuck to it. No text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:33:20.374898250Z
- Original: `sticker-regeneration-new/originals/empty_toilet_roll-1.png`, 1024 × 1536 PNG, sha256 `eee3e9cee247bf116926b7b7c3007eb75341ed53a490eefe57f4fd723f70a097`
- Shipped: 240 × 512 WebP, 93,846 bytes, sha256 `250f242e93c9e7b286524665ffde63a5759ab8e368c14116ddd61ae7149fd403`

### `espresso_martini.webp`

an espresso martini in a stemmed coupe glass, dark coffee-coloured with a creamy foam top and three coffee beans floating on it. No straw, napkin or bottle.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:02:06.358322560Z
- Original: `sticker-regeneration-full/originals/espresso_martini-1.png`, 1122 × 1402 PNG, sha256 `97c82f75deaff2ee92996ee34f114e1326d731a31ce8249a293fd573d5ad21fd`
- Shipped: 338 × 512 WebP, 88,588 bytes, sha256 `39ff530858de647a9b0628f8120474f6635aa509b706722c87d1db2e19aee6e8`

### `face_mask.webp`

a disposable surgical face mask in pale blue with three horizontal pleats, a thin bendable nose wire along the top edge and two white ear loops, lying flat and slightly crumpled. No text or logos.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:33:37.312051027Z
- Original: `sticker-regeneration-new/originals/face_mask-1.png`, 1785 × 881 PNG, sha256 `f4e7b584b9cc89cd918cd142bac61303ca07b1afda452f341ab511079b239729`
- Shipped: 512 × 237 WebP, 75,226 bytes, sha256 `e2fe557775ed6a8398ae865815e3538200ee54dceeb5ea502a2fb9fe58bd0010`

### `fidget_spinner.webp`

a three-lobed fidget spinner in shiny rainbow-anodised metal, with a round bearing in each lobe and a central bearing with a matte black cap, seen at a slight angle. No text or logos.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:04:59.246012357Z
- Original: `sticker-regeneration-new/originals/fidget_spinner-2.png`, 1312 × 1199 PNG, sha256 `fe0b5b429ebe5d5dc71bd0b90fbc25e69edb53a7e150e5eb7bf9abcbae905ef4`
- Shipped: 504 × 512 WebP, 184,488 bytes, sha256 `fe9bf55d6b086f45fddc6e9d7e14cbe4b4290e765d14af8b5abccc79e145aac3`

### `finger_pointing.webp`

one real adult hand pointing sideways to the right with the index finger extended and the other fingers curled, thumb resting on top, with a short length of wrist. Medium, warm golden-tan skin with natural knuckles and nails. Exactly five fingers. No rings, sleeve, face or body.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:02:19.100243636Z
- Original: `sticker-regeneration-full/originals/finger_pointing-1.png`, 1774 × 887 PNG, sha256 `9e38d157442763de40c767acf9cf8d592ecee7c70f1a55e677a25761955ed1d3`
- Shipped: 512 × 265 WebP, 66,310 bytes, sha256 `1b9365cbdb784a30720e7cb43590459f4fb07a2693a78a78a2e77d5558055e86`

### `flat_tire.webp`

a flat car tyre on a plain silver steel wheel, standing upright and seen from the side, the black rubber sagging and bulging flat at the bottom where it meets the ground, with a deep worn tread. No text, numbers or brand on the sidewall.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:05:21.408718367Z
- Original: `sticker-regeneration-new/originals/flat_tire-2.png`, 1312 × 1199 PNG, sha256 `3a6aefa91a2ad001ef6fca1ad79c0d37f32c6615fa10051e1f7c008eb3ced7f3`
- Shipped: 512 × 470 WebP, 182,280 bytes, sha256 `bc9440f898a3cd7d495f95e2cd626bbfcfe62962bc75bca5e85333072e290c20`

### `flip_flops.webp`

a pair of bright hot-pink rubber beach flip-flops with white Y-shaped thong straps, lying side by side, seen from above, with a few grains of sand on them. No logos, flags or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:06:03.354061366Z
- Original: `sticker-regeneration-new/originals/flip_flops-2.png`, 1269 × 1240 PNG, sha256 `59ddd5e1d597590c81f952dc054de3c22ce5b7c3bbe2b9723bfd82365116d067`
- Shipped: 441 × 512 WebP, 195,324 bytes, sha256 `fe70ed642a4c3a2df532c7494b42e533bb2ed947e4cbb459f4b4b06084158f2c`

### `floating_lilo.webp`

an inflatable pool lounger with a pillow at one end, made of shiny translucent vinyl in rainbow stripes running its length: aqua blue, hot pink, yellow and clear, fully inflated and seen at an angle. No print or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:03:16.706627056Z
- Original: `sticker-regeneration-redo/originals/floating_lilo-1.png`, 1536 × 1024 PNG, sha256 `8eed59a2ae6b1ad7f5a83274ab55c9c981760dca8b4fa013705e9ab9ece41df4`
- Shipped: 512 × 347 WebP, 88,328 bytes, sha256 `930ecbc99528c6a40ad2412578b725cb7163c24198e251cd4d7446c53380ecde`

### `foam_finger.webp`

a giant blue foam sports-fan hand with the index finger pointing up, printed with a thin white outline drawing of the folded fingers and thumb, and a large bold white #1 near the bottom. No text other than #1.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:35:38.655907695Z
- Original: `sticker-regeneration-redo/originals/foam_finger-2.png`, 1023 × 1538 PNG, sha256 `cc821d80f6cfbf5c0732728b214748f52b19db13fe8ad8d3cc2f86ec647f1d31`
- Shipped: 279 × 512 WebP, 95,740 bytes, sha256 `b4ecc5451fa8b443c82adcdb642edfdd88b9ff982ff208de981881eccddf78a8`

### `forest.webp`

a small cut-out cluster of three tall dark-green pine trees of different heights growing from a mound of moss. No animals, path or sky.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:03:53.941409606Z
- Original: `sticker-regeneration-full/originals/forest-1.png`, 1198 × 1313 PNG, sha256 `d548e25ab1b2702dfc7e5247e47fa3ec2734861cdbe16b83811596cc1561b318`
- Shipped: 411 × 512 WebP, 193,640 bytes, sha256 `3739479179553c914c4af41baca40469b37646742939992f8433eb6c3831324f`

### `forgot_password.webp`

a small brass padlock with a large black question mark painted on its body, next to a single silver key leaning against it. No other symbols or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:04:12.426858876Z
- Original: `sticker-regeneration-redo/originals/forgot_password-1.png`, 1288 × 1221 PNG, sha256 `2d21cbece4e03a60ac835c360aec18b4ab862f9371f375d07ab5bb4059d4c839`
- Shipped: 502 × 512 WebP, 208,890 bytes, sha256 `649e036e28ab5f1c6a065cbf954845b223d5a7afbf3a034b92e72b9af0aa77c5`

### `fortune_cookie.webp`

a golden fortune cookie broken open with a small blank white paper slip sticking out. No writing on the paper, no plate or chopsticks.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:04:33.874915991Z
- Original: `sticker-regeneration-full/originals/fortune_cookie-1.png`, 1751 × 898 PNG, sha256 `11cf7073500c0a6d031bf7b89bcaeb3bb55889e0e2922fc34a788ef84f014d9d`
- Shipped: 512 × 265 WebP, 73,632 bytes, sha256 `f1c566f763d42e3359571fa39842ea95a61eb4169eb84e2eb2e3e84e461487d0`

### `fountain_soda.webp`

a large fast-food fountain soda: a tall waxed paper cup printed with a playful pattern of red, yellow and blue bubbles and stripes, a white domed plastic lid and a bendy red-and-white striped straw, beaded with condensation. No logos, brand colours or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:36:21.571432254Z
- Original: `sticker-regeneration-new/originals/fountain_soda-1.png`, 1024 × 1536 PNG, sha256 `23b89170e29048dacec6021dca3a0450d37e8658e84f34615a9a8195b2c76d95`
- Shipped: 245 × 512 WebP, 86,886 bytes, sha256 `728c1759222015f7d9c76d6549483a971d9647f2f4a428685df52f75f81091e1`

### `french_bulldog.webp`

a fawn French bulldog puppy lying flat on its belly with its front legs splayed out to the sides and its chin down, big upright ears, looking up at the camera with a funny sideways glance. Seen from slightly above. No collar, toys or ground.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:36:30.672108778Z
- Original: `sticker-regeneration-redo/originals/french_bulldog-2.png`, 1536 × 1024 PNG, sha256 `01e9ec0338d7423d5d9ea97308f1407a2f593bace118e523a84bdb448f3bb5a8`
- Shipped: 512 × 355 WebP, 112,606 bytes, sha256 `b0cb5db5695d243b7ec21db4515fbd1d6d3fcf22a43aa0ed7d63b221a87f7da7`

### `game_controller.webp`

an unbranded budget USB gamepad for a PC, the kind sold in computer shops around 2000, moulded in glossy cobalt-blue plastic: a compact rounded body with two short stubby grips, a white plus-shaped direction pad on the left, four round face buttons in a diamond on the right, two white and two yellow, two small white oval buttons in the middle, and a thin grey cable. Its shape and colours must not copy any real console's controller: no grey body, no red, green or blue buttons, and no symbols, letters, logos or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T08:27:12.420158421Z
- Original: `sticker-regeneration-redo2/originals/game_controller-1.png`, 1535 × 1024 PNG, sha256 `5ae24e0c3c2bd3713992877e15a790384d4bc857a7584cff245e4e2c37944118`
- Shipped: 512 × 360 WebP, 100,256 bytes, sha256 `21ab9de371fb9be853f5cd36859f0c6f4cec3cbd55d5305f5c5445ee408ec932`

### `glitter_lips.webp`

a pair of full lips slightly parted to show the top front teeth, completely covered in sparkling red glitter lipstick that catches the light in tiny points. Lips only, with no other part of the face.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:37:22.560001048Z
- Original: `sticker-regeneration-redo/originals/glitter_lips-2.png`, 1536 × 1024 PNG, sha256 `d547acc85e315c6891abb9f5ea11a6ba5b1e67c5e49013b73a21aaef972d92f3`
- Shipped: 512 × 340 WebP, 157,920 bytes, sha256 `1286af99050d70af1f7e0e9bdc5969f3173daeb2511d769d894a68649fce2121`

### `hair_dryer.webp`

a hair dryer in glossy coral-pink plastic seen from the side, with a chrome-ringed nozzle, a matte black grip with two small slider switches, and its black cord loosely coiled below. No logos or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:37:24.113641911Z
- Original: `sticker-regeneration-new/originals/hair_dryer-1.png`, 1200 × 1310 PNG, sha256 `6a6d3b04a48abd7cfb96dc45d26170a439f8f3143f4f9752d1dc9fe5be26380d`
- Shipped: 433 × 512 WebP, 102,412 bytes, sha256 `611f01853368e213aaa6eaad9465034fb2cd9a9c282a33cbf05440822b8d863f`

### `hand_grip.webp`

a spring hand-grip exerciser with two hot-pink foam-covered handles joined by a coiled chrome spring, seen at an angle with the handles open. No text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:06:08.952659488Z
- Original: `sticker-regeneration-redo/originals/hand_grip-1.png`, 1310 × 1200 PNG, sha256 `55b2430a184ea6d7d24fdcbc087fdb309ea86db49eafac7ae6ea8f38c6c09da3`
- Shipped: 501 × 512 WebP, 125,350 bytes, sha256 `3856bf8b01b3a3f29e18fa04daf3b295d613740fef0494fac2429bcbbcedfcb5`

### `hand_sanitizer.webp`

a pump bottle of hand sanitizer: a clear plastic bottle filled with slightly bluish transparent gel with tiny suspended air bubbles, topped with a white pump dispenser. No label, logo or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:37:43.237454181Z
- Original: `sticker-regeneration-new/originals/hand_sanitizer-1.png`, 1024 × 1536 PNG, sha256 `7f9ed222e6399bb138fdcf78e792cd7cc6e69e2613a2ec0b1a899d9537f8ec58`
- Shipped: 250 × 512 WebP, 88,406 bytes, sha256 `b46118c5660520339fb9513df065021422ccb50456c7ddcfe2f203290d13e6b7`

### `handcuffs.webp`

a pair of shiny chrome steel handcuffs linked by a short chain, one cuff closed and one open, lying at a slight angle with a small handcuff key beside them. No text or engravings.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:08:15.388625042Z
- Original: `sticker-regeneration-new/originals/handcuffs-2.png`, 1536 × 1024 PNG, sha256 `34015ead69460fc54631d2507d9c15fdb9350c3e1b569b225c59a60f4f53b225`
- Shipped: 512 × 335 WebP, 93,468 bytes, sha256 `807d69ac114b37a2a6e54b1a51380f38a60557b57a5362c7140e213918e0befd`

### `handheld_console.webp`

a generic palm-sized handheld video game device in glossy cherry-red plastic, held horizontally, with a small screen in the centre showing simple glowing pixel blocks, a cross-shaped direction pad on the left and two round buttons on the right. No characters, logos, text or speaker grille lines.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:05:00.156179123Z
- Original: `sticker-regeneration-full/originals/handheld_console-2.png`, 1774 × 887 PNG, sha256 `88cd7aaac40aae2390216b12c5847fc4e051ae311ff26add2adb4f2f2315721d`
- Shipped: 512 × 262 WebP, 93,302 bytes, sha256 `30421219ba21dd6fed3d48276c554ef6104f7f1a5442d89d04e3576c55780f2f`

### `hang_loose.webp`

one real adult hand making the shaka, or "hang loose", gesture: thumb and little finger fully extended, index, middle and ring fingers curled into the palm. Back of the hand towards the camera at a slight angle, with a short length of wrist. Medium, warm golden-tan skin with natural knuckles, nails and creases. Exactly five fingers. No rings, sleeve, face or body.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T19:01:59.776170463Z
- Original: `sticker-regeneration-pilot/originals/hang_loose-2.png`, 1364 × 1153 PNG, sha256 `ffa77b1672a6c648007d7a654cd261727174b96a21e65b1bf18ce85145a57273`
- Shipped: 512 × 470 WebP, 88,316 bytes, sha256 `3b715067fe6fda255fd0958d14bd5c85074599fb5e64d2949f2cbd2bf2b03553`

### `hazard_sign.webp`

a square yellow hazard sign with rounded corners and a thick black border, with one black lightning-bolt symbol in the centre as its only mark, seen at a gentle three-quarter angle with light scuffs. No pole, bracket or wall.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:07:10.514539465Z
- Original: `sticker-regeneration-full/originals/hazard_sign-1.png`, 1254 × 1254 PNG, sha256 `4fa605f897f0c75fbebd1882a84e833cee678bb21d9cf6ea49906d8d6ab13cb2`
- Shipped: 445 × 512 WebP, 169,446 bytes, sha256 `c3f35dc651f6427f73f96c73f55ba221ec7631165948bc93b1b759daa8ee0887`

### `headphones.webp`

a pair of chunky late-90s over-ear headphones in glossy white plastic with lilac foam ear cushions, a padded headband and a short coiled cable. No logos, text or person.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:06:00.897185321Z
- Original: `sticker-regeneration-full/originals/headphones-2.png`, 1266 × 1243 PNG, sha256 `9031aeb68c863836281bed30adc157efb4b0dc290a55681720b1fbe25b98e041`
- Shipped: 485 × 512 WebP, 126,744 bytes, sha256 `7da527fa58ed11ccf25e8b8c04ebc1b7a4621776ea8bb09981769b637e6df220`

### `heart.webp`

a shiny red heart-shaped foil party balloon, fully inflated, with crinkled foil seams around its edge and a small sealed tab at the bottom point. No string, ribbon or print.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:38:20.016495811Z
- Original: `sticker-regeneration-redo/originals/heart-2.png`, 1289 × 1221 PNG, sha256 `6d7fc37a5713b71eadf848cfc5a5d45935957d09069bdaa528f5389d778d83c1`
- Shipped: 512 × 495 WebP, 148,272 bytes, sha256 `f69f63e2d7e008bf4018511e2d6aef2574d201f01c7f05cf34b9d6164c322702`

### `hibiscus_flower.webp`

a single open red hibiscus flower with five ruffled petals and a long yellow-tipped stamen, with one green leaf.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:07:04.071558237Z
- Original: `sticker-regeneration-full/originals/hibiscus_flower-2.png`, 1295 × 1214 PNG, sha256 `dc86c835d8c5776307ade13e953a172882e79b5b33e4ff76b13f7105f5b94786`
- Shipped: 512 × 490 WebP, 161,882 bytes, sha256 `33147814128c80614b9623dd6492c7a44356f55a40a664079b4cbd2a2f3b80c7`

### `holographic_jacket.webp`

a cropped puffer jacket made of iridescent holographic fabric shifting from silver to pink and blue, shown on its own from the front, zipped up, with relaxed sleeves. No person, mannequin, hanger, logos or labels.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:09:57.238904001Z
- Original: `sticker-regeneration-full/originals/holographic_jacket-1.png`, 1444 × 1089 PNG, sha256 `42006e07f83032b6bd8a863761a209517e380afaa4a3eb82c502601d1ba77695`
- Shipped: 512 × 397 WebP, 147,334 bytes, sha256 `650f8d007679597ece61cfb203559db18d383bf68ad5c97c42ad08953b4dc10f`

### `holographic_shape.webp`

an abstract, smooth wavy blob shape cut from thick iridescent holographic acrylic, shifting from pink to blue to silver as the light hits it, shown as a flat object with visible thickness.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:10:12.475873148Z
- Original: `sticker-regeneration-full/originals/holographic_shape-1.png`, 1774 × 887 PNG, sha256 `af0a57a3df778060685ced59be32bd95a8cd798d8af008e70b3b81da94e9626a`
- Shipped: 512 × 250 WebP, 73,982 bytes, sha256 `6c60d03dbc097d00d0a2edf7ac4330765ffed55bd889f1b30fb5a063ed03c869`

### `horse.webp`

a close-up of a brown-and-white paint horse's head and upper neck, turned toward the camera with its upper lip curled up to show its big teeth in a goofy, comical grin. The cut stops partway down the neck. No bridle, halter or rider.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:38:56.725692450Z
- Original: `sticker-regeneration-redo/originals/horse-2.png`, 1169 × 1346 PNG, sha256 `4031a41028e24396b104a25d45ea0c7b686276577daf4a839c3147d9e4ec026a`
- Shipped: 381 × 512 WebP, 111,932 bytes, sha256 `2606e11feb63cf826b91c862da2f2b9691ef7dfaaa730f22480659a5be394c29`

### `horseshoe_magnet.webp`

a classic horseshoe magnet painted glossy blue, with its two flat ends bare silver-grey metal, tilted slightly with the open ends pointing up. No N or S letters and no text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:08:35.128494230Z
- Original: `sticker-regeneration-new/originals/horseshoe_magnet-2.png`, 1265 × 1244 PNG, sha256 `28a819f97b9d595d1669644816b6bbaae1bd15d060b4c442972e4355684c76d1`
- Shipped: 452 × 512 WebP, 115,052 bytes, sha256 `e8242997b0f4400c6170f60a34c8b6db04d93f2c425e05c84d3b7aa29365b289`

### `hot_air_balloon.webp`

a full-size hot air balloon in flight, photographed from the ground looking up and cut out with no sky left around it, its envelope covered in a patchwork of yellow, teal, peach, green and blue squares, with a small wicker basket hanging below and a few tiny passengers in it, too small and far away to identify. No text, logos or other balloons.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:39:26.752766505Z
- Original: `sticker-regeneration-redo/originals/hot_air_balloon-2.png`, 1166 × 1349 PNG, sha256 `5ceaf19aa5065513bb45d80f5af4256725f8efc7bdd17ea77c1d35d6729e3dd1`
- Shipped: 424 × 512 WebP, 123,606 bytes, sha256 `3a320250b6e3fc7d9e2345a605d67430f89f9ca48e844438e9d34738d923c2f8`

### `index_finger_pointing_up.webp`

one real adult hand with the index finger pointing straight up and the other fingers curled into the palm, thumb tucked across them, palm facing the camera, with a short length of wrist. Medium, warm golden-tan skin with natural creases and nails. Exactly five fingers. No rings, sleeve, face or body.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:11:25.541086925Z
- Original: `sticker-regeneration-full/originals/index_finger_pointing_up-1.png`, 1024 × 1536 PNG, sha256 `345d36ef7d9980123c50dd9a26b08e85c04392c909e01c360713529a07f30e7a`
- Shipped: 210 × 512 WebP, 47,822 bytes, sha256 `70e38404e4acb87767f38788b02a72567106662dd946a62629ded74ead113a86`

### `inflatable_flamingo.webp`

a pink inflatable flamingo pool float with a long curved neck and a yellow-and-black beak, glossy vinyl with visible seams. No water, person or text.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:11:56.350344961Z
- Original: `sticker-regeneration-full/originals/inflatable_flamingo-1.png`, 1326 × 1187 PNG, sha256 `80b504401e5027b7d3da58cab6ddf9967ced709c1d1be8e06e0e6ee58e17bd01`
- Shipped: 512 × 464 WebP, 100,314 bytes, sha256 `a4899ae8383f308b00487add19828778ae7f626108a88c7f95d4060c7df3a047`

### `instant_camera.webp`

a compact instant film camera with a rounded, pebble-like body in glossy mint-green plastic, a large round lens, a small flash window and a film ejection slot on the front. Plain single-colour body with no stripes, logos, text or film.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:10:39.244274552Z
- Original: `sticker-regeneration-full/originals/instant_camera-2.png`, 1312 × 1199 PNG, sha256 `343738f80818c3142ca7e93fd114359d021b5a3915e59ac2a8176fa92ce7646d`
- Shipped: 512 × 480 WebP, 160,988 bytes, sha256 `d2117d49db08d04d43a3083fb36726bcc15cf269a1acdf564689da3517ae9963`

### `instant_photo.webp`

a single square instant film photo print with a white frame and a thicker white bottom border, its picture an overexposed summer snapshot: a dark, blurred silhouette holding up a bunch of colourful balloons against a low, blazing sun, washed out by a strong lens flare and a warm orange light leak, with faded colours and slightly burned edges inside the frame. No faces, writing, tape or pins.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:40:09.046785428Z
- Original: `sticker-regeneration-redo/originals/instant_photo-2.png`, 1254 × 1254 PNG, sha256 `338c3d27ad5776ad47883d8f967914f73b74b6dad956ac76ba6967c17a268079`
- Shipped: 428 × 512 WebP, 154,814 bytes, sha256 `440296e42c03dd7cdf22405a639556db5c45663c1469a163642691cfae97c283`

### `knight_in_armor.webp`

an empty standing suit of polished medieval plate armour with a closed helmet visor, gauntlets and a small red plume, seen from the front. No person visible, no weapon, shield or coat of arms.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:13:35.523124876Z
- Original: `sticker-regeneration-full/originals/knight_in_armor-1.png`, 1024 × 1536 PNG, sha256 `25329f40df847613e7c3a105a3c4d0bb5d324a152ef4b0be039b1688669e34a2`
- Shipped: 208 × 512 WebP, 70,036 bytes, sha256 `b6d8de359e4cedd51c11784eb411957398ee611c407a8a30cbbd4ad1cbae8916`

### `lip_piercing.webp`

a close-up of adult lips, relaxed and closed, with a small polished silver hoop piercing at one side of the lower lip. Only the lips and a hint of the skin around them, medium warm golden-tan skin. No teeth, face or nose.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:13:49.361163168Z
- Original: `sticker-regeneration-full/originals/lip_piercing-1.png`, 1791 × 878 PNG, sha256 `6872c46b7744eb06673bcb73eac2d7d8d6bcb076b7d16027d8a1c6e9b2c3bccc`
- Shipped: 512 × 257 WebP, 93,532 bytes, sha256 `bf35b388d56b1efc4e55e9cadd4a16424f97421d9cda1767c7ea9c5a4c9184d6`

### `lipstick.webp`

a pink lipstick with the bullet twisted up out of its matte pink tube, lying at an angle beside its separate matching pink cap. No text or logos.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:08:58.536777099Z
- Original: `sticker-regeneration-redo/originals/lipstick-1.png`, 1322 × 1190 PNG, sha256 `7fe13360459155772925982d3e7c39f847933fcab442e4552f51ce21eda14c03`
- Shipped: 462 × 512 WebP, 89,218 bytes, sha256 `b89d43c5ea38de56aaf126dca7e50249e654d24f084a9ed0847dcee318613cce`

### `low_battery_phone.webp`

a generic black smartphone seen straight on, with rounded corners and an even thin bezel, its screen showing only one large white battery outline with a thin red sliver of charge left at one end. No camera cut-out, status bar, numbers, percentage, app icons, logos or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:09:15.680857362Z
- Original: `sticker-regeneration-new/originals/low_battery_phone-2.png`, 951 × 1653 PNG, sha256 `c9cab099ed52e9041a5816e37a914ab0679d4e4c29fc8d0d8fe8d0206ef74328`
- Shipped: 266 × 512 WebP, 89,388 bytes, sha256 `2a4c2c1f178c484f53505d02f2450ad3839bf7496b6088b88c05733ad2c28ca6`

### `lucky_cat.webp`

a shiny gold ceramic lucky-cat figurine, the beckoning cat sold in Chinese shops, sitting upright with its battery-powered arm and paw raised in a waving gesture, a red collar with a small gold bell, a friendly painted face, and a blank gold coin held against its body. No characters, symbols or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:40:08.694560142Z
- Original: `sticker-regeneration-new/originals/lucky_cat-1.png`, 1158 × 1359 PNG, sha256 `ffd8be62010b5623cdb981d988d3dac1f7ef613c698f5c114ba9f9a3fbe4d9e6`
- Shipped: 413 × 512 WebP, 171,172 bytes, sha256 `c241d25ebc85d815081565f71ea017a85d164225325939111c42bef06aca8269`

### `luggage.webp`

two hard-shell travel suitcases side by side: a large teal one with horizontal ridges and a smaller bright yellow carry-on with its handle pulled up, both on small spinner wheels and covered with scuffed travel stickers and paper luggage tags. The stickers and tags show no readable text, logos or airline names.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:41:17.120588008Z
- Original: `sticker-regeneration-redo/originals/luggage-2.png`, 1312 × 1199 PNG, sha256 `5186437b7362e169e62ac2c742913d8b06acdea0586f0aa4c012e348296af5da`
- Shipped: 512 × 481 WebP, 188,136 bytes, sha256 `fd3a82d5c438c5b870da779f8618f231a879ccdd7952b43d82abbcc632e629b3`

### `mannequin_hand.webp`

a glossy gold jewellery display hand standing upright on its wrist, fingers gracefully spread, wearing several rings with coloured gemstones on different fingers. No text or label.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:41:31.771830562Z
- Original: `sticker-regeneration-redo/originals/mannequin_hand-2.png`, 1024 × 1536 PNG, sha256 `b4b9bd956819e908423ba0c64ad474439309b67a56071beb9a9af55a81dae541`
- Shipped: 332 × 512 WebP, 87,260 bytes, sha256 `923adf6843bf408e3cc48f873b0e066171c59130226d274152885c1468a1f18e`

### `maple_leaf.webp`

a single real autumn maple leaf in vivid red and orange, with visible veins and a short stem, lying slightly curled.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:15:25.554941899Z
- Original: `sticker-regeneration-full/originals/maple_leaf-1.png`, 1305 × 1206 PNG, sha256 `91e4875093407337fca3faed5f8b2e9f8e37cc581543e5a7312f0564975ff053`
- Shipped: 512 × 471 WebP, 115,744 bytes, sha256 `4dbe5b33cbeea6c166e44c82139ff1d078730695a7215a452e815c2925e3bc38`

### `massage_gun.webp`

a handheld percussion massage gun in matte graphite grey, shaped like a simple T with a straight cylindrical body and a rubberised handle, a round soft ball attachment at the front and a small ring of blue LED dots on the back. It must not copy any real brand's design; no logos or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:10:26.004801287Z
- Original: `sticker-regeneration-new/originals/massage_gun-2.png`, 1293 × 1217 PNG, sha256 `1204eb23abeed58a4957829336d01a1d479dc92fc798b75fa17d2a3301405b1f`
- Shipped: 512 × 489 WebP, 107,244 bytes, sha256 `7efcaed41e886e1ffdfc9bc8ce5bd57dff5f1749ec1a2959a762c366eb1f3b27`

### `matrix_message_sign.webp`

a portable roadside message sign on an orange two-wheeled trailer, with a small solar panel on top and a large black panel of amber LED dots that spells FOLLOW / DETOUR / AHEAD on three lines. No text other than those three words.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:10:46.481096181Z
- Original: `sticker-regeneration-redo/originals/matrix_message_sign-1.png`, 1312 × 1199 PNG, sha256 `75ac2a8de7f37999344110dfba62eff52f63c34f6af34997001c26bf729f5ac6`
- Shipped: 484 × 512 WebP, 164,464 bytes, sha256 `216af3190b38b3312d3360c8a3fb69ea22ff4c70897bbe059edacbf3c8f37aa6`

### `microwave_burger.webp`

a cheap microwave cheeseburger sealed in tight clear plastic vacuum packaging, the soft pale bun slightly squashed against the film, with a slice of orange cheese and a thin grey-brown patty visible and a crimped seal along one edge. No label, sticker or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:10:54.854633130Z
- Original: `sticker-regeneration-new/originals/microwave_burger-2.png`, 1672 × 941 PNG, sha256 `346185dc283765c34e22e870cd65a39bec8305b19ac5f28a333a4823227cf9d3`
- Shipped: 512 × 293 WebP, 100,222 bytes, sha256 `cfce0181070dc429e3cbac46c1b3ec05aacf3b3ad8b1e5a015b0504bff52cef9`

### `middle_finger.webp`

a light wooden artist's mannequin hand, the jointed kind used for drawing practice, posed giving the middle finger, with the middle finger raised and the other fingers folded down, standing on its wrist.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:11:00.869963492Z
- Original: `sticker-regeneration-redo/originals/middle_finger-1.png`, 1024 × 1536 PNG, sha256 `280734ac66dbb0a3abb98f409d5c874b138c46f5cf01eb0e866d0be51d6ae7a5`
- Shipped: 215 × 512 WebP, 53,528 bytes, sha256 `a5528786af90c6b7fa949811a5565b44b87575ac1f6d2ff5b9d35a733df87dfc`

### `milk_bottle.webp`

an old-fashioned glass milk bottle full of white milk, with a short neck and a shiny silver foil cap, and an invented dairy logo printed in blue on the glass: a simple stylised cow. No words, letters or other text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T11:33:43.436872424Z
- Original: `sticker-regeneration-new2/originals/milk_bottle-1.png`, 1024 × 1536 PNG, sha256 `99e6c7418b605fb8f23349f8e0e349bdc50dfc5a0d8311921536d988a7069507`
- Shipped: 234 × 512 WebP, 80,478 bytes, sha256 `8701177663f9d29fcfdb6bdf1eb8ea6b9fd940b98d87a456fc0dcbb4bd276270`

### `mirror_ball.webp`

a small gold mirror ball covered in tiny square gold-tinted mirror tiles, resting on its own with warm reflections. No chain, stand, glow or light beams outside the ball.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:15:46.995652835Z
- Original: `sticker-regeneration-full/originals/mirror_ball-2.png`, 1262 × 1246 PNG, sha256 `fd5925f13ddeca15e2bc91d474fab62fd2e0fc05759245a39ac903cdf4e6a7ef`
- Shipped: 486 × 512 WebP, 237,642 bytes, sha256 `f3f9c1b141ebebcd745f05b163fb77184416afb881826c99710f91f75bb4c6ad`

### `mittens.webp`

a pair of hand-knitted wool mittens in bright red with a white snowflake pattern, lying side by side and slightly overlapping. No string or text.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:16:18.276895662Z
- Original: `sticker-regeneration-full/originals/mittens-2.png`, 1263 × 1245 PNG, sha256 `3610f4c39cf58920872ddda04a38c64ade835cc6d1021ea60fb68748f3d5e711`
- Shipped: 512 × 504 WebP, 196,294 bytes, sha256 `eecbe675569e29bbfbb9acfe8fbc94975fc2947fb1252c2d4006ebfde87a341f`

### `moka_pot.webp`

a stovetop moka pot in red enamelled aluminium with a smooth, rounded body rather than an eight-sided one, a black heat-resistant handle and a small black knob on the hinged lid. It must not copy any real brand's design; no logo, figure or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:11:59.111810900Z
- Original: `sticker-regeneration-new/originals/moka_pot-2.png`, 1192 × 1320 PNG, sha256 `c470e4090db90b575bde5cae3308e521eff3cc4c6878bd92d8de9775006fb945`
- Shipped: 463 × 512 WebP, 115,402 bytes, sha256 `80546394123b2910fb16b6e62c967f53993db7a6c19aeccf9855c1db29f866f5`

### `motion_lamp.webp`

a lit liquid motion lamp with a straight-sided cylindrical glass vessel on a round chrome base and cap, filled with glowing magenta wax blobs floating in turquoise liquid. The glow stays inside the glass. No cable or text.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:16:54.143184420Z
- Original: `sticker-regeneration-full/originals/motion_lamp-2.png`, 1024 × 1536 PNG, sha256 `c86bdf8685c52d5cb16bd28605622bfe1dbd1b9ee28df54edcd4300f4957b256`
- Shipped: 182 × 512 WebP, 69,430 bytes, sha256 `0e166e4a9317bd841cd068327624311a3a4476ee0275b9c65fa8b0bf2161694e`

### `nail_polish.webp`

an open glass bottle of lime-green nail polish, with its black cap and brush lifted out and held at an angle beside it and a drop of green polish on the brush. No label, text or brand.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:11:36.135819871Z
- Original: `sticker-regeneration-redo/originals/nail_polish-1.png`, 1312 × 1199 PNG, sha256 `e3d2325bef7ed44d33fcc0d7ab3a2fc72a1ffd5a78be4f339e7157c8dc9b4a66`
- Shipped: 512 × 501 WebP, 133,466 bytes, sha256 `3afcfa2602015c44b524ef0977888ea16999f55a1c55de69ef1ef842fc7b3fa9`

### `news_camera.webp`

a professional shoulder-mounted broadcast news camera in black, with a large zoom lens and hood, a viewfinder, a top handle and a foam-covered shotgun microphone, seen from the side. On its side is a made-up TV station logo: the word NEWS in bold white italic capitals on a navy panel, with red and white diagonal stripes on the left. No other text and no operator.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:11:52.993186531Z
- Original: `sticker-regeneration-redo/originals/news_camera-1.png`, 1774 × 887 PNG, sha256 `b1cc475375909cee0af54ff46c830ff465a49a2b5e34aa83f67c878e966ad67f`
- Shipped: 512 × 261 WebP, 81,564 bytes, sha256 `2c7e557cbcb9b399fabc77e03151d698fd0c3fdf6c7af0f1337333c8effa3906`

### `oak_tree.webp`

a single full-grown oak tree with a broad rounded crown of green leaves and a thick gnarled trunk, with a little grass at its roots. No sky, people or other trees.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:18:37.080917475Z
- Original: `sticker-regeneration-full/originals/oak_tree-1.png`, 1344 × 1170 PNG, sha256 `989eba41192fdea16127ac9cd379f4aba53fc3d6cd2c0d7325e21e9d007cb159`
- Shipped: 512 × 450 WebP, 220,398 bytes, sha256 `998e9a12e3cff5a2b09f69bbc8f03b6d32e144d622f2a7747030e3d67a4b5181`

### `old_fashion_mic.webp`

a vintage chrome broadcast microphone with an oval capsule and a fine mesh grille, held in a spring-suspension ring on a short round stand. No logos, text, cable or person.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:18:47.322396683Z
- Original: `sticker-regeneration-full/originals/old_fashion_mic-2.png`, 1024 × 1536 PNG, sha256 `828bc54384bb6d4d2735b203a9e5109004125b52aab3ac13215bdcfc47a10dbc`
- Shipped: 315 × 512 WebP, 127,066 bytes, sha256 `c1e4699e0c3a9452286a96266c6c7419db0124c20e7acdde4ce02d25a5ecba1c`

### `on_air_sign.webp`

a red illuminated studio sign box with a black frame, its glowing face showing the words ON AIR in white capital letters. Those two words are the only exception to the no-text rule. The glow stays inside the sign.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:19:06.579264889Z
- Original: `sticker-regeneration-full/originals/on_air_sign-2.png`, 1774 × 887 PNG, sha256 `3fc91129e63ed5118a5df89a043fba5ba8652696979bd40b039d341178de7ca5`
- Shipped: 512 × 240 WebP, 88,956 bytes, sha256 `e65c15338111ceb66ddd675a984f26c415bbff2dd7cfc8a6527048c78562f22b`

### `orange_juice.webp`

a small glass bottle full of bright fresh orange juice, with a white metal screw cap and a simple paper label printed with an illustration of an orange slice and a green leaf, and below it the words fresh squeezed in stylised dark green hand-lettered script. Only those two words, spelled exactly in lower case; no logo or other text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T11:41:54.942628338Z
- Original: `sticker-regeneration-new2/originals/orange_juice-2.png`, 1024 × 1536 PNG, sha256 `ce710c2f28d0e3de28efc04c0f81f8fff3db4680596bada62e06125a53e47d65`
- Shipped: 213 × 512 WebP, 85,614 bytes, sha256 `6d936e4e60073445eb7529e4ee1e63b84700a6a86605d96da305388f16e0f600`

### `padlock.webp`

a combination padlock with a chrome body and a curved steel shackle, its black dial printed with white tick marks and the numbers 0 to 35 in steps of five, seen at a slight angle. No brand name or text other than those numbers.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:12:32.146239421Z
- Original: `sticker-regeneration-redo/originals/padlock-1.png`, 1136 × 1384 PNG, sha256 `626f54440296ee9d6d52b82934096039b1cd3eeb5b473fff5a5f5fc39fa1c173`
- Shipped: 355 × 512 WebP, 130,826 bytes, sha256 `038fee4923b053924bac3ad8a6c2ed955266f0b0ba3186097c038a05f7c8c103`

### `passport_holder.webp`

a closed passport holder in dark navy-blue leather with neat stitching, seen at a slight angle, with a simple airplane icon stamped in gold foil on the front and the word PASSPORT in gold capitals below it. The tops of two printed paper flight tickets stick out from the top edge of the holder; their printing is only small unreadable lines, with no airline name, logo or legible text. No other words, no flags, national emblems or crests.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T11:34:53.147887025Z
- Original: `sticker-regeneration-new2/originals/passport_holder-1.png`, 1062 × 1481 PNG, sha256 `ac6d5b12ddbfbc673066f85faa39da9c52b783c15038a5ba76499ad2474368ac`
- Shipped: 332 × 512 WebP, 117,014 bytes, sha256 `03af42284c1347fc195cdc439858f573fb1f05c565a98d75c9e8205fa3d8b307`

### `pause.webp`

a round glossy translucent orange plastic push button, like a large arcade button, seen from the front at a slight angle, with a white pause symbol of two upright rounded bars set into its face.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:43:59.621680320Z
- Original: `sticker-regeneration-redo/originals/pause-2.png`, 1271 × 1238 PNG, sha256 `980d31b707dc0d7c3db92f87065291f39322840d1a6a66ef4620e1c8ce4bffb6`
- Shipped: 512 × 501 WebP, 164,584 bytes, sha256 `5b0ef6ba72c3a4dd0bcc4e54076daf1acc2e173cecd8e5b882553ba77f55c4b6`

### `peace_sign.webp`

one real adult hand making the peace sign: index and middle fingers raised in a V, the other fingers folded under the thumb, palm facing the camera, with a short length of wrist. Medium, warm golden-tan skin with natural creases and nails. Exactly five fingers. No rings, sleeve, face or body.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:20:57.321213159Z
- Original: `sticker-regeneration-full/originals/peace_sign-1.png`, 1024 × 1536 PNG, sha256 `64e49d6bd6542c85b54b8e86f81ffd76dcb5369fc6aaf835be3f56908f126979`
- Shipped: 233 × 512 WebP, 65,388 bytes, sha256 `f33ab18b4ca8bf349054c72c9e38057517f5bc62e7dd1350da0687ba14f7f562`

### `peace_sign_neon.webp`

a neon sign made of a single lit red neon tube bent into the outline of a hand making the peace sign, with two fingers up in a V, held by small clear mounting clips. The light stays on the tube, with no glow spilling beyond it.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:44:36.807179739Z
- Original: `sticker-regeneration-redo/originals/peace_sign_neon-2.png`, 1067 × 1475 PNG, sha256 `2de7f9c3c825704b65ba3efcf1a4adc45a8a775f7c934f8961b317f90514f313`
- Shipped: 294 × 512 WebP, 97,778 bytes, sha256 `a0ae9f69d0e57fe0dd4464cc5324c3d8ef44df77467249428f735f3d9e557805`

### `peach.webp`

a single ripe peach with a soft fuzzy blush of red and yellow and one green leaf on its stem.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:22:17.976642988Z
- Original: `sticker-regeneration-full/originals/peach-2.png`, 1295 × 1214 PNG, sha256 `6d244cad0cd62c7a93d906ddd0d1a6f1412344a820b6850e324a573c4122476c`
- Shipped: 512 × 510 WebP, 183,874 bytes, sha256 `ed5bc9b4a876ee49890724550c4d9ee16eb3828ccecd86f0085c59bd0c687c41`

### `phone_charger.webp`

a black USB wall charger plug with its black charging cable tangled in a messy loose knot around it and the cable's small connector end poking out. No logos or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:13:46.900998642Z
- Original: `sticker-regeneration-new/originals/phone_charger-2.png`, 1536 × 1024 PNG, sha256 `4cf75b060ce55fe4f6465b159821dc6ac69569669b382ef5062a578b9fa4f56a`
- Shipped: 512 × 386 WebP, 126,466 bytes, sha256 `1213df6db31574ace220d83f6e0722b7ba3fe55f64dda2d2cd39bc1a0bb20466`

### `pineapple_pizza.webp`

a whole small round pizza with a golden crust, melted cheese, chunks of pineapple and pieces of ham, seen from slightly above. No box, plate, cutter or missing slice.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:22:32.403449789Z
- Original: `sticker-regeneration-full/originals/pineapple_pizza-1.png`, 1278 × 1230 PNG, sha256 `cf8648595d799b23517c28fbdbdbfd47a72593e59608c73de9ed909c3d46eb4c`
- Shipped: 512 × 494 WebP, 221,748 bytes, sha256 `84fa93634d1c3ae9e2ae520c814a9c7c00db90d745744b20e4c6a5b561016202`

### `pink_dumbbells.webp`

a pair of small pink neoprene-coated hand dumbbells with hexagonal ends, one resting against the other. No numbers, text or logos.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:23:37.608788831Z
- Original: `sticker-regeneration-full/originals/pink_dumbbells-2.png`, 1536 × 1024 PNG, sha256 `80026d55572687972ab052e48c91e00e3faac0d9e29d79c490fe590b6982ce06`
- Shipped: 512 × 357 WebP, 81,772 bytes, sha256 `a2d83caf5fdd93163be88d79827335ec591a04897e995d25187cc218fca9a93f`

### `pixel_sunglasses.webp`

a pair of novelty pixel-art sunglasses made as a real physical object from flat black acrylic cut in stepped square pixels, with two small white pixel highlights on the lenses, seen from the front. No text or person.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:23:55.868553887Z
- Original: `sticker-regeneration-full/originals/pixel_sunglasses-2.png`, 2172 × 724 PNG, sha256 `d86bb21736cf956612b3116a5f206304bf32217736a1ad750154baec132feb30`
- Shipped: 512 × 175 WebP, 48,194 bytes, sha256 `ea9d51c48a1ab0501691ea3457a6c4465bae8d56a2a6344bcedf2213d77c7eee`

### `pizza_slice.webp`

a single triangular slice of pepperoni pizza with a golden crust and a stretchy string of melted cheese, seen at a slight angle. No plate or box.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:23:58.052202985Z
- Original: `sticker-regeneration-full/originals/pizza_slice-1.png`, 1536 × 1024 PNG, sha256 `1fb1da765af87d640a6f8d2d6b5a75cbc2a1d853232ad50286a7ee12e5b0d27f`
- Shipped: 512 × 353 WebP, 112,430 bytes, sha256 `c09db26c70bb985c0f753e92345c57853a11d0bba616c6e3ddf3b5aa322ba8a6`

### `police_siren.webp`

a real rotating emergency beacon light: a ribbed, translucent red plastic dome on a short round black base, with the bulb and silver reflector visible inside. Seen slightly from above. No light rays, flare or glow outside the object, no vehicle and no markings.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T19:02:42.377147045Z
- Original: `sticker-regeneration-pilot/originals/police_siren-1.png`, 1263 × 1246 PNG, sha256 `c2ad93967405ab09e4ce9995c177920ad50d9781beb8c0cbe12e76929c9887aa`
- Shipped: 408 × 512 WebP, 169,530 bytes, sha256 `bd5828e8580c8c2e02db565727a7158817fa06decdd84bc847f7d66cddfcf982`

### `poop_emoji.webp`

a glossy chocolate-brown squishy toy shaped like a swirled pile of poo, with two big googly eyes and a wide white smile. A physical toy, not a drawing.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:13:44.133517346Z
- Original: `sticker-regeneration-redo/originals/poop_emoji-1.png`, 1320 × 1192 PNG, sha256 `f7981de962026b5d36e2737aff3a6728b6c3ac4da17c79b71f3708898f068c77`
- Shipped: 512 × 466 WebP, 126,064 bytes, sha256 `36cae01e4dde722814a016164284c26ed6c5e8eeade1d32f575418412f4e51f8`

### `power_bank.webp`

a slim rectangular power bank in matte black plastic with rounded corners, four small glowing blue LED dots in a row along one edge, and a short white cable plugged into it. No logos or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:46:49.344846656Z
- Original: `sticker-regeneration-new/originals/power_bank-1.png`, 1536 × 1024 PNG, sha256 `da6a8cae4309191196390c7c325e3275e10ee654a1df4b3ce4c5a4e3f6b47007`
- Shipped: 512 × 343 WebP, 66,872 bytes, sha256 `c7ffb3d07a64806fe4f812fffef73a946664b3376feeb8a069fef429180baa24`

### `profile.webp`

a physical user-profile symbol: a circular head above a rounded shoulder shape, cut from thick glossy cobalt-blue acrylic and shown as a flat object with visible thickness and polished edges, with small scratches and studio reflections. No face, stand, frame or circle around it.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T19:04:08.095382538Z
- Original: `sticker-regeneration-pilot/originals/profile-2.png`, 1426 × 1103 PNG, sha256 `eaa11df407499e15a346165818d7e05c4c253f5ca34d47010f27cf2ba7a59dc8`
- Shipped: 458 × 512 WebP, 116,832 bytes, sha256 `3b452fea92d1de75940b96d0bfedfa4cd70ec6182759dc34fbca5d6a13d4c850`

### `programmer.webp`

a chunky late-90s laptop in matte charcoal plastic, opened, its screen glowing dark with abstract lines of bright green blocks and brackets that are not readable characters. No logos, keyboard lettering, person or desk.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:25:34.162447667Z
- Original: `sticker-regeneration-full/originals/programmer-2.png`, 1312 × 1199 PNG, sha256 `9c32c0631174c72a4b8438d42e420fd895aff8cced683ab5b40731c2182faeb0`
- Shipped: 512 × 495 WebP, 166,294 bytes, sha256 `e27cd0bdbdd49d3f0d5cce2adae4ecec6f5793aecb025476019d64df21311906`

### `protein_bar.webp`

a chocolate-coated protein bar half out of its torn-open foil wrapper, with a bite missing from the exposed end and a few crumbs. The wrapper is plain metallic dark blue, printed with the words PROTEIN BAR in bold capitals, PROTEIN in red and BAR in yellow. Only those two words, spelled exactly; no logos, nutrition labels or other text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T11:42:37.570141577Z
- Original: `sticker-regeneration-new2/originals/protein_bar-2.png`, 1945 × 808 PNG, sha256 `974e65e472b13f3791cd184f2ac7cc7d63bf966b9ff3bc072730ce26e70345ff`
- Shipped: 512 × 219 WebP, 79,630 bytes, sha256 `839bbc79d45c1d7b680c6545ca300959e4f91a9463dd99628302f4c551601cbc`

### `psychedelic_tv.webp`

a 1970s wood-grain cabinet television with rabbit-ear antennas on top and knobs on the right side, its curved screen showing a surreal psychedelic picture: a white llama standing in front of swirling neon rainbow rings and floating ringed planets. No people, brand names or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:45:34.690591284Z
- Original: `sticker-regeneration-redo/originals/psychedelic_tv-2.png`, 1394 × 1128 PNG, sha256 `3f34e96d877319bbe163d05581cbe6164e02b11d325a6917dcc65343080b6d5d`
- Shipped: 512 × 491 WebP, 183,732 bytes, sha256 `4cd24a67954775df9f90eb7af97d86c7e311b31c78dc2d6551fdc0bdd3e78345`

### `purple_diamond.webp`

a large brilliant-cut gemstone in light violet purple, seen from the side so the flat top, the faceted crown and the long pointed bottom all show, sparkling with bright facet reflections.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:14:57.170071227Z
- Original: `sticker-regeneration-redo/originals/purple_diamond-1.png`, 1536 × 1024 PNG, sha256 `f022dd6785f3c6b8948f77b157357cc30df0c08dd62c41e11ad1d24f9ad82d7e`
- Shipped: 512 × 344 WebP, 110,680 bytes, sha256 `501e626ba1faf1f7508261332a769b7da347876cd42871629dea90632de76533`

### `radar.webp`

a round green radar scope display in a dark grey metal housing, with concentric rings, a bright sweep line and a few glowing blips on the screen. No text, numbers, labels or person.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:27:25.286634997Z
- Original: `sticker-regeneration-full/originals/radar-2.png`, 1263 × 1245 PNG, sha256 `6e28bd73a8644ca52262f4cecd707e90ba9850f81d540e204d7ee47914299a46`
- Shipped: 494 × 512 WebP, 209,408 bytes, sha256 `38db212350674de9fd9b618004084f743ad45efeb29862b8f2cb2944ca3c3ed9`

### `rainforest.webp`

a dense cut-out cluster of lush tropical rainforest plants: monstera leaves, banana leaves, ferns and a few vines, deep green with drops of moisture. No animals, people or sky.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:27:06.110627050Z
- Original: `sticker-regeneration-full/originals/rainforest-1.png`, 1356 × 1160 PNG, sha256 `0a262b962b0253200df9c877d3a59accd5b3277397a50859b7b17a468132874c`
- Shipped: 512 × 436 WebP, 213,282 bytes, sha256 `1885b82ebd37bd6de4da49e63fb5cd48688650976a3b566265966bb6569cf74a`

### `raised_hand.webp`

one real adult hand raised with the palm facing the camera, fingers slightly apart and pointing up and the thumb out to the side, showing natural palm lines, with a short length of wrist. Medium, warm golden-tan skin. Exactly five fingers. No sleeve, jewellery, face or body.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:46:44.049468748Z
- Original: `sticker-regeneration-redo/originals/raised_hand-2.png`, 1130 × 1392 PNG, sha256 `b8f60d2588929672fd628541611829ba2cef343afc9b407bbe0a3b26ad36c452`
- Shipped: 387 × 512 WebP, 78,030 bytes, sha256 `73964f3900f51118052d46d91382ea0332d4f16d45cf11fff9851fc793218a77`

### `roller_skates.webp`

a pair of white high-top quad roller skates customised by hand, the boots covered in playful hand-painted pink and purple doodles of hearts, stars, squiggles and drips, with mint-green laces, chunky pink and orange wheels and a mint-green toe stop. No words or lettering.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:15:58.114855805Z
- Original: `sticker-regeneration-redo/originals/roller_skates-1.png`, 1347 × 1167 PNG, sha256 `e74d01b5e44034410f8cc6629135dd193a2da0b4dd01d8514c71552294eb448a`
- Shipped: 512 × 445 WebP, 172,428 bytes, sha256 `451d6ee858c6f9af76c806202de7e9c494fb2314aeaaf34a70033af730177c7c`

### `rotary_phone.webp`

a classic rotary-dial desk telephone in glossy candy-red plastic with the handset resting on top and a coiled cord, seen at a three-quarter angle. The dial has finger holes but no printed numbers, letters or logos.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:30:31.589450850Z
- Original: `sticker-regeneration-full/originals/rotary_phone-2.png`, 1536 × 1024 PNG, sha256 `6834ee5fd780da30291b8234535c77ed0d3cc58ff4ed692167f432ad7c96b8c3`
- Shipped: 512 × 381 WebP, 143,066 bytes, sha256 `cfc7f555aa050d91b5a11ebe4473380c08fcc1bf98becbd333c7ecb180c8db32`

### `salt_lamp.webp`

a Himalayan salt lamp: a rough, chunky block of pink-orange rock salt glowing warmly from inside, standing on a small square dark wooden base with a thin cord. No text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:15:16.703427047Z
- Original: `sticker-regeneration-new/originals/salt_lamp-2.png`, 1128 × 1394 PNG, sha256 `ce854fe8e6356db5d410c8233f80878c802d05c2778f0ec57adcfccc15b8eea8`
- Shipped: 384 × 512 WebP, 115,088 bytes, sha256 `3bf4cc4d3c20c964d7f11f663b19da7a17a91ff0c58d35c476d48311eaf97d66`

### `samoyed_dog.webp`

a real fluffy white Samoyed dog sitting, turned slightly to one side, whole body visible including paws and curled tail, mouth open in a relaxed smile with the tongue slightly out, dark eyes. No collar, tag, clothing or ground.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T19:05:22.931464636Z
- Original: `sticker-regeneration-pilot/originals/samoyed_dog-2.png`, 1141 × 1378 PNG, sha256 `ca4b3444b9c47773aae0d8abec0fac0bb49ba3c123b674361407310a031a5f3c`
- Shipped: 401 × 512 WebP, 87,910 bytes, sha256 `73087c45ff208428bd5d350ce97c119e7fbfa3a3f603488c176b6c5b6398e130`

### `school_backpack.webp`

a classic 1990s kids' school backpack in colour-block nylon: a teal body, purple piping, carry loop and shoulder straps, a red front zip pocket, yellow corner panels and yellow zip pulls, standing upright. No logos, patches or keychains.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:47:35.468702777Z
- Original: `sticker-regeneration-redo/originals/school_backpack-2.png`, 1187 × 1326 PNG, sha256 `e3ad95e7d68c772b880035c1cc1d306312f71aaa29c22839eddb3542cfc7f319`
- Shipped: 458 × 512 WebP, 156,176 bytes, sha256 `256fc5d233bbe50debc027b375c58133222e2911099723836ccd312d55b5681c`

### `school_notebook.webp`

a spiral-bound school notebook lying open at a slight angle on a blank page of pale blue ruled lines with a red margin line, with a yellow wooden pencil with a pink eraser lying across the page. No writing.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:17:01.514099351Z
- Original: `sticker-regeneration-redo/originals/school_notebook-1.png`, 1480 × 1063 PNG, sha256 `3f266d3de24d681a672a41148c63d528efac5afc7e9fb494426de71f12c90d1f`
- Shipped: 512 × 374 WebP, 136,296 bytes, sha256 `ca78142f0b3dd3bdb7bee3c8b0c45cf8c3a36315e947f67ac32df79294196cbb`

### `secure_vault.webp`

a small brushed stainless-steel safe with a heavy door, a round black combination dial with white numbers and tick marks, a chrome lever handle and two hinges, seen at a slight angle. No brand name or text other than the dial numbers.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:17:51.485326383Z
- Original: `sticker-regeneration-redo/originals/secure_vault-1.png`, 1278 × 1230 PNG, sha256 `8114ce586f22e39fa410a8b0e808023c8697adcd04395999284b4f552937334a`
- Shipped: 512 × 498 WebP, 198,526 bytes, sha256 `1db7e0aaa9d7bdc6e33c3223ba1218f8fcf1138c37d2a6967a10225a90d4b570`

### `serum_dropper.webp`

a small amber glass dropper bottle with a black rubber bulb and a glass pipette, filled with golden liquid, with a single drop at the tip. No label, brand or text.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:33:00.205616444Z
- Original: `sticker-regeneration-full/originals/serum_dropper-2.png`, 1024 × 1536 PNG, sha256 `16251b9202e8fa94fce7485ec1c156bb295407ab9b09f42d72960924ae2b869c`
- Shipped: 280 × 512 WebP, 75,174 bytes, sha256 `c41120fe5d680be418c9d82b71035a6f1c19ea12971b146fa37a57c604b4ab04`

### `shrimp.webp`

a single cooked pink-and-orange shrimp curled in a C shape, with its tail on and fine antennae. No plate, sauce or lemon.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:30:49.260006447Z
- Original: `sticker-regeneration-full/originals/shrimp-1.png`, 1448 × 1086 PNG, sha256 `337cb48617c8497a7d19e79fb42bb25dd86117188ee2c0be37b9ccf4f0554416`
- Shipped: 512 × 379 WebP, 121,228 bytes, sha256 `94825e3f338d0d89589f940a33f113c93b8cbaa5cf461722c2c71a2a9ca7c9b4`

### `skateboard.webp`

a skateboard with a deck painted in bold colour blocks of yellow and turquoise abstract shapes, grey trucks and pink wheels, seen at a three-quarter angle. No logos, text or writing on the grip tape.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:31:08.879594704Z
- Original: `sticker-regeneration-full/originals/skateboard-1.png`, 1880 × 836 PNG, sha256 `304c9baf2f6aa2de42eba425249fed55650a7db8e60fceaaad59235008c2087a`
- Shipped: 512 × 240 WebP, 53,706 bytes, sha256 `3c511308bdcb46d4832b86e1f9f5a8b3e5c2a49d779d4cbe4d209ac114675172`

### `skeleton_key.webp`

a single ornate antique brass skeleton key with a decorative open bow, a long thin shaft and a notched bit, lying on a diagonal. Polished but aged brass with fine scratches and a light patina. No key ring, tag or chain.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T19:06:17.434670680Z
- Original: `sticker-regeneration-pilot/originals/skeleton_key-2.png`, 1536 × 1024 PNG, sha256 `3df1b661eece61c5cd42beb8cad4f95c2b6724b8fb40ca4a214f34c8afb45bef`
- Shipped: 512 × 353 WebP, 65,992 bytes, sha256 `87db6f09c083e69cbc5150d1074dc18ea598238fc648893d86d0b26dfcead88d`

### `soap_bar.webp`

a single rounded rectangular bar of pale lavender soap with a smooth, slightly wet surface and a few small white suds bubbles on one side. No embossed logo or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:48:21.611214196Z
- Original: `sticker-regeneration-new/originals/soap_bar-1.png`, 1536 × 1024 PNG, sha256 `cacfa90649d1cbb9b58c03995db6b84fca89234cc7ece5bad4b6be23693a6f3b`
- Shipped: 512 × 303 WebP, 116,582 bytes, sha256 `30bb093261dcb56c5c055f1bbb1328221569f804879ac6d885b118c82efa068c`

### `soccer_ball.webp`

a classic leather soccer ball with black pentagons and white hexagons, slightly scuffed from play. No logos, text or grass.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:31:35.480140443Z
- Original: `sticker-regeneration-full/originals/soccer_ball-1.png`, 1254 × 1254 PNG, sha256 `ab5c2b5a447bf035ac4d1e2dd27545df602f207b181205a008538995ef25564d`
- Shipped: 507 × 512 WebP, 170,826 bytes, sha256 `dbe80fc286bb774bc10f92db0f8fd3cdb770b9b145f88ab1a3cfeaa09497d450`

### `socks_and_sandals.webp`

a close-up of one foot and ankle wearing a white cotton sports sock pulled up the shin and a plain black rubber slide sandal with one wide strap, standing flat, seen from a front three-quarter angle. Only the foot, ankle and lower shin; no stripes, logo or text on the sandal.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:48:50.229825703Z
- Original: `sticker-regeneration-new/originals/socks_and_sandals-1.png`, 1226 × 1283 PNG, sha256 `64d2b65b1ffd2a1df18750b9af572e48c12f2d954674285b99739a074928c22b`
- Shipped: 284 × 512 WebP, 69,078 bytes, sha256 `00de70c0188599ca84aebe8ed9e75735a3bff171045fbabce0365526d7604793`

### `sparkle.webp`

a cluster of three four-pointed star shapes of different sizes cut from thick glittery gold acrylic, catching the light. No glow or rays outside the shapes.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:35:23.892029297Z
- Original: `sticker-regeneration-full/originals/sparkle-2.png`, 1299 × 1211 PNG, sha256 `9d4ff0617e08c3139bd92301e6da8e3e6389c0109b1420b1b8c18be3b53a6584`
- Shipped: 512 × 475 WebP, 136,522 bytes, sha256 `b63f560a6bda81ea72293988145b3f5935aaa924bb57b98518f1c34d82c327b2`

### `speakers.webp`

a pair of round, glossy orange-and-yellow plastic desktop computer speakers from the early 2000s, ball-shaped, each with a black speaker cone set in rings of white and black stripes on its front, one slightly behind the other. No logos or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:49:07.420867465Z
- Original: `sticker-regeneration-redo/originals/speakers-2.png`, 1477 × 1065 PNG, sha256 `4c1b34d1fcbb82307787eb18d44429b2abcb4f0d2f3a425530659dfea25f41ad`
- Shipped: 512 × 374 WebP, 123,376 bytes, sha256 `624d9874027e7adb62ae32e7af4492e3cbdcc2ee1de472014857fa910d2ea84e`

### `stop_sign.webp`

a red octagonal stop sign with a white border and the white word STOP, seen at a gentle three-quarter angle with light scuffs. That one word is the only exception to the no-text rule. No pole, bracket or wall.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:32:58.375567553Z
- Original: `sticker-regeneration-full/originals/stop_sign-1.png`, 1261 × 1247 PNG, sha256 `2d72bdd3153be65c389b67ecea5a6d800c234542da00128b5fe0c0efaaa444bd`
- Shipped: 464 × 512 WebP, 153,524 bytes, sha256 `9e1d58037f5414469ec97d215b5579c5a924f7cb09d7dbc57e39dffa96abcd35`

### `storyboard.webp`

a sheet of off-white paper with six quick, loose pencil-sketched storyboard panels, the kind a professional storyboard artist dashes off in a couple of minutes each: simple confident outlines, a few lines of quick hatching and nothing more, with no skin texture, no detailed rendering, no smooth gradients and no dramatic lighting. They follow one invented young Black student, not a real person, with a plain, ordinary face and build rather than a model's looks, wearing a baseball cap and wired earphones whose thin cable runs down into a hoodie: a close-up portrait, walking away down a street, holding up a camera, looking out at the sea, their trainers mid-step, and laughing at the end. A few small arrows show camera moves. One corner is slightly curled. No words.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:49:26.620934616Z
- Original: `sticker-regeneration-new/originals/storyboard-1.png`, 1360 × 1157 PNG, sha256 `95fd98aa2257b22b57e9a78f71cba87e86af08050c38faf0857650cb0a3c7262`
- Shipped: 512 × 482 WebP, 170,088 bytes, sha256 `1aee57da1cbeb24ba5d555c4effa34dd34dcfd22bcd2fa273b343c72f9756a9e`

### `sunglasses.webp`

a pair of chunky late-1990s oval sunglasses with thick glossy turquoise plastic frames and pink-tinted lenses, seen at a three-quarter angle. No logos or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:19:19.988243909Z
- Original: `sticker-regeneration-redo/originals/sunglasses-1.png`, 1774 × 887 PNG, sha256 `85fe7ab8ddf4fc643f00857d7cba3093ac6bc45fdcb8a0187940c79362330731`
- Shipped: 512 × 245 WebP, 63,690 bytes, sha256 `61c681cd3e566e6e9b995242408db79bfee00e268f9a5a2bc02f8143c3bd2d92`

### `teeth.webp`

a full set of dentures, upper and lower, with pink acrylic gums and white teeth, the two halves slightly apart as if mid-bite, seen at a slight angle.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:50:35.594765319Z
- Original: `sticker-regeneration-redo/originals/teeth-2.png`, 1460 × 1077 PNG, sha256 `e477324f92fb8eb439355f551cd5a41dab9cdee501b603fa748a6b5edfe1b7c0`
- Shipped: 512 × 382 WebP, 121,922 bytes, sha256 `43fd7d0daa6de19918b0f0ac2b7e89bbd20cc4d6d2b4ce4e9578480b50d92eb5`

### `tissue_box.webp`

a square tissue box printed with a pastel pattern of small flowers, with a single white tissue puffed up out of the oval opening on top. No logo or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:50:03.974439090Z
- Original: `sticker-regeneration-new/originals/tissue_box-1.png`, 1254 × 1254 PNG, sha256 `9ff33769c41af3b672d04858a40123147594bea6687d0818a240c6f4db13ed45`
- Shipped: 361 × 512 WebP, 124,894 bytes, sha256 `275785e0461e008f3914823441e2c0e1a8ce9be015849f0912a158eeffce38e4`

### `toaster.webp`

a retro chrome two-slot toaster with rounded edges, two slices of golden toast popping up and a small black lever. No cable, brand or text.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:34:40.447278416Z
- Original: `sticker-regeneration-full/originals/toaster-1.png`, 1312 × 1199 PNG, sha256 `a617d2da389e42d9097b651d9fb676566c1b55de3b8d9e4876e2c8f6ed942178`
- Shipped: 512 × 489 WebP, 188,648 bytes, sha256 `be5e2bcd372b323e0b8d29c958115bd5542745320a6e9960fedc98b4064d5195`

### `toddler_bike.webp`

a toddler's balance bike without pedals, with a glossy red metal frame, two small black rubber wheels with white rims, a little black saddle and white handlebar grips, seen from the side. No logos or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:50:35.355137098Z
- Original: `sticker-regeneration-new/originals/toddler_bike-1.png`, 1536 × 1024 PNG, sha256 `14442b8b68cbb40eabe5773ea49b03eaa77cb73bde37321ca322f581c49bd002`
- Shipped: 512 × 351 WebP, 92,148 bytes, sha256 `1cd842c9397675806fa42a36a1612e1821cf6c6a1dc5c2db1c2bae52de3b6db3`

### `toilet_paper.webp`

a full roll of white toilet paper with a soft quilted texture, standing upright, with the loose end hanging down a little. No packaging or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:50:54.279178738Z
- Original: `sticker-regeneration-new/originals/toilet_paper-1.png`, 1312 × 1199 PNG, sha256 `289f34cc32ae7b505ab624f5e3e5c3d9d473a0c82f8e8927e29fc2b5b0d2cae0`
- Shipped: 417 × 512 WebP, 141,884 bytes, sha256 `4410ca6f4e3cec509c03383eacff7ecd0942251a9634594c1dd586763426178c`

### `traffic_barrel.webp`

an orange-and-white striped plastic traffic barrel with an amber warning lamp on top and a black rubber base ring, leaning slightly, with a big black heart spray-painted on its front as graffiti. Scuffed from use. No other markings or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:20:15.158804588Z
- Original: `sticker-regeneration-redo/originals/traffic_barrel-1.png`, 1024 × 1536 PNG, sha256 `d98109a5b1fcdce66bf446c0604f025ac9521cd542ae925e8baba2c6a5edae44`
- Shipped: 304 × 512 WebP, 93,962 bytes, sha256 `a33707b9e0ffe1254e6c995bdcbd80f36cb81d0a09cc65de8d9710c333bfb1e5`

### `traffic_cone.webp`

a real orange traffic cone standing upright on a square black rubber base, with two white reflective bands, seen slightly from above. Light scuffs and road dust from use. No stencilled text, markings or other cones.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T19:07:23.435294520Z
- Original: `sticker-regeneration-pilot/originals/traffic_cone-2.png`, 1110 × 1417 PNG, sha256 `897b3c5b71f8914dac5fbfd6ebeff9e83b83edcc8024ec8ea25401d17991d7c0`
- Shipped: 318 × 512 WebP, 87,184 bytes, sha256 `fafd696a1bafe5ebcae3431866ba6bfada512046029554c3e88f52a1888298ea`

### `trail_sign.webp`

a rustic wooden hiking trail signpost with three blank arrow-shaped boards pointing in different directions on a weathered post. No carved or painted text, map or ground.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:35:37.520573755Z
- Original: `sticker-regeneration-full/originals/trail_sign-1.png`, 1024 × 1536 PNG, sha256 `2dafef25489737b4fcb6408947f313c214354489f392815b8bd16e23d76728e5`
- Shipped: 323 × 512 WebP, 95,958 bytes, sha256 `5ba34f292dbd2a1ab67f080f57c2b1015d1e41b18303cbe5918deca98ac4bd55`

### `travel_pillow.webp`

an inflatable U-shaped travel neck pillow in sky-blue velour with a small clear plastic valve and a short cord loop, seen from the front. No logos or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:51:22.881015289Z
- Original: `sticker-regeneration-new/originals/travel_pillow-1.png`, 1536 × 1024 PNG, sha256 `921aa080a2cc733f16f620866da92b0e5710f6060ce4f56e061bdfcc47c5ff96`
- Shipped: 512 × 351 WebP, 102,526 bytes, sha256 `0095595fbeaf5663a2097c6e0833d5722f8602fdb999792b17f86152b48de4ab`

### `tulip.webp`

a close-up of a single pink tulip flower, its petals deep pink fading to white at the base and closed in a soft cup, with a short length of green stem below. The bloom fills most of the frame. No leaves or vase.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:20:58.415290950Z
- Original: `sticker-regeneration-redo/originals/tulip-1.png`, 1043 × 1508 PNG, sha256 `9f0ce68601a33214d800ed86b2269b67ad7b5eab9a62da966736bb726366dd41`
- Shipped: 355 × 512 WebP, 90,712 bytes, sha256 `272ba9587591965d815a4acbf3ea46b353b19e71c005ba30ff95ef5760b73794`

### `tv_remote.webp`

a long black plastic TV remote control seen from the front at a slight angle, with rounded ends and small grey rubber buttons, labelled in white like a standard generic remote: at the top a red power button with a white power symbol; a number pad with the digits 1 to 9 and 0; a round directional pad with small arrows on its four sides around a centre button labelled OK; VOL with + and - on one side and CH with + and - on the other; a mute button showing a small speaker with a cross; and a back-arrow button. Only those labels and symbols, spelled exactly; no brand, logo, streaming-service buttons or other text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T11:43:09.628036342Z
- Original: `sticker-regeneration-new2/originals/tv_remote-2.png`, 811 × 1940 PNG, sha256 `f9541b3f2d22dcbfbee604f80c070f70a091aff6ac972ce887492b6febef7fc9`
- Shipped: 185 × 512 WebP, 60,652 bytes, sha256 `9129a2ff6828482dade74e68baf3044aa30e9b6d3f398186421043a0b2e180a5`

### `under_construction_sign.webp`

a weathered yellow metal sign hanging from a rusty chain, with black-and-yellow hazard stripes along its top and bottom edges, a black warning triangle with an exclamation mark, and the words UNDER CONSTRUCTION in bold black capitals. Light scratches and wear. No text other than those two words.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:21:14.956863843Z
- Original: `sticker-regeneration-redo/originals/under_construction_sign-1.png`, 1536 × 1024 PNG, sha256 `477407d3e40bdfcfb8945225f552e94954b99a80871b55a72ec2639be93047a8`
- Shipped: 512 × 409 WebP, 162,202 bytes, sha256 `fe8e1ba2a35fb7bfca2f39cbc7a46414a706c33b5b7eed1180f666e8b21b72db`

### `unicorn_float.webp`

a white inflatable unicorn pool float with a rainbow mane, a gold horn and pink cheeks, glossy vinyl with visible seams. No water, person or text.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:42:53.617592336Z
- Original: `sticker-regeneration-full/originals/unicorn_float-2.png`, 1416 × 1111 PNG, sha256 `1f91afadc86a9c8c51e61c76e378480699673632a577e65be57109821ff1172d`
- Shipped: 512 × 410 WebP, 103,134 bytes, sha256 `c16f09e61f0b8266e51d7bb79d7e5eee0c20c1acfbfd24c2f6c2fcb57c523fa9`

### `usb_stick.webp`

a USB flash drive with a glossy bright blue plastic body, a brushed silver metal swivel cover swung up and away at an angle to show the whole USB plug, a round blue cap where the cover pivots, and a short black braided lanyard loop with a small black slider bead, with 32 GB printed in dark grey on the silver cover. Only that text, spelled exactly; no logos or other markings.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T11:43:34.434584327Z
- Original: `sticker-regeneration-new2/originals/usb_stick-2.png`, 1536 × 1024 PNG, sha256 `c6c1af6f8c5fc2e8a5cf9e4ce2ac97d32ce7bbeac026f0b554a58d148cd5119c`
- Shipped: 512 × 354 WebP, 102,968 bytes, sha256 `4e43c6900077356ad361c1178dfd76ecdb313d76145545342bb1d0c5cc9a3cd7`

### `venus_flytrap.webp`

a close-up of a single Venus flytrap trap: one open pair of green lobes blushing deep red inside, lined along both edges with long, fine spiky teeth, on a short green stem. Only that one trap, with no pot, soil, other leaves, label or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T11:44:14.616882237Z
- Original: `sticker-regeneration-new2/originals/venus_flytrap-2.png`, 1367 × 1150 PNG, sha256 `14ec1b7557fc2f51e0aebb368422725ab5c944c1275284cfdc115c696549abe4`
- Shipped: 512 × 458 WebP, 146,612 bytes, sha256 `e32cf65d5170ba510d359218dc8629775cabdca94a31546451b94b21c2227469`

### `verified.webp`

a round glossy enamel badge pin in bright blue with a raised white check mark in the centre and a polished silver rim. No text, stars or scalloped edge.

- Style A, attempt 1 of 2
- Generated: 2026-11-11T20:37:48.000130283Z
- Original: `sticker-regeneration-full/originals/verified-1.png`, 1254 × 1254 PNG, sha256 `8a1816b41ee01d0ad6ccb48df03882c6cb9de8a72d61abc4c7d81d1827a495a6`
- Shipped: 501 × 512 WebP, 178,692 bytes, sha256 `4d48ed92fefd4cf734bad3e2f529e69ef664794f03c6a1df227db81f268c0d66`

### `video_camera.webp`

a compact late-90s handheld camcorder in silver-grey plastic with its side flip-out screen open, a lens hood and a hand strap, seen at a three-quarter angle. No logos, text or person.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:43:48.328909897Z
- Original: `sticker-regeneration-full/originals/video_camera-2.png`, 1536 × 1024 PNG, sha256 `bb3ef0e1939bd526ae65419fd5e838d45b07a2ed274f7b175ac36f1763ebc1a9`
- Shipped: 512 × 368 WebP, 121,446 bytes, sha256 `a2cd5087e63c6b6b52eebee70daf0598d9932f6e9313c42037746bba33b673d6`

### `video_clap_board.webp`

a real film clapperboard, slightly open, with black-and-white diagonally striped clapper sticks hinged above a black slate. The slate is filled in by hand in white chalk: printed field names SCENE, TAKE, ROLL, DATE, DIRECTOR and CAMERA, with the handwritten entries 7, 2, B and 12/31/99 and two scribbled initials. Seen at a slight angle. No other text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T04:22:20.606805648Z
- Original: `sticker-regeneration-redo/originals/video_clap_board-1.png`, 1367 × 1151 PNG, sha256 `689aa6811aa9cc57d5226d9abf406fe96d260847426bf3140f3054dfad0d0b7b`
- Shipped: 512 × 504 WebP, 189,982 bytes, sha256 `5cca3fdce1ce822b4b5d1663a65aaf7db489a293a3ed15977d7e6cdbe3865cbd`

### `vintage_tv_test_pattern.webp`

a small portable television from the late 1990s or early 2000s in blue and silver plastic, not wood, with a telescoping antenna, a speaker grille and a row of round buttons below the screen, showing a classic colour-bar test pattern. No brand name or text.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:52:59.327776765Z
- Original: `sticker-regeneration-redo/originals/vintage_tv_test_pattern-2.png`, 1305 × 1206 PNG, sha256 `022c74602e7a9356a01eb11e289c35424f851a342a8b15275e6363b4b50a9a0a`
- Shipped: 501 × 512 WebP, 159,404 bytes, sha256 `63cf69d5d0b24936463c3c27d49f16bd1ebac1252c62f49626903c72878992b2`

### `vinyl_record.webp`

a black vinyl LP record with fine visible grooves and a plain pastel-orange centre label with no writing, seen at a slight angle. No sleeve or turntable.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:44:50.223576538Z
- Original: `sticker-regeneration-full/originals/vinyl_record-2.png`, 1536 × 1024 PNG, sha256 `8ee8cf11ed50754a84a79abb43d2913d71479bcf0c530b95d25b48eca61e3c82`
- Shipped: 512 × 451 WebP, 148,166 bytes, sha256 `20a1930eaddc98634016372b4ee703d2b12df38c11ce18fc9687d3aeaefe775f`

### `vr_headset.webp`

a cheap white plastic virtual-reality headset for smartphones, with its hinged front flap open to show the slot where a phone slides in, two round lenses, soft grey face foam and a black elastic head strap. It must not copy any real product's design; no logos or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T09:53:15.671412989Z
- Original: `sticker-regeneration-new/originals/vr_headset-1.png`, 1536 × 1024 PNG, sha256 `1d25db1545ee1011d081080d3dd075e756699d37a8c196fdd3d1ac865b33048a`
- Shipped: 512 × 352 WebP, 99,960 bytes, sha256 `ea7bf45d34c3d2c8988ea3d5acd7c09eb8104679d02379e12dcfc1b2fff9433b`

### `wave_pool.webp`

a small rectangular blue plastic swimming pool with a metal ladder at one end, filled with water whipped into one big curling ocean wave with white foam crashing inside it. No people, text or signs.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T04:53:37.388078910Z
- Original: `sticker-regeneration-redo/originals/wave_pool-2.png`, 1774 × 887 PNG, sha256 `50ab89eb023e8cb8cb396789efccef002b52e64516576d01f30d5b9103ca76fa`
- Shipped: 512 × 264 WebP, 94,094 bytes, sha256 `bedaf5366d668b4a3285401a1e202b78feef54cd3e0da94a1ddcd4420f1bd3e2`

### `wet_wipes.webp`

an open soft pack of wet wipes in pale mint-green plastic, its white flip-top lid open and one white wipe pulled halfway out. No logo, text or illustrations.

- Style B, attempt 2 of 2
- Generated: 2026-11-12T10:22:09.408075565Z
- Original: `sticker-regeneration-new/originals/wet_wipes-2.png`, 1536 × 1024 PNG, sha256 `babf6b123215b10d5c4a050551bc353997151dbaca5ffc430ec73197fa27a466`
- Shipped: 512 × 370 WebP, 103,932 bytes, sha256 `486e84686454884e1cba36c8ff87a24b8487425138ee1463ec6b611d5ecd98fa`

### `whey_protein.webp`

a large round plastic tub of whey protein powder as sold in a supermarket, with a black screw lid, seen from the front at a slight angle. The label is an invented design in metallic dark red, with the words WHEY PROTEIN in big bold black condensed capitals with a white outline. Only those two words, spelled exactly; no other text, numbers, nutrition panel, people or design that resembles a real brand.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T11:37:33.138727305Z
- Original: `sticker-regeneration-new2/originals/whey_protein-1.png`, 1122 × 1402 PNG, sha256 `953e7ce77f6d67ecb3d0075717cd55922c2f1d053815d23cc2295ee91048ef78`
- Shipped: 357 × 512 WebP, 134,894 bytes, sha256 `6c5ceb6500fc05be241c5c20cdf6820394de74107fd738afced15ac289c3f9c0`

### `wireless_earbuds.webp`

a pair of generic wireless earbuds sitting in their open charging case, seen from a front three-quarter angle, in the translucent candy-coloured plastic of turn-of-the-millennium consumer electronics: a rounded, slightly bulbous clamshell case in glossy frosted translucent blue plastic with a band of opaque white plastic around its rim, its lid flipped up on a hinge, and its small battery and circuit board faintly visible through the blue; inside it two earbuds in the same translucent blue, rounded and compact without stems, with white silicone ear tips and their tiny inner parts faintly visible. It must not copy any real brand's design: not white with long stems, not a black pill-shaped case, not a colourless clear case; no logos, letters, numbers or text.

- Style B, attempt 1 of 2
- Generated: 2026-11-12T13:51:30.652959311Z
- Original: `sticker-regeneration-new5/originals/wireless_earbuds-1.png`, 1312 × 1199 PNG, sha256 `be714cd0ed9e1e5eb66e3756b9522274039fc393c03b0d4d8c7ef75c3fe0ef3b`
- Shipped: 512 × 491 WebP, 157,902 bytes, sha256 `237edf45cbb33202f947ed14bb56cb8441c003034f5746d2d7e548febded4e59`

### `x.webp`

a big bold X made of two thick crossing bars of glossy red acrylic with rounded ends, shown as a physical object with visible thickness.

- Style A, attempt 2 of 2
- Generated: 2026-11-11T21:45:44.046284885Z
- Original: `sticker-regeneration-full/originals/x-2.png`, 1263 × 1246 PNG, sha256 `6e929bf3e06089343e3eb46cb5d53ef5d27fd09aeac372dac39cd9b4866c02b2`
- Shipped: 510 × 512 WebP, 128,176 bytes, sha256 `8afe3242f332059a52384612542a53cce6bfb68b8634e010093fa72282133abd`
