// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {StorageNumber} from "../src/IQryptoStorageNumber.sol";
import {Token} from "../src/IQryptoToken.sol";

/// @notice Simple example contract to demonstrate how to link external deployed contracts.
contract ContractExampleScript {
    StorageNumber private storageNumberContract;
    Token private tokenContract;

    /// @notice Links external deployed contracts by setting their addresses.
    /// @param tokenAddress Deployed Token contract address.
    /// @param storageNumberAddress Deployed StorageNumber contract address.
    function linkToContract(
        address tokenAddress,
        address storageNumberAddress
    ) public {
        tokenContract = Token(tokenAddress);
        storageNumberContract = StorageNumber(storageNumberAddress);
    }
}
/// @notice Example contract demonstrating how to interact with StorageNumber.
contract ContractExampleAsk {
    StorageNumber private storageNumberContract;

    // Replace this with a dynamic setter in production; hardcoding isn't ideal.
    address public constant STORAGE_NUMBER_ADDRESS =
        0x71C95911E9a5D330f4D621842EC243EE1343292e;

    string[] internal iQryptoTable = [
        "iQrypto",
        "QRNG",
        "Miseno",
        "Quantum Random Numbers",
        "Quantum Microchip",
        "Quantum Technology",
        "Quantum Security",
        "https://www.iQrypto.com"
    ];

    /// @notice Initializes contract and sets up StorageNumber reference.
    constructor() {
        storageNumberContract = StorageNumber(STORAGE_NUMBER_ADDRESS);
    }

    /// @notice Requests a random number from StorageNumber and returns it.
    /// @return number The random number returned by StorageNumber.
    function requestRandomNumber() public returns (uint256 number) {
        bool verifyProof = false;
        number = storageNumberContract.askRandomNumber(verifyProof);
        return number;
    }
    /// @notice Picks a deterministic string from a preset list based on random input.
    /// @param number Random number used to index into the list.
    /// @return choice String selected based on input value.
    function randomChoice(
        uint256 number
    ) public view returns (string memory choice) {
        choice = iQryptoTable[number % iQryptoTable.length];
        return choice;
    }
}
