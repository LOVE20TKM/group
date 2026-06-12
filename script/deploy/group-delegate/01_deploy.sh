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

if [ -z "$RPC_URL" ]; then
    echo -e "\033[31mError:\033[0m Environment not initialized. Please run 00_init.sh first."
    return 1
fi

if [ -z "$groupAddress" ]; then
    if [ ! -f "$network_dir/address.group.params" ]; then
        echo -e "\033[31mError:\033[0m Group address file not found: $network_dir/address.group.params"
        return 1
    fi
    source "$network_dir/address.group.params"
fi

if [ -z "$groupAddress" ]; then
    echo -e "\033[31mError:\033[0m groupAddress not set"
    return 1
fi

group_code=$(cast code "$groupAddress" --rpc-url "$RPC_URL" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$group_code" ] || [ "$group_code" = "0x" ]; then
    echo -e "\033[31mError:\033[0m No contract code found at groupAddress"
    return 1
fi

export GROUP_ADDRESS="$groupAddress"

echo "Deploying GroupDelegate contract..."
echo "Using GROUP_ADDRESS: $GROUP_ADDRESS"

forge_script group-delegate/DeployGroupDelegate.s.sol:DeployGroupDelegate --sig "run()"

if [ $? -eq 0 ]; then
    source "$network_dir/address.group.delegate.params"
    echo -e "\033[32m✓\033[0m GroupDelegate deployed at: $groupDelegateAddress"
    return 0
else
    echo -e "\033[31m✗\033[0m Failed to deploy GroupDelegate"
    return 1
fi
