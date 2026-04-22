// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IGroupDefaults} from "./interfaces/IGroupDefaults.sol";

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

    function _ownerOfOrRevert(uint256 groupId) internal view returns (address owner) {
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
        try IERC721(GROUP_ADDRESS).ownerOf(groupId) returns (
            address owner
        ) {
            if (owner == account) {
                return groupId;
            }
        } catch {}
        return 0;
    }
}
