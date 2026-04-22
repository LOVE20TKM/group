#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

if [ -z "$LOVE20_TOKEN_ADDRESS" ]; then
    echo -e "\033[31mError:\033[0m LOVE20_TOKEN_ADDRESS not set"
    return 1
fi

export GROUP_ADDRESS="$groupAddress"

echo "Deploying GroupMarket contract..."
echo "Using GROUP_ADDRESS: $GROUP_ADDRESS"
echo "Using LOVE20_TOKEN_ADDRESS: $LOVE20_TOKEN_ADDRESS"

forge_script group-market/DeployGroupMarket.s.sol:DeployGroupMarket --sig "run()"

if [ $? -eq 0 ]; then
    source "$network_dir/address.group.market.params"
    echo -e "\033[32m✓\033[0m GroupMarket deployed at: $groupMarketAddress"
    return 0
else
    echo -e "\033[31m✗\033[0m Failed to deploy GroupMarket"
    return 1
fi
