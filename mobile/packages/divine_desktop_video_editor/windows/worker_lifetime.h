#ifndef DIVINE_MEDIA_WORKER_LIFETIME_H_
#define DIVINE_MEDIA_WORKER_LIFETIME_H_
#include <windows.h>
#include <filesystem>

namespace divine_media {
// Owns only verified children started by this app from the installed helper.
// Closing the job terminates remaining encoders, including after app failure.
class WorkerLifetime {
 public:
  explicit WorkerLifetime(std::filesystem::path expected);
  ~WorkerLifetime();
  WorkerLifetime(const WorkerLifetime&) = delete;
  WorkerLifetime& operator=(const WorkerLifetime&) = delete;
  bool Claim(DWORD pid);
 private:
  std::filesystem::path expected_;
  HANDLE job_ = nullptr;
};
}  // namespace divine_media
#endif
