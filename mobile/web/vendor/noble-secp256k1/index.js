/*! noble-secp256k1 - MIT License (c) 2019 Paul Miller (paulmillr.com) */
/**
 * 5KB JS implementation of secp256k1 ECDSA / Schnorr signatures & ECDH.
 * Compliant with RFC6979 & BIP340.
 * @module
 */
/**
 * Curve params from SEC 2 v2 §2.4.1.
 * secp256k1 is a short Weierstrass / Koblitz curve with equation
 * `y² == x³ + ax + b`.
 * * P = `2n**256n - 2n**32n - 977n` // field over which calculations are done
 * * N = `2n**256n - 0x14551231950b75fc4402da1732fc9bebfn` // group order, amount of curve points
 * * h = `1n` // cofactor
 * * a = `0n` // equation param
 * * b = `7n` // equation param
 * * Gx, Gy are coordinates of Generator / base point
 */
const freeze = Object.freeze;
const P = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2fn;
const N = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141n;
const Gx = 0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798n;
const Gy = 0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8n;
// Mirror noble-curves: Point.CURVE() returns shared params, but those params must stay frozen so
// callers cannot mutate them out from under the arithmetic constants captured below.
const secp256k1_CURVE = freeze({
    p: P,
    n: N,
    h: 1n,
    a: 0n,
    b: 7n,
    Gx,
    Gy,
});
// 32-byte field / scalar width, and the SHA-256 / HMAC-DRBG output width used
// by the RFC6979 paths here.
const L = 32;
// Helpers and Precomputes sections are reused between libraries
// ## Helpers
// ----------
/** Checks if something is Uint8Array. Be careful: nodejs Buffer will return true. */
const isBytes = (a) => {
    // Plain `instanceof Uint8Array` is too strict for some Buffer / proxy / cross-realm cases.
    // The fallback still requires a real ArrayBuffer view, so plain
    // JSON-deserialized `{ constructor: ... }` spoofing is rejected, and
    // `BYTES_PER_ELEMENT === 1` keeps the fallback on byte-oriented views.
    return (a instanceof Uint8Array ||
        (ArrayBuffer.isView(a) &&
            a.constructor.name === 'Uint8Array' &&
            a.BYTES_PER_ELEMENT === 1));
};
/** Asserts something is Uint8Array. */
const abytes = (value, length, title = '') => {
    // Success path first: this runs at the start of every update() / digestInto(), and the
    // common `abytes(data)` form must not pay for length handling it does not use.
    if (isBytes(value) && (length === undefined || value.length === length))
        return value;
    // Error path: recompute freely to build the exact message.
    const bytes = isBytes(value);
    const ofLen = length !== undefined ? ` of length ${length}` : '';
    const got = bytes ? `length=${value.length}` : `type=${typeof value}`;
    const message = (title ? `"${title}" ` : '') + 'expected Uint8Array' + ofLen + ', got ' + got;
    if (!bytes)
        throw new TypeError(message);
    throw new RangeError(message);
};
// Signing can retain the message across hash callbacks / awaits, and Schnorr hashes it more than
// once. Take one owned snapshot so caller mutation cannot change the signing transcript.
// cloneBytes expects an already-validated view; snapshotBytes validates, then copies.
const cloneBytes = (value) => Uint8Array.from(value);
const snapshotBytes = (value, title, length) => cloneBytes(abytes(value, length, title));
// Callers keep values non-negative and within the requested width; padStart() won't truncate over-wide inputs.
const padh = (n, pad) => n.toString(16).padStart(pad, '0');
/** Convert byte array to hex string. */
const bytesToHex = (bytes) => {
    let hex = '';
    for (const byte of abytes(bytes))
        hex += padh(byte, 2);
    return hex;
};
/** Convert hex string to byte array. */
const hexToBytes = (hex) => {
    const e = 'hex invalid'; // Strict ASCII hex only, with one generic error for parse failures.
    if (typeof hex !== 'string')
        throw new TypeError(e);
    if (hex.length % 2 || !/^[\da-f]*$/i.test(hex))
        throw new RangeError(e);
    const array = new Uint8Array(hex.length / 2);
    for (let ai = 0, hi = 0; ai < array.length; ai++, hi += 2) {
        const n1 = hex.charCodeAt(hi);
        const n2 = hex.charCodeAt(hi + 1);
        // Regex guarantees ASCII. For 0..9/A..F/a..f, this maps char codes to 0..15.
        array[ai] = ((n1 & 15) + (n1 >> 6) * 9) * 16 + (n2 & 15) + (n2 >> 6) * 9;
    }
    return array;
};
// WebCrypto is available in all modern environments
const subtle = () => {
    const s = globalThis?.crypto?.subtle;
    if (s)
        return s;
    throw new Error('crypto.subtle must be defined, consider polyfill');
};
/** Copies several Uint8Arrays into one. */
const concatBytes = (...arrays) => {
    let sum = 0;
    for (const a of arrays)
        sum += abytes(a).length;
    const res = new Uint8Array(sum);
    let pad = 0;
    for (const a of arrays) {
        res.set(a, pad);
        pad += a.length;
    }
    return res;
};
/**
 * WebCrypto OS-level CSPRNG (random number generator).
 * Will throw when not available; large-request ceilings are delegated to getRandomValues().
 */
const randomBytes = (len = L) => {
    const c = globalThis?.crypto;
    if (typeof c?.getRandomValues !== 'function')
        throw new Error('crypto.getRandomValues must be defined, consider polyfill');
    return c.getRandomValues(new Uint8Array(len));
};
const big = BigInt;
const arange = (n, min, max, msg = 'bad number: out of range') => {
    if (typeof n !== 'bigint')
        throw new TypeError(msg);
    if (min <= n && n < max)
        return n;
    throw new RangeError(msg);
};
/** Canonical modular reduction. Callers must provide a positive modulus. */
const M = (a, b = P) => ((a %= b) >= 0n ? a : b + a);
const modN = (a) => M(a, N);
/** Modular inversion using extended euclidean GCD. Variable-time (non-CT). */
const invert = (number, modulo) => {
    if (number === 0n)
        throw new Error('invert: expected non-zero number');
    // modulo = 1 is the zero ring: gcd(x, 1) = 1 makes the loop below "succeed" and return the
    // useless inverse 0. Reject it.
    if (modulo <= 1n)
        throw new Error('invert: expected modulus > 1, got ' + modulo);
    // This is variable-time: the loop count depends on `number`.
    let a = M(number, modulo);
    let b = modulo;
    // Only the Bézout coefficient of `number` (x/u chain) is tracked; the coefficient of `modulo`
    // never affects the output, so it is not computed.
    // prettier-ignore
    let x = 0n, u = 1n;
    while (a !== 0n) {
        const q = b / a;
        const r = b - a * q;
        const m = x - u * q;
        // prettier-ignore
        b = a, a = r, x = u, u = m;
    }
    const gcd = b;
    if (gcd !== 1n)
        throw new Error('invert: does not exist');
    return M(x, modulo);
};
const _hash = (name) => {
    // @ts-ignore
    const fn = hashes[name];
    if (typeof fn !== 'function')
        throw new Error('hashes.' + name + ' not set');
    return fn;
};
// All exported provider slots are caller-configurable and may be unset or return arbitrary values,
// so wrapper helpers must enforce the exact 32-byte digest contract instead of trusting providers.
const callHash = (name, a, b) => abytes(_hash(name)(a, b), L, 'digest');
const callHashAsync = async (name, a, b) => abytes(await _hash(name)(a, b), L, 'digest');
/**
 * SHA-256 helper used by the synchronous API.
 * @param msg - message bytes to hash
 * @returns 32-byte SHA-256 digest.
 * @example
 * Hash message bytes after wiring the synchronous SHA-256 implementation.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * import { sha256 } from '@noble/hashes/sha2.js';
 * secp.hashes.sha256 = sha256;
 * const digest = secp.hash(new Uint8Array([1, 2, 3]));
 * ```
 */
