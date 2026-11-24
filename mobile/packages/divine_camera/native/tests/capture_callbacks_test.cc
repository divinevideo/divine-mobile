#include "capture_callbacks.h"
#include "check.h"
#include <thread>

int main() {
  unsigned delivered = 0;
  auto lifetime = std::make_shared<int>(0);
  PostCaptureCallback(lifetime, [&] { ++delivered; });
  while (g_main_context_iteration(nullptr, FALSE)) {}
  CHECK(delivered == 1);

  auto pixels = std::make_shared<int>(0);
  std::weak_ptr<int> retained_pixels = pixels;
  PostCaptureCallback(lifetime, [&, pixels] { ++delivered; });
  pixels.reset();
  CHECK(!retained_pixels.expired());
  lifetime.reset();
  while (g_main_context_iteration(nullptr, FALSE)) {}
  CHECK(delivered == 1);
  CHECK(retained_pixels.expired());

  lifetime = std::make_shared<int>(0);
  PostCaptureCallback(lifetime, [&] { lifetime.reset(); ++delivered; });
  PostCaptureCallback(lifetime, [&] { ++delivered; });
  while (g_main_context_iteration(nullptr, FALSE)) {}
  CHECK(delivered == 2);
  lifetime = std::make_shared<int>(0);
  std::thread producer([&] {
    PostCaptureCallback(lifetime, [&] { ++delivered; });
  });
  producer.join();
  lifetime.reset();
  while (g_main_context_iteration(nullptr, FALSE)) {}
  CHECK(delivered == 2);
  lifetime = std::make_shared<int>(0);
  PostCaptureCallback(lifetime, [&] {
    lifetime.reset();
    while (g_main_context_iteration(nullptr, FALSE)) {}
    ++delivered;
  });
  PostCaptureCallback(lifetime, [&] { ++delivered; });
  while (g_main_context_iteration(nullptr, FALSE)) {}
  CHECK(delivered == 3);
  return FinishTests("pending capture callbacks");
}
