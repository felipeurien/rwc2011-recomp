#include "generated/default/rugby2011_init.h"
#include <Windows.h>
#include <array>
#include <chrono>
#include <rex/cvar.h>
#include <rex/input/input.h>

REXCVAR_DEFINE_BOOL(rugby_trace_input, false, "Debug", "Observe original game input polling");
REX_EXTERN(__imp__sub_8266A348);
REX_EXTERN(__imp__sub_8245ACB8);

// The generated forwarder moves its second argument to XamInputGetState's
// output argument and uses flags=1. Keep it intact and read only after success.
REX_HOOK_RAW(sub_8266A348) {
  if (!REXCVAR_GET(rugby_trace_input)) { __imp__sub_8266A348(ctx, base); return; }
  const uint32_t user = ctx.r3.u32, address = ctx.r4.u32;
  __imp__sub_8266A348(ctx, base);
  const uint32_t result = ctx.r3.u32;
  rex::input::X_INPUT_STATE state{};
  SIZE_T count = 0;
  const bool valid = result == 0 && ReadProcessMemory(GetCurrentProcess(), base+address, &state, sizeof(state), &count) && count == sizeof(state);
  const uint32_t buttons = valid ? uint16_t(state.gamepad.buttons) : 0;
  struct Previous { bool seen=false; uint32_t result=0, buttons=0; std::chrono::steady_clock::time_point at{}; };
  thread_local std::array<Previous,4> previous{};
  thread_local uint32_t logged = 0;
  if (user < previous.size() && logged < 1024) {
    auto& last = previous[user];
    const auto now = std::chrono::steady_clock::now();
    if (!last.seen || last.result != result || last.buttons != buttons || now-last.at >= std::chrono::seconds(5)) {
      ++logged;
      REXLOG_INFO("InputPoll user={} result={} valid={} packet={} buttons={:04X}", user, result, valid, valid ? uint32_t(state.packet_number) : 0, buttons);
      last = {true,result,buttons,now};
    }
  }
}

REX_HOOK_RAW(sub_8245ACB8) {
  if (!REXCVAR_GET(rugby_trace_input)) { __imp__sub_8245ACB8(ctx, base); return; }
  const uint32_t user = ctx.r3.u32;
  __imp__sub_8245ACB8(ctx, base);
  thread_local uint32_t logged = 0;
  if (logged++ < 16) REXLOG_INFO("InputSignin user={} state={}",user,ctx.r3.u32);
}
