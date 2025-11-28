
# Device-Reality Requirements for QA Testing in diVine
### Technical Rationale, Testing Boundaries, and Hardware-Specific Constraints

## 1. Purpose of This Document

This document explains why QA testing for **diVine**, a Nostr-native short-video application, must be conducted on real iOS and Android hardware. It outlines the technical limitations of emulators, specifies which test classes are safe to complete in emulator environments, and details the hardware-dependent behaviors that require physical devices.

This is intended for the full QA and engineering team, with a technical appendix at the end for developers who need system-level detail.

---

# 2. Overview: Why Hardware Matters for diVine

diVine integrates:

- Real-time camera capture  
- Hardware-accelerated video encoding (H.264/HEVC)  
- Device-secured private key management  
- Local caching (SQLite)  
- Relay publishing and network-dependent media uploads  
- GPU-accelerated UI  
- OS-level backgrounding and scheduling constraints  

Because these systems interact directly with physical hardware, **emulators cannot simulate the conditions under which the app must operate in production**. Emulators are appropriate only for basic UI and static-flow validation.

---

# 3. Emulator Limitations Relevant to diVine

## 3.1 Camera and Sensor Behavior Cannot Be Simulated
Emulators provide only mock camera streams. They cannot reproduce:

- Lens-specific properties (wide, ultrawide, telephoto)  
- Autofocus cycles  
- Exposure behavior  
- Motion/handshake response  
- Sensor noise characteristics  
- Frame timing under variable lighting  

Since diVine’s primary function is recording short-form video, this limitation makes emulator-based testing insufficient for any video capture scenario.

---

## 3.2 Hardware Video Encoding and Playback Are Not Emulated
Hardware encoding and decoding pipelines differ significantly across devices and include:

- CPU/GPU co-processing  
- Hardware video encoders  
- HEVC vs. H.264 codec differences  
- Frame dropping and bitrate adjustments  
- Thermal throttling of the encoder  
- Memory and bandwidth constraints  

Emulators bypass these layers entirely, producing encoding behavior that does not reflect real-world device performance, especially on mid-range or older Android devices.

---

## 3.3 Real Networking, Bandwidth, and Backgrounding Behavior
Critical workflows in diVine rely on real hardware interactions:

- Uploading media files to Blossom  
- Publishing Nostr events  
- Retrying uploads after suspension  
- Handling OS-imposed background limits  
- Managing low-memory or low-battery states  
- Dealing with real device network transitions (Wi-Fi → LTE → 3G → loss → regain)  

Emulators operate under stable, desktop-controlled networking and cannot surface these production failure modes.

---

## 3.4 Secure Key Management Depends on Hardware
Nostr identity in diVine uses:

- iOS Secure Enclave + Keychain  
- Android Keystore (hardware-backed when available)  
- Encrypted local storage  
- Optional biometric flows  

Emulators do not support:

- Secure enclave-backed key storage  
- Hardware-bound signing  
- Biometric prompts  
- Cryptographic key persistence behaviors  
- Platform-specific key isolation guarantees  

Testing identity flows on emulators yields unreliable results.

---

## 3.5 Performance, Thermal, and Memory Limitations
Hardware variability is one of the most important factors in diVine’s real-world performance. Emulator environments mask:

- device-level RAM constraints  
- rendering performance differences  
- thermal shutdown and throttling  
- garbage collection pressure differences  
- GPU frame drop behavior  

Testing only on emulators often results in a build that appears stable until deployed, where it fails on lower-end consumer hardware.

---

# 4. What CAN Be Tested on Emulators

Only the following classes of behavior are appropriate for emulator testing:

### User Interface
- Basic navigation  
- Non-media UI layouts  
- Light/dark mode consistency  
- Localization text checks  

### Non-Media Nostr Operations
- Fetching user metadata  
- Simple text-only Nostr note publishing  
- Basic relay connectivity without file attachments  

### Static Screen States
- Error dialogs  
- Placeholder screens  
- Non-interactive flows  

### Login Flows Without Hardware Keys
- Extension-based login  
- Username/password or test-account flows  
- Mocked network authentication  

---

# 5. What CANNOT Be Tested on Emulators

The following categories must be executed on real hardware:

### Camera & Media Pipeline
- Camera initialization  
- Video recording and playback  
- Photo/video permissions  
- Stabilization and lens handling  
- Exposure and motion response  

### Video Encoding & Rendering
- H.264/HEVC encoder behavior  
- GPU-accelerated video playback  
- Dropped frames  
- Thermal throttling impacts  

### Media Upload & Blossom Integration
- Upload reliability  
- Rate limiting and retry flows  
- Background upload constraints  

### Key Management
- Keychain/Keystore generation  
- Secure-enclave-backed signing  
- Key persistence  
- Biometric authentication  

### Performance & Stress Testing
- Multi-minute recording  
- Rapid switching between capture and playback  
- Network transition behavior  
- Memory pressure and cleanup  

---

# 6. Summary

Emulators are valuable for quick UI verification and functional smoke tests, but they are fundamentally unsuitable for validating the reliability, performance, and user experience of a hardware-dependent, video-first application such as diVine.

To ensure correctness and production readiness, **all video capture, media processing, cryptographic identity, and performance testing must be carried out on physical iOS and Android devices.**

---

# Appendix A: Technical Considerations for Developers

## A.1 Camera Implementations
Flutter relies on native camera APIs:

- `AVCaptureSession` on iOS  
- `CameraX` / legacy `Camera` on Android  

Both are sensitive to:
- lens switching  
- device-specific focus modes  
- OS-level camera restrictions  
- sensor availability  
- frame rate variability  

Emulators implement none of these.

---

## A.2 Codec-Level Behavior
Real devices differ by:

- OEM-specific HEVC tuning  
- differing hardware accelerators (Qualcomm, Samsung, Apple)  
- thermal dissipation and throttling  
- capture-to-encoder buffer size  

Emulators use desktop codecs that do not reflect device constraints.

---

## A.3 Network Stack Behavior
Real hardware encounters:

- transient loss  
- slow uploads under carrier throttling  
- variable DNS resolution  
- OS-managed sleep transitions  
- radio power-saving modes  

Emulators operate under stable host-level networking not representative of mobile environments.

---

## A.4 Secure Key Management
Hardware-backed key storage differs by platform:

### iOS  
- Secure Enclave  
- Keychain accessibility classes  
- biometric policies  
- local vs. iCloud key persistence  

### Android  
- Hardware-backed Keystore  
- StrongBox (when available)  
- biometric prompt integrations  
- OEM-level variations in Keystore implementation  

Emulators do not support hardware-backed cryptography and often fall back to insecure software keystores.

---

## A.5 Performance and Rendering
Flutter leverages Skia and platform GPU pipelines. In production hardware, rendering is gated by:

- GPU thread contention  
- thermal throttling  
- memory pressure  
- camera+GPU simultaneous load  

Desktop-based GPU simulation in emulators masks these behaviors, producing misleading results.

---

## A.6 Relay and Event Publishing
Real devices introduce:

- intermittent connectivity  
- variances in WebSocket stability  
- background WebSocket handling differences (iOS suspends aggressively)  
- timing issues for media upload + event publish coordination  

These are core to diVine’s reliability and cannot be replicated in emulator environments.
