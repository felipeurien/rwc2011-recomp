#pragma once

// Optional host-only capture diagnostic. Never compiled into the normal target.
#include <Windows.h>
#include <renderdoc/renderdoc_app.h>
#include <chrono>
#include <filesystem>
#include <thread>

REXCVAR_DEFINE_STRING(rugby_gpu_capture_trigger, "", "Debug",
                     "Consume a local request file to capture two seconds of GPU work");

class RugbyGpuCapture {
 public:
  void Start() {
    const auto path = REXCVAR_GET(rugby_gpu_capture_trigger);
    if (path.empty()) return;
    const auto module = GetModuleHandleW(L"renderdoc.dll");
    const auto get_api = module ? reinterpret_cast<pRENDERDOC_GetAPI>(
        GetProcAddress(module, "RENDERDOC_GetAPI")) : nullptr;
    RENDERDOC_API_1_0_0* api = nullptr;
    if (!get_api || !get_api(eRENDERDOC_API_Version_1_0_0,
                            reinterpret_cast<void**>(&api))) {
      REXLOG_WARN("GPU capture requested, but RenderDoc is not connected");
      return;
    }
    worker_ = std::jthread([path, api](std::stop_token stop) {
      using namespace std::chrono_literals;
      while (!stop.stop_requested()) {
        std::error_code error;
        if (std::filesystem::exists(path, error) &&
            !api->IsFrameCapturing() && std::filesystem::remove(path, error)) {
          REXLOG_INFO("GPU diagnostic: starting two-second manual capture");
          api->StartFrameCapture(nullptr, nullptr);
          for (unsigned i = 0; i < 20 && !stop.stop_requested(); ++i)
            std::this_thread::sleep_for(100ms);
          const auto result = api->EndFrameCapture(nullptr, nullptr);
          REXLOG_INFO("GPU diagnostic: manual capture result {}", result);
        }
        std::this_thread::sleep_for(100ms);
      }
    });
  }

  void Stop() {
    if (worker_.joinable()) {
      worker_.request_stop();
      worker_.join();
    }
  }

 private:
  std::jthread worker_;
};
