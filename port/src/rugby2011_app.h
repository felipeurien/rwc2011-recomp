// rugby2011 - ReXGlue Recompiled Project
//
// Customize your app by overriding virtual hooks from rex::ReXApp.

#pragma once

#include <rex/rex_app.h>
#include <rex/memory.h>
#include <rex/cvar.h>
#include <fstream>
#ifdef RUGBY_FRAME_CAPTURE
#include "gpu_capture.h"
#endif

REXCVAR_DEFINE_BOOL(rugby_inspect_startup, false, "Debug",
                   "Log decoded words around the first missing startup callback");
REXCVAR_DEFINE_STRING(rugby_snapshot_path, "", "Debug",
                     "Write the loaded guest image before launching game code");

class Rugby2011App : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

#ifdef RUGBY_FRAME_CAPTURE
  void OnPostSetup() override { gpu_capture_.Start(); }
  void OnShutdown() override { gpu_capture_.Stop(); }
#endif

  static std::unique_ptr<rex::ui::WindowedApp> Create(
      rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<Rugby2011App>(new Rugby2011App(ctx, "rugby2011",
        PPCImageConfig));
  }

  void OnPostLoadXexImage() override {
    const auto snapshot = REXCVAR_GET(rugby_snapshot_path);
    if (!snapshot.empty()) {
      std::ofstream output(snapshot, std::ios::binary | std::ios::trunc);
      output.write(reinterpret_cast<const char*>(runtime()->memory()->TranslateVirtual(REX_IMAGE_BASE)),
                   REX_IMAGE_SIZE);
      if (!output) throw std::runtime_error("Failed to write guest image snapshot");
      REXLOG_INFO("Guest image snapshot: {} (base {:08X}, size {:08X})",
                  snapshot, REX_IMAGE_BASE, REX_IMAGE_SIZE);
    }
    if (!REXCVAR_GET(rugby_inspect_startup)) return;
    // Read decoded guest memory around the first missing entry.
    for (uint32_t address = 0x827E7938; address < 0x827E7960; address += 4) {
      const auto* bytes = runtime()->memory()->TranslateVirtual(address);
      const uint32_t word = (uint32_t(bytes[0]) << 24) | (uint32_t(bytes[1]) << 16) |
                            (uint32_t(bytes[2]) << 8) | uint32_t(bytes[3]);
      REXLOG_INFO("Startup probe {:08X}: {:08X}", address, word);
    }
  }

  // Override virtual hooks for customization:
  // void OnPostInitLogging() override {}
  // void OnPreSetup(rex::RuntimeConfig& config) override {}
  // void OnLoadXexImage(std::string& xex_image) override {}
  // void OnPostLoadXexImage() override {}
  // void OnPostSetup() override {}
  // void OnCreateDialogs(rex::ui::ImGuiDrawer* drawer) override {}
  // std::unique_ptr<rex::ui::ImGuiDialog> CreateAchievementsOverlay() override;
  // std::unique_ptr<rex::ui::AchievementNotificationDialog>
  // CreateAchievementNotificationDialog() override;
  // void OnShutdown() override {}
  // void OnConfigurePaths(rex::PathConfig& paths) override {}
#ifdef RUGBY_FRAME_CAPTURE
 private:
  RugbyGpuCapture gpu_capture_;
#endif
};
