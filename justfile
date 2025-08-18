# Justfile for QRYPTORAND Project

# Load environment variables from .env
set dotenv-load := true


# Install foundry and setup it
[group('Setup')]
install-foundry:
    curl -L https://foundry.paradigm.xyz | bash
    foundryup -i 1.3.1

# Install dependencies of Solidity need to deploy contract
[group('Setup')]
install-solidity-dependencies:
    forge install --root ./contracts

# Setup the dependencies for foundry
[group('Setup')]
setup:
    just install-foundry
    just install-solidity-dependencies


# Run the example "Connect with script"
[group('Example')]
run-example-1:
    forge build --root ./contracts/examples
    forge create --private-key $PRIVATE_KEY_WALLET --root ./contracts examples/Contract.sol:ContractExampleScript --broadcast
    forge script --rpc-url $ETH_RPC_URL --sender $WALLET --private-key $PRIVATE_KEY_WALLET ./contracts/examples/Script.sol:ScriptExample --root ./contracts --broadcast

# Run the example "Ask random Number"
[group('Example')]
run-example-2:
    forge build --root ./contracts/examples
    forge create --private-key $PRIVATE_KEY_WALLET --root ./contracts examples/Contract.sol:ContractExampleAsk --broadcast
    forge script --rpc-url $ETH_RPC_URL --sender $WALLET --private-key $PRIVATE_KEY_WALLET ./contracts/examples/Script.sol:AskExample --root ./contracts --broadcast


# Build Solidity part
[group('Solidity only')]
build-solidity:
    forge build --root ./contracts

# Make bindings to use Solidity functions in Rust
[group('Solidity only')]
bind-solidity:
    forge bind --bindings-path ./crates/bindings --root ./contracts --crate-name foundry-contracts --overwrite --alloy-version 1.0

# Test Solidity functions
[group('Solidity only')]
test-solidity: 
    forge test --root ./contracts

# Clean the Solidity part of the project
[group('Solidity only')]
clean-solidity: 
    forge clean --root ./contracts


# Start local blockchain
[group('Anvil')]
[group('Workflow')]
start-anvil:
    anvil --host $HOST --port $PORT_BLOCKCHAIN

# Deploy contract and make the link
[group('Workflow')]
deploy-backend: 
    just build-solidity
    forge create --private-key $PRIVATE_KEY_WALLET --root ./contracts src/IQryptoToken.sol:Token --broadcast --constructor-args $INITIAL_SUPPLY
    forge create --private-key $PRIVATE_KEY_WALLET --root ./contracts src/IQryptoStorageNumber.sol:StorageNumber --broadcast --constructor-args $TOKEN_ADDRESS
    forge script --rpc-url $ETH_RPC_URL --sender $WALLET --private-key $PRIVATE_KEY_WALLET ./contracts/script/StorageNumber.s.sol --root ./contracts --broadcast
    forge script --rpc-url $ETH_RPC_URL --sender $WALLET --private-key $PRIVATE_KEY_WALLET ./contracts/script/DistributeYpto.s.sol --root ./contracts --broadcast

# Clean whole project
[group('Workflow')]
clean:
    just clean-solidity
    cargo clean

# Start project
[group('Workflow')]
start-qrng:
    just clean-solidity
    just build-solidity
    just bind-solidity
    cargo run

start-prng: 
  echo "THIS MODE IS FOR TESTING ONLY !"
  read
  just clean-solidity
  just build-solidity
  just bind-solidity
  cargo run --no-default-features --features="testing"
