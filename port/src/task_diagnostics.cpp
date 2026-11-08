#include "generated/default/rugby2011_init.h"
#include <Windows.h>
#include <atomic>
#include <chrono>
#include <rex/cvar.h>
#include "task_sync.h"

REXCVAR_DEFINE_BOOL(rugby_trace_tasks, false, "Debug", "Measure original task waits and completions");
REXCVAR_DEFINE_BOOL(rugby_fix_task_sync, true, "Compatibility", "Implement the original task wait/completion sync barriers");
REX_EXTERN(__imp__sub_823011D8);
REX_EXTERN(__imp__sub_82301238);

namespace {
bool Word(uint8_t* base, uint32_t address, uint32_t& value) {
  uint8_t bytes[4];
  SIZE_T size = 0;
  if (!ReadProcessMemory(GetCurrentProcess(), base + address, bytes, 4, &size) || size != 4) return false;
  value = (uint32_t(bytes[0]) << 24) | (uint32_t(bytes[1]) << 16) | (uint32_t(bytes[2]) << 8) | bytes[3];
  return true;
}
struct Task {
  uint32_t sequence = 0, worker = 0, completed = 0, target = 0, event = 0;
  bool valid = false;
};
Task Read(uint8_t* base, uint32_t descriptor) {
  Task t;
  t.valid = descriptor <= UINT32_MAX-8 && Word(base, descriptor, t.sequence) &&
      Word(base, descriptor+4, t.worker) && t.worker && t.worker <= UINT32_MAX-548 &&
      Word(base, t.worker+528, t.completed) && Word(base, t.worker+536, t.target) &&
      Word(base, t.worker+544, t.event);
  return t;
}
std::atomic<uint32_t> remaining{4000};
bool Budget() { auto n = remaining.load(); while (n && !remaining.compare_exchange_weak(n, n-1)) {} return n != 0; }
void Wait(PPCContext& ctx, uint8_t* base) {
  if (REXCVAR_GET(rugby_fix_task_sync)) WaitTaskWithSync(ctx,base);
  else __imp__sub_823011D8(ctx,base);
}
void Complete(PPCContext& ctx, uint8_t* base) {
  if (REXCVAR_GET(rugby_fix_task_sync)) CompleteTaskWithSync(ctx,base);
  else __imp__sub_82301238(ctx,base);
}
}

// Diagnostics only: always invoke the generated body with the same context.
REX_HOOK_RAW(sub_823011D8) {
  if (!REXCVAR_GET(rugby_trace_tasks)) { Wait(ctx, base); return; }
  const auto descriptor = ctx.r3.u32;
  const auto caller = uint32_t(ctx.lr);
  const auto before = Read(base, descriptor);
  const auto start = std::chrono::steady_clock::now();
  Wait(ctx, base);
  const auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-start).count();
  thread_local uint32_t calls = 0;
  const bool sampled = ++calls <= 8 || calls % 256 == 0 || elapsed >= 100000;
  if (before.valid && sampled && Budget()) {
    uint32_t completed = 0;
    Word(base, before.worker+528, completed);
    REXLOG_INFO("TaskWait caller={:08X} descriptor={:08X} worker={:08X} sequence={} completed_before={} completed_after={} event={:08X} elapsed_us={}",
        caller, descriptor, before.worker, before.sequence, before.completed, completed, before.event, elapsed);
  }
}

REX_HOOK_RAW(sub_82301238) {
  if (!REXCVAR_GET(rugby_trace_tasks)) { Complete(ctx, base); return; }
  const auto descriptor = ctx.r3.u32;
  const auto caller = uint32_t(ctx.lr);
  const auto before = Read(base, descriptor);
  Complete(ctx, base);
  thread_local uint32_t calls = 0;
  if (before.valid && (++calls <= 16 || calls % 256 == 0) && Budget()) {
    uint32_t completed = 0;
    Word(base, before.worker+528, completed);
    REXLOG_INFO("TaskComplete caller={:08X} descriptor={:08X} worker={:08X} sequence={} completed_before={} completed_after={} target={} event={:08X}",
        caller, descriptor, before.worker, before.sequence, before.completed, completed, before.target, before.event);
  }
}
