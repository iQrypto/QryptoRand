// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EcvrfContractProofSolidity, StorageInterface, Random, SignatureSolidity} from "./interfaces/StorageInterface.sol";
import {Token} from "./IQryptoToken.sol";
import {VRF} from "./lib/VRF.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title IQrypto Randomness Storage Contract
/// @author iQrypto
/// @notice Stores and manages random numbers submitted by trusted QRNGs, and allows retrieval with optional VRF verification.
/// @dev Verifies ECDSA signatures and (optionally) VRF proofs off-chain or on-chain using a simplified verifier.
/// Implements StorageInterface and Ownable for access control and external integration.
contract StorageNumber is StorageInterface, Ownable {
    /// @notice The token contract used to reward QRNG generators for valid random number submissions.
    /// @dev Must implement the `transferGenerationNumber` method, and be owned by the same owner as this contract.
    Token public token;
    uint256 public constant QRN_PRICE = 0.0003 ether;
    using VRF for uint256;

    // Storage structure.
    uint64 private _maxPerWalletSize = 20;
    uint32 private _currentGenerator;
    bool private _canAddNumber;
    mapping(address => Random[]) private _arrayRandom; // QRNGs -> Random[].
    mapping(address => uint64) private _nonces;

    error NotEnoughNumber(uint64 number);
    error TooMuchGeneratedNumber(uint64 number);
    error IncorrectSignature();
    error IncorrectHash();
    error IncorrectPayment(uint256 expected, uint256 actual);

    // QRNGs
    mapping(address => address) private _keyByWallet;
    address[] private _generators;

    /// @notice Emitted when a new random number is successfully added to a QRNG's storage array.
    /// @param number The Random struct containing the value and its proof.
    event RandomAdded(Random number);
    /// @notice Emitted when a generator's remaining capacity for new numbers is queried.
    /// @param qrng The QRNG wallet address being queried.
    /// @param number The number of slots still available for this QRNG.
    event GenerationLeft(address qrng, uint256 number);
    /// @notice Emitted when a random number is retrieved from a QRNG's stored array.
    /// @param qrng The QRNG wallet from which the number was taken.
    /// @param number The Random struct that was retrieved.
    event AskElements(address qrng, Random number);

    /// @notice Initializes the StorageNumber contract with the linked token contract.
    /// @param contractToken The address of the IQryptoToken contract.
    constructor(address contractToken) Ownable(msg.sender) {
        token = Token(contractToken);
    }

    /// @notice Registers a QRNG wallet with its corresponding public key.
    /// @param wallet The QRNG wallet address.
    /// @param key The public key associated with the QRNG.
    function setQrngKey(address wallet, address key) public onlyOwner {
        _keyByWallet[wallet] = key;
        _generators.push(wallet);
    }

    /// @notice Revokes the QRNG key for a wallet.
    /// @param wallet The QRNG wallet address to revoke.
    function revokeQrngKey(address wallet) public onlyOwner {
        delete _keyByWallet[wallet];

        for (uint256 i = 0; i < _generators.length; ++i) {
            if (_generators[i] == wallet) {
                _generators[i] = _generators[_generators.length - 1];
                _generators.pop();
                break;
            }
        }
    }

    /// @notice Updates the maximum number of stored random values per wallet.
    /// @param newarrayMaxSize The new maximum array size per QRNG wallet.
    function setArrayMaxSize(uint64 newarrayMaxSize) public onlyOwner {
        _maxPerWalletSize = newarrayMaxSize;
    }

    /// @notice Returns the current nonce value associated with the caller.
    /// @param wallet The address whose nonce value is being queried.
    /// @return The nonce value for msg.sender.
    function getNonce(address wallet) public view returns (uint64) {
        return _nonces[wallet];
    }

    /// @notice Emits an event showing how many more numbers the QRNG can generate.
    /// @param qrng The QRNG wallet address to query.
    function emitGenerationCapacity(address qrng) public {
        emit GenerationLeft(qrng, _maxPerWalletSize - getLengthArray(qrng));
    }

    /// @notice Returns the number of random values stored for a specific QRNG.
    /// @param qrng The QRNG wallet address.
    /// @return The number of values currently stored.
    function getLengthArray(address qrng) public view returns (uint256) {
        return _arrayRandom[qrng].length;
    }

    /// @notice Returns the total number of random values stored across all QRNGs.
    /// @return The total count of stored random numbers.
    function getAllNumber() public view returns (uint256) {
        uint256 number;
        for (uint32 i = 0; i < _generators.length; ++i) {
            number += _arrayRandom[_generators[i]].length;
        }
        return number;
    }

    /// @notice Requests a single random number from the available pool.
    /// @param verifyProof Whether to verify the VRF proof before returning.
    /// @return The retrieved random number.
    function askRandomNumber(
        bool verifyProof
    ) external payable returns (uint256) {
        if (msg.value != QRN_PRICE) {
            revert IncorrectPayment(QRN_PRICE, msg.value);
        }
        return _askRandomNumbers(1, verifyProof)[0];
    }

    /// @notice Requests multiple random numbers from the available pool.
    /// @param amount Number of random values requested.
    /// @param verifyProof Whether to verify each proof before returning.
    /// @return An array of random numbers retrieved from storage.
    function askRandomNumbers(
        uint16 amount,
        bool verifyProof
    ) external payable returns (uint256[] memory) {
        uint256 totalPrice = QRN_PRICE * amount;
        if (msg.value != totalPrice) {
            revert IncorrectPayment(totalPrice, msg.value);
        }
        return _askRandomNumbers(amount, verifyProof);
    }

    /// @notice Internal helper that handles retrieval of one or more random numbers.
    /// @param amount Number of values to retrieve.
    /// @param verifyProof Whether to verify the VRF proof before returning.
    /// @return An array of retrieved random numbers.
    function _askRandomNumbers(
        uint16 amount,
        bool verifyProof
    ) private returns (uint256[] memory) {
        if (amount == 0 || getAllNumber() < amount) {
            revert NotEnoughNumber(amount);
        }
        uint32 _currentGeneratorS = _currentGenerator;

        uint256 seed = uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender, gasleft()))
        );
        uint256 index = seed % _generators.length;

        uint256[] memory arrayNumbersToSend = new uint256[](amount);
        for (uint16 i = 0; i < amount; ++i) {
            for (uint32 j = 0; j < _generators.length; ++j) {
                address qrng = _generators[(index + j) % _generators.length];
                if (_arrayRandom[qrng].length != 0) {
                    _currentGenerator =
                        (_currentGeneratorS + 1) %
                        uint32(_generators.length);
                    Random memory random = _arrayRandom[qrng][
                        _arrayRandom[qrng].length - 1
                    ];
                    _arrayRandom[qrng].pop();
                    if (verifyProof) {
                        verifyVrf(random.proof);
                    }
                    token.transferGenerationNumber(qrng);
                    emit AskElements(qrng, random);
                    arrayNumbersToSend[i] = random.number;
                    break;
                }
            }
        }
        return arrayNumbersToSend;
    }

    /// @notice Adds a new random number to storage after verifying the signature and hash.
    /// @param number The random number to be stored (derived from VRF alpha).
    /// @param signature The ECDSA signature object with wallet metadata.
    /// @param hashData The keccak256 hash of alpha and nonce.
    /// @param proof The VRF proof structure for verification.
    function addRandomNumber(
        uint256 number,
        SignatureSolidity calldata signature,
        bytes32 hashData,
        EcvrfContractProofSolidity calldata proof
    ) public {
        uint64 nonce = _nonces[msg.sender];
        _addRandomNumber(number, nonce, signature, hashData, proof);
        ++_nonces[msg.sender];
    }

    /// @notice Adds multiple random numbers in a batch.
    /// @param numbers The random numbers to be stored (derived from VRF alpha).
    /// @param signatures Array of ECDSA signature objects.
    /// @param hashData Array of keccak256 hashes for each random submission.
    /// @param proofs Array of corresponding VRF proofs.
    function addRandomNumbers(
        uint256[] calldata numbers,
        SignatureSolidity[] calldata signatures,
        bytes32[] calldata hashData,
        EcvrfContractProofSolidity[] calldata proofs
    ) public {
        uint64 nonce = _nonces[msg.sender];
        for (uint8 i = 0; i < signatures.length; ++i) {
            _addRandomNumber(
                numbers[i],
                nonce,
                signatures[i],
                hashData[i],
                proofs[i]
            );
            ++nonce;
        }
        _nonces[msg.sender] = nonce;
    }

    /// @notice Internal logic to validate a submitted random number and store it.
    /// @param number The random number to be stored (derived from VRF alpha).
    /// @param nonce The expected nonce used to bind the number to the sender.
    /// @param signature The ECDSA signature metadata.
    /// @param hashData The signed hash combining alpha and nonce.
    /// @param proof The VRF proof associated with the random value.
    function _addRandomNumber(
        uint256 number,
        uint64 nonce,
        SignatureSolidity calldata signature,
        bytes32 hashData,
        EcvrfContractProofSolidity calldata proof
    ) private {
        if (_arrayRandom[signature.wallet].length >= _maxPerWalletSize) {
            revert TooMuchGeneratedNumber(_maxPerWalletSize);
        }

        // Construct expected hash with nonce
        bytes memory message = abi.encodePacked(bytes32(number), nonce);
        bytes32 expectedHash = keccak256(message);

        if (hashData != expectedHash) {
            revert IncorrectHash();
        }

        address recoveredAddress = ecrecover(
            hashData,
            signature.v,
            signature.r,
            signature.s
        );
        if (recoveredAddress != _keyByWallet[signature.wallet]) {
            revert IncorrectSignature();
        }

        _canAddNumber = true;
        _addToArray(proof.alpha, signature.wallet, proof);
        token.transferGenerationNumber(signature.wallet);
        _canAddNumber = false;
    }

    /// @notice Converts a bytes32 value to a bytes array.
    /// @param b The bytes32 input value.
    /// @return A bytes array of length 32.
    function bytes32ToBytes(bytes32 b) internal pure returns (bytes memory) {
        bytes memory out = new bytes(32);
        for (uint256 i = 0; i < 32; ++i) {
            out[i] = b[i];
        }
        return out;
    }

    /// @notice Adds a validated random number to the QRNG's storage array.
    /// @param bytesNumber The seed from which the number is derived.
    /// @param generator The wallet address that submitted the number.
    /// @param proof The VRF proof associated with the random value.
    function _addToArray(
        bytes32 bytesNumber,
        address generator,
        EcvrfContractProofSolidity calldata proof
    ) private {
        if (_canAddNumber) {
            Random memory random = Random(uint256(bytesNumber), proof);
            _arrayRandom[generator].push(random);
            emit RandomAdded(random);
        }
    }

    /// @notice Verifies a full VRF proof on-chain.
    /// @param proof The complete VRF proof data.
    /// @return True if the proof is valid, false otherwise.
    function verifyVrf(
        EcvrfContractProofSolidity memory proof
    ) public view returns (bool) {
        VRF._verifyVRFProof(
            proof.pk,
            proof.gamma,
            proof.c,
            proof.s,
            uint256(proof.alpha),
            proof.uWitness,
            proof.cGammaWitness,
            proof.sHashWitness,
            proof.zInv
        );
        return true;
    }
}
