# D-NEXA — Base-Ready Rewards & Merchant Settlement (USDC-first)

**D-NEXA** is a USDC-first B2B2C rewards rail on **Base**. Brands fund **USDC**, issue rewards in **DXA** (ecosystem digital unit with **1:1 operational parity to USDC**), and **tokenized GiftTokens (ERC-1155)**. **Merchants settle in USDC** on Base. Users keep value in DXA or exit by converting **DXA → USDC** on-chain.

> **Why Base?** Smart-wallet UX via **Base Accounts / Account Kit** (gasless with Paymaster), **Basenames** for readable IDs, and a fast, low-cost L2 with deepening **USDC** liquidity.

---

## 1) Problem
- Siloed, low-redemption points; poor perceived value; no real liquidity.
- Slow, error-prone reconciliation; merchant settlement not in USD.
- Macro erosion (local currency devaluation) reduces reward value.

## 2) Solution
- **Enterprises fund USDC** and run campaigns on Base.
- Rewards issued as **DXA (1:1 operational parity to USDC)** and/or **GiftTokens (ERC-1155)**.
- **Enterprise-to-enterprise flows** (issuers → redeemers/merchants) **settle in USDC**.
- Users redeem across brands; optional **DXA → USDC exit** on-chain (e.g., 3% exit fee).

---

## 3) Architecture (high-level)
- **On-chain (Base):** DXA (ERC-20), GiftToken1155, CampaignRegistry, MerchantRegistry, Treasury (USDC vault), Redeemer (atomic burn→pay), EAS attestations (missions/KYC/reputation), optional Badges (ERC-721).
- **Wallets:** D-NEXA Smart Wallet (AA via Base Accounts/Account Kit), Paymaster (sponsored gas), Basenames.
- **Apps:** B2B Backoffice (issuance/rules/reporting), Consumer PWA (earn/QR redeem/exit), Merchant Portal (withdraw USDC).
- **Web2 Core:** API Gateway, Event Bus, Postgres, Redis, Indexer/Analytics, Observability (OTel), Compliance (KYC tiers).

---

## 4) Contracts — **Base-native (new/updated for this proposal)**
These are the **new contracts** we propose for Base (in addition to the legacy prototypes below).

| Contract | Purpose | Key functions / roles |
|---|---|---|
| **DXA.sol (ERC20)** | Ecosystem unit with **1:1 operational parity to USDC** held in Treasury/Vault; mint/burn gated. | `mint`, `burnFrom`, `pause`, `setRedemptionFeeBps(300)`. Roles: `TREASURY_ROLE`, `ROUTER_ROLE`, `PAUSER_ROLE`. |
| **USDCTreasuryVault.sol** | Holds **USDC** on Base; authorizes DXA mint/burn; executes USDC payouts; handles exit fee sink/split. | `depositUSDC`, `withdrawUSDC`, `authorizeMint`, `authorizeBurn`, `setFeeSink`, `balances`. |
| **Router.sol** | Orchestrates flows: **USDC→DXA (0%)**, **DXA→USDC (3%)**, DXA↔GiftToken, merchant payouts; rate limits. | `buyDXAwithUSDC`, `redeemDXAforUSDC`, `payMerchant`, `setDailyLimits`. Role: `OPERATOR_ROLE`. |
| **MerchantPool.sol** *(optional)* | DXA sink per merchant to batch before **USDC withdraw**. | `receiveDXA`, `withdrawUSDC`. |
| **ComplianceGuard.sol** | On-chain allowlist/role for **DXA→USDC exits** (KYC-gated). | `setAllowed(wallet,bool)`, `isAllowed(wallet)`. Checked by Router. |
| **Badges721.sol** *(optional)* | Achievements as ERC-721. | `mintTo`, `setBaseURI`. |
| **EAS Schemas** | Attestations for missions, KYC tier, merchant reputation. | Publish schema UIDs on Base; heavy data off-chain w/ content hash. |

