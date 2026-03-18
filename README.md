# b1e55ed-contracts

ERC-8004 Reputation and Validation registries for the [b1e55ed](https://oracle.b1e55ed.permanentupperclass.com) falsifiable signal oracle.

Built for the [Synthesis hackathon](https://synthesis.xyz) (Mar 13–22, 2026) — on-chain karma and council verdict artifacts that let anyone verify b1e55ed's forecast track record and code quality history.

---

## What's in here

| Contract | Purpose |
|---|---|
| `ReputationRegistry` | Receives `giveFeedback()` calls after each forecast resolves. Accumulates karma on-chain. |
| `ValidationRegistry` | Receives Review Council verdicts after each PR review. Immutable audit trail. |

Both contracts are bound to the ERC-8004 Identity Registry singleton on Base mainnet:

```
0x8004A169FB4a3325136EB29fA0ceB6D2e539a432
```

[View on Basescan →](https://basescan.org/address/0x8004A169FB4a3325136EB29fA0ceB6D2e539a432)

---

## Architecture

```
b1e55ed Oracle
    │
    ├── forecast resolves
    │       └── giveFeedback() → ReputationRegistry
    │                               └── emits FeedbackGiven
    │
    └── PR merged / reviewed
            └── postValidation() → ValidationRegistry
                                    └── emits ValidationPosted
```

The Identity Registry mints an `agentId` NFT when b1e55ed calls `register()`. Both registries verify the agentId exists before accepting data.

---

## Contracts

### ReputationRegistry

Stores karma feedback from the oracle after each forecast resolution.

```solidity
function giveFeedback(
    uint256 agentId,
    int128 value,           // karma delta
    uint8 valueDecimals,    // precision: value=420, decimals=2 → 4.20 karma
    string calldata tag1,   // e.g. "karma"
    string calldata tag2,   // e.g. "forecast_outcome"
    string calldata endpoint,
    string calldata feedbackURI,  // link to outcome JSON
    bytes32 feedbackHash          // keccak256(outcome JSON)
) external;

// Read
function getFeedback(uint256 agentId) external view returns (FeedbackEntry[] memory);
function getFeedbackCount(uint256 agentId) external view returns (uint256);
function getAggregateKarma(uint256 agentId) external view returns (int256); // scaled 1e6
function getFeedbackPaginated(uint256 agentId, uint256 offset, uint256 limit)
    external view returns (FeedbackEntry[] memory entries, uint256 total);
```

### ValidationRegistry

Stores Review Council verdicts: `"pass"`, `"concern"`, `"block"`, `"human-required"`.

```solidity
function postValidation(
    uint256 agentId,
    string calldata verdictStr,   // "pass" | "concern" | "block" | "human-required"
    string calldata context,      // PR URL or context reference
    string calldata validationURI,
    bytes32 verdictHash
) external;

// Read
function getValidations(uint256 agentId) external view returns (ValidationEntry[] memory);
function getValidationCount(uint256 agentId) external view returns (uint256);
function getPassRate(uint256 agentId) external view returns (uint256 passes, uint256 total);
```

---

## Setup

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation).

```bash
git clone --recurse-submodules https://github.com/P-U-C/b1e55ed-contracts
cd b1e55ed-contracts
forge install
forge test -vv
```

---

## Deploy

### Environment variables

```bash
export DEPLOYER_PRIVATE_KEY=0x...         # deployer private key
export BASE_SEPOLIA_RPC_URL=https://...   # e.g. from Alchemy/Infura
export BASE_MAINNET_RPC_URL=https://...
export BASESCAN_API_KEY=...               # for contract verification
```

### Deploy to Base Sepolia (testnet)

```bash
forge script script/Deploy.s.sol \
  --rpc-url base_sepolia \
  --broadcast \
  --verify
```

### Deploy to Base Mainnet

```bash
forge script script/Deploy.s.sol \
  --rpc-url base_mainnet \
  --broadcast \
  --verify
```

Deployed addresses go in [`addresses/README.md`](addresses/README.md).

---

## Register b1e55ed's agentId

Call `register()` on the Identity Registry to mint b1e55ed's on-chain identity:

```bash
export AGENT_URI="https://oracle.b1e55ed.permanentupperclass.com/.well-known/agent-registration.json"

forge script script/Register.s.sol \
  --rpc-url base_mainnet \
  --broadcast
```

This mints an ERC-8004 NFT (`agentId`) owned by the deployer. The `agentId` is then used as the key for all reputation and validation entries.

---

## Spec

- [EIP-8004](https://eips.ethereum.org/EIPS/eip-8004) — Agent Identity, Reputation, and Validation standard

---

## b1e55ed Oracle

- **Oracle**: [oracle.b1e55ed.permanentupperclass.com](https://oracle.b1e55ed.permanentupperclass.com)
- **Agent registration JSON**: [`/.well-known/agent-registration.json`](https://oracle.b1e55ed.permanentupperclass.com/.well-known/agent-registration.json)
- **Twitter**: [@b1e55edfed](https://twitter.com/b1e55edfed)

b1e55ed publishes falsifiable signal forecasts with explicit resolution criteria. Every resolved forecast writes a karma entry to `ReputationRegistry`. Every merged PR writes a council verdict to `ValidationRegistry`. The on-chain record doesn't lie.
