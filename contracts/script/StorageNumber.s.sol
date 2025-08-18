// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {StorageNumber} from "../src/IQryptoStorageNumber.sol";
import {Token} from "../src/IQryptoToken.sol";

contract Interact is Script {
    address public constant CONTRACT_ADDRESS_STORAGE =
        0x71C95911E9a5D330f4D621842EC243EE1343292e;
    address public constant CONTRACT_ADDRESS_TOKEN =
        0x8464135c8F25Da09e49BC8782676a84730C318bC;

    function run() external {
        vm.startBroadcast();

        Token(CONTRACT_ADDRESS_TOKEN).setAuthorizedContract(
            CONTRACT_ADDRESS_STORAGE
        );
        StorageNumber(CONTRACT_ADDRESS_STORAGE).setQrngKey(
            0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            0x564bcd21744Aa13843bD217a6A12030238AceA85
        );
        StorageNumber(CONTRACT_ADDRESS_STORAGE).setQrngKey(
            0x90F79bf6EB2c4f870365E785982E1f101E93b906,
            0x564bcd21744Aa13843bD217a6A12030238AceA85
        );

        vm.stopBroadcast();
    }
}
