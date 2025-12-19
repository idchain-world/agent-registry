// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/AgentRegistry.sol";
import "../src/AgentRegistrar.sol";
import "../src/interfaces/IAgentRegistry.sol";

/**
 * @title AgentRegistrarTest
 * @dev Comprehensive tests for the AgentRegistrar contract
 * 
 * This test verifies:
 * - Minting functionality (single and batch)
 * - Mint price and payment handling
 * - Max supply enforcement
 * - Open/close minting
 * - Lock bits functionality
 * - Withdrawal functions
 * - Clone initialization
 */
contract AgentRegistrarTest is Test {
    
    /* --- State Variables --- */
    
    AgentRegistry public registry;
    AgentRegistrar public registrar;
    
    /* --- Test Addresses --- */
    
    address constant OWNER = address(0x1111111111111111111111111111111111111111);
    address constant USER1 = address(0x2222222222222222222222222222222222222222);
    address constant USER2 = address(0x3333333333333333333333333333333333333333);
    address constant RANDOM = address(0x4444444444444444444444444444444444444444);
    
    /* --- Constants --- */
    
    uint256 constant MINT_PRICE = 0.01 ether;
    uint256 constant MAX_SUPPLY = 100;
    
    /* --- Events --- */
    
    event MintingOpened();
    event MintingClosed();
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event MaxSupplyUpdated(uint256 oldSupply, uint256 newSupply);
    event LockBitSet(uint256 lockBit);
    event AgentMinted(uint256 indexed agentId, address indexed owner, uint256 mintNumber);
    event Withdrawn(address indexed to, uint256 amount);
    
    /* --- Setup --- */
    
    function setUp() public {
        // Deploy registry
        registry = new AgentRegistry();
        
        // Deploy registrar
        registrar = new AgentRegistrar(registry, MINT_PRICE, MAX_SUPPLY, OWNER);
        
        // Grant REGISTRAR_ROLE to registrar
        registry.grantRole(registry.REGISTRAR_ROLE(), address(registrar));
        
        // Fund test users
        vm.deal(USER1, 10 ether);
        vm.deal(USER2, 10 ether);
    }
    
    /* ============================================================== */
    /*                         DEPLOYMENT                             */
    /* ============================================================== */
    
    function test_001____deployment____ConfiguredCorrectly() public view {
        assertEq(address(registrar.registry()), address(registry), "Registry should be set");
        assertEq(registrar.mintPrice(), MINT_PRICE, "Mint price should be set");
        assertEq(registrar.maxSupply(), MAX_SUPPLY, "Max supply should be set");
        assertEq(registrar.owner(), OWNER, "Owner should be set");
        assertFalse(registrar.open(), "Minting should be closed initially");
        assertEq(registrar.totalMinted(), 0, "Total minted should be 0");
    }
    
    function test_002____deployment____LockBitsInitiallyZero() public view {
        assertEq(registrar.lockBits(), 0, "Lock bits should be 0");
        assertFalse(registrar.isLocked(registrar.LOCK_OPEN_CLOSE()), "LOCK_OPEN_CLOSE should not be set");
        assertFalse(registrar.isLocked(registrar.LOCK_MINT_PRICE()), "LOCK_MINT_PRICE should not be set");
        assertFalse(registrar.isLocked(registrar.LOCK_MAX_SUPPLY()), "LOCK_MAX_SUPPLY should not be set");
    }
    
    /* ============================================================== */
    /*                      OPEN/CLOSE MINTING                        */
    /* ============================================================== */
    
    function test_010____openClose____OwnerCanOpen() public {
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit MintingOpened();
        registrar.openMinting();
        
        assertTrue(registrar.open(), "Minting should be open");
    }
    
    function test_011____openClose____OwnerCanClose() public {
        vm.startPrank(OWNER);
        registrar.openMinting();
        
        vm.expectEmit(true, true, true, true);
        emit MintingClosed();
        registrar.closeMinting();
        vm.stopPrank();
        
        assertFalse(registrar.open(), "Minting should be closed");
    }
    
    function test_012____openClose____NonOwnerCannotOpen() public {
        vm.prank(RANDOM);
        vm.expectRevert();
        registrar.openMinting();
    }
    
    function test_013____openClose____NonOwnerCannotClose() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.prank(RANDOM);
        vm.expectRevert();
        registrar.closeMinting();
    }
    
    /* ============================================================== */
    /*                        SINGLE MINTING                          */
    /* ============================================================== */
    
    function test_020____mint____CanMintWhenOpen() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.prank(USER1);
        uint256 agentId = registrar.mint{value: MINT_PRICE}();
        
        assertEq(agentId, 0, "First agent ID should be 0");
        assertEq(registry.ownerOf(0), USER1, "USER1 should own the agent");
        assertEq(registrar.totalMinted(), 1, "Total minted should be 1");
    }
    
    function test_021____mint____CannotMintWhenClosed() public {
        vm.prank(USER1);
        vm.expectRevert(AgentRegistrar.MintingNotOpen.selector);
        registrar.mint{value: MINT_PRICE}();
    }
    
    function test_022____mint____CanMintToOtherAddress() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.prank(USER1);
        uint256 agentId = registrar.mint{value: MINT_PRICE}(USER2);
        
        assertEq(registry.ownerOf(agentId), USER2, "USER2 should own the agent");
    }
    
    function test_023____mint____EmitsAgentMintedEvent() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.expectEmit(true, true, true, true);
        emit AgentMinted(0, USER1, 1);
        
        vm.prank(USER1);
        registrar.mint{value: MINT_PRICE}();
    }
    
    function test_024____mint____RefundsOverpayment() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        uint256 balanceBefore = USER1.balance;
        
        vm.prank(USER1);
        registrar.mint{value: 0.05 ether}();
        
        uint256 balanceAfter = USER1.balance;
        assertEq(balanceBefore - balanceAfter, MINT_PRICE, "Should only charge mint price");
    }
    
    function test_025____mint____RevertsOnInsufficientPayment() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSelector(
            AgentRegistrar.InsufficientPayment.selector,
            0.005 ether,
            MINT_PRICE
        ));
        registrar.mint{value: 0.005 ether}();
    }
    
    /* ============================================================== */
    /*                        BATCH MINTING                           */
    /* ============================================================== */
    
    function test_030____mintBatch____CanMintMultiple() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.prank(USER1);
        uint256[] memory agentIds = registrar.mintBatch{value: MINT_PRICE * 5}(5);
        
        assertEq(agentIds.length, 5, "Should mint 5 agents");
        assertEq(registrar.totalMinted(), 5, "Total minted should be 5");
        
        for (uint256 i = 0; i < 5; i++) {
            assertEq(registry.ownerOf(i), USER1, "USER1 should own all agents");
        }
    }
    
    function test_031____mintBatch____CanMintToOtherAddress() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.prank(USER1);
        uint256[] memory agentIds = registrar.mintBatch{value: MINT_PRICE * 3}(USER2, 3);
        
        assertEq(agentIds.length, 3, "Should mint 3 agents");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(registry.ownerOf(agentIds[i]), USER2, "USER2 should own all agents");
        }
    }
    
    function test_032____mintBatch____RefundsOverpayment() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        uint256 balanceBefore = USER1.balance;
        
        vm.prank(USER1);
        registrar.mintBatch{value: 1 ether}(3);
        
        uint256 balanceAfter = USER1.balance;
        assertEq(balanceBefore - balanceAfter, MINT_PRICE * 3, "Should only charge for 3 mints");
    }
    
    function test_033____mintBatch____RevertsOnInsufficientPayment() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSelector(
            AgentRegistrar.InsufficientPayment.selector,
            0.02 ether,
            0.03 ether
        ));
        registrar.mintBatch{value: 0.02 ether}(3);
    }
    
    /* ============================================================== */
    /*                       MAX SUPPLY                               */
    /* ============================================================== */
    
    function test_040____maxSupply____EnforcesLimit() public {
        // Deploy with small max supply
        AgentRegistrar smallRegistrar = new AgentRegistrar(registry, MINT_PRICE, 3, OWNER);
        registry.grantRole(registry.REGISTRAR_ROLE(), address(smallRegistrar));
        
        vm.prank(OWNER);
        smallRegistrar.openMinting();
        
        // Mint up to max
        vm.startPrank(USER1);
        smallRegistrar.mint{value: MINT_PRICE}();
        smallRegistrar.mint{value: MINT_PRICE}();
        smallRegistrar.mint{value: MINT_PRICE}();
        
        // Should fail on 4th mint
        vm.expectRevert(abi.encodeWithSelector(
            AgentRegistrar.MaxSupplyExceeded.selector,
            1,
            0
        ));
        smallRegistrar.mint{value: MINT_PRICE}();
        vm.stopPrank();
    }
    
    function test_041____maxSupply____EnforcesBatchLimit() public {
        // Deploy with small max supply
        AgentRegistrar smallRegistrar = new AgentRegistrar(registry, MINT_PRICE, 5, OWNER);
        registry.grantRole(registry.REGISTRAR_ROLE(), address(smallRegistrar));
        
        vm.prank(OWNER);
        smallRegistrar.openMinting();
        
        vm.prank(USER1);
        smallRegistrar.mintBatch{value: MINT_PRICE * 3}(3);
        
        // Should fail if trying to mint more than remaining
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSelector(
            AgentRegistrar.MaxSupplyExceeded.selector,
            5,
            2
        ));
        smallRegistrar.mintBatch{value: MINT_PRICE * 5}(5);
    }
    
    function test_042____maxSupply____UnlimitedWhenZero() public {
        AgentRegistrar unlimitedRegistrar = new AgentRegistrar(registry, MINT_PRICE, 0, OWNER);
        registry.grantRole(registry.REGISTRAR_ROLE(), address(unlimitedRegistrar));
        
        vm.prank(OWNER);
        unlimitedRegistrar.openMinting();
        
        // Should be able to mint many
        vm.prank(USER1);
        unlimitedRegistrar.mintBatch{value: MINT_PRICE * 50}(50);
        
        assertEq(unlimitedRegistrar.totalMinted(), 50, "Should mint 50");
        assertEq(unlimitedRegistrar.remainingSupply(), type(uint256).max, "Unlimited should return max uint");
    }
    
    function test_043____maxSupply____RemainingSupplyCorrect() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        assertEq(registrar.remainingSupply(), MAX_SUPPLY, "Should be full supply initially");
        
        vm.prank(USER1);
        registrar.mintBatch{value: MINT_PRICE * 10}(10);
        
        assertEq(registrar.remainingSupply(), MAX_SUPPLY - 10, "Should reduce by minted amount");
    }
    
    /* ============================================================== */
    /*                     ADMIN FUNCTIONS                            */
    /* ============================================================== */
    
    function test_050____admin____CanSetMintPrice() public {
        uint256 newPrice = 0.05 ether;
        
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit MintPriceUpdated(MINT_PRICE, newPrice);
        registrar.setMintPrice(newPrice);
        
        assertEq(registrar.mintPrice(), newPrice, "Mint price should be updated");
    }
    
    function test_051____admin____CanSetMaxSupply() public {
        uint256 newSupply = 500;
        
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit MaxSupplyUpdated(MAX_SUPPLY, newSupply);
        registrar.setMaxSupply(newSupply);
        
        assertEq(registrar.maxSupply(), newSupply, "Max supply should be updated");
    }
    
    function test_052____admin____CannotSetMaxSupplyBelowMinted() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.prank(USER1);
        registrar.mintBatch{value: MINT_PRICE * 10}(10);
        
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(
            AgentRegistrar.MaxSupplyTooLow.selector,
            5,
            10
        ));
        registrar.setMaxSupply(5);
    }
    
    function test_053____admin____NonOwnerCannotSetMintPrice() public {
        vm.prank(RANDOM);
        vm.expectRevert();
        registrar.setMintPrice(0.05 ether);
    }
    
    function test_054____admin____NonOwnerCannotSetMaxSupply() public {
        vm.prank(RANDOM);
        vm.expectRevert();
        registrar.setMaxSupply(500);
    }
    
    /* ============================================================== */
    /*                        LOCK BITS                               */
    /* ============================================================== */
    
    function test_060____lockBits____CanLockOpenClose() public {
        vm.startPrank(OWNER);
        
        vm.expectEmit(true, true, true, true);
        emit LockBitSet(registrar.LOCK_OPEN_CLOSE());
        registrar.setLockBit(registrar.LOCK_OPEN_CLOSE());
        
        assertTrue(registrar.isLocked(registrar.LOCK_OPEN_CLOSE()), "Should be locked");
        
        vm.expectRevert(AgentRegistrar.FunctionLocked.selector);
        registrar.openMinting();
        vm.stopPrank();
    }
    
    function test_061____lockBits____CanLockMintPrice() public {
        vm.startPrank(OWNER);
        registrar.setLockBit(registrar.LOCK_MINT_PRICE());
        
        vm.expectRevert(AgentRegistrar.FunctionLocked.selector);
        registrar.setMintPrice(0.05 ether);
        vm.stopPrank();
    }
    
    function test_062____lockBits____CanLockMaxSupply() public {
        vm.startPrank(OWNER);
        registrar.setLockBit(registrar.LOCK_MAX_SUPPLY());
        
        vm.expectRevert(AgentRegistrar.FunctionLocked.selector);
        registrar.setMaxSupply(500);
        vm.stopPrank();
    }
    
    function test_063____lockBits____InvalidLockBitReverts() public {
        vm.prank(OWNER);
        vm.expectRevert(AgentRegistrar.InvalidLockBit.selector);
        registrar.setLockBit(1 << 5); // Invalid bit
    }
    
    function test_064____lockBits____MultipleBitsCanBeSet() public {
        vm.startPrank(OWNER);
        registrar.setLockBit(registrar.LOCK_OPEN_CLOSE());
        registrar.setLockBit(registrar.LOCK_MINT_PRICE());
        vm.stopPrank();
        
        assertTrue(registrar.isLocked(registrar.LOCK_OPEN_CLOSE()), "LOCK_OPEN_CLOSE should be set");
        assertTrue(registrar.isLocked(registrar.LOCK_MINT_PRICE()), "LOCK_MINT_PRICE should be set");
        assertFalse(registrar.isLocked(registrar.LOCK_MAX_SUPPLY()), "LOCK_MAX_SUPPLY should not be set");
    }
    
    /* ============================================================== */
    /*                        WITHDRAWALS                             */
    /* ============================================================== */
    
    function test_070____withdraw____OwnerCanWithdrawAll() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        // Collect some fees
        vm.prank(USER1);
        registrar.mintBatch{value: MINT_PRICE * 10}(10);
        
        uint256 contractBalance = address(registrar).balance;
        uint256 ownerBalanceBefore = OWNER.balance;
        
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(OWNER, contractBalance);
        registrar.withdraw();
        
        assertEq(address(registrar).balance, 0, "Contract should be empty");
        assertEq(OWNER.balance, ownerBalanceBefore + contractBalance, "Owner should receive funds");
    }
    
    function test_071____withdraw____OwnerCanWithdrawAmount() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.prank(USER1);
        registrar.mintBatch{value: MINT_PRICE * 10}(10);
        
        uint256 withdrawAmount = 0.05 ether;
        uint256 ownerBalanceBefore = OWNER.balance;
        
        vm.prank(OWNER);
        registrar.withdraw(withdrawAmount);
        
        assertEq(OWNER.balance, ownerBalanceBefore + withdrawAmount, "Owner should receive amount");
    }
    
    function test_072____withdraw____NonOwnerCannotWithdraw() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.prank(USER1);
        registrar.mint{value: MINT_PRICE}();
        
        vm.prank(RANDOM);
        vm.expectRevert();
        registrar.withdraw();
    }
    
    function test_073____withdraw____RevertsOnInsufficientBalance() public {
        vm.prank(OWNER);
        vm.expectRevert(AgentRegistrar.TransferFailed.selector);
        registrar.withdraw(1 ether);
    }
    
    /* ============================================================== */
    /*                    METADATA MINTING                            */
    /* ============================================================== */
    
    function test_080____metadataMint____WithBasicMetadata() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.prank(USER1);
        uint256 agentId = registrar.mint{value: MINT_PRICE}(
            USER1,
            "mcp",
            "https://agent.example.com",
            address(0x9999)
        );
        
        assertEq(registry.ownerOf(agentId), USER1, "USER1 should own the agent");
        assertEq(string(registry.getMetadata(agentId, "endpoint_type")), "mcp", "endpoint_type should be set");
        assertEq(string(registry.getMetadata(agentId, "endpoint")), "https://agent.example.com", "endpoint should be set");
    }
    
    function test_081____metadataMint____WithFlexibleMetadata() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        IAgentRegistry.MetadataEntry[] memory metadata = new IAgentRegistry.MetadataEntry[](2);
        metadata[0] = IAgentRegistry.MetadataEntry("name", bytes("Test Agent"));
        metadata[1] = IAgentRegistry.MetadataEntry("description", bytes("A test agent"));
        
        vm.prank(USER1);
        uint256 agentId = registrar.mint{value: MINT_PRICE}(USER1, metadata);
        
        assertEq(registry.ownerOf(agentId), USER1, "USER1 should own the agent");
        assertEq(string(registry.getMetadata(agentId, "name")), "Test Agent", "name should be set");
        assertEq(string(registry.getMetadata(agentId, "description")), "A test agent", "description should be set");
    }
    
    function test_082____metadataMint____BatchWithMetadata() public {
        vm.prank(OWNER);
        registrar.openMinting();
        
        IAgentRegistry.MetadataEntry[][] memory allMetadata = new IAgentRegistry.MetadataEntry[][](2);
        
        allMetadata[0] = new IAgentRegistry.MetadataEntry[](1);
        allMetadata[0][0] = IAgentRegistry.MetadataEntry("name", bytes("Agent 1"));
        
        allMetadata[1] = new IAgentRegistry.MetadataEntry[](1);
        allMetadata[1][0] = IAgentRegistry.MetadataEntry("name", bytes("Agent 2"));
        
        vm.prank(USER1);
        uint256[] memory agentIds = registrar.mintBatch{value: MINT_PRICE * 2}(USER1, allMetadata);
        
        assertEq(agentIds.length, 2, "Should mint 2 agents");
        assertEq(string(registry.getMetadata(agentIds[0], "name")), "Agent 1", "Agent 1 name");
        assertEq(string(registry.getMetadata(agentIds[1], "name")), "Agent 2", "Agent 2 name");
    }
    
    /* ============================================================== */
    /*                       FREE MINTING                             */
    /* ============================================================== */
    
    function test_090____freeMint____WorksWithZeroPrice() public {
        AgentRegistrar freeRegistrar = new AgentRegistrar(registry, 0, MAX_SUPPLY, OWNER);
        registry.grantRole(registry.REGISTRAR_ROLE(), address(freeRegistrar));
        
        vm.prank(OWNER);
        freeRegistrar.openMinting();
        
        vm.prank(USER1);
        uint256 agentId = freeRegistrar.mint();
        
        assertEq(registry.ownerOf(agentId), USER1, "Should mint without payment");
    }
    
    function test_091____freeMint____BatchWorksWithZeroPrice() public {
        AgentRegistrar freeRegistrar = new AgentRegistrar(registry, 0, MAX_SUPPLY, OWNER);
        registry.grantRole(registry.REGISTRAR_ROLE(), address(freeRegistrar));
        
        vm.prank(OWNER);
        freeRegistrar.openMinting();
        
        vm.prank(USER1);
        uint256[] memory agentIds = freeRegistrar.mintBatch(10);
        
        assertEq(agentIds.length, 10, "Should mint 10 agents");
    }
    
    /* ============================================================== */
    /*                        FUZZ TESTS                              */
    /* ============================================================== */
    
    function testFuzz_mint(uint256 payment) public {
        vm.assume(payment >= MINT_PRICE && payment <= 10 ether);
        
        vm.prank(OWNER);
        registrar.openMinting();
        
        vm.deal(USER1, payment);
        uint256 balanceBefore = USER1.balance;
        
        vm.prank(USER1);
        registrar.mint{value: payment}();
        
        assertEq(balanceBefore - USER1.balance, MINT_PRICE, "Should only charge mint price");
    }
    
    function testFuzz_mintBatch(uint8 count) public {
        vm.assume(count > 0 && count <= MAX_SUPPLY);
        
        vm.prank(OWNER);
        registrar.openMinting();
        
        uint256 totalCost = MINT_PRICE * count;
        vm.deal(USER1, totalCost);
        
        vm.prank(USER1);
        uint256[] memory agentIds = registrar.mintBatch{value: totalCost}(count);
        
        assertEq(agentIds.length, count, "Should mint correct count");
        assertEq(registrar.totalMinted(), count, "Total minted should match");
    }
    
    function testFuzz_setMintPrice(uint256 newPrice) public {
        vm.assume(newPrice <= 100 ether);
        
        vm.prank(OWNER);
        registrar.setMintPrice(newPrice);
        
        assertEq(registrar.mintPrice(), newPrice, "Price should be updated");
    }
}

