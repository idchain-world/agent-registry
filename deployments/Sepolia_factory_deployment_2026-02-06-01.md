# Sepolia Factory Deployment - 2025-02-06

**Date:** February 6, 2026
**Network:** Sepolia Testnet
**Chain ID:** 11155111

## Contract Details

- **Contract Name:** AgentRegistryFactory
- **Contract Address:** [`0xEdd20967A704c2B2065B7adF41c8cA0d6bec01b3`](https://sepolia.etherscan.io/address/0xEdd20967A704c2B2065B7adF41c8cA0d6bec01b3)
- **Compiler Version:** Solidity 0.8.30
- **EVM Version:** Prague
- **Status:** Verified on Etherscan

## Implementation Contracts

### AgentRegistry Implementation
- **Implementation Address:** [`0x7AB7A16B64BBbC2d680ACc5D2770BfD10b551274`](https://sepolia.etherscan.io/address/0x7AB7A16B64BBbC2d680ACc5D2770BfD10b551274)
- **Status:** Verified on Etherscan
- **Transaction Hash:** [`0x9c37b554aa3bf1503c8dfb9cdb5ad1ddc57e1bf911d3c381d1cc19b5c0980f44`](https://sepolia.etherscan.io/tx/0x9c37b554aa3bf1503c8dfb9cdb5ad1ddc57e1bf911d3c381d1cc19b5c0980f44)
- **Deployment Block:** `10202305`

### AgentRegistrar Implementation
- **Implementation Address:** [`0x6AE5852f98e54461bE8b057a7BdE71A83Fc7F678`](https://sepolia.etherscan.io/address/0x6AE5852f98e54461bE8b057a7BdE71A83Fc7F678)
- **Status:** Verified on Etherscan
- **Transaction Hash:** [`0x0c65fe6449e28224e32bdd9c33a5d791d649bd616279828af9d3fabf540cb03b`](https://sepolia.etherscan.io/tx/0x0c65fe6449e28224e32bdd9c33a5d791d649bd616279828af9d3fabf540cb03b)
- **Deployment Block:** `10202305`

## Factory Transaction

- **Transaction Hash:** [`0xc6b4acff909be08c56f0a393051be1ba528acdcbccdf2b94d54c4768c0371e31`](https://sepolia.etherscan.io/tx/0xc6b4acff909be08c56f0a393051be1ba528acdcbccdf2b94d54c4768c0371e31)
- **Deployment Block:** `10202305`
- **Deployer Address:** `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`

## Deployment Method

Two-step deployment to avoid initcode size limits:
1. Deploy AgentRegistry implementation
2. Deploy AgentRegistrar implementation (with dummy constructor params)
3. Deploy AgentRegistryFactory with both implementation addresses

## Security Fixes Included

This deployment includes security fixes from a Trail of Bits-methodology audit:

### High: Reentrancy on Overpayment Refund (Fixed)
- **Issue:** `AgentRegistrar._checkMintAndPay` sent overpayment refund via `.call{value:}` before `totalMinted` was incremented, allowing re-entrant minting past `maxSupply`
- **Fix:** Added `nonReentrant` modifier to all 7 public mint/mintBatch functions

### Medium: Zero-Address Owner Registration (Fixed)
- **Issue:** `AgentRegistry.register()` accepted `address(0)` as owner, creating unrecoverable orphaned agents
- **Fix:** Added `ZeroAddressOwner` error and checks in `register()` and `_register()`

### Medium: Zero-Address Transfer (Fixed)
- **Issue:** `transfer()` and `transferFrom()` accepted `address(0)` as receiver, effectively burning tokens with no recovery
- **Fix:** Added `ZeroAddressReceiver` error and checks in both functions

### Interface Rename
- **Change:** `IAgentRegistry` renamed to `IERC8122` for ERC-8122 standard compliance
- All imports and references updated across the codebase

## Test Suite

238 tests passing (0 failures) across 5 test suites:
- AgentRegistryTest: 56 tests
- AgentRegistrarTest: 78 tests
- AgentRegistryFactoryTest: 72 tests
- ERC8048Test: 15 tests
- ERC8049Test: 17 tests

Includes 28 new tests: 12 critical security tests (reentrancy PoC, zero-address exploits, overflow), 16 edge case tests.

## Usage

```solidity
AgentRegistryFactory factory = AgentRegistryFactory(0xEdd20967A704c2B2065B7adF41c8cA0d6bec01b3);

// Deploy registry + registrar pair
(address registry, address registrar) = factory.deploy(admin, mintPrice, maxSupply);

// Or with a name
(address registry, address registrar) = factory.deploy(admin, mintPrice, maxSupply, "My Registry");

// Open minting
AgentRegistrar(registrar).openMinting(true);  // true = public, false = private
```

## Verification

All contracts verified on Etherscan:
- **Factory:** https://sepolia.etherscan.io/address/0xEdd20967A704c2B2065B7adF41c8cA0d6bec01b3#code
- **Registry Implementation:** https://sepolia.etherscan.io/address/0x7AB7A16B64BBbC2d680ACc5D2770BfD10b551274#code
- **Registrar Implementation:** https://sepolia.etherscan.io/address/0x6AE5852f98e54461bE8b057a7BdE71A83Fc7F678#code

## Previous Deployment

Supersedes: [`Sepolia_factory_deployment_2025-12-27-01.md`](Sepolia_factory_deployment_2025-12-27-01.md)
- Old Factory: `0x86a5139cBA9AB0f588aeFA3A7Ea3351E62C18563`
- Reason: Security fixes (reentrancy, zero-address checks) and IERC8122 interface rename

## Repository

- **GitHub:** https://github.com/idchain-world/agent-registry
- **Base Commit:** `7df1d31` (uncommitted changes include security fixes + interface rename)
