#include <windows.h>
#include <filesystem>
#include <iostream>
#include <stdexcept>
#include <string>
#include "../worker_lifetime.h"

namespace {
void require(bool value) {
  if (!value) throw std::runtime_error("Native worker lifetime assertion failed.");
}
std::filesystem::path executable() {
  std::wstring path(32768, L'\0');
  const DWORD size = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  require(size != 0 && size < path.size());
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
    require(CreatePipe(&read, &input, &security, 0));
    require(SetHandleInformation(input, HANDLE_FLAG_INHERIT, 0));
    HANDLE output = CreateFileW(L"NUL", GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
        &security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    require(output != INVALID_HANDLE_VALUE);
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
    require(started);
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
        require(lifetime.Claim(child.pid));
      }
      require(WaitForSingleObject(child.process, 5000) == WAIT_OBJECT_0);
      DWORD code = 0;
      require(GetExitCodeProcess(child.process, &code) && code != 0);
    }
    {
      Child child(path);
      {
        divine_media::WorkerLifetime lifetime(path.parent_path() / "different-worker.exe");
        require(!lifetime.Claim(child.pid));
        require(!lifetime.Claim(0));
      }
      require(WaitForSingleObject(child.process, 0) == WAIT_TIMEOUT);
      CloseHandle(child.input);
      child.input = nullptr;
      require(WaitForSingleObject(child.process, 5000) == WAIT_OBJECT_0);
      DWORD code = 1;
      require(GetExitCodeProcess(child.process, &code) && code == 0);
    }
    {
      divine_media::WorkerLifetime lifetime(path);
      require(!lifetime.Claim(GetCurrentProcessId()));
    }
    std::cout << "DIVINE_WINDOWS_WORKER_LIFETIME_PASS\n";
    return 0;
  } catch (const std::exception&) {
    std::cerr << "DIVINE_WINDOWS_WORKER_LIFETIME_FAIL\n";
    return 1;
  }
}
