#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$DEPLOY_DIR" || return 1

echo -e "\n[Step 1/3] Initializing environment..."
source "$DEPLOY_DIR/00_init.sh" "$1"
if [ $? -ne 0 ]; then
    echo -e "\033[31mError:\033[0m Failed to initialize environment"
    return 1
fi

echo -e "\n========================================="
echo -e "  One-Click Deploy GroupMarket"
echo -e "  Network: $network"
echo -e "========================================="

echo -e "\n[Step 2/3] Deploying GroupMarket..."
source "$SCRIPT_DIR/01_deploy.sh"
if [ $? -ne 0 ]; then
    echo -e "\033[31mError:\033[0m Deployment failed"
    return 1
fi

echo -e "\n[Step 3/3] Running deployment checks..."
source "$SCRIPT_DIR/99_check.sh"
if [ $? -ne 0 ]; then
    echo -e "\033[31mError:\033[0m Deployment checks failed"
    return 1
fi

echo -e "\n========================================="
echo -e "\033[32m✓ Deployment completed successfully!\033[0m"
echo -e "========================================="
echo -e "Group Address: $groupAddress"
echo -e "GroupMarket Address: $groupMarketAddress"
echo -e "LOVE20 Token Address: $LOVE20_TOKEN_ADDRESS"
echo -e "Network: $network"
echo -e "=========================================\n"
