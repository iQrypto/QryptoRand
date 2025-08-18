// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {StorageNumber} from "../src/IQryptoStorageNumber.sol";
import {Token} from "../src/IQryptoToken.sol";

/// @title Deploy IQrypto contracts
/// @notice Deploys `Token` and `StorageNumber`, authorizes `StorageNumber` on the token,
///         and optionally registers a QRNG wallet/key if provided via env vars.
/// @dev Required env: `INITIAL_SUPPLY` (uint). Optional env: `QRNG_WALLET`, `QRNG_PUBKEY` (addresses).
///
/// Example (Sepolia):
///   export SEPOLIA_RPC_URL=https://... 
///   export PRIVATE_KEY_WALLET=0x...
///   export ETHERSCAN_API_KEY=...            # if you pass --verify
///   export INITIAL_SUPPLY=1000000000000000000000
///   forge script -C contracts \
///     --rpc-url "$SEPOLIA_RPC_URL" \
///     --private-key "$PRIVATE_KEY_WALLET" \
///     --broadcast --verify \
///     script/Deploy.s.sol:DeployScript
///
/// Security: never commit private keys or RPC URLs. Use env vars and CI secrets.

contract DeployScript is Script {
    Token public token;
    StorageNumber public storage_number;

    function run() public {
        uint256 initialSupply = vm.envUint("INITIAL_SUPPLY");
        require(initialSupply > 0, "INITIAL_SUPPLY must be > 0");
        address maybeQrngWallet = vm.envOr("WALLET", address(0));
        address maybeQrngKey = vm.envOr("QRNG_PUBKEY", address(0));

        vm.startBroadcast();

        token = new Token(initialSupply);
        storage_number = new StorageNumber(address(token));
        token.setAuthorizedContract(address(storage_number));

        console.log("Token deployed:", address(token));
        console.log("StorageNumber deployed:", address(storage_number));
        console.log("Authorized storage on token.");

        if (maybeQrngWallet != address(0) && maybeQrngKey != address(0)) {
            storage_number.setQrngKey(maybeQrngWallet, maybeQrngKey);
            console.log("Registered QRNG:", maybeQrngWallet);
        }

        vm.stopBroadcast();
    }
}
