// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct EcvrfContractProofSolidity {
    bytes32 alpha; // Random Number.
    uint256[2] pk; // Public key.
    uint256[2] gamma; // Proof (x, y).
    uint256 c; // Scalar c.
    uint256 s; // Scalar s.
    address uWitness;
    uint256[2] cGammaWitness;
    uint256[2] sHashWitness;
    uint256 zInv;
}

struct SignatureSolidity {
    // Data to recover address.
    // Load in Rust to gain some gaz.
    bytes32 r;
    bytes32 s;
    uint8 v;
    address wallet;
}

struct Random {
    uint256 number;
    EcvrfContractProofSolidity proof;
}

interface StorageInterface {
    function QRN_PRICE() external view returns (uint256);
    
    function askRandomNumber(
        bool verifyProof
    ) external payable returns (uint256);

    function askRandomNumbers(
        uint16 amount,
        bool verifyProof
    ) external payable returns (uint256[] memory);

    function addRandomNumber(
      uint256 number,
        SignatureSolidity calldata signature,
        bytes32 hashData,
        EcvrfContractProofSolidity calldata proof
    ) external;

    function addRandomNumbers(
      uint256[] calldata numbers,
        SignatureSolidity[] calldata signature,
        bytes32[] calldata hashData,
        EcvrfContractProofSolidity[] calldata proof
    ) external;

    function verifyVrf(
        EcvrfContractProofSolidity calldata proof
    ) external returns (bool);
}
