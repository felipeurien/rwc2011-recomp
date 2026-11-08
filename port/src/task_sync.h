// PPC bodies retained verbatim except for implementing their sync instructions.
// Source: ReXGlue 0.10.0 output for this title; no event or counter is bypassed.
#pragma once
#include <atomic>

// Original body SHA-256: 07d0cc5554a0ff9b911a08e2ff2e557f10e8e7c3bc2bae0782e0d8b62e450e7a
static void WaitTaskWithSync(PPCContext& ctx, uint8_t* base) {
	REX_FUNC_PROLOGUE();
	uint32_t ea{};
	// mflr r12
	ctx.r12.u64 = ctx.lr;
	// bl 0x824485bc
	ctx.lr = 0x823011E0;
	__savegprlr_29(ctx, base);
	// stwu r1,-112(r1)
	ea = -112 + ctx.r1.u32;
	REX_STORE_U32(ea, ctx.r1.u32);
	ctx.r1.u32 = ea;
	// lwz r31,4(r3)
	ctx.r31.u64 = REX_LOAD_U32(ctx.r3.u32 + 4);
	// cmplwi cr6,r31,0
	ctx.cr6.compare<uint32_t>(ctx.r31.u32, 0, ctx.xer);
	// beq cr6,0x82301230
	if (ctx.cr6.eq) goto loc_82301230;
	// lwz r30,0(r3)
	ctx.r30.u64 = REX_LOAD_U32(ctx.r3.u32 + 0);
	// lwz r11,528(r31)
	ctx.r11.u64 = REX_LOAD_U32(ctx.r31.u32 + 528);
	// subf. r10,r30,r11
	ctx.r10.u64 = ctx.r11.u64 - ctx.r30.u64;
	ctx.cr0.compare<int32_t>(ctx.r10.s32, 0, ctx.xer);
	// bge 0x82301230
	if (!ctx.cr0.lt) goto loc_82301230;
	// li r29,-1
	ctx.r29.s64 = -1;
loc_82301204:
	// stw r30,536(r31)
	REX_STORE_U32(ctx.r31.u32 + 536, ctx.r30.u32);
	// sync: full PowerPC store/load ordering
	std::atomic_thread_fence(std::memory_order_seq_cst);
	// lwz r11,528(r31)
	ctx.r11.u64 = REX_LOAD_U32(ctx.r31.u32 + 528);
	// subf. r10,r30,r11
	ctx.r10.u64 = ctx.r11.u64 - ctx.r30.u64;
	ctx.cr0.compare<int32_t>(ctx.r10.s32, 0, ctx.xer);
	// bge 0x82301224
	if (!ctx.cr0.lt) goto loc_82301224;
	// mr r4,r29
	ctx.r4.u64 = ctx.r29.u64;
	// lwz r3,544(r31)
	ctx.r3.u64 = REX_LOAD_U32(ctx.r31.u32 + 544);
	// bl 0x8245f9b8
	ctx.lr = 0x82301224;
	sub_8245F9B8(ctx, base);
loc_82301224:
	// lwz r11,528(r31)
	ctx.r11.u64 = REX_LOAD_U32(ctx.r31.u32 + 528);
	// subf. r10,r30,r11
	ctx.r10.u64 = ctx.r11.u64 - ctx.r30.u64;
	ctx.cr0.compare<int32_t>(ctx.r10.s32, 0, ctx.xer);
	// blt 0x82301204
	if (ctx.cr0.lt) goto loc_82301204;
loc_82301230:
	// addi r1,r1,112
	ctx.r1.s64 = ctx.r1.s64 + 112;
	// b 0x8244860c
	__restgprlr_29(ctx, base);
	return;
}

