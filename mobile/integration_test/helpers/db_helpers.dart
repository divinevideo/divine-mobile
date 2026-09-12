// ABOUTME: Database helpers for E2E integration tests
// ABOUTME: Query and manipulate keycast postgres for auth flow testing

import 'package:material_ui/material_ui.dart';
import 'package:postgres/postgres.dart';

import 'constants.dart';

/// Helper to open a connection to keycast postgres.
Future<Connection> _openKeycastConnection() async {
  return Connection.open(
    Endpoint(
      host: localHost,
      port: pgPort,
      database: 'keycast',
      username: 'postgres',
      password: 'password',
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
}

/// The plaintext 6-digit PIN the e2e types into the verification screen.
///
/// keycast stores PINs bcrypt-hashed and never surfaces the plaintext, so the
/// test seeds a KNOWN hash ([knownPinHash]) instead of trying to read the real
/// one, then types this value. keycast still verifies it for real through
/// `/api/headless/verify-pin`.
const knownPin = '123456';

/// A real bcrypt hash of [knownPin] (`123456`, cost 12).
///
/// Written into `oauth_codes.pin_hash` by [seedKnownPin]. The cost is encoded
/// in the hash, so keycast's bcrypt verify reads it back regardless of the
/// cost keycast itself uses when issuing PINs.
const knownPinHash =
    r'$2b$12$zmj2GR8M0AJVKHSLtnE.SumQqxgVumEcPLqi5oN0mdW6KXZQW2Df6';

/// Seed a known PIN for [email] so the e2e can type [knownPin].
///
/// Sets `oauth_codes.pin_hash` to [knownPinHash] and resets `pin_attempts` on
/// the most recent pending row for [email]. Mirrors the DB access the token
/// helper uses — no keycast prod changes, no mail-catcher. Requires a keycast
/// image that has the verify-pin migration (keycast#262 / `keycast:262-local`).
/// Retries because the row may not be written immediately after registration.
Future<void> seedKnownPin(
  String email, {
  int retries = 10,
  Duration delay = const Duration(seconds: 2),
}) async {
  for (var i = 0; i < retries; i++) {
    try {
      final conn = await _openKeycastConnection();
      try {
        final result = await conn.execute(
          Sql.named(
            'UPDATE oauth_codes '
            'SET pin_hash = @pinHash, pin_attempts = 0 '
            'WHERE id = ('
            '  SELECT id FROM oauth_codes '
            '  WHERE pending_email = @email '
            '  ORDER BY created_at DESC '
            '  LIMIT 1)',
          ),
          parameters: {'pinHash': knownPinHash, 'email': email},
        );
        if (result.affectedRows > 0) {
          debugPrint('seedKnownPin: seeded PIN for $email');
          return;
        }
      } finally {
        await conn.close();
      }
    } catch (e) {
      debugPrint('seedKnownPin attempt ${i + 1} failed: $e');
    }

    if (i < retries - 1) {
      await Future<void>.delayed(delay);
    }
  }

  throw Exception(
    'Failed to seed known PIN for $email after $retries retries',
  );
}

/// Query the email verification token from local keycast postgres.
///
/// Connects to postgres via the host-mapped port (15432) from the Android
/// emulator using 10.0.2.2 (emulator -> host loopback).
/// Retries up to [retries] times with [delay] since the token may not be
/// written immediately after registration.
Future<String> getVerificationToken(
  String email, {
  int retries = 10,
  Duration delay = const Duration(seconds: 2),
}) async {
  for (var i = 0; i < retries; i++) {
    try {
      final conn = await _openKeycastConnection();

      try {
        final result = await conn.execute(
          Sql.named(
            'SELECT pending_email_verification_token '
            'FROM oauth_codes '
            'WHERE pending_email = @email '
            'AND pending_email_verification_token IS NOT NULL '
            'ORDER BY created_at DESC '
            'LIMIT 1',
          ),
          parameters: {'email': email},
        );

        if (result.isNotEmpty) {
          final token = result.first[0]! as String;
          if (token.isNotEmpty) return token;
        }
      } finally {
        await conn.close();
      }
    } catch (e) {
      debugPrint('Verification token query attempt ${i + 1} failed: $e');
    }

    if (i < retries - 1) {
      await Future<void>.delayed(delay);
    }
  }

  throw Exception(
    'Failed to get verification token for $email after $retries retries',
  );
}

/// Query the password reset token from local keycast postgres.
///
/// The reset token is stored in the `users` table (not `oauth_codes`).
/// Retries up to [retries] times with [delay] since the token may not be
/// written immediately after requesting a reset.
Future<String> getPasswordResetToken(
  String email, {
  int retries = 10,
  Duration delay = const Duration(seconds: 2),
}) async {
  for (var i = 0; i < retries; i++) {
    try {
      final conn = await _openKeycastConnection();

      try {
        final result = await conn.execute(
          Sql.named(
            'SELECT password_reset_token '
            'FROM users '
            'WHERE email = @email '
            'AND password_reset_token IS NOT NULL '
            'LIMIT 1',
          ),
          parameters: {'email': email},
        );

        if (result.isNotEmpty) {
          final token = result.first[0]! as String;
          if (token.isNotEmpty) return token;
        }
      } finally {
        await conn.close();
      }
    } catch (e) {
      debugPrint('Reset token query attempt ${i + 1} failed: $e');
    }

    if (i < retries - 1) {
      await Future<void>.delayed(delay);
    }
  }

  throw Exception(
    'Failed to get password reset token for $email after $retries retries',
  );
}

/// Consume all refresh tokens for a user so they cannot be used.
///
/// Sets consumed_at = NOW() on all unconsumed refresh tokens belonging to
/// the user's authorizations. Returns the number of rows affected.
Future<int> consumeAllRefreshTokens(String userPubkey) async {
  final conn = await _openKeycastConnection();
  try {
    final result = await conn.execute(
      Sql.named(
        'UPDATE oauth_refresh_tokens ort '
        'SET consumed_at = NOW() '
        'FROM oauth_authorizations oa '
        'WHERE ort.authorization_id = oa.id '
        'AND oa.user_pubkey = @pubkey '
        'AND ort.consumed_at IS NULL',
      ),
      parameters: {'pubkey': userPubkey},
    );
    debugPrint(
      'consumeAllRefreshTokens: consumed ${result.affectedRows} '
      'tokens for $userPubkey',
    );
    return result.affectedRows;
  } finally {
    await conn.close();
  }
}

/// Get the user's pubkey hex from their email address.
///
/// Looks up the user in keycast's users table by email.
Future<String?> getUserPubkeyByEmail(String email) async {
  final conn = await _openKeycastConnection();
  try {
    final result = await conn.execute(
      Sql.named(
        'SELECT pubkey FROM users WHERE email = @email LIMIT 1',
      ),
      parameters: {'email': email},
    );
    if (result.isNotEmpty) {
      return result.first[0] as String?;
    }
    return null;
  } finally {
    await conn.close();
  }
}

/// Refresh token record from the `oauth_refresh_tokens` table.
class RefreshTokenRecord {
  const RefreshTokenRecord({
    required this.id,
    required this.createdAt,
    required this.expiresAt,
    this.consumedAt,
  });

  final int id;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? consumedAt;

  bool get isConsumed => consumedAt != null;
  bool get isValid => !isConsumed && expiresAt.isAfter(DateTime.now());
}

/// Query all refresh tokens for a user identified by their Nostr pubkey.
///
/// Joins `oauth_refresh_tokens` with `oauth_authorizations` to find tokens
/// belonging to the given pubkey. Returns records ordered by creation time
/// (newest first).
///
/// Retries up to [retries] times with [delay] since the token row may not
/// be written immediately after the OAuth flow completes.
Future<List<RefreshTokenRecord>> getRefreshTokenRecords(
  String userPubkey, {
  int retries = 10,
  Duration delay = const Duration(seconds: 2),
}) async {
  for (var i = 0; i < retries; i++) {
    try {
      final conn = await _openKeycastConnection();

      try {
        final result = await conn.execute(
          Sql.named(
            'SELECT ort.id, ort.created_at, ort.expires_at, ort.consumed_at '
            'FROM oauth_refresh_tokens ort '
            'JOIN oauth_authorizations oa '
            '  ON ort.authorization_id = oa.id '
            'WHERE oa.user_pubkey = @pubkey '
            'ORDER BY ort.created_at DESC',
          ),
          parameters: {'pubkey': userPubkey},
        );

        if (result.isNotEmpty) {
          return result.map((row) {
            return RefreshTokenRecord(
              id: row[0]! as int,
              createdAt: row[1]! as DateTime,
              expiresAt: row[2]! as DateTime,
              consumedAt: row[3] as DateTime?,
            );
          }).toList();
        }
      } finally {
        await conn.close();
      }
    } catch (e) {
      debugPrint('Refresh token query attempt ${i + 1} failed: $e');
    }

    if (i < retries - 1) {
      await Future<void>.delayed(delay);
    }
  }

  return [];
}
