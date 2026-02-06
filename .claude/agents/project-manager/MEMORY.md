# Project Manager Memory

## Session 2026-02-06: Initial Reconnaissance

### Key Findings
1. **9 failing tests** in AgentRegistrarTest.t.sol -- TWO root causes:
   - (a) OWNER not funded with ETH in setUp() (5 tests: 021, 034, 101, 104, 105)
   - (b) vm.prank() consumed by MINTER_ROLE() getter staticcall before grantRole/revokeRole (4 tests: 102, 106, 111, 112)
   - These are TEST bugs, not contract bugs
2. **Potential reentrancy** in `AgentRegistrar._checkMintAndPay` line 327 -- overpayment refund before state update
3. **No zero-address checks** on register() owner or transfer() receiver
4. **Interface rename** IAgentRegistry -> IERC8122 in progress (uncommitted)
5. **Untested functions**: deployRegistry(admin), predictRegistrarAddress, getDeployedRegistrars, 5-param deployDeterministic

### Test Suite Status
- AgentRegistryTest: 45 pass, 0 fail
- AgentRegistrarTest: 52 pass, 9 fail (role management issue)
- AgentRegistryFactoryTest: 72 pass, 0 fail
- ERC8048Test: 15 pass, 0 fail
- ERC8049Test: 17 pass, 0 fail

### Work Phases Proposed
1. Fix 9 failing tests
2. Critical security tests (reentrancy, zero-addr)
3. Edge case tests (count=0, receive(), withdraw(0))
4. Coverage completion (untested factory functions)
5. Low-priority tests (diamond storage verification, docs alignment)

## Team Coordination Notes
- Delivered full work breakdown to team-lead on first session

## Project-Specific Context
- Solidity 0.8.25, Foundry framework
- EIP-1167 minimal clones pattern
- Diamond Storage in ERC8048/ERC8049
- OpenZeppelin AccessControl for roles
- Deployed on Sepolia (Dec 27, 2025)