// Original body SHA-256: de0e0992b682e8d671409c021b3b40ec2565ed54f7fd8294b6642d1a69a9a97b
static void CompleteTaskWithSync(PPCContext& ctx, uint8_t* base) {
	REX_FUNC_PROLOGUE();
	uint32_t ea{};
	// mflr r12
	ctx.r12.u64 = ctx.lr;
	// stw r12,-8(r1)
	REX_STORE_U32(ctx.r1.u32 + -8, ctx.r12.u32);
	// std r30,-24(r1)
	REX_STORE_U64(ctx.r1.u32 + -24, ctx.r30.u64);
	// std r31,-16(r1)
	REX_STORE_U64(ctx.r1.u32 + -16, ctx.r31.u64);
	// stwu r1,-112(r1)
	ea = -112 + ctx.r1.u32;
	REX_STORE_U32(ea, ctx.r1.u32);
	ctx.r1.u32 = ea;
	// lwz r31,4(r3)
	ctx.r31.u64 = REX_LOAD_U32(ctx.r3.u32 + 4);
	// cmplwi cr6,r31,0
	ctx.cr6.compare<uint32_t>(ctx.r31.u32, 0, ctx.xer);
	// beq cr6,0x823012c4
	if (ctx.cr6.eq) goto loc_823012C4;
	// lbz r11,908(r31)
	ctx.r11.u64 = REX_LOAD_U8(ctx.r31.u32 + 908);
	// lwz r30,0(r3)
	ctx.r30.u64 = REX_LOAD_U32(ctx.r3.u32 + 0);
	// cmplwi cr6,r11,0
	ctx.cr6.compare<uint32_t>(ctx.r11.u32, 0, ctx.xer);
	// beq cr6,0x82301278
	if (ctx.cr6.eq) goto loc_82301278;
	// lwz r11,540(r31)
	ctx.r11.u64 = REX_LOAD_U32(ctx.r31.u32 + 540);
	// addi r11,r11,1
	ctx.r11.s64 = ctx.r11.s64 + 1;
	// stw r11,540(r31)
	REX_STORE_U32(ctx.r31.u32 + 540, ctx.r11.u32);
	// b 0x823012c4
	goto loc_823012C4;
loc_82301278:
	// lwz r3,812(r31)
	ctx.r3.u64 = REX_LOAD_U32(ctx.r31.u32 + 812);
	// lwz r11,11036(r3)
	ctx.r11.u64 = REX_LOAD_U32(ctx.r3.u32 + 11036);
	// stw r11,11056(r3)
	REX_STORE_U32(ctx.r3.u32 + 11056, ctx.r11.u32);
	// bl 0x822eb730
	ctx.lr = 0x82301288;
	sub_822EB730(ctx, base);
	// lwz r10,528(r31)
	ctx.r10.u64 = REX_LOAD_U32(ctx.r31.u32 + 528);
	// subf. r9,r30,r10
	ctx.r9.u64 = ctx.r10.u64 - ctx.r30.u64;
	ctx.cr0.compare<int32_t>(ctx.r9.s32, 0, ctx.xer);
	// blt 0x8230129c
	if (ctx.cr0.lt) goto loc_8230129C;
	// li r11,0
	ctx.r11.s64 = 0;
	// stw r11,0(0)
	REX_STORE_U32(0, ctx.r11.u32);
loc_8230129C:
	// lwz r11,528(r31)
	ctx.r11.u64 = REX_LOAD_U32(ctx.r31.u32 + 528);
	// addi r11,r11,1
	ctx.r11.s64 = ctx.r11.s64 + 1;
	// stw r11,528(r31)
	REX_STORE_U32(ctx.r31.u32 + 528, ctx.r11.u32);
	// sync: full PowerPC store/load ordering
	std::atomic_thread_fence(std::memory_order_seq_cst);
	// lwz r10,536(r31)
	ctx.r10.u64 = REX_LOAD_U32(ctx.r31.u32 + 536);
	// lwz r9,528(r31)
	ctx.r9.u64 = REX_LOAD_U32(ctx.r31.u32 + 528);
	// cmplw cr6,r9,r10
	ctx.cr6.compare<uint32_t>(ctx.r9.u32, ctx.r10.u32, ctx.xer);
	// bne cr6,0x823012c4
	if (!ctx.cr6.eq) goto loc_823012C4;
	// lwz r3,544(r31)
	ctx.r3.u64 = REX_LOAD_U32(ctx.r31.u32 + 544);
	// bl 0x826610a0
	ctx.lr = 0x823012C4;
	sub_826610A0(ctx, base);
loc_823012C4:
	// addi r1,r1,112
	ctx.r1.s64 = ctx.r1.s64 + 112;
	// lwz r12,-8(r1)
	ctx.r12.u64 = REX_LOAD_U32(ctx.r1.u32 + -8);
	// mtlr r12
	ctx.lr = ctx.r12.u64;
	// ld r30,-24(r1)
	ctx.r30.u64 = REX_LOAD_U64(ctx.r1.u32 + -24);
	// ld r31,-16(r1)
	ctx.r31.u64 = REX_LOAD_U64(ctx.r1.u32 + -16);
	// blr 
	return;
}
