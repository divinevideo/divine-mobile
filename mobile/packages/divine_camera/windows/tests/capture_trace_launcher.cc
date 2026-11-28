// Test tooling only: a trace and its children belong to one kill-on-close job.
#include <windows.h>

#include <cstdint>
#include <cstdio>
#include <cwchar>
#include <string>
#include <vector>

namespace {
struct Handle {
  HANDLE value = nullptr;
  ~Handle() { Close(); }
  void Close() {
    if (value && value != INVALID_HANDLE_VALUE) CloseHandle(value);
    value = nullptr;
  }
};

struct Process {
  PROCESS_INFORMATION info{};
  ~Process() {
    if (info.hThread) CloseHandle(info.hThread);
    if (info.hProcess) CloseHandle(info.hProcess);
  }
};

bool ConfigureJob(Handle& job) {
  job.value = CreateJobObjectW(nullptr, nullptr);  // Never inheritable.
  if (!job.value) return false;
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
  limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  return SetInformationJobObject(job.value, JobObjectExtendedLimitInformation,
                                &limits, sizeof(limits)) != FALSE;
}

bool StartChild(const std::vector<std::wstring>& arguments, HANDLE job,
                HANDLE ready, Process& process) {
  std::wstring command;
  for (const auto& argument : arguments) {
    // Only executable paths and fixed tool arguments are accepted. None need
    // embedded quotes or a trailing slash; rejecting them avoids ambiguous CLI.
    if (argument.find(L'"') != std::wstring::npos ||
        (!argument.empty() && argument.back() == L'\\')) return false;
    command += L"\"" + argument + L"\" ";
  }
  SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
  Handle input{CreateFileW(L"NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                           &security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr)};
  Handle output, error;
  const HANDLE current = GetCurrentProcess();
  if (input.value == INVALID_HANDLE_VALUE ||
      !DuplicateHandle(current, GetStdHandle(STD_OUTPUT_HANDLE), current,
                       &output.value, 0, TRUE, DUPLICATE_SAME_ACCESS) ||
      !DuplicateHandle(current, GetStdHandle(STD_ERROR_HANDLE), current,
                       &error.value, 0, TRUE, DUPLICATE_SAME_ACCESS)) return false;
  std::vector<HANDLE> inherited{input.value, output.value, error.value};
  if (ready) inherited.push_back(ready);
  SIZE_T size = 0;
  const DWORD attributes = job ? 2 : 1;
  InitializeProcThreadAttributeList(nullptr, attributes, 0, &size);
  if (size == 0) return false;
  std::vector<BYTE> storage(size);
  STARTUPINFOEXW startup{};
  startup.StartupInfo.cb = static_cast<DWORD>(sizeof(startup));
  startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
  startup.StartupInfo.hStdInput = input.value;
  startup.StartupInfo.hStdOutput = output.value;
  startup.StartupInfo.hStdError = error.value;
  startup.lpAttributeList = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(storage.data());
  if (!InitializeProcThreadAttributeList(startup.lpAttributeList, attributes, 0, &size)) return false;
  bool configured = UpdateProcThreadAttribute(startup.lpAttributeList, 0,
      PROC_THREAD_ATTRIBUTE_HANDLE_LIST, inherited.data(),
      inherited.size() * sizeof(HANDLE), nullptr, nullptr) != FALSE;
  if (configured && job) {
    // Ownership is applied by process creation, before its first instruction.
    configured = UpdateProcThreadAttribute(startup.lpAttributeList, 0,
        PROC_THREAD_ATTRIBUTE_JOB_LIST, &job, sizeof(job), nullptr, nullptr) != FALSE;
  }
  const bool created = configured && CreateProcessW(nullptr, command.data(), nullptr,
      nullptr, TRUE, EXTENDED_STARTUPINFO_PRESENT | CREATE_SUSPENDED, nullptr,
      nullptr, &startup.StartupInfo, &process.info);
  DeleteProcThreadAttributeList(startup.lpAttributeList);
  if (!created) return false;
  if (ResumeThread(process.info.hThread) == static_cast<DWORD>(-1)) {
    TerminateProcess(process.info.hProcess, 2);
    return false;
  }
  return true;
}

std::wstring SelfPath() {
  std::vector<wchar_t> path(32768);
  const DWORD count = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  return count && count < path.size() ? std::wstring(path.data(), count) : L"";
}

int VerifyTreeRelease() {
  Handle job;
  if (!ConfigureJob(job)) return 2;
  SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
  Handle ready{CreateEventW(&security, TRUE, FALSE, nullptr)};
  Process child;
  if (!ready.value || !StartChild({SelfPath(), L"--test-child",
          std::to_wstring(reinterpret_cast<std::uintptr_t>(ready.value))},
          job.value, ready.value, child)) return 3;
  if (WaitForSingleObject(ready.value, 5000) != WAIT_OBJECT_0) return 4;
  alignas(JOBOBJECT_BASIC_PROCESS_ID_LIST)
      BYTE storage[sizeof(JOBOBJECT_BASIC_PROCESS_ID_LIST) + sizeof(ULONG_PTR) * 4]{};
  auto* processes = reinterpret_cast<JOBOBJECT_BASIC_PROCESS_ID_LIST*>(storage);
  if (!QueryInformationJobObject(job.value, JobObjectBasicProcessIdList,
                                 processes, static_cast<DWORD>(sizeof(storage)), nullptr) ||
      processes->NumberOfProcessIdsInList != 2) return 5;
  Handle first{OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                           static_cast<DWORD>(processes->ProcessIdList[0]))};
  Handle second{OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                            static_cast<DWORD>(processes->ProcessIdList[1]))};
  if (!first.value || !second.value) return 6;
  if (WaitForSingleObject(child.info.hProcess, 20) != WAIT_TIMEOUT) return 8;
  job.Close();
  for (HANDLE process : {first.value, second.value}) {
    DWORD code = STILL_ACTIVE;
    if (WaitForSingleObject(process, 5000) != WAIT_OBJECT_0 ||
        !GetExitCodeProcess(process, &code) || code == STILL_ACTIVE) return 7;
  }
  std::puts("DIVINE_CAPTURE_TRACE_TREE_RELEASE_PASS");
  return 0;
}
}  // namespace

int wmain(int argc, wchar_t** argv) {
  if (argc == 2 && std::wstring(argv[1]) == L"--self-test") return VerifyTreeRelease();
  if (argc == 2 && std::wstring(argv[1]) == L"--test-leaf") {
    Sleep(INFINITE);
    return 0;
  }
  if (argc == 3 && std::wstring(argv[1]) == L"--test-child") {
    Process leaf;
    if (!StartChild({SelfPath(), L"--test-leaf"}, nullptr, nullptr, leaf)) return 8;
    const auto value = static_cast<std::uintptr_t>(std::wcstoull(argv[2], nullptr, 10));
    if (!SetEvent(reinterpret_cast<HANDLE>(value))) return 9;
    Sleep(INFINITE);
    return 0;
  }
  if (argc < 2) return 2;
  Handle job;
  Process trace;
  if (!ConfigureJob(job) ||
      !StartChild(std::vector<std::wstring>(argv + 1, argv + argc), job.value, nullptr, trace)) return 2;
  const DWORD waited = WaitForSingleObject(trace.info.hProcess, 30000);
  DWORD code = 124;
  if (waited == WAIT_OBJECT_0) GetExitCodeProcess(trace.info.hProcess, &code);
  // Close on success too: an exited tracer cannot leave a capture child alive
  // holding the parent's stdout/stderr pipes open.
  job.Close();
  return static_cast<int>(code);
}