// Public helper validates the message boundary explicitly; the configured provider is still looked
// up dynamically and its output is checked with `gh(...)`.
const hash = (msg) => callHash('sha256', abytes(msg, undefined, 'message'));
// also rejects structurally similar Point values from other realms / bundled copies
const apoint = (p) => {
    if (p instanceof Point)
        return p;
    throw new TypeError('Point expected');
};
// ## End of Helpers
// -----------------
const E_BADPOINT = 'bad point: not on curve';
/**
 * secp256k1 formula. Koblitz curves are subclass of weierstrass curves with a=0,
 * making it x³+b; callers validate x first.
 */
const koblitz = (x) => M(M(x * x) * x + 7n);
/** assert is element of field mod P (incl. 0 for projective infinity coordinates) */
const FpIsValid = (n) => arange(n, 0n, P);
/** assert is element of field mod P (excl. 0 where current callers need a non-zero coordinate) */
const FpIsValidNot0 = (n) => arange(n, 1n, P);
/** assert is element of field mod N (excl. 0), matching the shared BIP340 scalar-failure rule used here.
 * There is deliberately no FnIsValid: no caller accepts the scalar 0. */
const FnIsValidNot0 = (n) => arange(n, 1n, N);
// Shared parity primitive for BIP340 even-y checks and SEC 1 compressed prefixes.
const isEven = (y) => !(y & 1n);
/** SEC 1 compressed-prefix helper. Parity only: callers validate y before asking for the prefix byte. */
const getPrefix = (y) => Uint8Array.of(isEven(y) ? 0x02 : 0x03);
/** lift_x from BIP340 returns the unique point with x and an even square root of x³+7.
 * SEC 1 callers still negate it for the odd-prefix branch. */
const lift_x = (x) => {
    // Let c = x³ + 7 mod p. Fail if x ≥ p. (also fail if x < 1)
    const c = koblitz(FpIsValidNot0(x));
    // r = √c candidate
    // r = c^((p+1)/4) mod p
    // This formula works for fields p = 3 mod 4 -- a special, fast case.
    // Paper: "Square Roots from 1;24,51,10 to Dan Shanks".
    let r = 1n;
    for (let num = c, e = (P + 1n) / 4n; e > 0n; e >>= 1n) {
        // powMod: modular exponentiation.
        if (e & 1n)
            r = (r * num) % P; // Uses exponentiation by squaring.
        num = (num * num) % P; // Not constant-time.
    }
    if (M(r * r) !== c)
        throw new Error('sqrt invalid'); // check if result is valid
    return new Point(x, isEven(r) ? r : M(-r), 1n);
};
/**
 * Point in 3d xyz projective coordinates. 3d takes less inversions than 2d.
 * @param X - X coordinate.
 * @param Y - Y coordinate.
 * @param Z - projective Z coordinate.
 * @example
 * Do point arithmetic with the base point and encode the result as hex.
 * ```ts
 * import { Point } from '@noble/secp256k1';
 * const hex = Point.BASE.double().toHex();
 * ```
 */
