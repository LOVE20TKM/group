#!/bin/bash

# Ensure environment is initialized
if [ -z "$RPC_URL" ]; then
    echo -e "\033[31mError:\033[0m Environment not initialized. Please run 00_init.sh first."
    return 1
fi

echo "Deploying LOVE20Group contract..."

forge_script ../DeployLOVE20Group.s.sol:DeployLOVE20Group --sig "run()"

if [ $? -eq 0 ]; then
    # Load deployed address
    source $network_dir/address.group.params
    echo -e "\033[32m✓\033[0m LOVE20Group deployed at: $groupAddress"
    return 0
else
    echo -e "\033[31m✗\033[0m Failed to deploy LOVE20Group"
    return 1
fi
