// ABOUTME: MIME type of a local audio file, from the extension of its name.

import 'package:path/path.dart' as p;

/// MIME type of the audio file named [path], judged by its extension, or
/// `null` for an extension the app neither imports nor writes.
///
/// Draft-local audio is published by uploading its file, and the upload names
/// the file's type; the name is the only record of it the app keeps.
String? audioMimeTypeForPath(String path) =>
    switch (p.extension(path).toLowerCase()) {
      '.aac' => 'audio/aac',
      '.m4a' => 'audio/mp4',
      '.mp3' => 'audio/mpeg',
      '.wav' => 'audio/wav',
      '.weba' || '.webm' => 'audio/webm',
      _ => null,
    };
