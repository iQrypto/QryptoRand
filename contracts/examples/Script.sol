// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script,console2} from "../lib/forge-std/src/Script.sol";
import {ContractExampleAsk, ContractExampleScript} from "./Contract.sol";

/// @notice Script to simulate linking contracts in a broadcast.
contract ScriptExample is Script {
    address public constant CONTRACT_EXAMPLE_SCRIPT_ADDRESS =
        0x59F2f1fCfE2474fD5F0b9BA1E73ca90b143Eb8d0;

    /// @notice Executes the contract linking on-chain.
    function run() external {
        vm.startBroadcast();

        scriptToConnect();

        vm.stopBroadcast();
    }
    /// @notice Links deployed Token and StorageNumber contracts to a consumer contract.
    function scriptToConnect() public {
        ContractExampleScript(CONTRACT_EXAMPLE_SCRIPT_ADDRESS).linkToContract(
            0x71C95911E9a5D330f4D621842EC243EE1343292e, // StorageNumber address.
            0x8464135c8F25Da09e49BC8782676a84730C318bC // Token address.
        );
    }
}
/// @notice Script to demonstrate random number request and mapping it to a semantic choice.
contract AskExample is Script {
    address public constant CONTRACT_EXAMPLE_ASK_ADDRESS =
        0x1275D096B9DBf2347bD2a131Fb6BDaB0B4882487;
    /// @notice Requests a random number and logs its associated string.
    function run() external {
        vm.startBroadcast();

        // Function for section "Ask for Random Numbers".
        uint256 number = ContractExampleAsk(CONTRACT_EXAMPLE_ASK_ADDRESS)
            .requestRandomNumber();
        console2.log(number);
        string memory choice = ContractExampleAsk(CONTRACT_EXAMPLE_ASK_ADDRESS)
            .randomChoice(number);
        console2.log(choice);

        vm.stopBroadcast();
    }
}
