// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IGroupDefaults} from "./interfaces/IGroupDefaults.sol";
import {ILOVE20Group} from "./interfaces/ILOVE20Group.sol";

contract GroupDefaults is IGroupDefaults {
    address public immutable GROUP_ADDRESS;

    mapping(address => uint256) internal _defaultGroupIds;

    constructor(address groupAddress_) {
        GROUP_ADDRESS = groupAddress_;
    }

    function setDefaultGroupId(uint256 groupId) external {
        address senderOwner = _ownerOfOrRevert(groupId);
        if (msg.sender != senderOwner) revert SenderNotGroupOwner();
        if (_defaultGroupIds[msg.sender] == groupId) {
            revert DefaultGroupIdAlreadySet(groupId);
        }
        _defaultGroupIds[msg.sender] = groupId;
        emit DefaultGroupIdSet(msg.sender, groupId);
    }

    function clearDefaultGroupId() external {
        uint256 prevGroupId = _defaultGroupIds[msg.sender];
        if (prevGroupId == 0) revert DefaultGroupIdNotStored();
        delete _defaultGroupIds[msg.sender];
        emit DefaultGroupIdCleared(msg.sender, prevGroupId);
    }

    function defaultGroupIdOf(address account) external view returns (uint256) {
        return _effectiveDefaultGroupId(account);
    }

    function defaultGroupsOf(
        address[] calldata accounts
    )
        external
        view
        returns (uint256[] memory groupIds, string[] memory groupNames)
    {
        uint256 length = accounts.length;
        groupIds = new uint256[](length);
        groupNames = new string[](length);

        ILOVE20Group group = ILOVE20Group(GROUP_ADDRESS);

        for (uint256 i; i < length; ) {
            uint256 groupId = _effectiveDefaultGroupId(accounts[i]);
            groupIds[i] = groupId;

            if (groupId != 0) {
                groupNames[i] = group.groupNameOf(groupId);
            }

            unchecked {
                ++i;
            }
        }
    }

    function _ownerOfOrRevert(
        uint256 groupId
    ) internal view returns (address owner) {
        try IERC721(GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
            return resolved;
        } catch {
            revert GroupNotExist();
        }
    }

    function _effectiveDefaultGroupId(
        address account
    ) internal view returns (uint256 groupId) {
        groupId = _defaultGroupIds[account];
        if (groupId == 0) {
            return 0;
        }
        return IERC721(GROUP_ADDRESS).ownerOf(groupId) == account ? groupId : 0;
    }
}
