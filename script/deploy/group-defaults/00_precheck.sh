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

if [ -z "$CHAIN_ID" ]; then
    echo -e "\033[31mError:\033[0m CHAIN_ID not set. Please run 00_init.sh first."
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

echo "========================================="
echo "Prechecking GroupDefaults Deployment"
echo "========================================="
echo "Network: $network"
echo "Network Dir: $network_dir"
echo "RPC_URL: $RPC_URL"
echo "Group Address: $groupAddress"

actual_chain_id=$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$actual_chain_id" ]; then
    echo -e "\033[31mError:\033[0m Failed to read chain id from RPC"
    return 1
fi

if [ "$actual_chain_id" != "$CHAIN_ID" ]; then
    echo -e "\033[31mError:\033[0m RPC chain id mismatch"
    echo "  Expected: $CHAIN_ID"
    echo "  Actual:   $actual_chain_id"
    return 1
fi
echo -e "\033[32m✓\033[0m RPC chain id matches: $actual_chain_id"

group_code=$(cast code "$groupAddress" --rpc-url "$RPC_URL" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$group_code" ] || [ "$group_code" = "0x" ]; then
    echo -e "\033[31mError:\033[0m No contract code found at groupAddress"
    return 1
fi
echo -e "\033[32m✓\033[0m Group contract code found"

address_file="$network_dir/address.group.defaults.params"
if [ -f "$address_file" ]; then
    source "$address_file"

    if [ -n "$groupDefaultsAddress" ]; then
        defaults_code=$(cast code "$groupDefaultsAddress" --rpc-url "$RPC_URL" 2>/dev/null)
        if [ -n "$defaults_code" ] && [ "$defaults_code" != "0x" ]; then
            bound_group_address=$(cast call "$groupDefaultsAddress" "GROUP_ADDRESS()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
            echo -e "\033[33mWarning:\033[0m Existing GroupDefaults deployment detected"
            echo "  GroupDefaults Address: $groupDefaultsAddress"
            echo "  Bound Group Address:   $bound_group_address"

            if [ "$(printf '%s' "$bound_group_address" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$groupAddress" | tr '[:upper:]' '[:lower:]')" ]; then
                if [ "$FORCE_REDEPLOY" != "1" ]; then
                    echo -e "\033[31mError:\033[0m Refusing to redeploy while address.group.defaults.params already points to live code for the current group"
                    echo "Set FORCE_REDEPLOY=1 if you really want to replace it."
                    return 1
                fi

                echo -e "\033[33mWarning:\033[0m FORCE_REDEPLOY=1 set, continuing"
            else
                echo -e "\033[33mWarning:\033[0m Existing GroupDefaults is bound to a different group, continuing with redeploy"
            fi
        else
            echo -e "\033[33mWarning:\033[0m Existing address.group.defaults.params found, but no live code at that address"
        fi
    fi
fi

export GROUP_DEFAULTS_PRECHECK_DONE=1
export GROUP_DEFAULTS_PRECHECK_KEY="$current_precheck_key"
echo -e "\033[32m✓\033[0m GroupDefaults deployment precheck passed"
echo "========================================="
