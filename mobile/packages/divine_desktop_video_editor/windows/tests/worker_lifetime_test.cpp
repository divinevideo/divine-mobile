#include <windows.h>
#include <filesystem>
#include <iostream>
#include <stdexcept>
#include <string>
#include "../worker_lifetime.h"

namespace {
void require(bool value, const char* boundary) {
  if (!value) throw std::runtime_error(boundary);
}
std::filesystem::path executable() {
  std::wstring path(32768, L'\0');
  const DWORD size = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  require(size != 0 && size < path.size(), "executable_path");
  path.resize(size);
  return path;
}
struct Child {
  HANDLE process = nullptr;
  HANDLE input = nullptr;
  DWORD pid = 0;
  explicit Child(const std::filesystem::path& binary) {
    SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
    HANDLE read = nullptr;
    require(CreatePipe(&read, &input, &security, 0), "stdin_pipe");
    require(SetHandleInformation(input, HANDLE_FLAG_INHERIT, 0), "input_inheritance");
    HANDLE output = CreateFileW(L"NUL", GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
        &security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    require(output != INVALID_HANDLE_VALUE, "output_handle");
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdInput = read;
    startup.hStdOutput = output;
    startup.hStdError = output;
    PROCESS_INFORMATION information{};
    std::wstring command = L"\"" + binary.wstring() + L"\" --wait";
    const BOOL started = CreateProcessW(binary.c_str(), command.data(), nullptr,
        nullptr, TRUE, CREATE_NO_WINDOW, nullptr, nullptr, &startup, &information);
    CloseHandle(read);
    CloseHandle(output);
    require(started, "child_start");
    process = information.hProcess;
    pid = information.dwProcessId;
    CloseHandle(information.hThread);
  }
  ~Child() {
    if (input) CloseHandle(input);
    if (process) {
      if (WaitForSingleObject(process, 0) == WAIT_TIMEOUT) TerminateProcess(process, 99);
      WaitForSingleObject(process, 5000);
      CloseHandle(process);
    }
  }
};
}  // namespace

int main(int argc, char**) {
  if (argc > 1) { char value = 0; std::cin.get(value); return 0; }
  try {
    const auto path = executable();
    {
      Child child(path);
      {
        divine_media::WorkerLifetime lifetime(path);
        require(lifetime.Claim(child.pid), "claim_owned_child");
        require(WaitForSingleObject(child.process, 0) == WAIT_TIMEOUT, "owned_child_alive");
      }
      require(WaitForSingleObject(child.process, 5000) == WAIT_OBJECT_0, "child_terminated");
      DWORD code = 0;
      // Kill-on-close guarantees termination, not a nonzero exit status.
      require(GetExitCodeProcess(child.process, &code), "owned_exit_available");
    }
    {
      Child child(path);
      {
        divine_media::WorkerLifetime lifetime(path.parent_path() / "different-worker.exe");
        require(!lifetime.Claim(child.pid), "reject_foreign_image");
        require(!lifetime.Claim(0), "reject_zero");
      }
      require(WaitForSingleObject(child.process, 0) == WAIT_TIMEOUT, "foreign_child_alive");
      CloseHandle(child.input);
      child.input = nullptr;
      require(WaitForSingleObject(child.process, 5000) == WAIT_OBJECT_0, "child_terminated");
      DWORD code = 1;
      require(GetExitCodeProcess(child.process, &code) && code == 0, "foreign_child_normal_exit");
    }
    {
      divine_media::WorkerLifetime lifetime(path);
      require(!lifetime.Claim(GetCurrentProcessId()), "reject_self");
    }
    std::cout << "DIVINE_WINDOWS_WORKER_LIFETIME_PASS\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "DIVINE_WINDOWS_WORKER_LIFETIME_FAIL " << error.what() << '\n';
    return 1;
  }
}
