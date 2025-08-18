![Contributions Closed](https://img.shields.io/badge/contributions-closed-red)
![Project Stage: Alpha](https://img.shields.io/badge/status-alpha-orange)
![Rust](https://img.shields.io/badge/Rust-1.81%2B-orange)

# Qrng Blockchain Project

QryptoRand is a hybrid Rust + Solidity system enabling verifiable on-chain randomness from a quantum random number generator (QRNG). It combines hardware interaction (Rust) with smart contract-based consumption (Solidity/Foundry), offering secure randomness for games, lotteries, and zero-trust applications.


## Getting Started

## 0. Cloning repository 

> Already present in lottery under `./contracts/lib/QryptoRand`

When cloning the repo, use `--recurse-submodules`:
```bash
git clone --recurse-submodules https://github.com/iQrypto/QryptoRand
cd QryptoRand
```

### 1. Install Dependencies
 
You will need Rust version 1.81 or higher to build the project.
 
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash && foundryup -i 1.3.1
 
# Install just (optional but recommended)
cargo install just
```
 
### 2. Setup the Project
 
```bash
cp .env.example .env
just setup
```
 
### 3. Run the System 
Run the following commands from the `QryptoRand` directory (`./contracts/lib/QryptoRand` in lottery repo).
```bash
just start-anvil       # Start local blockchain
# On another terminal:
just deploy-backend    # Deploy Token and StorageNumber contracts
# If no access to qrng and for testing purposes use
just start-prng
# If access to qrng use
just start-qrng
```

## Randomness Source Requirements

By default, this system is designed to use a true quantum random number generator (QRNG) to ensure high-entropy, unbiased randomness for production use. To obtain early access to a QRNG device, please contact us at [hello@iqrypto.com](mailto:hello@iqrypto.com). For local development without hardware, enable the testing feature to fall back to a pseudorandom number generator (PRNG).

## Environment Configuration

The `.env` file configures your deployment and wallet keys.

| Key | Description |
|-----|-------------|
| `PRIVATE_KEY_WALLET` | Deployer key (used for contract creation and transactions) |
| `WALLET`             | Public address of the deployer |
| `ETH_RPC_URL`        | HTTP RPC endpoint for Anvil or external chain |
| `WS_RPC_URL`         | WebSocket endpoint for event listeners |
| `TOKEN_ADDRESS`      | Address of the deployed IQryptoToken |
| `STORAGE_ADDRESS`    | Address of the deployed StorageNumber |
| `INITIAL_SUPPLY`     | Token initial supply (e.g., 1000000000000000000000) |
| `PORT_BLOCKCHAIN`    | Anvil RPC port |
| `IP_HARDWARE`        | IP address of the QRNG device |
| `PORT_HARDWARE`      | TCP port of the QRNG device |

## Available Commands

Run `just --list` for the full set.

Common ones:

```bash
just start-anvil      # Run local blockchain
just deploy-backend   # Deploy all contracts
just start-qrng       # Run Rust backend and feed QRNG numbers
just start-prng       # For testing only: Run Rust backend and feed PRNG numbers
just test-solidity    # Run Forge tests
just clean            # Clean all generated files
```

## Project Structure

```
QryptoRand/
├── contracts/           # Solidity contracts (StorageNumber, Token)
│   ├── src/             # Core logic
│   ├── test/            # Forge-based tests
│   ├── script/          # Script automation for deployment/config
│   └── examples/        # Learning & integration examples
├── qrng-controller/     # Rust crate to communicate with the QRNG hardware
├── crates/bindings/     # Auto-generated Solidity ABI bindings for Rust
├── justfile             # Task automation using `just`
├── .env.example         # Environment variables required for CLI commands
└── README.md
```

## Architecture Overview

QryptoRand is composed of three major layers:

1. **Quantum RNG Device (Hardware)**  
   - Emits signed, hashed and proved quantum entropy over a TCP connection.

2. **Rust Backend (`qrng-controller/`)**  
   - Listens for events on the `StorageNumber` smart contract.
   - Fetches entropy from the QRNG.

3. **Solidity Smart Contracts (`contracts/src/`)**  
   - `IQryptoStorageNumber`: Stores randomness and verifies it optionally via VRF.
   - `IQryptoToken`: Pays QRNG providers in a native token upon submission.

4. **Bindings (`crates/bindings/`)**  
   - Generated Rust code that maps Solidity functions via ABI → used by the Rust backend.
   - Run `just bind-solidity` to regenerate after contract changes.

---

### Data Flow

```text
[QRNG Hardware] --(TCP Msgpk)--> [Rust (qrng-controller)]
                           |
                           v
       [forge bind] <-- [Solidity Contracts]
                           |
                           v
             [Anvil / Blockchain Node]
```

> To generate ABI bindings:  
> ```bash
> just bind-solidity
> ```

> These go in: `crates/bindings/`, auto-generated from the contracts in `contracts/`


## Security Model

- `StorageNumber` optionally verifies VRF proofs on-chain.
- Off-chain QRNG uses signed and hashed messages to ensure authenticity.
- All random numbers must be authorized by `msg.sender` and validated against a public key.

See [`SECURITY.md`](./SECURITY.md) for details.

## Contributing

🚧 QryptoRand is not open to external contributions **yet**.

See [`CONTRIBUTING.md`](./CONTRIBUTING.md)

## License

This project is licensed under the [MIT License](./LICENSE).

## Additional Resources

- [Foundry Docs](https://book.getfoundry.sh/)
- [Alloy](https://github.com/alloy-rs/alloy)
- [just task runner](https://github.com/casey/just)

