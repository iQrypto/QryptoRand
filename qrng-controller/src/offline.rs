//! Offline QRN Generator for Testing
//!
//! This module provides an implementation of the `SignedQrnGenerator` trait using a fixed private key
//! for signing and proving VRF outputs. It is intended solely for offline testing and simulations without
//! requiring access to the actual QRNG hardware.
//!
//! Activated when the `testing` feature is enabled (`--features testing`).

use alloy::primitives::{keccak256, Address, FixedBytes, U256};
use ethsign::SecretKey as SignatureSecretKey;
use ethsign::SecretKey;
use foundry_contracts::storage_number::StorageNumber::{
    EcvrfContractProofSolidity, SignatureSolidity,
};
use libecvrf::{
    extends::ScalarExtend,
    secp256k1::curve::{Affine, Scalar},
    secp256k1::SecretKey as ProverSecretKey,
    ECVRF,
};
use qrng_controller::{SignedGenerator, SignedNumber};

use rand::{self, Rng};

// FOR OFFLINE TEST ONLY!
// Need to adapt the public key in deployment script of the solidity contract
const PRIVATE_KEY: &[u8; 32] = &[
    0xa1, 0x2b, 0x45, 0xc8, 0x9d, 0x3e, 0x47, 0xa4, 0x56, 0xf8, 0xf8, 0x9b, 0xa6, 0x7c, 0x85, 0xc4,
    0xd2, 0xc6, 0x72, 0x01, 0x91, 0xb4, 0x8f, 0x79, 0xd4, 0xe5, 0x68, 0xf1, 0xa6, 0x47, 0xc3, 0xf1,
];

pub struct OfflineGenerator {
    private_key_sign: SignatureSecretKey,
    private_key_prover: ProverSecretKey,
}

impl OfflineGenerator {
    /// Creates a new `OfflineGenerator` using a static private key.
    ///
    /// # Panics
    /// Panics if the private key cannot be parsed into either the signature or prover key format.
    pub fn new() -> Self {
        let private_key_sign = SignatureSecretKey::from_raw(PRIVATE_KEY).unwrap();
        let private_key_prover = ProverSecretKey::parse_slice(PRIVATE_KEY).unwrap();
        Self { private_key_sign, private_key_prover }
    }
}

impl SignedGenerator for OfflineGenerator {
    /// Generates `amount` pseudorandom numbers and corresponding signatures and VRF proofs.
    fn get_signed(
        &mut self,
        amount: u32,
        nonce: u64,
        address: Address,
    ) -> color_eyre::Result<Vec<SignedNumber>> {
        let mut rng = rand::thread_rng();
        let ecvrf = ECVRF::new(self.private_key_prover);
        let mut res = vec![];

        for i in 0..(amount as u64) {
            let (number, hash) = generate_number(&mut rng, nonce + i);
            let number_u256 =
                U256::from_be_bytes::<{ U256::BYTES }>(number);

            let signature_solidity = sign_data(&hash, &self.private_key_sign, address);

            let proof_solidity = create_vrf_proof(&ecvrf, &number);

            res.push((number_u256, hash, signature_solidity, proof_solidity));
        }
        Ok(res)
    }
}

/// Generates a deterministic ECVRF proof for the given `random_data` using the given `ECVRF` instance.
///
/// # Arguments
///
/// * `ecvrf` - ECVRF prover configured with a secret key.
/// * `random_data` - 32-byte pseudorandom data that serves as the input alpha.
///
/// # Returns
///
/// A fully structured `EcvrfContractProofSolidity` suitable for contract submission.
pub fn create_vrf_proof(ecvrf: &ECVRF<'_>, random_data: &[u8]) -> EcvrfContractProofSolidity {
    let proof = ecvrf.prove_contract(&Scalar::from_bytes(random_data));
    let mut proof_pb: Affine = proof.pk.into();
    proof_pb.x.normalize();
    proof_pb.y.normalize();
    EcvrfContractProofSolidity {
        alpha: FixedBytes::<{ U256::BYTES }>::from_slice(&proof.alpha.b32()),
        pk: [U256::from_be_bytes(proof_pb.x.b32()), U256::from_be_bytes(proof_pb.y.b32())],
        gamma: [U256::from_be_bytes(proof.gamma.x.b32()), U256::from_be_bytes(proof.gamma.y.b32())],
        c: U256::from_be_bytes(proof.c.b32()),
        s: U256::from_be_bytes(proof.s.b32()),
        uWitness: Address::from_slice(&proof.witness_address.b32()[0..20]),
        cGammaWitness: [
            U256::from_be_bytes(proof.witness_gamma.x.b32()),
            U256::from_be_bytes(proof.witness_gamma.y.b32()),
        ],
        sHashWitness: [
            U256::from_be_bytes(proof.witness_hash.x.b32()),
            U256::from_be_bytes(proof.witness_hash.y.b32()),
        ],
        zInv: U256::from_be_bytes(proof.inverse_z.b32()),
    }
}

/// Signs a 32-byte hash using the provided Ethereum-compatible signature key.
///
/// # Arguments
///
/// * `random_data` - The 32-byte hash to sign (typically keccak256 of randomness + nonce).
/// * `private_key_sign` - Ethereum `SecretKey` used to sign the hash.
/// * `wallet_address` - Address to be embedded in the signature for verification.
///
/// # Returns
///
/// A `SignatureSolidity` structure suitable for submitting to an Ethereum smart contract.
pub fn sign_data(
    random_data: &[u8; 32],
    private_key_sign: &SecretKey,
    wallet_address: Address,
) -> SignatureSolidity {
    let signature = private_key_sign.sign(random_data).unwrap();
    SignatureSolidity {
        r: FixedBytes::<{ U256::BYTES }>::new(signature.r),
        s: FixedBytes::<{ U256::BYTES }>::new(signature.s),
        v: signature.v + 27, // signature.v returns 0 or 1 but Ethereum uses value 27 or 28 respectively, that's why the "+27" appears.
        wallet: wallet_address,
    }
}

/// Generates a random 256-bit number and its associated keccak256 hash.
///
/// # Arguments
///
/// * `rng` - Random number generator implementing `Rng`.
/// * `nonce` - A nonce to pair with the randomness to ensure uniqueness.
///
/// # Returns
///
/// A tuple `(random_data, hash)` where:
/// - `random_data` is a 32-byte array representing the random number.
/// - `hash` is the `keccak256(random_data || nonce)`.
pub fn generate_number(
    rng: &mut impl Rng,
    nonce: u64,
) -> ([u8; U256::BYTES], FixedBytes<{ U256::BYTES }>) {
    let data: [u8; U256::BYTES] = rng.gen();
    let mut message = Vec::with_capacity(32 + 8); // 32 for random_data, 8 for nonce
    message.extend_from_slice(&data);
    message.extend_from_slice(&nonce.to_be_bytes());

    let hash_data = keccak256(&message);
    (data, hash_data)
}
