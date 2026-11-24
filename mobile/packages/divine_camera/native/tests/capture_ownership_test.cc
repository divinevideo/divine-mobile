#include "capture_output.h"
#include "capture_work.h"
#include "capture_tasks.h"
#include "synthetic_audio.h"
#include <cmath>
#include <vector>
#include <atomic>

#include <chrono>
#include <filesystem>
#include <fstream>
#include <future>
#include <iostream>
#include <stdexcept>
#include <thread>

static void Require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}

int main() {
  const auto directory = std::filesystem::temp_directory_path() /
      ("divine capture ownership " + std::to_string(
          std::chrono::steady_clock::now().time_since_epoch().count()));
  try {
    std::filesystem::create_directory(directory);
    const auto photo = CaptureOutputFile(directory, CaptureFileKind::kPhoto);
    const auto video = CaptureOutputFile(directory, CaptureFileKind::kVideo);
    Require(photo == directory / "photo.jpg", "Photo escaped owned directory");
    Require(video == directory / "recording.mp4", "Video escaped owned directory");
    for (const auto& invalid : {std::filesystem::path("relative-output"),
                               directory / "missing"}) {
      bool rejected = false;
      try {
        CaptureOutputFile(invalid, CaptureFileKind::kVideo);
      } catch (const std::invalid_argument&) {
        rejected = true;
      }
      Require(rejected, "Invalid output directory was accepted");
    }
    {
      std::ofstream existing(photo);
      existing << "caller-owned";
    }
    bool rejected = false;
    try {
      CaptureOutputFile(directory, CaptureFileKind::kPhoto);
    } catch (const std::invalid_argument&) {
      rejected = true;
    }
    Require(rejected, "Existing output could be overwritten");
    std::ifstream preserved(photo);
    std::string contents;
    preserved >> contents;
    Require(contents == "caller-owned", "Existing output was modified");
    preserved.close();

    std::vector<int16_t> tone(4800);
    FillSyntheticAudio(tone.data(), 2400, 0);
    FillSyntheticAudio(tone.data() + 2400, 2400, 2400);
    double power = 0;
    for (const auto value : tone) {
      const double normalized = value / 32768.0;
      power += normalized * normalized;
    }
    Require(std::abs(std::sqrt(power / static_cast<double>(tone.size())) - 0.35355) < 0.001,
            "Synthetic microphone must supply a non-silent test signal");
    std::vector<int16_t> continuous(tone.size());
    FillSyntheticAudio(continuous.data(), continuous.size(), 0);
    Require(tone == continuous, "Microphone phase changed at a sample boundary");

    std::atomic<int> wakeups{0};
    auto tasks = std::make_shared<CaptureTaskQueue>([&wakeups] {
      ++wakeups;
      return true;
    });
    const auto platform_thread = std::this_thread::get_id();
    int delivered = 0;
    std::vector<std::thread> producers;
    for (int producer = 0; producer < 4; ++producer) {
      producers.emplace_back([&] {
        for (int index = 0; index < 16; ++index) {
          Require(tasks->Post([&] {
            Require(std::this_thread::get_id() == platform_thread,
                    "Native callback ran off the platform thread");
            ++delivered;
          }), "Open dispatcher rejected a callback");
        }
      });
    }
    for (auto& producer : producers) producer.join();
    Require(delivered == 0, "Worker thread executed its callback inline");
    tasks->Drain();
    Require(delivered == 64 && wakeups.load() == 64, "Native callback was lost");
    auto payload = std::make_shared<int>(1);
    std::weak_ptr<int> pending_payload = payload;
    tasks->Post([payload] {});
    payload.reset();
    Require(!pending_payload.expired(), "Pending callback lost its owned data");
    tasks->Close();
    Require(pending_payload.expired(), "Shutdown retained a dropped callback");
    Require(!tasks->Post([&] { ++delivered; }), "Closed dispatcher accepted work");
    tasks->Drain();
    Require(delivered == 64, "Shutdown ran a retired callback");
    auto failed_dispatch = std::make_shared<CaptureTaskQueue>([] { return false; });
    Require(!failed_dispatch->Post([&] { ++delivered; }), "Failed wakeup was accepted");
    failed_dispatch->Drain();
    Require(delivered == 64, "Failed wakeup retained executable work");

    CaptureWorkBarrier writers;
    auto first = writers.Begin();
    auto second = writers.Begin();
    Require(first != nullptr && second != nullptr, "Writer could not begin");
    auto released = std::async(std::launch::async, [&writers] {
      writers.CloseAndWait();
    });
    // A rejected new lease proves closing has entered its protected state.
    while (auto contender = writers.Begin()) std::this_thread::yield();
    Require(released.wait_for(std::chrono::seconds(0)) == std::future_status::timeout,
            "Release acknowledged active writers");
    first.reset();
    Require(released.wait_for(std::chrono::seconds(0)) == std::future_status::timeout,
            "Release ignored the remaining writer");
    second.reset();
    released.get();
    Require(writers.Begin() == nullptr, "Closed capture accepted a new writer");
    std::filesystem::remove_all(directory);
    std::cout << "CAPTURE_OWNERSHIP_PASS" << std::endl;
    return 0;
  } catch (const std::exception& error) {
    std::error_code ignored;
    std::filesystem::remove_all(directory, ignored);
    std::cerr << error.what() << std::endl;
    return 1;
  }
}
