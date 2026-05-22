// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {GroupDelegate} from "../src/GroupDelegate.sol";
import {LOVE20Group} from "../src/LOVE20Group.sol";
import {IGroupDelegateErrors, IGroupDelegateEvents} from "../src/interfaces/IGroupDelegate.sol";
import {MockLOVE20Token} from "./mocks/MockLOVE20Token.sol";

contract GroupDelegateTest is Test, IGroupDelegateEvents {
    LOVE20Group public group;
    GroupDelegate public groupDelegate;
    MockLOVE20Token public love20Token;

    address public owner;
    address public delegateOwner;
    address public other;

    uint256 public groupId;
    uint256 public delegateId;

    uint256 constant MAX_SUPPLY = 21_000_000_000 * 1e18;
    uint256 constant BASE_DIVISOR = 1e7;
    uint256 constant BYTES_THRESHOLD = 7;
    uint256 constant MULTIPLIER = 10;
    uint256 constant MAX_GROUP_NAME_LENGTH = 64;

    function setUp() public {
        owner = makeAddr("owner");
        delegateOwner = makeAddr("delegateOwner");
        other = makeAddr("other");

        love20Token = new MockLOVE20Token("LOVE20", "LOVE", MAX_SUPPLY);
        group = new LOVE20Group(address(love20Token), BASE_DIVISOR, BYTES_THRESHOLD, MULTIPLIER, MAX_GROUP_NAME_LENGTH);
        groupDelegate = new GroupDelegate(address(group));

        love20Token.mint(owner, 1_000_000 * 1e18);
        love20Token.mint(delegateOwner, 1_000_000 * 1e18);
        love20Token.mint(other, 1_000_000 * 1e18);

        groupId = _mintGroupFor(owner, "AlphaGroup");
        delegateId = _mintGroupFor(delegateOwner, "DelegateGroup");
    }

    function testInitialization() public view {
        assertEq(groupDelegate.GROUP_ADDRESS(), address(group));
    }

    function testConstructorRevertsForZeroGroupAddress() public {
        vm.expectRevert(IGroupDelegateErrors.InvalidAddress.selector);
        new GroupDelegate(address(0));
    }

    function testSetDelegateIdAndOperatorQueries() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit SetDelegateId(groupId, owner, delegateId, 0);
        groupDelegate.setDelegateId(groupId, delegateId);

        assertEq(groupDelegate.delegateIdOf(groupId), delegateId);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, owner), groupId);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, delegateOwner), delegateId);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, other), 0);
        assertTrue(groupDelegate.isOwnerOrDelegate(groupId, owner));
        assertTrue(groupDelegate.isOwnerOrDelegate(groupId, delegateOwner));
        assertTrue(!groupDelegate.isOwnerOrDelegate(groupId, other));
    }

    function testDelegateIdsOf() public {
        uint256 otherGroupId = _mintGroupFor(other, "OtherGroup");

        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);

        uint256[] memory groupIds = new uint256[](2);
        groupIds[0] = groupId;
        groupIds[1] = otherGroupId;

        uint256[] memory delegateIds = groupDelegate.delegateIdsOf(groupIds);
        assertEq(delegateIds.length, 2);
        assertEq(delegateIds[0], delegateId);
        assertEq(delegateIds[1], 0);
    }

    function testCanSetDelegateToZeroDelegateId() public view {
        assertTrue(groupDelegate.canSetDelegateTo(groupId, 0));
    }

    function testCanSetDelegateToSelfReturnsFalse() public view {
        assertTrue(!groupDelegate.canSetDelegateTo(groupId, groupId));
    }

    function testDelegatedGroupIdsReturnsRawListWithEffectiveness() public {
        uint256 secondGroupId = _mintGroupFor(owner, "SecondGroup");

        vm.startPrank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);
        groupDelegate.setDelegateId(secondGroupId, delegateId);
        group.transferFrom(owner, other, groupId);
        vm.stopPrank();

        (uint256[] memory firstPage, bool[] memory firstEffective, uint256 total) =
            groupDelegate.delegatedGroupIds(delegateId, 0, 1);
        assertEq(total, 2);
        assertEq(groupDelegate.delegatedGroupIdsCount(delegateId), total);
        assertEq(firstPage.length, 1);
        assertEq(firstEffective.length, 1);
        assertEq(firstPage[0], groupId);
        assertTrue(!firstEffective[0]);

        (uint256[] memory secondPage, bool[] memory secondEffective,) =
            groupDelegate.delegatedGroupIds(delegateId, 1, 10);
        assertEq(secondPage.length, 1);
        assertEq(secondEffective.length, 1);
        assertEq(secondPage[0], secondGroupId);
        assertTrue(secondEffective[0]);
    }

    function testDelegatedGroupIdsUpdatesWhenDelegateChangesOrClears() public {
        uint256 secondDelegateId = _mintGroupFor(other, "SecondDelegate");

        vm.startPrank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);
        groupDelegate.setDelegateId(groupId, secondDelegateId);
        vm.stopPrank();

        (uint256[] memory oldDelegateGroups,, uint256 oldTotal) = groupDelegate.delegatedGroupIds(delegateId, 0, 10);
        assertEq(oldTotal, 0);
        assertEq(oldDelegateGroups.length, 0);

        (uint256[] memory newDelegateGroups, bool[] memory newEffective, uint256 newTotal) =
            groupDelegate.delegatedGroupIds(secondDelegateId, 0, 10);
        assertEq(newTotal, 1);
        assertEq(newDelegateGroups.length, 1);
        assertEq(newDelegateGroups[0], groupId);
        assertTrue(newEffective[0]);

        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, 0);

        (uint256[] memory clearedGroups,, uint256 clearedTotal) =
            groupDelegate.delegatedGroupIds(secondDelegateId, 0, 10);
        assertEq(clearedTotal, 0);
        assertEq(clearedGroups.length, 0);
    }

    function testDelegateOwnerCanClearDelegatedGroupIds() public {
        uint256 secondGroupId = _mintGroupFor(owner, "SecondGroup");
        uint256 unrelatedDelegateId = _mintGroupFor(other, "UnrelatedDelegate");

        vm.startPrank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);
        groupDelegate.setDelegateId(secondGroupId, delegateId);
        vm.stopPrank();

        uint256[] memory groupIds = new uint256[](3);
        groupIds[0] = groupId;
        groupIds[1] = secondGroupId;
        groupIds[2] = unrelatedDelegateId;

        vm.startPrank(delegateOwner);
        vm.expectEmit(true, true, true, true);
        emit ClearDelegatedGroupId(groupId, delegateId, delegateOwner);
        vm.expectEmit(true, true, true, true);
        emit ClearDelegatedGroupId(secondGroupId, delegateId, delegateOwner);
        groupDelegate.clearDelegatedGroupIds(delegateId, groupIds);
        vm.stopPrank();

        assertEq(groupDelegate.delegateIdOf(groupId), 0);
        assertEq(groupDelegate.delegateIdOf(secondGroupId), 0);
        (uint256[] memory delegatedGroups,, uint256 total) = groupDelegate.delegatedGroupIds(delegateId, 0, 10);
        assertEq(total, 0);
        assertEq(delegatedGroups.length, 0);
    }

    function testDelegatorWhitelistIsDisabledByDefault() public {
        assertTrue(!groupDelegate.isDelegatorWhitelistEnabled(delegateId));
        assertTrue(groupDelegate.canSetDelegateTo(groupId, delegateId));

        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);

        assertEq(groupDelegate.delegateIdOf(groupId), delegateId);
    }

    function testDelegateOwnerCanEnableDelegatorWhitelist() public {
        uint256 secondGroupId = _mintGroupFor(owner, "SecondGroup");

        vm.prank(delegateOwner);
        vm.expectEmit(true, true, true, true);
        emit SetDelegatorWhitelistEnabled(delegateId, delegateOwner, true);
        groupDelegate.setDelegatorWhitelistEnabled(delegateId, true);

        assertTrue(groupDelegate.isDelegatorWhitelistEnabled(delegateId));
        assertTrue(!groupDelegate.canSetDelegateTo(groupId, delegateId));

        vm.prank(owner);
        vm.expectRevert(IGroupDelegateErrors.DelegatorGroupIdNotAllowed.selector);
        groupDelegate.setDelegateId(groupId, delegateId);

        uint256[] memory allowedGroupIds = new uint256[](2);
        allowedGroupIds[0] = groupId;
        allowedGroupIds[1] = secondGroupId;

        vm.startPrank(delegateOwner);
        vm.expectEmit(true, true, true, true);
        emit SetAllowedDelegatorGroupId(delegateId, groupId, delegateOwner, true);
        vm.expectEmit(true, true, true, true);
        emit SetAllowedDelegatorGroupId(delegateId, secondGroupId, delegateOwner, true);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, allowedGroupIds, true);
        vm.stopPrank();

        assertTrue(groupDelegate.canSetDelegateTo(groupId, delegateId));
        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);
        vm.prank(owner);
        groupDelegate.setDelegateId(secondGroupId, delegateId);
        assertEq(groupDelegate.delegateIdOf(groupId), delegateId);
        assertEq(groupDelegate.delegateIdOf(secondGroupId), delegateId);

        (uint256[] memory firstPage, uint256 total) = groupDelegate.allowedDelegatorGroupIds(delegateId, 0, 1);
        assertEq(total, 2);
        assertEq(groupDelegate.allowedDelegatorGroupIdsCount(delegateId), total);
        assertEq(firstPage.length, 1);
        assertEq(firstPage[0], groupId);

        (uint256[] memory secondPage,) = groupDelegate.allowedDelegatorGroupIds(delegateId, 1, 10);
        assertEq(secondPage.length, 1);
        assertEq(secondPage[0], secondGroupId);

        uint256[] memory removeGroupIds = new uint256[](1);
        removeGroupIds[0] = groupId;
        vm.prank(delegateOwner);
        vm.expectEmit(true, true, true, true);
        emit SetAllowedDelegatorGroupId(delegateId, groupId, delegateOwner, false);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, removeGroupIds, false);

        assertTrue(!groupDelegate.canSetDelegateTo(groupId, delegateId));
        assertEq(groupDelegate.delegateIdOf(groupId), 0);
        assertEq(groupDelegate.delegateIdOf(secondGroupId), delegateId);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, delegateOwner), 0);
    }

    function testWhitelistRemovalTemporarilyDisablesDelegateAndRestoresOnReallow() public {
        uint256[] memory allowedGroupIds = new uint256[](1);
        allowedGroupIds[0] = groupId;

        vm.startPrank(delegateOwner);
        groupDelegate.setDelegatorWhitelistEnabled(delegateId, true);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, allowedGroupIds, true);
        vm.stopPrank();

        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);

        vm.prank(delegateOwner);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, allowedGroupIds, false);

        assertTrue(!groupDelegate.canSetDelegateTo(groupId, delegateId));
        assertEq(groupDelegate.delegateIdOf(groupId), 0);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, delegateOwner), 0);
        assertTrue(!groupDelegate.isOwnerOrDelegate(groupId, delegateOwner));
        (uint256[] memory rawGroups, bool[] memory effectiveGroups, uint256 total) =
            groupDelegate.delegatedGroupIds(delegateId, 0, 10);
        assertEq(total, 1);
        assertEq(rawGroups.length, 1);
        assertEq(effectiveGroups.length, 1);
        assertEq(rawGroups[0], groupId);
        assertTrue(!effectiveGroups[0]);

        vm.recordLogs();
        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);

        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(groupDelegate.delegateIdOf(groupId), 0);
        assertEq(groupDelegate.delegatedGroupIdsCount(delegateId), 1);

        vm.prank(delegateOwner);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, allowedGroupIds, true);

        assertEq(groupDelegate.delegateIdOf(groupId), delegateId);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, delegateOwner), delegateId);
    }

    function testDelegateOwnerCanDisableDelegatorWhitelist() public {
        vm.prank(delegateOwner);
        groupDelegate.setDelegatorWhitelistEnabled(delegateId, true);
        assertTrue(!groupDelegate.canSetDelegateTo(groupId, delegateId));

        vm.prank(delegateOwner);
        vm.expectEmit(true, true, true, true);
        emit SetDelegatorWhitelistEnabled(delegateId, delegateOwner, false);
        groupDelegate.setDelegatorWhitelistEnabled(delegateId, false);

        assertTrue(!groupDelegate.isDelegatorWhitelistEnabled(delegateId));
        assertTrue(groupDelegate.canSetDelegateTo(groupId, delegateId));
    }

    function testDelegatePolicyNoopsDoNotEmit() public {
        vm.prank(delegateOwner);
        groupDelegate.setDelegatorWhitelistEnabled(delegateId, true);

        vm.recordLogs();
        vm.prank(delegateOwner);
        groupDelegate.setDelegatorWhitelistEnabled(delegateId, true);
        assertEq(vm.getRecordedLogs().length, 0);

        uint256[] memory groupIds = new uint256[](1);
        groupIds[0] = groupId;

        vm.prank(delegateOwner);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, groupIds, true);

        vm.recordLogs();
        vm.prank(delegateOwner);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, groupIds, true);
        assertEq(vm.getRecordedLogs().length, 0);

        vm.prank(delegateOwner);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, groupIds, false);

        vm.recordLogs();
        vm.prank(delegateOwner);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, groupIds, false);
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function testDelegatePolicyRevertsWhenSenderNotDelegateOwner() public {
        vm.prank(other);
        vm.expectRevert(IGroupDelegateErrors.SenderNotDelegateOwner.selector);
        groupDelegate.setDelegatorWhitelistEnabled(delegateId, true);

        uint256[] memory groupIds = new uint256[](1);
        groupIds[0] = groupId;

        vm.prank(other);
        vm.expectRevert(IGroupDelegateErrors.SenderNotDelegateOwner.selector);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, groupIds, true);
    }

    function testClearDelegatedGroupIdsRevertsWhenSenderNotDelegateOwner() public {
        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);

        uint256[] memory groupIds = new uint256[](1);
        groupIds[0] = groupId;

        vm.prank(other);
        vm.expectRevert(IGroupDelegateErrors.SenderNotDelegateOwner.selector);
        groupDelegate.clearDelegatedGroupIds(delegateId, groupIds);

        assertEq(groupDelegate.delegateIdOf(groupId), delegateId);
    }

    function testDelegateInvalidatesAndRestoresAcrossTransfer() public {
        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);

        vm.prank(owner);
        group.transferFrom(owner, other, groupId);

        assertEq(groupDelegate.delegateIdOf(groupId), 0);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, owner), 0);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, delegateOwner), 0);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, other), groupId);

        vm.prank(other);
        group.transferFrom(other, owner, groupId);

        assertEq(groupDelegate.delegateIdOf(groupId), delegateId);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, delegateOwner), delegateId);
    }

    function testDelegateInvalidatesAndRestoresAcrossDelegateTransfer() public {
        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);

        vm.prank(delegateOwner);
        group.transferFrom(delegateOwner, other, delegateId);

        assertEq(groupDelegate.delegateIdOf(groupId), 0);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, delegateOwner), 0);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, other), 0);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit SetDelegateId(groupId, owner, delegateId, 0);
        groupDelegate.setDelegateId(groupId, delegateId);

        assertEq(groupDelegate.delegateIdOf(groupId), delegateId);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, delegateOwner), 0);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, other), delegateId);

        vm.prank(other);
        group.transferFrom(other, delegateOwner, delegateId);

        assertEq(groupDelegate.delegateIdOf(groupId), 0);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, delegateOwner), 0);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, other), 0);

        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);

        assertEq(groupDelegate.delegateIdOf(groupId), delegateId);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, delegateOwner), delegateId);
    }

    function testClearDelegateId() public {
        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit SetDelegateId(groupId, owner, 0, delegateId);
        groupDelegate.setDelegateId(groupId, 0);

        assertEq(groupDelegate.delegateIdOf(groupId), 0);
        assertEq(groupDelegate.ownerOrDelegateIdOf(groupId, delegateOwner), 0);
    }

    function testSettingSameDelegateIsNoop() public {
        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);

        vm.recordLogs();
        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);

        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(groupDelegate.delegateIdOf(groupId), delegateId);
    }

    function testNewOwnerCanClearStaleDelegate() public {
        vm.prank(owner);
        groupDelegate.setDelegateId(groupId, delegateId);

        vm.prank(owner);
        group.transferFrom(owner, other, groupId);
        assertEq(groupDelegate.delegateIdOf(groupId), 0);

        vm.prank(other);
        vm.expectEmit(true, true, true, true);
        emit SetDelegateId(groupId, other, 0, 0);
        groupDelegate.setDelegateId(groupId, 0);

        vm.prank(other);
        group.transferFrom(other, owner, groupId);
        assertEq(groupDelegate.delegateIdOf(groupId), 0);
    }

    function testInvalidSetDelegateIdCases() public {
        vm.prank(other);
        vm.expectRevert(IGroupDelegateErrors.SenderNotGroupOwner.selector);
        groupDelegate.setDelegateId(groupId, delegateId);

        vm.prank(owner);
        vm.expectRevert(IGroupDelegateErrors.DelegateIdCannotBeGroupId.selector);
        groupDelegate.setDelegateId(groupId, groupId);

        vm.prank(owner);
        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.setDelegateId(groupId, 999999);

        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.delegateIdOf(999999);

        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.ownerOrDelegateIdOf(999999, owner);

        uint256[] memory groupIds = new uint256[](1);
        groupIds[0] = 999999;
        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.delegateIdsOf(groupIds);

        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.delegatedGroupIds(999999, 0, 10);

        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.clearDelegatedGroupIds(999999, groupIds);

        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.setDelegatorWhitelistEnabled(999999, true);

        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.setAllowedDelegatorGroupIds(999999, groupIds, true);

        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.isDelegatorWhitelistEnabled(999999);

        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.canSetDelegateTo(999999, delegateId);

        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.canSetDelegateTo(groupId, 999999);

        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.allowedDelegatorGroupIds(999999, 0, 10);

        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.allowedDelegatorGroupIdsCount(999999);

        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.delegatedGroupIdsCount(999999);
    }

    function testAllowedDelegatorGroupIdsRevertsForInvalidGroupId() public {
        uint256[] memory groupIds = new uint256[](1);

        groupIds[0] = 0;
        vm.prank(delegateOwner);
        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, groupIds, true);

        groupIds[0] = group.totalSupply() + 1;
        vm.prank(delegateOwner);
        vm.expectRevert(IGroupDelegateErrors.GroupNotExist.selector);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, groupIds, true);
    }

    function testAllowedDelegatorGroupIdsRevertsForDelegateIdItself() public {
        uint256[] memory groupIds = new uint256[](1);
        groupIds[0] = delegateId;

        vm.prank(delegateOwner);
        vm.expectRevert(IGroupDelegateErrors.DelegateIdCannotBeGroupId.selector);
        groupDelegate.setAllowedDelegatorGroupIds(delegateId, groupIds, true);
    }

    function _mintGroupFor(address to, string memory groupName) internal returns (uint256 tokenId) {
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(to);
        love20Token.approve(address(group), mintCost);
        (tokenId,) = group.mint(groupName);
        vm.stopPrank();
    }
}