class Point {
    static BASE;
    static ZERO;
    X;
    Y;
    Z;
    constructor(X, Y, Z) {
        this.X = FpIsValid(X);
        this.Y = FpIsValidNot0(Y); // Y can't be 0 in Projective
        this.Z = FpIsValid(Z);
        freeze(this);
    }
    /** Returns the shared curve metadata object by reference.
     * It is readonly only at type level, and mutating it won't retarget arithmetic,
     * which already uses module-load snapshots. */
    static CURVE() {
        return secp256k1_CURVE;
    }
    /** Create 3d xyz point from 2d xy. (0, 0) => (0, 1, 0), not (0, 0, 1) */
    static fromAffine(ap) {
        const { x, y } = ap;
        return x === 0n && y === 0n ? I : new Point(x, y, 1n);
    }
    /** Convert Uint8Array or hex string to Point. */
    static fromBytes(bytes) {
        abytes(bytes);
        const length = bytes.length;
        const head = bytes[0];
        const x = sliceBytesNumBE(bytes, 1, 33);
        // SEC 1 defines the rare infinity encoding 0x00, but SEC 1 public-key validation rejects
        // infinity. We keep 0x00 rejected here because this parser is reused by verify(), ECDH,
        // and public-key validation helpers, so strict handling applies to all callers by default.
        // Local secp256k1 crosstests show OpenSSL raw point codecs accept 0x00 too.
        // Parse and validate SEC 1 compressed/uncompressed encodings before returning.
        try {
            if (length === 33 && (head === 0x02 || head === 0x03)) {
                // Equation is y² == x³ + ax + b. We calculate y from x.
                // lift_x() returns the even point; SEC 1 0x03 still needs the odd point.
                const p = lift_x(x);
                return head === 0x03 ? p.negate() : p;
            }
            // Uncompressed 65-byte point, 0x04 prefix
            if (length === 65 && head === 0x04)
                return new Point(x, sliceBytesNumBE(bytes, 33, 65), 1n).assertValidity();
        }
        catch (error) {
            // Out-of-range coordinates and non-residue x report the same error as wrong
            // prefixes / off-curve points, instead of generic range-check messages.
            throw new Error(E_BADPOINT);
        }
        throw new Error(E_BADPOINT);
    }
    static fromHex(hex) {
        return Point.fromBytes(hexToBytes(hex));
    }
    get x() {
        return this.toAffine().x;
    }
    get y() {
        return this.toAffine().y;
    }
    /** Equality check: compare points P&Q. */
    equals(other) {
        const { X: X1, Y: Y1, Z: Z1 } = this;
        const { X: X2, Y: Y2, Z: Z2 } = apoint(other); // checks class equality
        return M(X1 * Z2) === M(X2 * Z1) && M(Y1 * Z2) === M(Y2 * Z1);
    }
    is0() {
        return this.Z === 0n;
    }
    /** Flip point over y coordinate. */
    negate() {
        return new Point(this.X, M(-this.Y), this.Z);
    }
    /** Point doubling: P+P, complete formula. */
    double() {
        return this.add(this);
    }
    /**
     * Point addition: P+Q, complete, exception-free formula
     * (Renes-Costello-Batina, algo 1 of [2015/1060](https://eprint.iacr.org/2015/1060)).
     * Cost: `12M + 0S + 3*a + 3*b3 + 23add`.
     */
    // prettier-ignore
    add(other) {
        const { X: X1, Y: Y1, Z: Z1 } = this;
        const { X: X2, Y: Y2, Z: Z2 } = apoint(other);
        const a = 0n;
        const b = 7n;
        let X3 = 0n, Y3 = 0n, Z3 = 0n;
        const b3 = M(b * 3n);
        let t0 = M(X1 * X2), t1 = M(Y1 * Y2), t2 = M(Z1 * Z2), t3 = M(X1 + Y1); // step 1
        let t4 = M(X2 + Y2); // step 5
        t3 = M(t3 * t4);
        t4 = M(t0 + t1);
        t3 = M(t3 - t4);
        t4 = M(X1 + Z1);
        let t5 = M(X2 + Z2); // step 10
        t4 = M(t4 * t5);
        t5 = M(t0 + t2);
        t4 = M(t4 - t5);
        t5 = M(Y1 + Z1);
        X3 = M(Y2 + Z2); // step 15
        t5 = M(t5 * X3);
        X3 = M(t1 + t2);
        t5 = M(t5 - X3);
        Z3 = M(a * t4);
        X3 = M(b3 * t2); // step 20
        Z3 = M(X3 + Z3);
        X3 = M(t1 - Z3);
        Z3 = M(t1 + Z3);
        Y3 = M(X3 * Z3);
        t1 = M(t0 + t0); // step 25
        t1 = M(t1 + t0);
        t2 = M(a * t2);
        t4 = M(b3 * t4);
        t1 = M(t1 + t2);
        t2 = M(t0 - t2); // step 30
        t2 = M(a * t2);
        t4 = M(t4 + t2);
        t0 = M(t1 * t4);
        Y3 = M(Y3 + t0);
        t0 = M(t5 * t4); // step 35
        X3 = M(t3 * X3);
        X3 = M(X3 - t0);
        t0 = M(t3 * t1);
        Z3 = M(t5 * Z3);
        Z3 = M(Z3 + t0); // step 40
        return new Point(X3, Y3, Z3);
    }
    subtract(other) {
        return this.add(apoint(other).negate());
    }
    /**
     * Point-by-scalar multiplication. Scalar must be in range 1 <= n < CURVE.n.
     * Uses {@link wNAF} for base point.
     * Uses fake point to mitigate leakage shape in JS, not as a hard constant-time guarantee.
     * @param n scalar by which point is multiplied
     * @param safe safe mode guards against timing attacks; unsafe mode is faster
     */
    multiply(n, safe = true) {
        // Unsafe internal callers may legitimately need 0*P = O during double-scalar multiplication.
        if (!safe && n === 0n)
            return I;
        FnIsValidNot0(n);
        if (n === 1n)
            return this;
        if (this.equals(G))
            return wNAF(n).p;
        // init result point & fake point
        let p = I;
        let f = G;
        let d = this;
        // Safe mode always runs 256 iterations so ladder length can't leak the scalar's
        // leading zero bits; unsafe mode stops at the top set bit for speed.
        for (let i = 0; safe ? i < 256 : n > 0n; i++) {
            // if bit is present, add to point
            // if not present, add to fake, for timing safety
            if (n & 1n)
                p = p.add(d);
            else if (safe)
                f = f.add(d);
            d = d.double();
            n >>= 1n;
        }
        return p;
    }
    multiplyUnsafe(scalar) {
        return this.multiply(scalar, false);
    }
    /** Convert point to 2d xy affine point. (X, Y, Z) ∋ (x=X/Z, y=Y/Z) */
    toAffine() {
        const { X: x, Y: y, Z: z } = this;
        // fast-paths for ZERO point OR Z=1
        if (z === 0n)
            return { x: 0n, y: 0n };
        if (z === 1n)
            return { x, y };
        const iz = invert(z, P);
        // (Z * Z^-1) must be 1, otherwise bad math
        if (M(z * iz) !== 1n)
            throw new Error('inverse invalid');
        // x = X*Z^-1; y = Y*Z^-1
        return { x: M(x * iz), y: M(y * iz) };
    }
    /** Checks if the point is valid and on-curve. */
    assertValidity() {
        const { x, y } = this.toAffine(); // convert to 2d xy affine point.
        FpIsValidNot0(x); // must be in range 1 <= x,y < P
        FpIsValidNot0(y);
        // y² == x³ + ax + b, equation sides must be equal
        if (M(y * y) !== koblitz(x))
            throw new Error(E_BADPOINT);
        return this;
    }
    /** Converts point to 33/65-byte Uint8Array. */
    toBytes(isCompressed = true) {
        // Same policy as fromBytes(): SEC 1 has the rare infinity encoding 0x00, but we keep ZERO
        // out of this byte surface because callers treat these encodings as public keys by default.
        const { x, y } = this.assertValidity().toAffine();
        const x32b = numTo32b(x);
        if (isCompressed)
            return concatBytes(getPrefix(y), x32b);
        return concatBytes(Uint8Array.of(0x04), x32b, numTo32b(y));
    }
    toHex(isCompressed) {
        return bytesToHex(this.toBytes(isCompressed));
    }
}
/** Generator / base point */
const G = new Point(Gx, Gy, 1n);
/** Identity / zero point */
const I = new Point(0n, 1n, 0n);
// Static aliases
Point.BASE = G;
Point.ZERO = I;
/** `Q = u1⋅G + u2⋅R`. Verifies Q is not ZERO. Unsafe: non-CT. */
const doubleScalarMulUns = (R, u1, u2) => {
    return G.multiply(u1, false).add(R.multiply(u2, false)).assertValidity();
};
// Inherits byte validation from bytesToHex(); the || '0' fallback keeps empty input mapped to 0n.
const bytesToNumBE = (b) => big('0x' + (bytesToHex(b) || '0'));
// Callers provide monotone slice bounds; subarray() would otherwise clamp or reinterpret them silently.
const sliceBytesNumBE = (b, from, to) => bytesToNumBE(b.subarray(from, to));
/** Generic 32-byte big-endian encoder. Must be 0 <= num < 2²⁵⁶; call sites need not be field/scalar elements. */
const numTo32b = (num) => hexToBytes(padh(arange(num, 0n, 2n ** 256n), L * 2)); // L*2 = 64 hex chars for a zero-padded 32-byte value
/** Normalize private key to scalar (bigint). Verifies scalar is in range 1 <= d < N. */
const secretKeyToScalar = (secretKey) => {
    const num = bytesToNumBE(abytes(secretKey, L, 'secret key'));
    return arange(num, 1n, N, 'invalid secret key: outside of range');
};
/** For signature malleability, checks the strict upper-half predicate s > floor(N/2). */
const highS = (n) => n > N >> 1n;
// Recovery id of an affine nonce point: bit 0 is y parity, bit 1 is x = r + n.
const getRecoveryBit = (x, y, r) => (x === r ? 0 : 2) | Number(y & 1n);
/**
 * Creates a SEC 1 public key from a 32-byte private key.
 * @param privKey - 32-byte secret key.
 * @param isCompressed - return 33-byte compressed SEC 1 encoding when `true`, otherwise 65-byte uncompressed.
 * @returns serialized secp256k1 public key in SEC 1 encoding.
 * @example
 * Derive the serialized public key for a secp256k1 secret key.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * const secretKey = secp.utils.randomSecretKey();
 * const publicKey = secp.getPublicKey(secretKey);
 * ```
 */
const getPublicKey = (privKey, isCompressed = true) => {
    return G.multiply(secretKeyToScalar(privKey)).toBytes(isCompressed);
};
const isValidSecretKey = (secretKey) => {
    try {
        return !!secretKeyToScalar(secretKey);
    }
    catch (error) {
        return false;
    }
};
const isValidPublicKey = (publicKey, isCompressed) => {
    try {
        const l = publicKey.length;
        if (isCompressed === true && l !== 33)
            return false;
        if (isCompressed === false && l !== 65)
            return false;
        return !!Point.fromBytes(publicKey);
    }
    catch (error) {
        return false;
    }
};
const assertRecoveryBit = (recovery) => {
    if (recovery != null && [0, 1, 2, 3].includes(recovery))
        return recovery;
    throw new Error('invalid recovery id');
};
const assertSigFormat = (format) => {
    if (format === 'der')
        throw new Error('Signature format "der" is not supported: switch to noble-curves');
    if (format != null && format !== SIG_COMPACT && format !== SIG_RECOVERED)
        throw new Error('Signature format must be one of: compact, recovered, der');
};
const assertSigLength = (sig, format = SIG_COMPACT) => {
    assertSigFormat(format);
    const bytes = abytes(sig, undefined, 'signature');
    const len = 64 + Number(format === SIG_RECOVERED);
    if (bytes.length !== len)
        throw new Error(`Signature format "${format}" expects Uint8Array with length ${len}`);
    return bytes;
};
/**
 * ECDSA Signature class. Supports only compact 64-byte representation, not DER.
 * @param r - signature `r` scalar.
 * @param s - signature `s` scalar.
 * @param recovery - optional recovery id.
 * @example
 * Build a recovered-format signature object and serialize it.
 * ```ts
 * import { Signature } from '@noble/secp256k1';
 * const bytes = new Signature(1n, 2n, 0).toBytes('recovered');
 * ```
 */
