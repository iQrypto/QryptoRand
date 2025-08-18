//! QRNG Controller Binary
//!
//! This binary connects to a WebSocket provider and listens for events from the on-chain
//! QRNG consumer contract. When a generation request is observed, it fetches random numbers
//! (from either hardware or a mock source) and submits them via `send_random_number`.
//!
//! The backend can be real hardware or mocked (if compiled with `--features testing`).

#[cfg(feature = "testing")]
mod offline;

use alloy::{
    eips::BlockNumberOrTag,
    primitives::{Address, U256},
    providers::{Provider, ProviderBuilder, WsConnect},
    rpc::types::Filter,
    signers::local::PrivateKeySigner,
};
use dotenv::dotenv;
use foundry_contracts::storage_number::StorageNumber;
use futures_util::stream::StreamExt;
use log::{debug, info};
use qrng_controller::send_random_number;
use std::{env, str::FromStr};

#[tokio::main]
async fn main() -> color_eyre::Result<()> {
    dotenv().ok();
    env_logger::init_from_env(
        env_logger::Env::default().filter_or(env_logger::DEFAULT_FILTER_ENV, "debug"),
    );

    let wallet_address: Address = Address::from_str(&env::var("WALLET")?)?;
    info!("Using wallet address: {wallet_address:?}");

    let private_key = env::var("PRIVATE_KEY_WALLET")?;
    let wallet: PrivateKeySigner = private_key.parse()?;

    // WS and http provider
    let provider = ProviderBuilder::new()
        .wallet(wallet.clone())
        .connect_http(env::var("ETH_RPC_URL")?.parse()?)
        .to_owned();
    let storage_address = env::var("STORAGE_ADDRESS")?;
    let storage_contract = StorageNumber::new(storage_address.parse()?, provider.clone());
    let ws = WsConnect::new(env::var("WS_RPC_URL")?);
    let ws_provider = ProviderBuilder::new().wallet(wallet).connect_ws(ws).await?;

    #[cfg(not(feature = "testing"))]
    let mut interface = {
        let ip = env::var("IP_HARDWARE").unwrap_or("192.168.0.223".to_string());

        let port = env::var("PORT_HARDWARE").unwrap_or_default().parse().unwrap_or(2260);
        backend::interface::Tcp::connect(ip.parse()?, port)?
    };

    #[cfg(feature = "testing")]
    let mut interface = offline::OfflineGenerator::new();

    // Creating subscriber to generation event logs
    let filter = Filter::new()
        .address(Address::from_str(&storage_address)?)
        .from_block(BlockNumberOrTag::Latest)
        .events([
            "GenerationLeft(address,uint256)",
            "AskElements(address,(uint256,(bytes32,uint256[2],uint256[2],uint256,uint256,address,uint256[2],uint256[2],uint256)))",
        ])
    ;
    let sub = ws_provider.subscribe_logs(&filter).await?;
    let mut stream = sub.into_stream();

    info!("Asking generation left");
    let _ = storage_contract.emitGenerationCapacity(wallet_address).send().await?;
    let mut nonce = storage_contract.getNonce(wallet_address).call().await?;

    let mut generation_left = U256::ZERO;
    while let Some(log) = stream.next().await {
        debug!("Received event");

        if let Ok(event) = log.log_decode::<StorageNumber::AskElements>() {
            if event.inner.data.qrng == wallet_address {
                generation_left += U256::from(1);
            }
        } else if let Ok(event) = log.log_decode::<StorageNumber::GenerationLeft>() {
            if event.inner.data.qrng == wallet_address && event.inner.data.number != U256::ZERO {
                generation_left = event.inner.data.number;
            }
        } else {
            debug!("{log:?}")
        }

        debug!("Gen left {generation_left}");
        if generation_left >= U256::from(5) {
            send_random_number(
                &storage_contract,
                wallet_address,
                generation_left,
                &mut interface,
                nonce,
            )
            .await?;
            generation_left = U256::ZERO;
            nonce = storage_contract.getNonce(wallet_address).call().await?;
        }
    }
    Ok(())
}
