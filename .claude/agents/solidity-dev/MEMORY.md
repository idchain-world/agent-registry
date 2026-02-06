# Solidity Developer Memory

Record code patterns, test results, and development notes here.
This file persists across sessions.

## Code Patterns Found
- **vm.prank gotcha**: `vm.prank` only applies to the NEXT external call. If a function argument involves a contract getter (e.g. `registrar.MINTER_ROLE()`), that getter is evaluated first as a staticcall, consuming the prank. Fix: cache the getter value before calling `vm.prank`. `vm.startPrank` is unaffected since it persists.

## Test Results History
- 2026-02-06: 222/222 tests passing after adding C2-C5 security tests
- 2026-02-06: 238/238 tests passing after adding H1-H9 edge case tests

## Fixes Applied
### 2026-02-06: Fixed 9 failing AgentRegistrarTest tests
- Added `vm.deal(OWNER, 10 ether)` to setUp() — OWNER needed ETH for mint calls
- Cached `MINTER_ROLE()` before `vm.prank` in tests 102, 106, 111, 112
- Result: 210/210 tests passing

### 2026-02-06: Added critical security tests (C2-C5)
- **C2 Reentrancy (2 tests):** `_checkMintAndPay` sends refund before `totalMinted++`. Attacker re-enters during refund to mint past `maxSupply`. No `nonReentrant` on mint functions.
- **C3 Zero-address register (3 tests):** `register()` accepts `address(0)` as owner. Agent becomes unrecoverable — `ownerOf()` reverts `AgentNotFound`, nobody can transfer or update metadata.
- **C4 Transfer to zero (4 tests):** `transfer()`/`transferFrom()` allow sending to `address(0)`, effectively burning the token. Metadata persists on "burned" agent.
- **C5 Overflow (3 tests):** `mintPrice * count` overflows with extreme prices. Solidity 0.8 reverts cleanly, state unchanged.
- Result: 222/222 tests passing

### 2026-02-06: Added edge case tests (H1-H9)
- **H1 (2 tests):** `mintBatch(0)` succeeds, returns empty array, refunds any overpayment
- **H2 (2 tests):** `receive()` accepts raw ETH, withdrawable by admin
- **H3 (2 tests):** `withdraw()` and `withdraw(0)` succeed with zero balance
- **H4 (2 tests):** `closeMinting()` preserves `publicMinting` flag (only sets `open=false`)
- **H5 (1 test):** `setMaxSupply(0)` after minting switches to unlimited, allows minting beyond original cap
- **H6 (2 tests):** `transferFrom` with `sender == msg.sender` short-circuits approval check, doesn't consume approvals
- **H7 (2 tests):** `approve(amount > 1)` stores as bool, allowance always returns 0 or 1
- **H8 (1 test):** `setLockBit` is idempotent (OR operation)
- **H9 (2 tests):** Locking OPEN_CLOSE prevents both open and close; permanently freezes minting state
- Result: 238/238 tests passing

### 2026-02-06: Fixed vulnerabilities C2, C3, C4 and updated tests
- **C2 Fix:** Added `nonReentrant` to all 7 external mint/mintBatch functions in AgentRegistrar.sol. Updated C2 tests to expect `TransferFailed` revert (refund fails because reentrancy is blocked).
- **C3 Fix:** Added `ZeroAddressOwner` error + check in `register()` and `_register()` in AgentRegistry.sol. Updated C3 tests to expect `ZeroAddressOwner` revert. Also added batch register zero-address test.
- **C4 Fix:** Added `ZeroAddressReceiver` error + check in `transfer()` and `transferFrom()` in AgentRegistry.sol. Updated C4 tests to expect `ZeroAddressReceiver` revert. Added approval-not-consumed test.
- Result: 238/238 tests passing
