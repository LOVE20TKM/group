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
echo "Verifying GroupDefaults Configuration"
echo "========================================="

if [ -z "$groupAddress" ]; then
    if [ ! -f "$network_dir/address.group.params" ]; then
        echo -e "\033[31mError:\033[0m Group address file not found: $network_dir/address.group.params"
        return 1
    fi
    source "$network_dir/address.group.params"
fi

if [ -z "$groupDefaultsAddress" ]; then
    if [ ! -f "$network_dir/address.group.defaults.params" ]; then
        echo -e "\033[31mError:\033[0m GroupDefaults address file not found: $network_dir/address.group.defaults.params"
        return 1
    fi
    source "$network_dir/address.group.defaults.params"
fi

if [ -z "$groupAddress" ]; then
    echo -e "\033[31mError:\033[0m groupAddress not set"
    return 1
fi

if [ -z "$groupDefaultsAddress" ]; then
    echo -e "\033[31mError:\033[0m groupDefaultsAddress not set"
    return 1
fi

echo -e "Group Address: $groupAddress"
echo -e "GroupDefaults Address: $groupDefaultsAddress\n"

failed_checks=0

check_equal \
    "GroupDefaults: GROUP_ADDRESS" \
    "$groupAddress" \
    "$(cast_call "$groupDefaultsAddress" "GROUP_ADDRESS()(address)")"
[ $? -ne 0 ] && ((failed_checks++))
echo ""

actual_default_group_id=$(cast_call "$groupDefaultsAddress" "defaultGroupIdOf(address)(uint256)" "$ACCOUNT_ADDRESS")
echo -e "\033[32m✓\033[0m GroupDefaults: defaultGroupIdOf(ACCOUNT_ADDRESS)"
echo -e "  Actual: $actual_default_group_id"
echo ""

echo "========================================="
if [ $failed_checks -eq 0 ]; then
    echo -e "\033[32m✓ All parameter checks passed (1/1)\033[0m"
    echo "========================================="
    return 0
else
    echo -e "\033[31m✗ $failed_checks check(s) failed\033[0m"
    echo "========================================="
    return 1
fi
