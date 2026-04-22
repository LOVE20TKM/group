#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$DEPLOY_DIR" || return 1

echo "========================================="
echo "Verifying GroupMarket Configuration"
echo "========================================="

if [ -z "$groupAddress" ]; then
    if [ ! -f "$network_dir/address.group.params" ]; then
        echo -e "\033[31mError:\033[0m Group address file not found: $network_dir/address.group.params"
        return 1
    fi
    source "$network_dir/address.group.params"
fi

if [ -z "$groupMarketAddress" ]; then
    if [ ! -f "$network_dir/address.group.market.params" ]; then
        echo -e "\033[31mError:\033[0m GroupMarket address file not found: $network_dir/address.group.market.params"
        return 1
    fi
    source "$network_dir/address.group.market.params"
fi

if [ -z "$groupAddress" ]; then
    echo -e "\033[31mError:\033[0m groupAddress not set"
    return 1
fi

if [ -z "$groupMarketAddress" ]; then
    echo -e "\033[31mError:\033[0m groupMarketAddress not set"
    return 1
fi

if [ -z "$LOVE20_TOKEN_ADDRESS" ]; then
    echo -e "\033[31mError:\033[0m LOVE20_TOKEN_ADDRESS not set"
    return 1
fi

echo -e "Group Address: $groupAddress"
echo -e "GroupMarket Address: $groupMarketAddress"
echo -e "LOVE20 Token Address: $LOVE20_TOKEN_ADDRESS\n"

failed_checks=0

check_equal \
    "GroupMarket: group" \
    "$groupAddress" \
    "$(cast_call "$groupMarketAddress" "group()(address)")"
[ $? -ne 0 ] && ((failed_checks++))
echo ""

check_equal \
    "GroupMarket: love20Token" \
    "$LOVE20_TOKEN_ADDRESS" \
    "$(cast_call "$groupMarketAddress" "love20Token()(address)")"
[ $? -ne 0 ] && ((failed_checks++))
echo ""

check_equal \
    "Group: LOVE20_TOKEN_ADDRESS" \
    "$LOVE20_TOKEN_ADDRESS" \
    "$(cast_call "$groupAddress" "LOVE20_TOKEN_ADDRESS()(address)")"
[ $? -ne 0 ] && ((failed_checks++))
echo ""

echo "========================================="
if [ $failed_checks -eq 0 ]; then
    echo -e "\033[32m✓ All parameter checks passed (3/3)\033[0m"
    echo "========================================="
    return 0
else
    echo -e "\033[31m✗ $failed_checks check(s) failed\033[0m"
    echo "========================================="
    return 1
fi