class Signature {
    r;
    s;
    recovery;
    constructor(r, s, recovery) {
        this.r = FnIsValidNot0(r); // 1 <= r < N
        this.s = FnIsValidNot0(s); // 1 <= s < N
        // Keep recovered Signature objects internally consistent across all construction paths.
        if (recovery != null)
            this.recovery = assertRecoveryBit(recovery);
        freeze(this);
    }
    static fromBytes(b, format = SIG_COMPACT) {
        b = assertSigLength(b, format);
        let rec;
        if (format === SIG_RECOVERED) {
            rec = b[0];
            b = b.subarray(1);
        }
        const r = sliceBytesNumBE(b, 0, L);
        const s = sliceBytesNumBE(b, L, 64);
        return new Signature(r, s, rec);
    }
    addRecoveryBit(bit) {
        return new Signature(this.r, this.s, bit);
    }
    hasHighS() {
        return highS(this.s);
    }
    toBytes(format = SIG_COMPACT) {
        // Standalone noble-secp256k1 does not implement DER; reject here so direct Signature users
        // don't silently get compact bytes for an unsupported format.
        assertSigFormat(format);
        const { r, s, recovery } = this;
        const res = concatBytes(numTo32b(r), numTo32b(s));
        if (format === SIG_RECOVERED) {
            return concatBytes(Uint8Array.of(assertRecoveryBit(recovery)), res);
        }
        return res;
    }
}
/**
 * RFC6979: ensure ECDSA msg is X bytes, convert to BigInt.
 * RFC 6979 §2.3.2 says bits2int keeps the leftmost qlen bits and discards the rest.
 * FIPS 186-4 4.6 gives the same leftmost-bit truncation rule. bits2int can produce res>N.
 */
// The 8 KiB cap is only a local DoS guard. Longer ordinary prehashes must still follow
// RFC 6979 §2.3.2 truncation instead of being rejected just because blen > qlen.
const MAX_PREHASHED_BYTES = 8192;
const E_MSGBIG = 'input is too large';
const oversizedMsg = (bytes, prehash) => !prehash && bytes.length > MAX_PREHASHED_BYTES;
const bits2int = (bytes) => {
    if (oversizedMsg(bytes))
        throw new Error(E_MSGBIG);
    const delta = bytes.length * 8 - 256;
    const num = bytesToNumBE(bytes);
    return delta > 0 ? num >> big(delta) : num;
};
/** int2octets can't be used; pads small msgs with 0: BAD for truncation as per RFC vectors */
const bits2int_modN = (bytes) => modN(bits2int(abytes(bytes)));
// Async entry points snapshot the message before their first await. An oversized prehash is
// rejected before the copy, so an attacker-controlled view is never cloned just to fail in
// bits2int().
const snapshotMsg = (message, prehash) => {
    const view = abytes(message, undefined, 'message');
    if (oversizedMsg(view, prehash))
        throw new Error(E_MSGBIG);
    return cloneBytes(view);
};
const SIG_COMPACT = 'compact';
const SIG_RECOVERED = 'recovered';
const _sha = 'SHA-256';
/**
 * Hash implementations used by the synchronous and async ECDSA / Schnorr helpers.
 * All slots are configurable API surface; wrapper helpers revalidate that SHA-256 and HMAC-SHA256
 * providers still return exact 32-byte Uint8Array digests.
 * @example
 * Provide sync hash helpers before calling the synchronous signing API.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * import { hmac } from '@noble/hashes/hmac.js';
 * import { sha256 } from '@noble/hashes/sha2.js';
 * secp.hashes.sha256 = sha256;
 * secp.hashes.hmacSha256 = (key, msg) => hmac(sha256, key, msg);
 * const secretKey = secp.utils.randomSecretKey();
 * const sig = secp.sign(new Uint8Array([1, 2, 3]), secretKey);
 * ```
 */
