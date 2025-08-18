# Example to use QRYPTORAND PROJECT

This folder contain an example to "How can we get some random numbers from `StorageNumber` contract".

In these examples we will assume the QRYPTORAND contracts are deployed in the same blockchain that you deploy your contract. We assume the knowledge basis of Solidity syntax is well known. In alternative, here is the [documentation](https://docs.soliditylang.org/en/latest/) of solidity used to construct the whole project.

For each section, we will provide a text of information to help you to understand the meaning and the concept with also an example in solidity. Each Case will be written in the contracts inside the folder `/example` and you will be able to run the code.

At the end of each section, we provide a `just` command line to help you to run the part of the code **IF YOU USE THE** `.env.example` as `.env`.

## Starting point

Before going to the tutorial, we will create the contract for the demonstration. For the `Contract.sol`, we will put a contract name that correspond to the concept of the section:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract ContractExample {

    ...

}
```

For the `Script.sol`, we use only one class as `ScriptExample` with this structure:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "../lib/forge-std/src/Script.sol"; // Access to script functions.
import {ContractExample} from "./Contract.sol"; // Our ContractExample.

contract ScriptExample is Script {

    function run() external {
        vm.startBroadcast();

        ...

        vm.stopBroadcast();
    }
}

```

Finally, all the tests will be done in the `Anvil` environment with the `.env.example` with the following commands used:

```bash
just start-anvil
just deploy-backend
just start-qrng
```

If you want to use the second example, please run the previous one or you will have to change the address of the contract.

## How to connect with QRYPTORAND contracts ?

You will need to know the address of each contract you want to be connected to with QRYPTORAND contracts. For example, in the `Anvil` blockchain case and with the address of the wallet inside the `.env.example`, the address of each contract are:

```
StorageNumber: 0x71C95911E9a5D330f4D621842EC243EE1343292e
Token: 0x8464135c8F25Da09e49BC8782676a84730C318bC
```

We will call a script to make the link with these contracts. To make it, we will write a function to create the link for those contracts and after it, with the script, we will call this with the information.

```solidity
// Contract.sol
constructor() {}

function linkToContract(
    address tokenAddress,
    address storageNumberAddress,
) public {
    tokenContract = Token(tokenAddress);
    storageNumberContract = StorageNumber(storageNumberAddress);
}
```

As you can see, this time the constructor is completely empty and we will use the script to connect to the contract when it's deployed. So, we need to know what is the address of our contract. When you will deploy it, with `.env.example`, you will receive an address for it:

```bash
ContractExampleScript: 0xC6bA8C3233eCF65B761049ef63466945c362EdD2
```

With this address, you just need to put it inside the script and you will be able to use all functions stored inside the `ContractExampleScript` with the correct visibility:

```solidity
// Script.sol
address public constant contractExampleScriptAddress =
    0xC6bA8C3233eCF65B761049ef63466945c362EdD2;

function run() external {
    vm.startBroadcast();

    scriptToConnect();

    vm.stopBroadcast();
}

function scriptToConnect() public {
    ContractExampleScript(contractExampleScriptAddress).linkToContract(
        0x71C95911E9a5D330f4D621842EC243EE1343292e, // StorageNumber address.
        0x8464135c8F25Da09e49BC8782676a84730C318bC, // Token address.
    );
}
```

To test it, you can also use:

```bash
just run-example-1
```

Now, your contract has accessed to the functions inside the `StorageNumber` contract in regards of the visibility of the function.

## Ask for Random Numbers

To ask some random numbers, you will need to connect to the `StorageNumber` to have access to the numbers. First of all, we debut with the `Contract.sol` to link to the Storage and we will use the function `askRandomNumber(uint256 number, bool verifyProof)` to get some numbers.

```solidity
// Contract.sol
function requestRandomNumber() public returns (uint256 number) {
    bool verifyProof = false;
    number = storageNumberContract.askRandomNumber(verifyProof);
    return number;
}
```

We can now get a random number from the storage and use it for personal work like security or games in solidity. To use it, you can call the function and use it but if you want to display it, you can use the following script:

```solidity
// Script.sol
function run() external {
    vm.startBroadcast();

    // Function for section "Ask for Random Numbers".
    uint256 number = ContractExampleAsk(contractExampleAskAddress)
        .requestRandomNumber();
    console.log(number);

    vm.stopBroadcast();
}
```

Finally, an example of use of these numbers could be a random choice on a list:

```solidity
// Contract.sol
string[] iQryptoTable = [
    "iQrypto",
    "QRNG",
    "Miseno",
    "Quantum Random Numbers",
    "Quantum Microchip",
    "Quantum Technology",
    "Quantum Security",
    "https://www.iQrypto.com"
];

function randomChoice(
    uint256 number
) public view returns (string memory choice) {
    choice = iQryptoTable[number % iQryptoTable.length];
    return choice;
}
```

To test it, you can also use:

```bash
just run-example-2
```

Launching it will deploy the smart contract and get you a random number stored in `StorageNumber`. After, it will use it to get a random string from a list.
