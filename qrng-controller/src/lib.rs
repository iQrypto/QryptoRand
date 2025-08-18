//! QRNG Controller Library
//!
//! This library provides utilities for requesting and formatting quantum random numbers (QRNs)
//! to be consumed by an on-chain contract. It supports both real hardware backends and mock
//! offline generation (via the `SignedQrnGenerator` trait).


use alloy::{
    network::{Network, ReceiptResponse},
    primitives::{Address, FixedBytes, U256},
    providers::Provider,
};

#[cfg(not(feature = "testing"))]
use backend::{HardwareInterface, SignedQRN};
use color_eyre::{Result, eyre::eyre};
use foundry_contracts::storage_number::StorageNumber::{
    self, EcvrfContractProofSolidity, SignatureSolidity,
};
use log::debug;

pub type SignedNumber = (U256, FixedBytes<32>, SignatureSolidity, EcvrfContractProofSolidity);

/// Trait for types that can generate signed and provable quantum random numbers (QRNs).
///
/// This trait abstracts over the hardware backend or a mock (e.g., for testing).
/// Each generated QRN is accompanied by a keccak256 hash, an Ethereum-compatible signature,
/// and a VRF proof.
pub trait SignedGenerator {
    fn get_signed(&mut self, amount: u32, nonce: u64, wallet: Address) -> Result<Vec<SignedNumber>>;
}

#[cfg(not(feature = "testing"))]
impl<T: HardwareInterface> SignedGenerator for T {
    fn get_signed(&mut self, amount: u32, nonce: u64, wallet: Address) -> Result<Vec<SignedNumber>> {
        let mut ret = vec![];

        for SignedQRN { number, hash, sig, v, proof } in self.get_qrn(amount, nonce)? {
            let random_data_u256 =
                U256::from_be_bytes::<{ U256::BYTES }>(number.clone().try_into().unwrap());

            let signature_solidity = SignatureSolidity {
                r: FixedBytes::from_slice(&sig[..32]),
                s: FixedBytes::from_slice(&sig[32..]),
                v: v + 27, // signature.v returns 0 or 1 but Ethereum uses value 27 or 28 respectively, that's why the "+27" appears
                wallet,
            };

            let proof_solidity = parse_vrf_proof(&proof);

            ret.push((
                random_data_u256,
                FixedBytes::from_slice(&hash),
                signature_solidity,
                proof_solidity,
            ));
        }
        Ok(ret)
    }
}

/// Sends one or more signed and verified random numbers to the on-chain QRNG contract.
///
/// Handles both batch and single insertions depending on the `generation_left` value.
///
/// # Arguments
///
/// * `contract_qrng` - Instance of the on-chain storage contract.
/// * `wallet_address` - Address to submit transactions from.
/// * `generation_left` - Number of QRNs requested by the contract.
/// * `rng` - Generator providing QRNs (either hardware or mock).
/// * `nonce` - Nonce to use for this generation batch.
///
/// # Errors
///
/// Returns a `color_eyre::Report` if:
//  - The generation fails.
//  - The transaction is reverted.
//  - The receipt shows a failed status.
pub async fn send_random_number<P, N>(
    contract_qrng: &StorageNumber::StorageNumberInstance<P, N>,
    wallet_address: Address,
    generation_left: U256,
    rng: &mut impl SignedGenerator,
    nonce: u64,
) -> color_eyre::Result<()>
where
    P: Provider<N>,
    N: Network,
{
    let mut data = vec![];
    let mut hashes = vec![];
    let mut signatures = vec![];
    let mut proofs = vec![];

    let gen_left = generation_left.into_limbs()[0] as u32;
    let signed_qrn_data = rng.get_signed(gen_left, nonce, wallet_address)?;
    for (random_data_u256, hash, sig, proof) in signed_qrn_data {
        data.push(random_data_u256);
        hashes.push(hash);
        signatures.push(sig);
        proofs.push(proof);
    }
    let tx_qrng = if generation_left != U256::from(1) {
        contract_qrng
            .addRandomNumbers(data.clone(), signatures, hashes, proofs)
            .from(wallet_address)
            .send()
            .await?
    } else {
        contract_qrng
            .addRandomNumber(data[0], signatures[0].clone(), hashes[0], proofs[0].clone())
            .from(wallet_address)
            .send()
            .await?
    };

    let receipt = tx_qrng.get_receipt().await?;
    if receipt.status() {
        for bytes in data {
            debug!("Number generated: {bytes:?}");
        }
    } else {
        let tx_hash = receipt.transaction_hash();
        let trace: serde_json::Value = contract_qrng
            .provider()
            .raw_request(std::borrow::Cow::Borrowed("debug_traceTransaction"), [tx_hash])
            .await?;
        return Err(eyre!("Revert reason: {trace:?}"));
    }
    Ok(())
}

/// Parses a raw byte buffer into a Solidity-compatible VRF proof structure.
///
/// # Arguments
///
/// * `buf` - A byte slice containing the VRF proof as expected by the ECVRF contract.
///
/// # Panics
///
/// Panics if the buffer is not the expected length or improperly formatted.
pub fn parse_vrf_proof(buf: &[u8]) -> EcvrfContractProofSolidity {
    let mut i = 0;
    let mut next_n = |n| {
        let bytes: [u8; 32] = buf[i..i + 32].try_into().expect("Data send should be ok");
        i += n;
        bytes
    };
    let alpha = next_n(32);
    let pk_x = U256::from_be_bytes(next_n(32));
    let pk_y = U256::from_be_bytes(next_n(32));
    let gamma_x = U256::from_be_bytes(next_n(32));
    let gamma_y = U256::from_be_bytes(next_n(32));
    let c = U256::from_be_bytes(next_n(32));
    let s = U256::from_be_bytes(next_n(32));

    let u_witness = Address::from_slice(&next_n(20)[..20]);

    let c_gamma_x = U256::from_be_bytes(next_n(32));
    let c_gamma_y = U256::from_be_bytes(next_n(32));
    let s_hash_x = U256::from_be_bytes(next_n(32));
    let s_hash_y = U256::from_be_bytes(next_n(32));
    let z_inv = U256::from_be_bytes(next_n(32));

    EcvrfContractProofSolidity {
        alpha: FixedBytes::<{ U256::BYTES }>::from_slice(&alpha),
        pk: [pk_x, pk_y],
        gamma: [gamma_x, gamma_y],
        c,
        s,
        uWitness: u_witness,
        cGammaWitness: [c_gamma_x, c_gamma_y],
        sHashWitness: [s_hash_x, s_hash_y],
        zInv: z_inv,
    }
}
