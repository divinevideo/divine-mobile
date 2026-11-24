#ifndef DIVINE_PRIVATE_CAPTURE_FILE_H_
#define DIVINE_PRIVATE_CAPTURE_FILE_H_

#include <gio/gio.h>
#include <glib/gstdio.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <cstdio>

// A completed capture may leave its operation directory. Its own permissions
// must therefore remain private after rename or a caller-requested copy.
inline FILE* OpenPrivateCaptureFile(const char* path, GError** error) {
  const int descriptor = g_open(path,
      O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0600);
  if (descriptor < 0) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
        "Capture output could not be opened");
    return nullptr;
  }
  if (fchmod(descriptor, 0600) != 0) {
    close(descriptor);
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
        "Capture output permissions could not be secured");
    return nullptr;
  }
  FILE* file = fdopen(descriptor, "wb");
  if (!file) {
    close(descriptor);
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED,
        "Capture output writer could not be opened");
  }
  return file;
}

#endif  // DIVINE_PRIVATE_CAPTURE_FILE_H_
