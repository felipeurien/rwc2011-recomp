#include "generated/default/rugby2011_init.h"

REX_EXTERN(__imp__sub_8245F170);

// The title checks the extended HRESULT for end-of-list only when the
// overlapped operation returns ERROR_FUNCTION_FAILED. ReXGlue 0.10 returns
// ERROR_NO_MORE_FILES directly while also setting the correct extended code.
REX_HOOK_RAW(sub_8245F170) {
  const bool checking_content_list = ctx.lr == 0x823755E0;
  const uint32_t overlapped = ctx.r3.u32;
  __imp__sub_8245F170(ctx, base);
  if (checking_content_list && ctx.r3.u32 == 18 &&
      REX_LOAD_U32(overlapped + 24) == 0x80070012) {
    ctx.r3.u64 = 1627;
    REXLOG_DEBUG("Profile storage: reached end of content list");
  }
}
