// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/IQryptoToken.sol";

contract DistributeYpto is Script {
    function run() external {
        address[] memory accounts = new address[](10);
        accounts[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        accounts[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        accounts[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        accounts[3] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        accounts[4] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        accounts[5] = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
        accounts[6] = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;
        accounts[7] = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955;
        accounts[8] = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
        accounts[9] = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

        Token token = Token(0x8464135c8F25Da09e49BC8782676a84730C318bC);

        vm.startBroadcast();

        for (uint256 i = 0; i < accounts.length; i++) {
            token.distribute(accounts[i], 100 ether);
        }

        vm.stopBroadcast();
    }
}