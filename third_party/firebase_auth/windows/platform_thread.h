// Quiz Studio patch, not part of upstream FlutterFire.
//
// The Firebase C++ SDK completes futures and fires listeners on its own worker
// threads. Answering Flutter from there breaks the engine's rule that platform
// channel messages go out on the platform thread, which can end the app on
// Windows without any error (flutterfire#11933, #18630). Everything that talks
// back to Flutter goes through PlatformThreadDispatcher::Post instead.
//
// Same approach as cloud_firestore's own Windows plugin: a message-only window
// created on the platform thread receives the posted tasks through the
// runner's normal message loop.

#ifndef QUIZ_STUDIO_PLATFORM_THREAD_H_
#define QUIZ_STUDIO_PLATFORM_THREAD_H_

#include <flutter/encodable_value.h>
#include <flutter/event_sink.h>
#include <windows.h>

#include <functional>
#include <memory>
#include <mutex>
#include <queue>

#ifndef QUIZ_STUDIO_DISPATCHER_CLASS_NAME
#error "Define QUIZ_STUDIO_DISPATCHER_CLASS_NAME before including this header"
#endif

namespace {

constexpr UINT kQuizStudioTaskMessage = WM_APP + 0x5153;

class PlatformThreadDispatcher {
 public:
  static PlatformThreadDispatcher& GetInstance() {
    static PlatformThreadDispatcher instance;
    return instance;
  }

  // Call once on the platform thread, i.e. from RegisterWithRegistrar.
  void Initialize() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (window_ != nullptr) {
      return;
    }

    platform_thread_id_ = GetCurrentThreadId();

    WNDCLASSW window_class = {};
    window_class.lpfnWndProc = PlatformThreadDispatcher::WindowProc;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.lpszClassName = QUIZ_STUDIO_DISPATCHER_CLASS_NAME;

    RegisterClassW(&window_class);
    window_ = CreateWindowExW(0, QUIZ_STUDIO_DISPATCHER_CLASS_NAME, L"", 0, 0,
                              0, 0, 0, HWND_MESSAGE, nullptr,
                              window_class.hInstance, this);
  }

  // Runs [task] on the platform thread: right away when already there,
  // otherwise on the next turn of the message loop.
  void Post(std::function<void()> task) {
    if (GetCurrentThreadId() == platform_thread_id_ || window_ == nullptr) {
      task();
      return;
    }

    {
      std::lock_guard<std::mutex> lock(mutex_);
      tasks_.push(std::move(task));
    }
    PostMessageW(window_, kQuizStudioTaskMessage, 0, 0);
  }

 private:
  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) {
    if (message == WM_NCCREATE) {
      auto create_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
      SetWindowLongPtr(
          window, GWLP_USERDATA,
          reinterpret_cast<LONG_PTR>(create_struct->lpCreateParams));
      return TRUE;
    }

    auto dispatcher = reinterpret_cast<PlatformThreadDispatcher*>(
        GetWindowLongPtr(window, GWLP_USERDATA));
    if (dispatcher != nullptr && message == kQuizStudioTaskMessage) {
      dispatcher->ProcessTasks();
      return 0;
    }

    return DefWindowProc(window, message, wparam, lparam);
  }

  void ProcessTasks() {
    std::queue<std::function<void()>> tasks;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      tasks.swap(tasks_);
    }

    while (!tasks.empty()) {
      tasks.front()();
      tasks.pop();
    }
  }

  PlatformThreadDispatcher() = default;

  HWND window_ = nullptr;
  DWORD platform_thread_id_ = 0;
  std::mutex mutex_;
  std::queue<std::function<void()>> tasks_;
};

// Wraps a Pigeon reply so it always runs on the platform thread.
template <typename T>
std::function<void(T)> OnPlatformThread(std::function<void(T)> result) {
  auto shared = std::make_shared<std::function<void(T)>>(std::move(result));
  return [shared](T reply) {
    auto boxed = std::make_shared<T>(std::move(reply));
    PlatformThreadDispatcher::GetInstance().Post(
        [shared, boxed]() { (*shared)(std::move(*boxed)); });
  };
}

// An event sink that may be fed from any thread and closed from the platform
// thread while a worker thread is still delivering.
class SharedEventSink {
 public:
  void Set(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink) {
    std::lock_guard<std::mutex> lock(mutex_);
    sink_ = std::move(sink);
  }

  void Clear() { Set(nullptr); }

  static void Success(std::shared_ptr<SharedEventSink> self,
                      flutter::EncodableValue value) {
    PlatformThreadDispatcher::GetInstance().Post(
        [self, value = std::move(value)]() {
          std::lock_guard<std::mutex> lock(self->mutex_);
          if (self->sink_) {
            self->sink_->Success(value);
          }
        });
  }

  static void Error(std::shared_ptr<SharedEventSink> self,
                    const std::string& code, const std::string& message,
                    flutter::EncodableValue details) {
    PlatformThreadDispatcher::GetInstance().Post(
        [self, code, message, details = std::move(details)]() {
          std::lock_guard<std::mutex> lock(self->mutex_);
          if (self->sink_) {
            self->sink_->Error(code, message, details);
          }
        });
  }

  static void EndOfStream(std::shared_ptr<SharedEventSink> self) {
    PlatformThreadDispatcher::GetInstance().Post([self]() {
      std::lock_guard<std::mutex> lock(self->mutex_);
      if (self->sink_) {
        self->sink_->EndOfStream();
        self->sink_ = nullptr;
      }
    });
  }

 private:
  std::mutex mutex_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
};

}  // namespace

#endif  // QUIZ_STUDIO_PLATFORM_THREAD_H_
