// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {LOVE20Group} from "../src/LOVE20Group.sol";
import {GroupDefaults} from "../src/GroupDefaults.sol";
import {
    IGroupDefaultsErrors
} from "../src/interfaces/IGroupDefaults.sol";
import {MockLOVE20Token} from "./mocks/MockLOVE20Token.sol";

contract GroupDefaultsTest is Test {
    LOVE20Group public group;
    GroupDefaults public groupDefaults;
    MockLOVE20Token public love20Token;

    address public user1;
    address public user2;

    uint256 constant MAX_SUPPLY = 21_000_000_000 * 1e18;
    uint256 constant BASE_DIVISOR = 1e7;
    uint256 constant BYTES_THRESHOLD = 7;
    uint256 constant MULTIPLIER = 10;
    uint256 constant MAX_GROUP_NAME_LENGTH = 64;

    function setUp() public {
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        love20Token = new MockLOVE20Token("LOVE20", "LOVE", MAX_SUPPLY);
        group = new LOVE20Group(
            address(love20Token),
            BASE_DIVISOR,
            BYTES_THRESHOLD,
            MULTIPLIER,
            MAX_GROUP_NAME_LENGTH
        );
        groupDefaults = new GroupDefaults(address(group));

        love20Token.mint(user1, 1_000_000 * 1e18);
        love20Token.mint(user2, 1_000_000 * 1e18);
    }

    function testInitialization() public view {
        assertEq(groupDefaults.GROUP_ADDRESS(), address(group));
    }

    function testDefaultGroupIdOfReturnsZeroWhenUnset() public view {
        assertEq(groupDefaults.defaultGroupIdOf(user1), 0);
    }

    function testSetDefaultGroupId() public {
        uint256 groupId = _mintGroupFor(user1, "AlphaGroup");

        vm.prank(user1);
        groupDefaults.setDefaultGroupId(groupId);

        assertEq(groupDefaults.defaultGroupIdOf(user1), groupId);
    }

    function testSetDefaultGroupIdRevertsWhenGroupNotExist() public {
        vm.prank(user1);
        vm.expectRevert(IGroupDefaultsErrors.GroupNotExist.selector);
        groupDefaults.setDefaultGroupId(999);
    }

    function testSetDefaultGroupIdRevertsWhenCallerNotOwner() public {
        uint256 groupId = _mintGroupFor(user1, "AlphaGroup");

        vm.prank(user2);
        vm.expectRevert(IGroupDefaultsErrors.SenderNotGroupOwner.selector);
        groupDefaults.setDefaultGroupId(groupId);
    }

    function testSetDefaultGroupIdRevertsWhenAlreadySet() public {
        uint256 groupId = _mintGroupFor(user1, "AlphaGroup");

        vm.startPrank(user1);
        groupDefaults.setDefaultGroupId(groupId);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGroupDefaultsErrors.DefaultGroupIdAlreadySet.selector,
                groupId
            )
        );
        groupDefaults.setDefaultGroupId(groupId);
        vm.stopPrank();
    }

    function testClearDefaultGroupId() public {
        uint256 groupId = _mintGroupFor(user1, "AlphaGroup");

        vm.startPrank(user1);
        groupDefaults.setDefaultGroupId(groupId);
        groupDefaults.clearDefaultGroupId();
        vm.stopPrank();

        assertEq(groupDefaults.defaultGroupIdOf(user1), 0);
    }

    function testClearDefaultGroupIdRevertsWhenNotStored() public {
        vm.prank(user1);
        vm.expectRevert(IGroupDefaultsErrors.DefaultGroupIdNotStored.selector);
        groupDefaults.clearDefaultGroupId();
    }

    function testDefaultGroupIdOfReturnsZeroAfterTransfer() public {
        uint256 groupId = _mintGroupFor(user1, "AlphaGroup");

        vm.prank(user1);
        groupDefaults.setDefaultGroupId(groupId);

        vm.prank(user1);
        group.transferFrom(user1, user2, groupId);

        assertEq(groupDefaults.defaultGroupIdOf(user1), 0);
        assertEq(groupDefaults.defaultGroupIdOf(user2), 0);
    }

    function testOwnerCanSetTransferredGroupAsDefault() public {
        uint256 groupId = _mintGroupFor(user1, "AlphaGroup");

        vm.prank(user1);
        group.transferFrom(user1, user2, groupId);

        vm.prank(user2);
        groupDefaults.setDefaultGroupId(groupId);

        assertEq(groupDefaults.defaultGroupIdOf(user2), groupId);
    }

    function testUserCanReplaceDefaultGroupId() public {
        uint256 firstGroupId = _mintGroupFor(user1, "AlphaGroup");
        uint256 secondGroupId = _mintGroupFor(user1, "BetaGroupX");

        vm.startPrank(user1);
        groupDefaults.setDefaultGroupId(firstGroupId);
        groupDefaults.setDefaultGroupId(secondGroupId);
        vm.stopPrank();

        assertEq(groupDefaults.defaultGroupIdOf(user1), secondGroupId);
    }

    function _mintGroupFor(
        address owner,
        string memory groupName
    ) internal returns (uint256 tokenId) {
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(owner);
        love20Token.approve(address(group), mintCost);
        (tokenId, ) = group.mint(groupName);
        vm.stopPrank();
    }
}
