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

current_precheck_key="${network}|${RPC_URL}|${groupAddress}"

if [ "$GROUP_DEFAULTS_PRECHECK_DONE" != "1" ] || [ "$GROUP_DEFAULTS_PRECHECK_KEY" != "$current_precheck_key" ]; then
    if ! source "$SCRIPT_DIR/00_precheck.sh"; then
        return 1
    fi
fi

export GROUP_ADDRESS="$groupAddress"

echo "Deploying GroupDefaults contract..."
echo "Using GROUP_ADDRESS: $GROUP_ADDRESS"

forge_script group-defaults/DeployGroupDefaults.s.sol:DeployGroupDefaults --sig "run()"

if [ $? -eq 0 ]; then
    source "$network_dir/address.group.defaults.params"
    echo -e "\033[32m✓\033[0m GroupDefaults deployed at: $groupDefaultsAddress"
    return 0
else
    echo -e "\033[31m✗\033[0m Failed to deploy GroupDefaults"
    return 1
fi
