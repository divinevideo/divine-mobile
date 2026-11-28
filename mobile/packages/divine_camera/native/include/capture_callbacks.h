#ifndef DIVINE_CAPTURE_CALLBACKS_H_
#define DIVINE_CAPTURE_CALLBACKS_H_

#include <glib.h>
#include <functional>
#include <memory>
#include <utility>

// Dispatch streaming-thread work on the platform loop. Lifetime invalidation
// and dispatch both belong to that loop; stopping the producer precedes reset.
inline void PostCaptureCallback(std::weak_ptr<void> lifetime,
                                std::function<void()> callback) {
  struct Pending {
    std::weak_ptr<void> lifetime;
    std::function<void()> callback;
  };
  g_idle_add_full(G_PRIORITY_DEFAULT_IDLE, [](gpointer data) -> gboolean {
    auto* pending = static_cast<Pending*>(data);
    // Do not retain the sentinel across user code: disposal may re-enter this
    // context, and another queued callback must see invalidation immediately.
    if (!pending->lifetime.expired()) pending->callback();
    return G_SOURCE_REMOVE;
  }, new Pending{std::move(lifetime), std::move(callback)}, [](gpointer data) {
    delete static_cast<Pending*>(data);
  });
}

#endif  // DIVINE_CAPTURE_CALLBACKS_H_