const hashes = {
    hmacSha256Async: async (key, message) => {
        const s = subtle();
        const k = await s.importKey('raw', key, { name: 'HMAC', hash: _sha }, false, ['sign']);
        return new Uint8Array(await s.sign('HMAC', k, message));
    },
    hmacSha256: undefined,
    sha256Async: async (msg) => new Uint8Array(await subtle().digest(_sha, msg)),
    sha256: undefined,
};
// prehash=false means the caller already supplies the digest bytes
// used by sign/verify/recover, and this helper returns the same reference unchanged.
const prepMsg = (msg, prehash, async_) => {
    const message = abytes(msg, undefined, 'message');
    if (!prehash)
        return message;
    return async_ ? callHashAsync('sha256Async', message) : callHash('sha256', message);
};
const NULL = /* @__PURE__ */ new Uint8Array(0);
const byte0 = /* @__PURE__ */ Uint8Array.of(0x00);
const byte1 = /* @__PURE__ */ Uint8Array.of(0x01);
const _drbgErr = 'drbg: tried max amount of iterations';
// HMAC-DRBG from NIST 800-90. Minimal, non-full-spec - used for RFC6979 signatures.
const hmacDrbg = (seed, pred) => {
    let v = new Uint8Array(L); // Steps B, C of RFC6979 3.2: set hashLen
    let k = new Uint8Array(L); // In our case, it's always equal to L
    let i = 0; // Iterations counter, will throw when over max
    const reset = () => {
        v.fill(1);
        k.fill(0);
    };
    // h = hmac(k || v || ...). The configured provider is still checked on every call because the
    // exported slot can be replaced or unset at runtime.
    const h = (...b) => callHash('hmacSha256', k, concatBytes(v, ...b));
    const reseed = (seed = NULL) => {
        // HMAC-DRBG reseed() function. Steps D-G
        k = h(byte0, seed); // k = hmac(k || v || 0x00 || seed)
        v = h(); // v = hmac(k || v)
        if (seed.length === 0)
            return;
        k = h(byte1, seed); // k = hmac(k || v || 0x01 || seed)
        v = h(); // v = hmac(k || v)
    };
    // HMAC-DRBG generate() function
    const gen = () => {
        if (i++ >= 1000)
            throw new Error(_drbgErr);
        v = h(); // v = hmac(k || v)
        return v; // One block is enough here because secp256k1 qlen and SHA-256 hlen are both 32 bytes.
    };
    reset();
    reseed(seed); // Steps D-G
    let res = undefined; // Step H: grind until k is in [1..n-1]
    // `pred` receives the live V buffer from gen(); it must treat that input as read-only and
    // return independent bytes, because reset() scrubs the DRBG state before hmacDrbg returns.
    while (!(res = pred(gen())))
        reseed(); // test predicate until it returns ok
    reset();
    return res;
};
// Identical to hmacDrbg, but async: uses built-in WebCrypto
const hmacDrbgAsync = async (seed, pred) => {
    let v = new Uint8Array(L); // Steps B, C of RFC6979 3.2: set hashLen
    let k = new Uint8Array(L); // In our case, it's always equal to L
    let i = 0; // Iterations counter, will throw when over max
    const reset = () => {
        v.fill(1);
        k.fill(0);
    };
    // h = hmac(k || v || ...). Async provider lookup still goes through `callHash(...)` because the
    // exported slot can be replaced or unset at runtime.
    const h = (...b) => callHashAsync('hmacSha256Async', k, concatBytes(v, ...b));
    const reseed = async (seed = NULL) => {
        // HMAC-DRBG reseed() function. Steps D-G
        k = await h(byte0, seed); // k = hmac(k || v || 0x00 || seed)
        v = await h(); // v = hmac(k || v)
        if (seed.length === 0)
            return;
        k = await h(byte1, seed); // k = hmac(k || v || 0x01 || seed)
        v = await h(); // v = hmac(k || v)
    };
    // HMAC-DRBG generate() function
    const gen = async () => {
        if (i++ >= 1000)
            throw new Error(_drbgErr);
        v = await h(); // v = hmac(k || v)
        return v; // Same one-block shortcut: secp256k1 qlen and SHA-256 hlen are both 32 bytes here.
    };
    reset();
    await reseed(seed); // Steps D-G
    let res = undefined; // Step H: grind until k is in [1..n-1]
    // Same contract as sync hmacDrbg(): pred sees the live V buffer and must not mutate or return it.
    while (!(res = pred(await gen())))
        await reseed(); // test predicate until it returns ok
    reset();
    return res;
};
// RFC6979 signature generation, preparation step.
// Follows [SEC1](https://secg.org/sec1-v2.pdf) 4.1.3 & RFC6979.
const _sign = (messageHash, secretKey, opts, drbg) => {
    const [lowS, , format, extraEntropy] = opts; // generates low-s sigs by default
    // RFC6979 3.2: we skip step A
    const h1i = bits2int_modN(messageHash); // msg bigint
    const d = secretKeyToScalar(secretKey); // validate private key, convert to bigint
    const seedArgs = [numTo32b(d), numTo32b(h1i)]; // Step D of RFC6979 3.2
    /** RFC6979 3.6: additional k' (optional). See {@link ECDSAExtraEntropy}. */
    if (extraEntropy != null && extraEntropy !== false) {
        // K = HMAC_K(V || 0x00 || int2octets(x) || bits2octets(h1) || k')
        // gen random bytes OR pass as-is
        seedArgs.push(abytes(extraEntropy === true ? randomBytes(L) : extraEntropy, undefined, 'extraEntropy'));
    }
    // Converts signature params into point w r/s, checks result for validity.
    // To transform k => Signature:
    // q = k⋅G
    // r = q.x mod n
    // s = k^-1(m + rd) mod n
    // Can use scalar blinding b^-1(bm + bdr) where b ∈ [1,q−1] according to
    // https://tches.iacr.org/index.php/TCHES/article/view/7337/6509. We've decided against it:
    // a) dependency on CSPRNG b) 15% slowdown c) doesn't really help since bigints are not CT
    const k2sig = (kBytes) => {
        // RFC 6979 Section 3.2, step 3: k = bits2int(T)
        // Important: all mod() calls here must be done over N
        const k = bits2int(kBytes);
        if (!(1n <= k && k < N))
            return; // Valid scalars (including k) must be in 1..N-1
        const ik = invert(k, N); // k^-1 mod n
        const q = G.multiply(k).toAffine(); // q = k⋅G
        const r = modN(q.x); // r = q.x mod n
        // RFC 6979 §2.4 step 3 / §3.4 only spell out retry for r = 0.
        // FIPS 186-5 §6.4.1 step 11 says deterministic ECDSA should fail on r = 0 or s = 0, but
        // that restart-from-scratch note does not apply here: hmacDrbg() keeps advancing through one
        // RFC6979 stream until k2sig() accepts a candidate, instead of restarting from the same seed.
        if (r === 0n)
            return;
        const s = modN(ik * (h1i + r * d)); // s = k^-1(m + rd) mod n
        if (s === 0n)
            return;
        let recovery = getRecoveryBit(q.x, q.y, r); // recovery bit (2 or 3, when q.x > n)
        let normS = s; // normalized S
        if (lowS && highS(s)) {
            // if lowS was passed, ensure s is always
            normS = N - s; // in the bottom half of CURVE.n
            recovery ^= 1;
        }
        const sig = new Signature(r, normS, recovery); // use normS, not s
        return sig.toBytes(format);
    };
    return drbg(concatBytes(...seedArgs), k2sig);
};
// Follows [SEC1](https://secg.org/sec1-v2.pdf) 4.1.4.
const _verify = (sig, messageHash, publicKey, opts) => {
    const [lowS, , format] = opts;
    if (sig instanceof Signature)
        throw new Error('Signature must be in Uint8Array, use .toBytes()');
    // Deliberately outside the try: wrong-length / wrongly-typed inputs are caller bugs which
    // throw loudly, while only well-formed signatures failing crypto checks return false.
    assertSigLength(sig, format);
    abytes(publicKey, undefined, 'publicKey');
    try {
        const { r, s, recovery } = Signature.fromBytes(sig, format);
        const h = bits2int_modN(messageHash); // Truncate hash
        const Q = Point.fromBytes(publicKey); // Validate public key. Q, not P: P is the field prime
        if (lowS && highS(s))
            return false; // lowS bans sig.s >= CURVE.n/2
        const is = invert(s, N); // s^-1
        // R = u1⋅G + u2⋅Q with u1 = hs^-1, u2 = rs^-1. Identity throws inside doubleScalarMulUns.
        const { x, y } = doubleScalarMulUns(Q, modN(h * is), modN(r * is)).toAffine();
        if (modN(x) !== r)
            return false; // Reduce R.x in N's field, not P's.
        // The recovery byte is part of the recovered signature and must describe this exact R.
        return format !== SIG_RECOVERED || recovery === getRecoveryBit(x, y, r);
    }
    catch (error) {
        return false;
    }
};
// `own` snapshots extraEntropy bytes, for async paths that must not see caller mutation.
const setDefaults = (opts, own = false) => {
    const e = opts.extraEntropy;
    return [
        opts.lowS ?? true,
        opts.prehash ?? true,
        opts.format ?? SIG_COMPACT,
        own && e != null && typeof e !== 'boolean' ? snapshotBytes(e, 'extraEntropy') : e,
    ];
};
/**
 * Sign a message using secp256k1. Sync: uses `hashes.sha256` and `hashes.hmacSha256`.
 * Prehashes message with sha256, disable using `prehash: false`.
 * @param message - message bytes to sign.
 * @param secretKey - 32-byte secret key.
 * @param opts - See {@link ECDSASignOpts} for details. Enabling {@link ECDSAExtraEntropy} improves security.
 * @returns ECDSA signature encoded according to `opts.format`.
 * @example
 * Sign a message using secp256k1.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * import { hmac } from '@noble/hashes/hmac.js';
 * import { sha256 } from '@noble/hashes/sha2.js';
 * secp.hashes.sha256 = sha256;
 * secp.hashes.hmacSha256 = (key, msg) => hmac(sha256, key, msg);
 * const secretKey = secp.utils.randomSecretKey();
 * const msg = new TextEncoder().encode('hello noble');
 * secp.sign(msg, secretKey);
 * secp.sign(msg, secretKey, { extraEntropy: true });
 * secp.sign(msg, secretKey, { format: 'recovered' });
 * ```
 */
const sign = (message, secretKey, opts = {}) => {
    const o = setDefaults(opts);
    assertSigFormat(o[2]);
    const msg = prepMsg(message, o[1], false);
    return _sign(msg, secretKey, o, hmacDrbg);
};
/**
 * Sign a message using secp256k1. Async: uses built-in WebCrypto hashes.
 * Prehashes message with sha256, disable using `prehash: false`.
 * @param message - message bytes to sign.
 * @param secretKey - 32-byte secret key.
 * @param opts - See {@link ECDSASignOpts} for details. Enabling {@link ECDSAExtraEntropy} improves security.
 * @returns ECDSA signature encoded according to `opts.format`.
 * @example
 * Sign a message using secp256k1 with the async WebCrypto path.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * import { keccak_256 } from '@noble/hashes/sha3.js';
 * const secretKey = secp.utils.randomSecretKey();
 * const msg = new TextEncoder().encode('hello noble');
 * await secp.signAsync(msg, secretKey);
 * await secp.signAsync(keccak_256(msg), secretKey, { prehash: false });
 * await secp.signAsync(msg, secretKey, { extraEntropy: true });
 * await secp.signAsync(msg, secretKey, { format: 'recovered' });
 * ```
 */
