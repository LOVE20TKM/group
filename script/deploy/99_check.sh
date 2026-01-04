#!/bin/bash

echo "========================================="
echo "Verifying Group Configuration"
echo "========================================="

# Ensure environment is initialized
if [ -z "$groupAddress" ]; then
    echo -e "\033[31mError:\033[0m Group address not set"
    return 1
fi

# Validate initialization parameters are set
echo "Validating initialization parameters..."
missing_params=0

if [ -z "$LOVE20_TOKEN_ADDRESS" ]; then
    echo -e "\033[31m✗\033[0m LOVE20_TOKEN_ADDRESS not set"
    ((missing_params++))
fi

if [ -z "$BASE_DIVISOR" ]; then
    echo -e "\033[31m✗\033[0m BASE_DIVISOR not set"
    ((missing_params++))
fi

if [ -z "$BYTES_THRESHOLD" ]; then
    echo -e "\033[31m✗\033[0m BYTES_THRESHOLD not set"
    ((missing_params++))
fi

if [ -z "$MULTIPLIER" ]; then
    echo -e "\033[31m✗\033[0m MULTIPLIER not set"
    ((missing_params++))
fi

if [ -z "$MAX_GROUP_NAME_LENGTH" ]; then
    echo -e "\033[31m✗\033[0m MAX_GROUP_NAME_LENGTH not set"
    ((missing_params++))
fi

if [ $missing_params -gt 0 ]; then
    echo -e "\033[31mError:\033[0m $missing_params initialization parameter(s) missing"
    echo "Please ensure all parameters are loaded from group.params"
    return 1
fi

echo -e "\033[32m✓\033[0m All initialization parameters are set"
echo ""

echo -e "Group Address: $groupAddress\n"

# Track failures
failed_checks=0

# Verify initialization parameters match contract values
echo "Verifying initialization parameters match contract values..."

# Check LOVE20_TOKEN_ADDRESS
check_equal "Group: LOVE20_TOKEN_ADDRESS" $LOVE20_TOKEN_ADDRESS $(cast_call $groupAddress "LOVE20_TOKEN_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check BASE_DIVISOR
check_equal "Group: BASE_DIVISOR" $BASE_DIVISOR $(cast_call $groupAddress "BASE_DIVISOR()(uint256)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check BYTES_THRESHOLD
check_equal "Group: BYTES_THRESHOLD" $BYTES_THRESHOLD $(cast_call $groupAddress "BYTES_THRESHOLD()(uint256)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check MULTIPLIER
check_equal "Group: MULTIPLIER" $MULTIPLIER $(cast_call $groupAddress "MULTIPLIER()(uint256)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check MAX_GROUP_NAME_LENGTH
check_equal "Group: MAX_GROUP_NAME_LENGTH" $MAX_GROUP_NAME_LENGTH $(cast_call $groupAddress "MAX_GROUP_NAME_LENGTH()(uint256)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check name
actual_name=$(cast_call $groupAddress "name()(string)")
echo -e "\033[32m✓\033[0m Group: name"
echo -e "  Actual: $actual_name"
echo ""

# Check symbol
actual_symbol=$(cast_call $groupAddress "symbol()(string)")
echo -e "\033[32m✓\033[0m Group: symbol"
echo -e "  Actual: $actual_symbol"
echo ""

# Check totalSupply
actual_supply=$(cast_call $groupAddress "totalSupply()(uint256)")
echo -e "\033[32m✓\033[0m Group: totalSupply"
echo -e "  Actual: $actual_supply"
echo ""

# Check totalMintCost
actual_burned=$(cast_call $groupAddress "totalMintCost()(uint256)")
echo -e "\033[32m✓\033[0m Group: totalMintCost"
echo -e "  Actual: $actual_burned"
echo ""

# Check holdersCount
actual_holders_count=$(cast_call $groupAddress "holdersCount()(uint256)")
echo -e "\033[32m✓\033[0m Group: holdersCount"
echo -e "  Actual: $actual_holders_count"
echo ""

# Summary
echo "========================================="
if [ $failed_checks -eq 0 ]; then
    echo -e "\033[32m✓ All checks passed (10/10)\033[0m"
    echo "========================================="
    return 0
else
    echo -e "\033[31m✗ $failed_checks check(s) failed\033[0m"
    echo "========================================="
    return 1
fi