#!/bin/bash

if [ -n "${ZSH_VERSION:-}" ]; then
    SCRIPT_PATH="$0"
elif [ -n "${BASH_VERSION:-}" ]; then
    SCRIPT_PATH="${BASH_SOURCE[0]}"
else
    SCRIPT_PATH="$0"
fi

SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$DEPLOY_DIR" || return 1

echo "========================================="
echo "Verifying GroupDelegate Configuration"
echo "========================================="

if [ -z "$groupAddress" ]; then
    if [ ! -f "$network_dir/address.group.params" ]; then
        echo -e "\033[31mError:\033[0m Group address file not found: $network_dir/address.group.params"
        return 1
    fi
    source "$network_dir/address.group.params"
fi

if [ -z "$groupDelegateAddress" ]; then
    if [ ! -f "$network_dir/address.group.delegate.params" ]; then
        echo -e "\033[31mError:\033[0m GroupDelegate address file not found: $network_dir/address.group.delegate.params"
        return 1
    fi
    source "$network_dir/address.group.delegate.params"
fi

if [ -z "$groupAddress" ]; then
    echo -e "\033[31mError:\033[0m groupAddress not set"
    return 1
fi

if [ -z "$groupDelegateAddress" ]; then
    echo -e "\033[31mError:\033[0m groupDelegateAddress not set"
    return 1
fi

echo -e "Group Address: $groupAddress"
echo -e "GroupDelegate Address: $groupDelegateAddress\n"

failed_checks=0

check_equal \
    "GroupDelegate: GROUP_ADDRESS" \
    "$groupAddress" \
    "$(cast_call "$groupDelegateAddress" "GROUP_ADDRESS()(address)")"
[ $? -ne 0 ] && ((failed_checks++))
echo ""

actual_delegate_id=$(cast_call "$groupDelegateAddress" "delegateIdOf(uint256)(uint256)" "0" 2>/dev/null)
if [ -n "$actual_delegate_id" ]; then
    echo -e "\033[31m✗\033[0m GroupDelegate: delegateIdOf(0) should revert"
    echo -e "  Actual: $actual_delegate_id"
    ((failed_checks++))
else
    echo -e "\033[32m✓\033[0m GroupDelegate: delegateIdOf(0) reverts for nonexistent group"
fi
echo ""

echo "========================================="
if [ $failed_checks -eq 0 ]; then
    echo -e "\033[32m✓ All parameter checks passed (2/2)\033[0m"
    echo "========================================="
    return 0
else
    echo -e "\033[31m✗ $failed_checks check(s) failed\033[0m"
    echo "========================================="
    return 1
fi