const signAsync = async (message, secretKey, opts = {}) => {
    const o = setDefaults(opts, true);
    assertSigFormat(o[2]);
    const msgBytes = snapshotMsg(message, o[1]);
    const secretBytes = snapshotBytes(secretKey, 'secret key', L);
    const msg = (await prepMsg(msgBytes, o[1], true));
    return _sign(msg, secretBytes, o, hmacDrbgAsync);
};
/**
 * Verify a signature using secp256k1. Sync: uses `hashes.sha256` and `hashes.hmacSha256`.
 * @param signature - default is 64-byte `compact` format; also see {@link ECDSASignatureFormat}.
 * @param message - message which was signed. Keep in mind `prehash` from opts.
 * @param publicKey - public key that should verify the signature.
 * @param opts - See {@link ECDSAVerifyOpts} for details.
 * @returns `true` when the signature is valid. Malformed inputs — wrong signature length for
 * the chosen format, non-Uint8Array arguments, unsupported format — throw instead of
 * returning `false`. This is intentional, so caller bugs fail loudly; only well-formed
 * signatures failing cryptographic checks return `false`.
 * @example
 * Verify a signature using secp256k1.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * import { hmac } from '@noble/hashes/hmac.js';
 * import { sha256 } from '@noble/hashes/sha2.js';
 * import { keccak_256 } from '@noble/hashes/sha3.js';
 * secp.hashes.sha256 = sha256;
 * secp.hashes.hmacSha256 = (key, msg) => hmac(sha256, key, msg);
 * const secretKey = secp.utils.randomSecretKey();
 * const msg = new TextEncoder().encode('hello noble');
 * const publicKey = secp.getPublicKey(secretKey);
 * const sig = secp.sign(msg, secretKey);
 * const sigr = secp.sign(msg, secretKey, { format: 'recovered' });
 * secp.verify(sig, msg, publicKey);
 * secp.verify(sig, keccak_256(msg), publicKey, { prehash: false });
 * secp.verify(sig, msg, publicKey, { lowS: false });
 * secp.verify(sigr, msg, publicKey, { format: 'recovered' });
 * ```
 */
const verify = (signature, message, publicKey, opts = {}) => {
    const o = setDefaults(opts);
    const msg = prepMsg(message, o[1], false);
    return _verify(signature, msg, publicKey, o);
};
/**
 * Verify a signature using secp256k1. Async: uses built-in WebCrypto hashes.
 * @param sig - default is 64-byte `compact` format; also see {@link ECDSASignatureFormat}.
 * @param message - message which was signed. Keep in mind `prehash` from opts.
 * @param publicKey - public key that should verify the signature.
 * @param opts - See {@link ECDSAVerifyOpts} for details.
 * @returns `true` when the signature is valid. Malformed inputs — wrong signature length for
 * the chosen format, non-Uint8Array arguments, unsupported format — reject instead of
 * resolving `false`. This is intentional, so caller bugs fail loudly; only well-formed
 * signatures failing cryptographic checks resolve to `false`.
 * @example
 * Verify a signature using secp256k1 with the async WebCrypto path.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * import { keccak_256 } from '@noble/hashes/sha3.js';
 * const secretKey = secp.utils.randomSecretKey();
 * const msg = new TextEncoder().encode('hello noble');
 * const publicKey = secp.getPublicKey(secretKey);
 * const sig = await secp.signAsync(msg, secretKey);
 * const sigr = await secp.signAsync(msg, secretKey, { format: 'recovered' });
 * await secp.verifyAsync(sig, msg, publicKey);
 * await secp.verifyAsync(sigr, msg, publicKey, { format: 'recovered' });
 * await secp.verifyAsync(sig, keccak_256(msg), publicKey, { prehash: false });
 * ```
 */
const verifyAsync = async (sig, message, publicKey, opts = {}) => {
    const o = setDefaults(opts);
    const sigView = assertSigLength(sig, o[2]);
    const msgView = abytes(message, undefined, 'message');
    const publicKeyView = abytes(publicKey, undefined, 'publicKey');
    // Reject bounded malformed inputs before copying attacker-controlled views. This also avoids
    // copying a prehashed message that bits2int() would reject immediately.
    if (oversizedMsg(msgView, o[1]) || (publicKeyView.length !== 33 && publicKeyView.length !== 65))
        return false;
    const sigBytes = cloneBytes(sigView);
    const msgBytes = cloneBytes(msgView);
    const publicKeyBytes = cloneBytes(publicKeyView);
    const msg = (await prepMsg(msgBytes, o[1], true));
    return _verify(sigBytes, msg, publicKeyBytes, o);
};
const _recover = (signature, messageHash, isCompressed) => {
    const { r, s, recovery: rec } = Signature.fromBytes(signature, 'recovered');
    // 0 or 1 recovery id determines sign of "y" coordinate.
    // 2 or 3 means q.x was >N.
    const recovery = assertRecoveryBit(rec);
    // SEC 1 recovery derives e through the same truncation path as verification, so prehash:false
    // must accept long digests here too instead of hard-requiring 32-byte SHA-256 input.
    const h = bits2int_modN(messageHash); // Truncate hash; prepMsg() already validated it.
    const radj = recovery > 1 ? r + N : r;
    FpIsValidNot0(radj); // ensure q.x is still a field element
    const ir = invert(radj, N); // r^-1
    // Recovery bit and R.y share parity: even bit => 0x02, odd => 0x03.
    const R = Point.fromBytes(concatBytes(getPrefix(big(recovery)), numTo32b(radj)));
    // (sr^-1)R-(hr^-1)G = -(hr^-1)G + (sr^-1)R
    return doubleScalarMulUns(R, modN(-h * ir), modN(s * ir)).toBytes(isCompressed);
};
/**
 * ECDSA public key recovery. Requires msg hash and recovery id.
 * Follows {@link https://secg.org/sec1-v2.pdf | SEC1} 4.1.6.
 * @param signature - recovered-format signature from `sign(..., { format: 'recovered' })`.
 * @param message - signed message bytes.
 * @param opts - See {@link ECDSARecoverOpts} for details.
 * @returns recovered public key bytes, compressed by default.
 * @example
 * Recover a secp256k1 public key from a recovered-format signature.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * import { hmac } from '@noble/hashes/hmac.js';
 * import { sha256 } from '@noble/hashes/sha2.js';
 * secp.hashes.sha256 = sha256;
 * secp.hashes.hmacSha256 = (key, msg) => hmac(sha256, key, msg);
 * const secretKey = secp.utils.randomSecretKey();
 * const message = new Uint8Array([1, 2, 3]);
 * const sig = secp.sign(message, secretKey, { format: 'recovered' });
 * secp.recoverPublicKey(sig, message);
 * ```
 */
const recoverPublicKey = (signature, message, opts = {}) => {
    const msg = prepMsg(message, setDefaults(opts)[1], false);
    return _recover(signature, msg, opts.isCompressed ?? true);
};
/**
 * Async ECDSA public key recovery. Requires msg hash and recovery id.
 * @param signature - recovered-format signature from `signAsync(..., { format: 'recovered' })`.
 * @param message - signed message bytes.
 * @param opts - See {@link ECDSARecoverOpts} for details.
 * @returns recovered public key bytes, compressed by default.
 * @example
 * Recover a secp256k1 public key from a recovered-format signature with the async API.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * const secretKey = secp.utils.randomSecretKey();
 * const message = new Uint8Array([1, 2, 3]);
 * const sig = await secp.signAsync(message, secretKey, { format: 'recovered' });
 * await secp.recoverPublicKeyAsync(sig, message);
 * ```
 */
