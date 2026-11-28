#include "worker_lifetime.h"
#include <tlhelp32.h>
#include <string>
#include <utility>

namespace divine_media {
namespace {
struct Handle {
  HANDLE value;
  ~Handle() { if (value && value != INVALID_HANDLE_VALUE) CloseHandle(value); }
};
bool IsChild(DWORD pid) {
  Handle snapshot{CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)};
  if (snapshot.value == INVALID_HANDLE_VALUE) return false;
  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(entry);
  if (!Process32FirstW(snapshot.value, &entry)) return false;
  do {
    if (entry.th32ProcessID == pid) return entry.th32ParentProcessID == GetCurrentProcessId();
  } while (Process32NextW(snapshot.value, &entry));
  return false;
}
}  // namespace

WorkerLifetime::WorkerLifetime(std::filesystem::path expected)
    : expected_(std::move(expected)) {
  Handle candidate{CreateJobObjectW(nullptr, nullptr)};
  if (!candidate.value) return;
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
  limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if (!SetInformationJobObject(candidate.value, JobObjectExtendedLimitInformation,
                              &limits, sizeof(limits))) return;
  job_ = candidate.value;
  candidate.value = nullptr;
}

WorkerLifetime::~WorkerLifetime() {
  if (job_) CloseHandle(job_);
}

bool WorkerLifetime::Claim(DWORD pid) {
  if (!job_ || pid == 0 || pid == GetCurrentProcessId()) return false;
  Handle process{OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION |
      PROCESS_SET_QUOTA | PROCESS_TERMINATE, FALSE, pid)};
  if (!process.value || !IsChild(pid)) return false;
  std::wstring image(32768, L'\0');
  DWORD size = static_cast<DWORD>(image.size());
  if (!QueryFullProcessImageNameW(process.value, 0, image.data(), &size)) return false;
  image.resize(size);
  std::error_code error;
  if (!std::filesystem::equivalent(image, expected_, error) || error) return false;
  return AssignProcessToJobObject(job_, process.value) != FALSE;
}
}  // namespace divine_media