> **Minimal Base alpha set:** `DXA`, `USDCTreasuryVault`, `Router`, `GiftToken1155`, `CampaignRegistry`, `MerchantRegistry`, `Redeemer` (+ `ComplianceGuard`; `MerchantPool` optional).

---

## 5) Contracts — **Legacy / experimental (from prior R&D)**
These are the contracts you already deployed or tested while exploring multi-chain. They remain useful as references but are **not required** for the Base alpha.

| Contract | Network(s) | Purpose | Key functions / roles |
|---|---|---|---|
| **GiftToken1155** | Base, Lisk | ERC-1155 vouchers per campaign; mint by issuer, burn on redeem. | `mint/mintBatch`, `burn/burnFrom`, `setURI`. Roles: `ISSUER_ROLE`, `REDEEMER_ROLE`, `PAUSER_ROLE`. |
| **CampaignRegistry** | Base, Lisk | Business rules per `tokenId`: unit value USD(6), window, caps, terms. | `createCampaign`, `isActive`, `update*`. Role: `ISSUER_ROLE`. |
| **MerchantRegistry** | Base, Lisk | Allowlist + payout wallet + fee bps. | `addMerchant`, `setPayout`, `setFeeBps`. Role: `MERCHANT_ADMIN_ROLE`. |
| **Treasury** | Base, Lisk | Holds USDC/mUSDC; pays merchants; per-campaign caps. | `deposit`, `pay(to, usdc, tokenId)`, `authorizeRedeemer`, `setStable`, `balance`. |
| **Redeemer** | Base, Lisk | Atomic **burn→pay** flow; reads rules, applies fee, settles from Treasury. | `quoteRedeem`, `redeem`. Role: `PAUSER_ROLE`. |
| **MockUSDC6** *(legacy)* | Lisk (testnet) | 6-decimals mock stablecoin for Lisk testnet. | `decimals=6`, `mint`, `faucetMint`. |
| **FlarePriceProxy(Simple)** *(legacy)* | Flare Coston2 | On-chain FLR/USD6 board (FTSO/FDC via updater). | `pushPrice("FLR", usd6, ts)`, `getUSD6("FLR")`. Role: `UPDATER_ROLE`. |
| **FlarePayout** *(legacy)* | Flare Coston2 | Claim in FLR with EIP-712 voucher; price via `FlarePriceProxy`. | `claim(Claim, sig)`, `setSigner`, `receive()`. |
| **ConfidentialGiftToken (skeleton)** *(experimental)* | Zama fhEVM | Encrypted balances/vesting; unwrap intent to public layer. | `requestUnwrap(amount, ref)`, events. |

---

## 6) On-chain flows (Base)
1. **Issue:** Brand funds **USDC** → sets rules in **CampaignRegistry** → mints **GiftToken1155**.  
2. **Earn:** User receives **DXA** and/or GiftToken based on EAS attestations.  
3. **Redeem:** User scans QR; **Redeemer** performs **burn→pay**; **Treasury** pays merchant in **USDC** (fee rules from registry).  
4. **Exit (user):** Optional **DXA → USDC** (e.g., 3% exit fee) via **Router** + **USDCTreasuryVault**.  
5. **Proof-of-reserves:** Events reconcile **DXA totalSupply == Vault USDC** (alert if drift > 1 wei).

---

## 7) Addresses & proofs (Base Sepolia — fill after deploy)
- **DXA:** `0xDXA_ADDRESS`  
- **USDCTreasuryVault:** `0xVAULT_ADDRESS`  
- **Router:** `0xROUTER_ADDRESS`  
- **GiftToken1155:** `0xGIFT1155_ADDRESS`  
- **CampaignRegistry:** `0xCAMPAIGN_REG_ADDRESS`  
- **MerchantRegistry:** `0xMERCHANT_REG_ADDRESS`  
- **Redeemer:** `0xREDEEMER_ADDRESS`  
- **MerchantPool (opt):** `0xPOOL_ADDRESS`  
- **EAS Schemas:** `0xSCHEMA_MISSION`, `0xSCHEMA_KYC`, `0xSCHEMA_MERCHANT_REP`

