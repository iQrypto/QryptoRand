// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Token} from "../src/IQryptoToken.sol";

contract TestIQryptoToken is Test {
    Token private token;
    address private owner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address private user1 = address(0x456);
    address private user2 = address(0x789);
    address private authorizedContract = address(0xabc);

    uint256 private initialSupply = 1000 * 10 ** 18;

    /// @notice Tests that the token name is correctly set.
    function testName() public view {
        assertEq(token.name(), "IQryptoToken", "Bad name");
    }

    /// @notice Tests that the token symbol is correctly set.
    function testSymbol() public view {
        assertEq(token.symbol(), "Ypto", "Bad symbol");
    }

    /// @notice Initializes a fresh Token instance with the initial supply before each test.
    function setUp() public {
        vm.startPrank(owner);
        token = new Token(initialSupply);
        vm.stopPrank();
    }

    /// @notice Tests that the initial token supply is correctly minted to the owner.
    function testInitialSupply() public view {
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.balanceOf(address(token)), initialSupply);
    }

    /// @notice Tests that token transfers between users succeed and update balances.
    function testTransfer() public {
        vm.prank(address(token));
        bool success = token.transfer(user1, 1 * 10 ** 18);
        assertTrue(success);
        assertEq(token.balanceOf(user1), 1 * 10 ** 18);
        assertEq(token.balanceOf(address(token)), initialSupply - 1 * 10 ** 18);
    }

    /// @notice Tests that unauthorized contracts cannot call transferGenerationNumber.
    function testRevertUnauthorizedContract() public {
        vm.prank(user1);
        vm.expectRevert();
        token.transferGenerationNumber(user2);
    }

    /// @notice Tests that an authorized contract can call transferGenerationNumber successfully.
    function testSetAuthorizedContract() public {
        vm.prank(owner);
        token.setAuthorizedContract(authorizedContract);
        vm.prank(authorizedContract);
        bool success = token.transferGenerationNumber(user1);
        assertTrue(success);
    }

    /// @notice Tests that the owner can mint additional tokens to a recipient.
    function testMint() public {
        vm.prank(owner);
        token.mint(user1, 500 * 10 ** 18);
        assertEq(token.balanceOf(user1), 500 * 10 ** 18);
    }

    /// @notice Tests that the owner can burn tokens from their own balance.
    function testBurn() public {
        vm.prank(owner);
        token.burn(address(token), 200 * 10 ** 18);
        assertEq(token.totalSupply(), initialSupply - 200 * 10 ** 18);
    }

    /// @notice Tests that approve sets correct allowance for a spender.
    function testApprove() public {
        vm.startPrank(owner);
        token.approve(user1, 300 * 10 ** 18);
        assertEq(token.allowance(owner, user1), 300 * 10 ** 18);
        vm.stopPrank();
    }

    /// @notice Tests that transferFrom allows an approved user to spend tokens on behalf of another.
    function testTransferFrom() public {
        vm.prank(owner);
        token.mint(user1, 300 * 10 ** 18);

        vm.prank(user1);
        token.approve(user2, 300 * 10 ** 18);

        vm.prank(user2);
        bool success = token.transferFrom(user1, user2, 200 * 10 ** 18);

        assertTrue(success);
        assertEq(token.balanceOf(user2), 200 * 10 ** 18);
        assertEq(token.allowance(user1, user2), 100 * 10 ** 18);
    }

    /// @notice Tests that only the owner can mint tokens.
    function testRevertNonOwnerCannotMint() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user1, 1 ether);
    }

    /// @notice Tests that only the owner can burn tokens.
    function testRevertNonOwnerCannotBurn() public {
        vm.prank(user1);
        vm.expectRevert();
        token.burn(owner, 1 ether);
    }

    /// @notice Ensures transferGenerationNumber updates the totalDistributed mapping.
    function testTotalDistributedTracksCorrectly() public {
        vm.prank(owner);
        token.setAuthorizedContract(authorizedContract);

        // Top up contract balance if needed (depends on your mint logic)
        // Already minted in constructor to address(token)

        vm.prank(authorizedContract);
        token.transferGenerationNumber(user1);

        uint256 distributed = token.totalDistributed(user1);
        assertGt(
            distributed,
            0,
            "Distribution amount should be greater than zero"
        );
        assertEq(
            token.balanceOf(user1),
            distributed,
            "User should receive exactly distributed amount"
        );
    }

    /// @notice Verifies that allowance is reduced after transferFrom.
    function testAllowanceReductionAfterTransferFrom() public {
        vm.prank(owner);
        token.mint(user1, 300 * 10 ** 18);

        vm.prank(user1);
        token.approve(user2, 300 * 10 ** 18);

        vm.prank(user2);
        token.transferFrom(user1, user2, 200 * 10 ** 18);

        assertEq(token.allowance(user1, user2), 100 * 10 ** 18);
    }

    /// @notice Transfers a reward from the contract to the generator wallet and the owner.
    /// @dev 80% of the calculated amount is sent to the generator, and 20% is sent to the owner.
    /// Reverts if the generator exceeds their max distribution cap or if caller is unauthorized.
    function testTransferGenerationNumberSplitsCorrectly() public {
        vm.prank(owner);
        token.setAuthorizedContract(authorizedContract);

        uint256 initialBalance = token.balanceOf(address(token));
        uint256 totalAmount = (initialBalance * 1e18) /
            (2 * token.totalSupply());
        uint256 expectedGenerator = (totalAmount * 80) / 100;
        uint256 expectedOwner = totalAmount - expectedGenerator;

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 userBalanceBefore = token.balanceOf(user1);

        vm.prank(authorizedContract);
        token.transferGenerationNumber(user1);

        assertEq(token.balanceOf(user1), userBalanceBefore + expectedGenerator);
        assertEq(token.balanceOf(owner), ownerBalanceBefore + expectedOwner);
    }
}
