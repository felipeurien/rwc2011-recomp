#include "generated/default/rugby2011_init.h"
#include <Windows.h>
#include <string>
#include <rex/cvar.h>

REXCVAR_DEFINE_BOOL(rugby_trace_lua, false, "Debug", "Trace Lua throws without changing their behavior");

REX_EXTERN(__imp__sub_82395B60);

namespace {
bool ReadWord(uint8_t* base, uint32_t address, uint32_t& value) {
  uint8_t bytes[4];
  SIZE_T count = 0;
  if (!ReadProcessMemory(GetCurrentProcess(), base + address, bytes, 4, &count) || count != 4)
    return false;
  value = (uint32_t(bytes[0]) << 24) | (uint32_t(bytes[1]) << 16) |
          (uint32_t(bytes[2]) << 8) | uint32_t(bytes[3]);
  return true;
}

std::string ReadText(uint8_t* base, uint32_t address) {
  std::string result;
  for (uint32_t i = 0; i < 256 && address <= UINT32_MAX-i; ++i) {
    char byte = 0;
    SIZE_T count = 0;
    if (!ReadProcessMemory(GetCurrentProcess(), base + address + i, &byte, 1, &count) || count != 1)
      return result + "<unreadable>";
    if (!byte) break;
    result += (byte >= 32 && byte <= 126) ? byte : '?';
  }
  return result;
}
}

// Diagnostic wrapper: preserve all guest registers and always call the original.
// Offsets are corroborated by the generated Lua stack operations (top at +8,
// 16-byte values, tag at +8). This does not suppress or repair Lua errors.
REX_HOOK_RAW(sub_82395B60) {
  if (!REXCVAR_GET(rugby_trace_lua)) {
    __imp__sub_82395B60(ctx, base);
    return;
  }
  const uint32_t state = ctx.r3.u32;
  REXLOG_ERROR("Lua throw: state={:08X} code={} LR={:08X} SP={:08X}",
               state, ctx.r4.u32, uint32_t(ctx.lr), ctx.r1.u32);
  uint32_t top = 0, tag = 0, value = 0;
  if (ReadWord(base, state + 8, top) && top >= 16 &&
      ReadWord(base, top - 8, tag) && ReadWord(base, top - 16, value)) {
    REXLOG_ERROR("Lua error value: top={:08X} tag={} value={:08X}", top, tag, value);
    if (tag == 4 && value < UINT32_MAX-16)
      REXLOG_ERROR("Lua error text candidate: {}", ReadText(base, value + 16));
  }
  uint32_t frame = ctx.r1.u32;
  for (int i = 0; i < 16; ++i) {
    uint32_t previous = 0, saved_lr = 0;
    if (!ReadWord(base, frame, previous) || previous <= frame || previous-frame > 0x100000 ||
        !ReadWord(base, previous-8, saved_lr)) break;
    REXLOG_ERROR("Lua guest backchain {}: frame={:08X} saved_LR={:08X}", i, frame, saved_lr);
    frame = previous;
  }
  __imp__sub_82395B60(ctx, base);
}