Add **BaseScan** links for every address and tx.

**Transactions (≥1 each):**
- Campaign creation: `0xTX_CREATE_CAMPAIGN`  
- Redemption (burn→pay): `0xTX_REDEEM`  
- Merchant withdraw (if separate): `0xTX_WITHDRAW`  
- DXA → USDC exit: `0xTX_EXIT`

---

## 8) Getting started

### Prereqs
Node 18+, pnpm (or npm), Foundry (or Hardhat), Postgres, Redis, Base Sepolia RPC + deployer key.

### Install
```bash
pnpm install
# or
npm install
```

### Env
```bash
# contracts/.env
RPC_BASE_SEPOLIA="https://sepolia.base.org"
PRIVATE_KEY="0xYOUR_PRIVATE_KEY"

# api/gateway/.env
DATABASE_URL="postgres://user:pass@localhost:5432/dnexa"
REDIS_URL="redis://localhost:6379"
```

### Deploy (Foundry)
```bash
export RPC_BASE_SEPOLIA="https://sepolia.base.org"
export DEPLOYER_PK="0xYOUR_PRIVATE_KEY"

forge script scripts/Deploy_Base.s.sol   --rpc-url $RPC_BASE_SEPOLIA   --private-key $DEPLOYER_PK   --broadcast
```

### Verify
```bash
forge verify-contract --chain base-sepolia <DXA_ADDRESS> src/DXA.sol:DXA
forge verify-contract --chain base-sepolia <VAULT_ADDRESS> src/USDCTreasuryVault.sol:USDCTreasuryVault
forge verify-contract --chain base-sepolia <ROUTER_ADDRESS> src/Router.sol:Router
forge verify-contract --chain base-sepolia <GIFT1155_ADDRESS> src/GiftToken1155.sol:GiftToken1155
# ...and so on
```

### Seed
```bash
node scripts/seed-alpha.js
# Creates sample campaign, mints GiftTokens, registers merchants,
# funds Treasury with testnet USDC (or mock locally)
```

### Run apps
```bash
pnpm --filter @dnexa/b2b dev       # Backoffice
pnpm --filter @dnexa/pwa dev       # Consumer PWA
pnpm --filter @dnexa/merchant dev  # Merchant Portal
pnpm --filter @dnexa/wallet dev    # Smart Wallet (AA)
pnpm --filter @dnexa/api dev       # API Gateway
```

---

## 9) Security & compliance
- **AA smart wallets** (method allowlists, spend limits, role approvals).  
- **QR redemption safety:** nonce + TTL; on-chain burn; anti-replay indexer.  
- **USDC-only enterprise settlement** on Base; **DXA** as internal unit.  
- **KYC tiers** gate **DXA → USDC** exits via **ComplianceGuard**.  
- **Proof-of-reserves dashboard** (DXA vs Vault USDC).

---

## 10) Roadmap
- Multi-location merchants; signed catalogs (attestable prices/stock).  
- Expanded EAS schemas (referrals, streaks, location proofs).  
- B2B invoicing & netting in **USDC**; settlement SLAs.  
- Finance dashboard (fees, reserves, GiftToken aging, breakage rescue).  
- Optional Base DeFi hooks for enterprise treasury (opt-in, guarded).

---

## 11) License
MIT (suggested) or dual-license (contracts vs apps). Update `LICENSE`.

---

## 12) Maintainers
- Team: **D-NEXA**  
- Basename: `yourname.base` / `dnexa.base` (update)  
- X/Twitter: `@yourhandle` (update)  
- Email: `team@dnexa.app` (update)