const recoverPublicKeyAsync = async (signature, message, opts = {}) => {
    const prehash = setDefaults(opts)[1];
    const sigBytes = cloneBytes(assertSigLength(signature, SIG_RECOVERED));
    const msgBytes = snapshotMsg(message, prehash);
    const isCompressed = opts.isCompressed ?? true;
    const msg = (await prepMsg(msgBytes, prehash, true));
    return _recover(sigBytes, msg, isCompressed);
};
/**
 * Elliptic Curve Diffie-Hellman (ECDH) on secp256k1.
 * Result is **NOT hashed** and returns the serialized shared point (compressed by default),
 * not the SEC 1 x-only primitive `z = x_P`.
 * secp256k1 has cofactor `h = 1`, so there is no separate cofactor-ECDH distinction here.
 * @param secretKeyA - local 32-byte secret key.
 * @param publicKeyB - peer public key.
 * @param isCompressed - return 33-byte compressed output when `true`.
 * @returns shared secret point bytes.
 * @example
 * Derive a shared secp256k1 secret with ECDH.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * const alice = secp.utils.randomSecretKey();
 * const bob = secp.utils.randomSecretKey();
 * const shared = secp.getSharedSecret(alice, secp.getPublicKey(bob));
 * ```
 */
const getSharedSecret = (secretKeyA, publicKeyB, isCompressed = true) => {
    return Point.fromBytes(publicKeyB).multiply(secretKeyToScalar(secretKeyA)).toBytes(isCompressed);
};
// FIPS 186-5 Appendix A.4.1 style key generation reduces a wide random integer mod (n - 1) and adds 1.
// The 48-byte minimum keeps the secp256k1 bias bound below the appendix's epsilon <= 2^-64 target.
const randomSecretKey = (seed) => {
    seed = seed === undefined ? randomBytes(48) : seed;
    abytes(seed);
    // Keep the public range text aligned with the enforced 48-byte FIPS floor.
    if (seed.length < 48 || seed.length > 1024)
        throw new RangeError('expected 48-1024b');
    const num = M(bytesToNumBE(seed), N - 1n);
    return numTo32b(num + 1n);
};
const createKeygen = (getPublicKey) => (seed) => {
    const secretKey = randomSecretKey(seed);
    return { secretKey, publicKey: getPublicKey(secretKey) };
};
/**
 * Generates a secp256k1 keypair.
 * @param seed - optional entropy seed.
 * @returns keypair with `secretKey` and `publicKey`.
 * @example
 * Generate a secp256k1 keypair for sync signing.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * import { hmac } from '@noble/hashes/hmac.js';
 * import { sha256 } from '@noble/hashes/sha2.js';
 * secp.hashes.sha256 = sha256;
 * secp.hashes.hmacSha256 = (key, msg) => hmac(sha256, key, msg);
 * const { secretKey, publicKey } = secp.keygen();
 * ```
 */
const keygen = /* @__PURE__ */ createKeygen(getPublicKey);
/**
 * Math, hex, byte helpers. Not in `utils` because utils share API with noble-curves.
 * @example
 * Convert bytes to a hex string with the low-level helper namespace.
 * ```ts
 * import { etc } from '@noble/secp256k1';
 * const hex = etc.bytesToHex(new Uint8Array([1, 2, 3]));
 * ```
 */
const etc = /* @__PURE__ */ freeze({
    hexToBytes,
    bytesToHex,
    concatBytes,
    bytesToNumberBE: bytesToNumBE,
    numberToBytesBE: numTo32b,
    mod: M,
    invert,
    randomBytes,
    secretKeyToScalar,
    abytes,
});
/**
 * Curve-specific key utilities.
 * @example
 * Generate a fresh secret key and derive its public key.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * const secretKey = secp.utils.randomSecretKey();
 * const publicKey = secp.getPublicKey(secretKey);
 * ```
 */
const utils = /* @__PURE__ */ freeze({
    isValidSecretKey,
    isValidPublicKey,
    randomSecretKey,
});
// Schnorr signatures are superior to ECDSA from above. Below is Schnorr-specific BIP0340 code.
// https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki
// Internal BIP340 tag names are ASCII-only here, so charCodeAt() is enough; this is not a general UTF-8 encoder.
const getTag = (tag) => Uint8Array.from('BIP0340/' + tag, (c) => c.charCodeAt(0));
// Both SHA-256 provider slots are configurable, so tag hashing still goes through the checked
// wrappers even though the built-in defaults are deterministic and the tag bytes are ASCII-only.
const taggedHash = (tag, ...messages) => {
    const tagH = callHash('sha256', getTag(tag));
    return callHash('sha256', concatBytes(tagH, tagH, ...messages));
};
// Async twin of taggedHash with the same checked provider boundary.
const taggedHashAsync = (tag, ...messages) => callHashAsync('sha256Async', getTag(tag)).then((tagH) => callHashAsync('sha256Async', concatBytes(tagH, tagH, ...messages)));
// BIP340 PubKey(sk) = bytes(d'⋅G), where bytes(P) is bytes(x(P)); signing also normalizes
// d to the equivalent scalar whose point has even y so the x-only public key stays canonical.
const extpubSchnorr = (priv) => {
    const d_ = secretKeyToScalar(priv);
    const p = G.multiply(d_); // P = d'⋅G; 0 < d' < n check is done inside
    const { x, y } = p.assertValidity().toAffine(); // validate Point is not at infinity
    const d = isEven(y) ? d_ : modN(-d_);
    const px = numTo32b(x);
    return { d, px };
};
const bytesModN = (bytes) => modN(bytesToNumBE(bytes));
const challenge = (...args) => bytesModN(taggedHash('challenge', ...args));
const challengeAsync = async (...args) => bytesModN(await taggedHashAsync('challenge', ...args));
/** Schnorr public key is just `x` coordinate of Point as per BIP340. */
const pubSchnorr = (secretKey) => {
    return extpubSchnorr(secretKey).px; // d'=int(sk). Fail if d'=0 or d'≥n. Ret bytes(d'⋅G)
};
const keygenSchnorr = /* @__PURE__ */ createKeygen(pubSchnorr);
// Common preparation fn for both sync and async signing
const prepSigSchnorr = (message, secretKey, auxRand) => {
    const m = snapshotBytes(message, 'message');
    const { px, d } = extpubSchnorr(secretKey);
    return { m, px, d, a: abytes(auxRand, L) };
};
const extractK = (rand) => {
    const k_ = bytesModN(rand); // Let k' = int(rand) mod n
    if (k_ === 0n)
        throw new Error('sign failed: k is zero'); // Fail if k' = 0.
    const { px, d } = extpubSchnorr(numTo32b(k_)); // Let R = k'⋅G.
    return { rx: px, k: d };
};
// Common signature creation helper
const createSigSchnorr = (k, px, e, d) => {
    return concatBytes(px, numTo32b(modN(k + e * d)));
};
const E_INVSIG = 'invalid signature produced';
/**
 * Creates Schnorr signature as per BIP340. Verifies itself before returning anything.
 * auxRand is optional and defaults to fresh 32-byte randomness; it is not the sole source of
 * k generation, so bad CSPRNG won't be the only entropy source.
 */
