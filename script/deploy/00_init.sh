# ------ set network ------
export network=$1
if [ -z "$network" ] || [ ! -d "../network/$network" ]; then
    echo -e "\033[31mError:\033[0m Network parameter is required."
    echo -e "\nAvailable networks:"
    for net in $(ls ../network); do
        echo "  - $net"
    done
    return 1
fi

echo -e "Selected network: \033[36m$network\033[0m"

# ------ dont change below ------
network_dir="../network/$network"

if [ ! -f "$network_dir/.account" ]; then
    echo -e "\033[31mError:\033[0m .account file not found"
    echo -e "Please create $network_dir/.account with KEYSTORE_ACCOUNT and ACCOUNT_ADDRESS"
    return 1
fi
source $network_dir/.account && \
source $network_dir/network.params

# Load Group configuration (includes LOVE20 token address and parameters)
if [ -f "$network_dir/group.params" ]; then
    source $network_dir/group.params
    
    # Check if LOVE20_TOKEN_ADDRESS is set
    if [ -z "$LOVE20_TOKEN_ADDRESS" ]; then
        echo -e "\033[31mError:\033[0m LOVE20_TOKEN_ADDRESS not set in group.params"
        return 1
    fi
    
    # Export all variables
    export LOVE20_TOKEN_ADDRESS
    export BASE_DIVISOR
    export BYTES_THRESHOLD
    export MULTIPLIER
    export MAX_GROUP_NAME_LENGTH
    
    echo "Group Configuration loaded:"
    echo "  LOVE20 Token: $LOVE20_TOKEN_ADDRESS"
    echo "  BASE_DIVISOR: $BASE_DIVISOR"
    echo "  BYTES_THRESHOLD: $BYTES_THRESHOLD"
    echo "  MULTIPLIER: $MULTIPLIER"
    echo "  MAX_GROUP_NAME_LENGTH: $MAX_GROUP_NAME_LENGTH"
else
    echo -e "\033[31mError:\033[0m group.params not found"
    echo -e "Please create $network_dir/group.params"
    return 1
fi

# ------ Request keystore password ------
echo -e "\nPlease enter keystore password (for $KEYSTORE_ACCOUNT):"
read -s KEYSTORE_PASSWORD
export KEYSTORE_PASSWORD
echo "Password saved, will not be requested again in this session"

cast_call() {
    local address=$1
    local function_signature=$2
    shift 2
    local args=("$@")

    # echo "Executing cast call: $address $function_signature ${args[@]}"
    cast call "$address" \
        "$function_signature" \
        "${args[@]}" \
        --rpc-url "$RPC_URL"
}
echo "cast_call() loaded"

# Check if two values are equal
check_equal() {
    local description="$1"
    local expected="$2"
    local actual="$3"
    
    # Convert to lowercase for comparison
    expected=$(echo "$expected" | tr '[:upper:]' '[:lower:]')
    actual=$(echo "$actual" | tr '[:upper:]' '[:lower:]')
    
    if [ "$expected" = "$actual" ]; then
        echo -e "\033[32m✓\033[0m $description"
        echo -e "  Expected: $expected"
        echo -e "  Actual:   $actual"
        return 0
    else
        echo -e "\033[31m✗\033[0m $description"
        echo -e "  Expected: $expected"
        echo -e "  Actual:   $actual"
        return 1
    fi
}
echo "check_equal() loaded"


## Using keystore file method
forge_script() {
  forge script "$@" \
    --rpc-url $RPC_URL \
    --account $KEYSTORE_ACCOUNT \
    --sender $ACCOUNT_ADDRESS \
    --password "$KEYSTORE_PASSWORD" \
    --gas-price 5000000000 \
    --gas-limit 50000000 \
    --broadcast \
    --legacy \
    $([[ "$network" != "anvil" ]] && [[ "$network" != thinkium* ]] && echo "--verify --etherscan-api-key $ETHERSCAN_API_KEY")
}
echo "forge_script() loaded"
