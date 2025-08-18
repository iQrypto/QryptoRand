// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StorageNumber} from "../src/IQryptoStorageNumber.sol";
import {Token} from "../src/IQryptoToken.sol";
import {EcvrfContractProofSolidity, SignatureSolidity} from "../src/interfaces/StorageInterface.sol";

contract TestStorageNumber is Test {
    StorageNumber private contractStorage;
    Token private token;

    address internal qrng = vm.addr(1);
    uint256 internal qrngKey = 1;

    /// @notice Sets up the test environment with a token and storage contract instance.
    /// @dev Also sets the QRNG key for signature verification.
    function setUp() public {
        token = new Token(1000 * 10 ** 18);
        contractStorage = new StorageNumber(address(token));
        token.setAuthorizedContract(address(contractStorage));

        // Set QRNG key with (wallet = qrng, key = recovered signer)
        contractStorage.setQrngKey(qrng, qrng); // now both match what ecrecover returns
    }

    /// @notice Builds a mock submission including signature, hash, proof, and number for testing.
    /// @param sender The address of the QRNG wallet (used as signature signer and proof wallet).
    /// @param key The private key used to sign the message (used in vm.sign).
    /// @param nonce The current nonce expected for the sender.
    /// @return sig The generated signature over the hashed message.
    /// @return hashData The keccak256 hash of the VRF input and nonce.
    /// @return proof A mocked, structurally valid VRF proof (not cryptographically sound).
    /// @return number The number extracted from the seed (`alpha`) used in the proof.
    function buildSubmission(
        address sender,
        uint256 key,
        uint64 nonce
    )
        internal
        pure
        returns (
            SignatureSolidity memory sig,
            bytes32 hashData,
            EcvrfContractProofSolidity memory proof,
            uint256 number
        )
    {
        // Step 1: Generate seed
        bytes32 alpha = keccak256(abi.encodePacked("alpha", sender, nonce));
        number = uint256(alpha);

        // Step 2: Compute message hash
        bytes memory message = abi.encodePacked(bytes32ToBytes(alpha), nonce);
        hashData = keccak256(message);

        // Step 3: Signature
        (uint8 v, bytes32 r, bytes32 s_) = vm.sign(key, hashData);
        sig = SignatureSolidity({r: r, s: s_, v: v, wallet: sender});

        // Step 4: Mock VRF points
        uint256[2] memory pk = [
            0x8c6f9b6a2721da17874e4c6d6f1f7027b6f3bb45702f3e0a8ebf5737c5f7f847,
            0x78e0b6f8f4f6a5c3dceaf5fc4a7c138e6b05c1fa3fa96ad7df7f373b6e17487f
        ];
        uint256[2] memory gamma = [
            0xb71c71e054e90546b1cb4c11d7dd2b5763ecbc3b01ebefbf4de7ed602ff75d1d,
            0x5a6db1595dd6d6c5a3eac35693f11f939e003bc8ed754c3f1ec2f0cbeb52939b
        ];

        uint256 c = uint256(keccak256(abi.encodePacked(alpha, pk, gamma))) >> 3;
        uint256 s = uint256(keccak256(abi.encodePacked(pk, gamma, sender))) >>
            2;

        uint256[2] memory cGammaWitness = [uint256(8), uint256(9)];
        uint256[2] memory sHashWitness = [uint256(10), uint256(11)];
        uint256 zInv = 12;

        // Construct final proof
        proof = EcvrfContractProofSolidity({
            alpha: alpha,
            pk: pk,
            gamma: gamma,
            c: c,
            s: s,
            uWitness: sender,
            cGammaWitness: cGammaWitness,
            sHashWitness: sHashWitness,
            zInv: zInv
        });
    }

    /// @notice Converts a bytes32 value to a dynamic byte array (length 32).
    /// @param b The bytes32 input.
    /// @return A dynamic byte array representing the same 32 bytes as the input.
    function bytes32ToBytes(bytes32 b) internal pure returns (bytes memory) {
        bytes memory out = new bytes(32);
        for (uint256 i = 0; i < 32; ++i) {
            out[i] = b[i];
        }
        return out;
    }

    /// @notice Tests that a number is correctly accepted when the nonce is valid
    function testCorrectNonceSubmission() public {
        vm.prank(qrng);
        uint64 nonce = contractStorage.getNonce(qrng);

        (
            SignatureSolidity memory sig,
            bytes32 hashData,
            EcvrfContractProofSolidity memory proof,
            uint256 number
        ) = buildSubmission(qrng, qrngKey, nonce);

        vm.prank(qrng);
        contractStorage.addRandomNumber(number, sig, hashData, proof);

        assertEq(contractStorage.getLengthArray(qrng), 1);
        vm.prank(qrng);
        assertEq(contractStorage.getNonce(qrng), nonce + 1);
    }

    /// @notice Tests rejection when the hash is built using an incorrect nonce
    function testRejectIncorrectNonceHashMismatch() public {
        vm.prank(qrng);
        uint64 nonce = contractStorage.getNonce(qrng);

        (
            SignatureSolidity memory sig,
            bytes32 hashData,
            EcvrfContractProofSolidity memory proof,
            uint256 number
        ) = buildSubmission(qrng, qrngKey, nonce + 1); // incorrect nonce

        vm.prank(qrng);
        vm.expectRevert(StorageNumber.IncorrectHash.selector);
        contractStorage.addRandomNumber(number, sig, hashData, proof);
    }

    /// @notice Tests rejection when the signature is invalid (wrong private key)
    function testRejectInvalidSignature() public {
        vm.prank(qrng);
        uint64 nonce = contractStorage.getNonce(qrng);

        (
            SignatureSolidity memory sig,
            bytes32 hashData,
            EcvrfContractProofSolidity memory proof,
            uint256 number
        ) = buildSubmission(qrng, 2, nonce); // Wrong private key

        vm.prank(qrng);
        vm.expectRevert(StorageNumber.IncorrectSignature.selector);
        contractStorage.addRandomNumber(number, sig, hashData, proof);
    }

    /// @notice Tests that a submitted number can be successfully retrieved
    function testAskNumberAfterSubmission() public {
        vm.prank(qrng);
        uint64 nonce = contractStorage.getNonce(qrng);

        (
            SignatureSolidity memory sig,
            bytes32 hashData,
            EcvrfContractProofSolidity memory proof,
            uint256 number
        ) = buildSubmission(qrng, qrngKey, nonce);

        vm.prank(qrng);
        contractStorage.addRandomNumber(number, sig, hashData, proof);

        uint256 fetched = contractStorage.askRandomNumber{value: 0.0003 ether}(
            false
        );
        assertEq(fetched, number);
    }

    /// @notice Tests retrieving multiple numbers after submitting multiple valid ones
    function testAskMultipleNumbers() public {
        for (uint8 i = 0; i < 3; ++i) {
            vm.prank(qrng);
            uint64 nonce = contractStorage.getNonce(qrng);
            (
                SignatureSolidity memory sig,
                bytes32 hashData,
                EcvrfContractProofSolidity memory proof,
                uint256 number
            ) = buildSubmission(qrng, qrngKey, nonce);

            vm.prank(qrng);
            contractStorage.addRandomNumber(number, sig, hashData, proof);
        }

        uint256[] memory results = contractStorage.askRandomNumbers{
            value: 0.0009 ether
        }(3, false);
        assertEq(results.length, 3);
    }

    /// @notice Tests that asking for numbers fails when none are stored
    function testRevertOnInsufficientStored() public {
        vm.expectRevert(
            abi.encodeWithSelector(StorageNumber.NotEnoughNumber.selector, 1)
        );
        contractStorage.askRandomNumbers{value: 0.0003 ether}(1, false);
    }

    /// @notice Tests that the contract reverts when attempting to add more random numbers than allowed per QRNG.
    /// Fills the storage to `maxPerWalletSize`, then asserts that the next addition fails with the correct custom error.
    function testRevertWhenExceedingMaxPerWalletSize() public {
        vm.prank(qrng);
        uint64 nonce = contractStorage.getNonce(qrng);

        // Fill to maxPerWalletSize (default is 20)
        for (uint64 i = 0; i < 20; ++i) {
            (
                SignatureSolidity memory sig,
                bytes32 hashData,
                EcvrfContractProofSolidity memory proof,
                uint256 number
            ) = buildSubmission(qrng, qrngKey, nonce + i);

            vm.prank(qrng);
            contractStorage.addRandomNumber(number, sig, hashData, proof);
        }

        // One more should revert
        (
            SignatureSolidity memory sigExtra,
            bytes32 hashDataExtra,
            EcvrfContractProofSolidity memory proofExtra,
            uint256 numberExtra
        ) = buildSubmission(qrng, qrngKey, nonce + 20);

        vm.prank(qrng);
        vm.expectRevert(
            abi.encodeWithSelector(
                StorageNumber.TooMuchGeneratedNumber.selector,
                20
            )
        );
        contractStorage.addRandomNumber(
            numberExtra,
            sigExtra,
            hashDataExtra,
            proofExtra
        );
    }

    /// @notice Tests that calling askRandomNumber with insufficient ETH fails.
    function testRevertOnIncorrectPayment() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                StorageNumber.IncorrectPayment.selector,
                0.0003 ether,
                0 ether
            )
        );
        contractStorage.askRandomNumber{value: 0 ether}(false);
    }

    /// @notice Tests that a QRNG can submit before revocation and is blocked after revocation
    function testRevokeQrngPreventsFurtherSubmissions() public {
        // Submit once successfully before revocation
        vm.prank(qrng);
        uint64 nonceBefore = contractStorage.getNonce(qrng);
        (
            SignatureSolidity memory sig1,
            bytes32 hashData1,
            EcvrfContractProofSolidity memory proof1,
            uint256 number1
        ) = buildSubmission(qrng, qrngKey, nonceBefore);

        vm.prank(qrng);
        contractStorage.addRandomNumber(number1, sig1, hashData1, proof1);
        assertEq(contractStorage.getLengthArray(qrng), 1);

        // Revoke the QRNG key
        contractStorage.revokeQrngKey(qrng);

        // Next submission from the same QRNG should fail with IncorrectSignature
        vm.prank(qrng);
        uint64 nonceAfter = contractStorage.getNonce(qrng);
        (
            SignatureSolidity memory sig2,
            bytes32 hashData2,
            EcvrfContractProofSolidity memory proof2,
            uint256 number2
        ) = buildSubmission(qrng, qrngKey, nonceAfter);

        vm.prank(qrng);
        vm.expectRevert(StorageNumber.IncorrectSignature.selector);
        contractStorage.addRandomNumber(number2, sig2, hashData2, proof2);
    }

    /// @notice Tests that numbers added before revocation cannot be consumed after revocation
    function testRevokedNumbersAreNotConsumable() public {
        // Add a number successfully
        vm.prank(qrng);
        uint64 nonce = contractStorage.getNonce(qrng);
        (
            SignatureSolidity memory sig,
            bytes32 hashData,
            EcvrfContractProofSolidity memory proof,
            uint256 number
        ) = buildSubmission(qrng, qrngKey, nonce);

        vm.prank(qrng);
        contractStorage.addRandomNumber(number, sig, hashData, proof);
        assertEq(contractStorage.getLengthArray(qrng), 1);

        // Revoke QRNG
        contractStorage.revokeQrngKey(qrng);

        // Attempting to consume should revert with NotEnoughNumber because revoked QRNG
        // is no longer counted in getAllNumber()/iteration
        vm.expectRevert(
            abi.encodeWithSelector(StorageNumber.NotEnoughNumber.selector, 1)
        );
        contractStorage.askRandomNumber{value: 0.0003 ether}(false);
    }
}