const signSchnorr = (message, secretKey, auxRand = randomBytes(L)) => {
    const { m, px, d, a } = prepSigSchnorr(message, secretKey, auxRand);
    // Let t be the byte-wise xor of bytes(d) and hash/aux(a)
    const t = numTo32b(d ^ bytesToNumBE(taggedHash('aux', a)));
    // Let rand = hash/nonce(t || bytes(P) || m)
    const { rx, k } = extractK(taggedHash('nonce', t, px, m));
    // Let e = int(hash/challenge(bytes(R) || bytes(P) || m)) mod n.
    const sig = createSigSchnorr(k, rx, challenge(rx, px, m), d);
    // If Verify(bytes(P), m, sig) (see below) returns failure, abort
    if (!verifySchnorr(sig, m, px))
        throw new Error(E_INVSIG);
    return sig;
};
const signSchnorrAsync = async (message, secretKey, auxRand = randomBytes(L)) => {
    const { m, px, d, a } = prepSigSchnorr(message, secretKey, auxRand);
    // Let t be the byte-wise xor of bytes(d) and hash/aux(a)
    const t = numTo32b(d ^ bytesToNumBE(await taggedHashAsync('aux', a)));
    // Let rand = hash/nonce(t || bytes(P) || m)
    const { rx, k } = extractK(await taggedHashAsync('nonce', t, px, m));
    // Let e = int(hash/challenge(bytes(R) || bytes(P) || m)) mod n.
    const sig = createSigSchnorr(k, rx, await challengeAsync(rx, px, m), d);
    // If Verify(bytes(P), m, sig) (see below) returns failure, abort
    if (!(await verifySchnorrAsync(sig, m, px)))
        throw new Error(E_INVSIG);
    return sig;
};
const callSyncAsyncFn = (res, later) => {
    return res instanceof Promise ? res.then(later) : later(res);
};
const _verifSchnorr = (signature, message, publicKey, challengeFn) => {
    const sig = abytes(signature, 64, 'signature');
    const msg = abytes(message, undefined, 'message');
    const pub = abytes(publicKey, L, 'publicKey');
    let P_;
    let r;
    let s;
    let chalInput; // challenge preimage bytes(r) || bytes(P) || m
    try {
        // lift_x from BIP340. Convert 32-byte x coordinate to elliptic curve point.
        // Fail if x ≥ p. Let c = x³ + 7 mod p.
        const x = bytesToNumBE(pub);
        P_ = lift_x(x); // lift_x returns the validated even-y point required by BIP340.
        // P = lift_x(int(pk)); fail if that fails
        r = FpIsValidNot0(sliceBytesNumBE(sig, 0, L)); // Let r = int(sig[0:32]); fail if r ≥ p.
        // Let s = int(sig[32:64]); fail if s ≥ n.
        // Stricter than BIP-340/libsecp256k1, which only reject s >= n. Honest signing reaches
        // s = 0 only with negligible probability (k + e*d ≡ 0 mod n), so treat zero-s inputs as
        // crafted edge cases and fail closed instead of carrying that extra verification surface.
        s = FnIsValidNot0(sliceBytesNumBE(sig, L, 64));
        // lift_x validated x < P, so the 32-byte input encoding equals bytes(P.x) exactly.
        chalInput = concatBytes(numTo32b(r), pub, msg);
    }
    catch (error) {
        return false;
    }
    // Hash-provider errors (unset hashes.sha256, missing crypto.subtle, bad provider digests)
    // stay outside the catch above: backend misconfiguration is not an "invalid signature"
    // result, so it throws / rejects instead of becoming false.
    // int(challenge(bytes(r)||bytes(P)||m))%n
    return callSyncAsyncFn(challengeFn(chalInput), (e) => {
        try {
            const { x, y } = doubleScalarMulUns(P_, s, modN(-e)).toAffine(); // R = s⋅G - e⋅P
            if (!isEven(y) || x !== r)
                return false; // -eP == (n-e)P
            return true; // Fail if is_infinite(R) / not has_even_y(R) / x(R) ≠ r.
        }
        catch (error) {
            return false; // is_infinite(R) throws inside doubleScalarMulUns
        }
    });
};
/** Verifies Schnorr signature. Invalid points, scalars and failed curve checks return false;
 * hash-backend misconfiguration (e.g. unset hashes.sha256) throws instead, since it is a
 * runtime/backend error, not an "invalid signature" result. */
const verifySchnorr = (s, m, p) => _verifSchnorr(s, m, p, challenge);
/** Async Schnorr verification. Curve/encoding failures after the initial byte checks still
 * become false, but async backend failures reject the promise. Missing crypto.subtle is a
 * runtime/backend error, not an "invalid signature" result, so we surface it instead of
 * turning it into false. */
const verifySchnorrAsync = async (s, m, p) => _verifSchnorr(s, m, p, challengeAsync);
/**
 * BIP340 Schnorr helpers over secp256k1.
 * @example
 * Sign and verify a BIP340 Schnorr signature.
 * ```ts
 * import * as secp from '@noble/secp256k1';
 * import { sha256 } from '@noble/hashes/sha2.js';
 * secp.hashes.sha256 = sha256;
 * const secretKey = secp.utils.randomSecretKey();
 * const message = new Uint8Array([1, 2, 3]);
 * const sig = secp.schnorr.sign(message, secretKey);
 * const publicKey = secp.schnorr.getPublicKey(secretKey);
 * const isValid = secp.schnorr.verify(sig, message, publicKey);
 * ```
 */
const schnorr = /* @__PURE__ */ freeze({
    keygen: keygenSchnorr,
    getPublicKey: pubSchnorr,
    sign: signSchnorr,
    verify: verifySchnorr,
    signAsync: signSchnorrAsync,
    verifyAsync: verifySchnorrAsync,
});
// ## Precomputes
// --------------
const precompute = () => {
    const points = [];
    let p = G;
    let b = p;
    for (let w = 0; w < 33; w++) {
        b = p;
        points.push(b);
        for (let i = 1; i < 128; i++) {
            b = b.add(p);
            points.push(b);
        } // i=1, bc we skip 0
        p = b.double();
    }
    return points;
};
let Gpows = undefined; // precomputes for base point G
// Branch-shaped negate helper for wNAF; not a hard constant-time primitive in JavaScript.
const ctneg = (cnd, p) => {
    const n = p.negate();
    return cnd ? n : p;
};
/**
 * Precomputes give 12x faster getPublicKey(), 10x sign(), 2x verify() by
 * caching multiples of G (base point). Cache is stored in 32MB of RAM.
 * Any time `G.multiply` is done, precomputes are used.
 * Not used for getSharedSecret, which instead multiplies random pubkey `P.multiply`.
 *
 * w-ary non-adjacent form (wNAF) precomputation method is 10% slower than windowed method,
 * but takes 2x less RAM. RAM reduction is possible by utilizing `.subtract`.
 *
 * !! Precomputes can be disabled by commenting-out call of the wNAF() inside Point#multiply().
 */
const wNAF = (n) => {
    const comp = Gpows || (Gpows = precompute());
    let p = I;
    let f = G; // f must be G, or could become I in the end
    for (let w = 0; w < 33; w++) {
        let wbits = Number(n & 255n); // extract W=8 bits.
        n >>= 8n; // shift number by W=8 bits.
        // We use negative indexes to reduce size of precomputed table by 2x.
        // Instead of needing precomputes 0..256, we only calculate them for 0..128.
        // If an index > 128 is found, we do (256-index) - where 256 is next window.
        // Naive: index +127 => 127, +224 => 224
        // Optimized: index +127 => 127, +224 => 256-32
        if (wbits > 128) {
            wbits -= 256;
            n += 1n;
        }
        const off = w * 128;
        const offP = off + Math.abs(wbits) - 1;
        const isOddW = w % 2 !== 0; // conditions, evaluate both; alternates fake-add sign per window
        const isNeg = wbits < 0;
        if (wbits === 0) {
            // off == I: can't add it. Add the first point in this window to the fake accumulator.
            f = f.add(ctneg(isOddW, comp[off])); // bits are 0: add garbage to fake point
        }
        else {
            p = p.add(ctneg(isNeg, comp[offP])); // bits are 1: add to result point
        }
    }
    if (n !== 0n)
        throw new Error('invalid wnaf');
    return { p, f }; // return both real and fake points for JIT/leakage-shape symmetry
};
/** Test-only surface for shared noble test suites. Not part of the public API. */
export const __TEST = /* @__PURE__ */ freeze({
    // Shared tests expect the BIP340 helper to expose the canonical even-y point, not just the root.
    lift_x: lift_x,
    extractK: extractK,
});
// !! Remove the export below to easily use in REPL / browser console
export { etc, getPublicKey, getSharedSecret, hash, hashes, keygen, Point, recoverPublicKey, recoverPublicKeyAsync, schnorr, sign, signAsync, Signature, utils, verify, verifyAsync, };
