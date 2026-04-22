#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$DEPLOY_DIR" || return 1

if [[ "$network" != thinkium70001* ]]; then
  echo "Network is not thinkium70001 related, skipping verification"
  return 0
fi

if [ -z "$RPC_URL" ]; then
    source "$DEPLOY_DIR/00_init.sh" "$network"
fi

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

verify_contract() {
  local contract_address=$1
  local contract_name=$2
  local contract_path=$3
  shift 3
  local ctor_args="$@"

  echo "Verifying contract: $contract_name at $contract_address"

  forge verify-contract \
    --chain-id "$CHAIN_ID" \
    --verifier "$VERIFIER" \
    --verifier-url "$VERIFIER_URL" \
    --constructor-args "$ctor_args" \
    "$contract_address" \
    "$contract_path:$contract_name"

  if [ $? -eq 0 ]; then
    echo -e "\033[32m✓\033[0m Contract $contract_name verified successfully"
    return 0
  else
    echo -e "\033[31m✗\033[0m Failed to verify contract $contract_name"
    return 1
  fi
}
echo "verify_contract() loaded"

constructor_args=$(cast abi-encode "constructor(address)" "$groupAddress")

verify_contract "$groupDefaultsAddress" "GroupDefaults" "src/GroupDefaults.sol" "$constructor_args"
