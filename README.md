# DYNEXA — Base‑Ready Rewards & Merchant Settlement (USDC‑first)

**DYNEXA** is a USDC‑first B2B2C rewards rail on **Base**. Brands fund **USDC**, issue rewards in **DXA** (the ecosystem digital unit with 1:1 operational parity to USDC) or **GiftTokens (ERC‑1155)**, and **merchants settle in USDC** on Base. Users can keep value inside the ecosystem in DXA, or exit by converting **DXA → USDC** on‑chain.

> **Why Base?** Smart‑wallet UX via **Base Accounts / Account Kit** (gasless with Paymaster), **Basenames** for readable IDs, and a fast, low‑cost L2 with growing USDC liquidity and developer tooling.

---

## 1) Problem (LATAM loyalty today)
- Siloed, low‑redemption points with poor perceived value and no real liquidity.  
- Complex, error‑prone reconciliation for brands; **slow, non‑USD** settlement for merchants.  
- Macroeconomic erosion (e.g., local currency devaluation) devalues rewards further.

## 2) Solution (USDC‑first, Base‑native)
- **Enterprises fund USDC** on Base and run campaigns.  
- Rewards are issued as **DXA (1:1 operational parity to USDC)** and/or **GiftTokens (ERC‑1155)**.  
- **Enterprise‑to‑enterprise** flows (issuers → redeemers/merchants) **settle in USDC** on Base.  
- Users redeem instantly across brands; if they wish to exit the ecosystem, they **convert DXA → USDC** on‑chain.

---

## 3) Architecture (high‑level)
- **On‑chain (Base):** DXA (ERC‑20), **GiftToken1155**, **CampaignRegistry**, **MerchantRegistry**, **Treasury** (USDC custody/settlement), **Redeemer** (atomic burn→pay), **EAS attestations** (missions/KYC/reputation), optional **Badges (ERC‑721)**.
- **Wallets:** **D‑NEXA Smart Wallet** (AA via Base Accounts/Account Kit), Paymaster (gas sponsorship), Basenames.
- **Apps:** B2B Backoffice (issuance, rules, reporting), Consumer PWA (earn, QR redeem, optional exit), Merchant Portal (withdraw USDC).
- **Web2 Core:** API Gateway, Event Bus, Postgres, Redis, Indexer/Analytics, Observability (OTel), Compliance (KYC tiers).

---

## 4) Contracts (what each one does)

> Primary target network: **Base** (Sepolia for alpha, Mainnet for production). Some contracts were prototyped on other networks during earlier R&D; they are listed as **Legacy/Experimental**.

| Contract                | Network(s)                 | Purpose                                                                 | Key functions / roles |
|-------------------------|---------------------------|-------------------------------------------------------------------------|-----------------------|
| **GiftToken1155**       | **Base** (also Lisk)      | ERC‑1155 vouchers per campaign; mint by issuer, burn on redeem.         | `mint/mintBatch`, `burn/burnFrom`, `setURI`. Roles: `ISSUER_ROLE`, `REDEEMER_ROLE`, `PAUSER_ROLE`. |
| **CampaignRegistry**    | **Base** (also Lisk)      | Business rules per `tokenId`: unit value (USD(6)), window, caps, terms. | `createCampaign`, `isActive`, `update*`. Role: `ISSUER_ROLE`. |
| **MerchantRegistry**    | **Base** (also Lisk)      | Allowlist + merchant payout wallet + fee bps.                           | `addMerchant`, `setPayout`, `setFeeBps`. Role: `MERCHANT_ADMIN_ROLE`. |
| **Treasury**            | **Base** (also Lisk)      | Holds **USDC** (or mock); pays merchants; optional per‑campaign cap.    | `deposit`, `pay(to, usdc, tokenId)`, `authorizeRedeemer`, `setStable`, `balance`. |
| **Redeemer**            | **Base** (also Lisk)      | Atomic **burn→pay** flow; reads rules, applies fee, settles from Treasury.| `quoteRedeem`, `redeem`. Role: `PAUSER_ROLE`. |
| **MockUSDC6** *(legacy)*| Lisk (testnet)            | 6‑decimals mock stablecoin for Lisk testnet.                            | `decimals=6`, `mint`, `faucetMint`. |
| **FlarePriceProxy(Simple)** *(legacy)* | Flare Coston2         | On‑chain FLR/USD6 board (FTSO/FDC via updater).                         | `pushPrice("FLR", usd6, ts)`, `getUSD6("FLR")`. Role: `UPDATER_ROLE`. |
| **FlarePayout** *(legacy)* | Flare Coston2         | Claim in FLR via EIP‑712 voucher; price via `FlarePriceProxy`.          | `claim(Claim, sig)`, `setSigner`, `receive()`. |
| **ConfidentialGiftToken (skeleton)** *(experimental)* | Zama fhEVM | Encrypted balances/vesting; unwrap intent to public layer.              | `requestUnwrap(amount, ref)`, events. |

> **Base‑only minimal set for Alpha:** `GiftToken1155`, `CampaignRegistry`, `MerchantRegistry`, `Treasury`, `Redeemer` (+ DXA/ERC‑20 if kept separate).

---

## 5) On‑chain flows (Base)
1. **Issue:** Brand funds **USDC** → defines rules in **CampaignRegistry** → mints **GiftToken1155**.  
2. **Earn:** User receives **DXA** and/or GiftToken based on EAS‑certified actions.  
3. **Redeem:** User scans QR; **Redeemer** performs **burn→pay** atomically; **Treasury** pays merchant in **USDC** (fee rules from registry).  
4. **Exit (user):** Optional **DXA → USDC** on‑chain (e.g., 3% exit fee).  
5. **Proof‑of‑reserves:** DXA supply vs. Treasury USDC is reconciled via events/analytics.

---

## 6) Addresses & proofs (Base Sepolia — fill after deploy)
- **GiftToken1155:** `0xGIFT1155_ADDRESS`  
- **CampaignRegistry:** `0xCAMPAIGN_REG_ADDRESS`  
- **MerchantRegistry:** `0xMERCHANT_REG_ADDRESS`  
- **Treasury (USDC vault):** `0xTREASURY_ADDRESS`  
- **Redeemer:** `0xREDEEMER_ADDRESS`  

**Transactions (at least one each):**
- Campaign creation: `0xTX_CREATE_CAMPAIGN`  
- Redemption (burn→pay): `0xTX_REDEEM`  
- Merchant withdraw (if separate method): `0xTX_WITHDRAW`  
- DXA → USDC exit (user): `0xTX_EXIT`  

> Add **BaseScan** links for all addresses & tx hashes.

---

## 7) Getting started (local & testnet)

### Prerequisites
- Node.js 18+ and pnpm (or npm)
- Foundry (or Hardhat)
- Postgres & Redis (local)
- A Base Sepolia RPC + deployer key

### Install
```bash
pnpm install
# or
npm install
```

### Environment
Create `.env` files as needed:
```bash
# contracts/.env
RPC_BASE_SEPOLIA="https://sepolia.base.org"
PRIVATE_KEY="0xYOUR_PRIVATE_KEY"

# api/gateway/.env
DATABASE_URL="postgres://user:pass@localhost:5432/dynexa"
REDIS_URL="redis://localhost:6379"
```

### Deploy (Foundry)
```bash
export RPC_BASE_SEPOLIA="https://sepolia.base.org"
export DEPLOYER_PK="0xYOUR_PRIVATE_KEY"

forge script scripts/Deploy.s.sol   --rpc-url $RPC_BASE_SEPOLIA   --private-key $DEPLOYER_PK   --broadcast
```

### Verify
```bash
forge verify-contract --chain base-sepolia <GIFT1155_ADDRESS> src/GiftToken1155.sol:GiftToken1155
# repeat for CampaignRegistry, MerchantRegistry, Treasury, Redeemer
```

### Seed demo data
```bash
node scripts/seed-alpha.js
# creates a sample campaign, mints GiftTokens, registers a merchant,
# and funds Treasury with testnet USDC (or mock if used locally)
```

### Run apps
```bash
# Backoffice (B2B)
pnpm --filter @dynexa/b2b dev

# Consumer PWA
pnpm --filter @dynexa/pwa dev

# Merchant Portal
pnpm --filter @dynexa/merchant dev

# Wallet (AA)
pnpm --filter @dynexa/wallet dev

# API Gateway
pnpm --filter @dynexa/api dev
```

---

## 8) Security & compliance highlights
- **AA smart wallets** with method allowlists, spend limits, and role approvals.  
- **QR redemption safety:** nonce + TTL; on‑chain burn; anti‑replay indexing.  
- **USDC‑only enterprise settlement** on Base; DXA remains the internal spend unit.  
- **KYC tiers** gate DXA → USDC exits; limits & AML rules enforced on/off‑chain.  
- **Proof‑of‑reserves dashboard** for DXA vs. Treasury USDC parity.

---

## 9) Roadmap (post‑alpha)
- Multi‑location merchants + signed catalogs (prices/stock with attestable proofs).  
- Expanded EAS schemas (referrals, streaks, location proofs).  
- B2B invoicing & netting in **USDC**; settlement SLA reporting.  
- Finance dashboard (fees, reserves, GiftToken aging, breakage rescue).  
- Optional Base DeFi hooks for enterprise treasury (opt‑in, guarded).

---

## 10) License
MIT

## 11) Maintainers / contacts
- Team: **DYNEXA**  
- Basename: `dynexa.base`  
- X/Twitter: `@themaurix` (update)  
- Email: `hi@dynexa.base` (update)

- # DYNEXA — Base-Native Contract Suite (USDC-first)

This README lists the **Base-ready** contracts for DYNEXA, beyond the legacy prototypes you shared. It focuses on **USDC-first** flows, **DXA (1:1 operational parity to USDC)**, **enterprise USDC settlement**, and **smart-wallet (AA)** UX.

---

## 1) Core contracts (Base)

| Contract | Purpose | Key functions / roles |
|---|---|---|
| **DXA.sol (ERC20)** | Ecosystem unit with **1:1 operational parity to USDC** held in Treasury/Vault; mint/burn controlled by Treasury/Router. | `mint`, `burnFrom`, `pause`, `setRedemptionFeeBps(300)`. Roles: `TREASURY_ROLE`, `ROUTER_ROLE`, `PAUSER_ROLE`. |
| **USDCTreasuryVault.sol** | Holds **USDC** on Base; authorizes DXA mint/burn; executes USDC payouts; houses the **3% DXA→USDC exit fee** sink/split. | `depositUSDC`, `withdrawUSDC`, `authorizeMint`, `authorizeBurn`, `setFeeSink`, `balances`. |
| **Router.sol** | Orchestrates flows: **USDC→DXA (0%)**, **DXA→USDC (3%)**, DXA↔GiftToken settlements; enforces limits/cooldowns. | `buyDXAwithUSDC`, `redeemDXAforUSDC`, `payMerchant`, `setDailyLimits`. Role: `OPERATOR_ROLE`. |
| **GiftToken1155.sol** | Tokenized rewards/coupons per campaign; burn-on-redeem. | `mintBatch`, `burn`, `setURI`. Roles: `ISSUER_ROLE`, `REDEEMER_ROLE`, `PAUSER_ROLE`. |
| **CampaignRegistry.sol** | Business rules per `tokenId`: unit value (USD(6)), windows, caps, terms. | `createCampaign`, `isActive`, `update*`. Role: `ISSUER_ROLE`. |
| **MerchantRegistry.sol** | Allowlist, merchant payout wallet, fee bps per merchant/brand. | `addMerchant`, `setPayout`, `setFeeBps`. Role: `MERCHANT_ADMIN_ROLE`. |
| **Redeemer.sol** | **Atomic burn→pay**: validates QR/nonce, reads rules, applies fee, settles from Treasury in **USDC**. | `quoteRedeem`, `redeem`. Roles: `REDEEMER_ROLE`, `PAUSER_ROLE`. |
| **MerchantPool.sol** (optional) | DXA sink per merchant; batches redemptions before withdrawing **USDC**. | `receiveDXA`, `withdrawUSDC`. |

> Minimal Base alpha set: **DXA**, **USDCTreasuryVault**, **Router**, **GiftToken1155**, **CampaignRegistry**, **MerchantRegistry**, **Redeemer** (and optional **MerchantPool**).

---

## 2) Compliance & attestations

| Contract / Integration | Purpose | Notes |
|---|---|---|
| **ComplianceGuard.sol** | On-chain allowlist/role for **DXA→USDC exits** (KYC-gated). | API/oracle toggles `isAllowed(wallet)`; Router checks before redeem. |
| **EAS Schemas** | Attestations for missions, KYC tier, merchant reputation. | Publish schema UIDs on **Base**; store heavy data off-chain w/ content hashes. |
| **Badges721.sol** (optional) | Achievements as ERC-721. | Mint on EAS events. |

---

## 3) AA / Wallet (Base Accounts / Account Kit)

- **Smart wallet** with WebAuthn/social login.  
- **Paymaster** for gas sponsorship (allowlist of contract methods).  
- **Session keys / policy engine** (spend limits, method scopes for enterprise ops).  
- **Basenames** for readable identities in the UI and receipts.

---

## 4) Events & proof-of-reserves

Emit granular events so finance teams can reconcile **DXA totalSupply == USDC balance**:

- `DXAMinted(to, amount, usdcRef)`  
- `DXABurned(from, amount, fee)`  
- `USDCDeposited(from, amount)`  
- `USDCWithdrawn(to, amount)`  
- `GiftRedeemed(user, tokenId, qty, merchant)`

Dashboard indexes these events and raises alerts if drift > 1 wei.

---

## 5) Addresses (Base Sepolia — placeholders)

- **DXA:** `0xDXA_ADDRESS`  
- **USDCTreasuryVault:** `0xVAULT_ADDRESS`  
- **Router:** `0xROUTER_ADDRESS`  
- **GiftToken1155:** `0xGIFT1155_ADDRESS`  
- **CampaignRegistry:** `0xCAMPAIGN_REG_ADDRESS`  
- **MerchantRegistry:** `0xMERCHANT_REG_ADDRESS`  
- **Redeemer:** `0xREDEEMER_ADDRESS`  
- **MerchantPool (opt):** `0xPOOL_ADDRESS`  
- **EAS Schema UIDs:** `0xSCHEMA_MISSION`, `0xSCHEMA_KYC`, `0xSCHEMA_MERCHANT_REP`

Include BaseScan links for each.

---

## 6) Deploy & verify (Foundry)

```bash
export RPC_BASE_SEPOLIA="https://sepolia.base.org"
export DEPLOYER_PK="0xYOUR_PRIVATE_KEY"

forge script scripts/Deploy_Base.s.sol   --rpc-url $RPC_BASE_SEPOLIA   --private-key $DEPLOYER_PK   --broadcast

# Verify
forge verify-contract --chain base-sepolia <DXA_ADDRESS> src/DXA.sol:DXA
forge verify-contract --chain base-sepolia <VAULT_ADDRESS> src/USDCTreasuryVault.sol:USDCTreasuryVault
forge verify-contract --chain base-sepolia <ROUTER_ADDRESS> src/Router.sol:Router
# ...and so on
```

---

## 7) Notes

- **Enterprise settlement is always in USDC** on Base; **DXA** stays as the internal spend/earn unit with **1:1 operational parity**.  
- **USDC→DXA** fee **0%** (frictionless entry). **DXA→USDC** exit fee **3%** (configurable bps).  
- **QR redemption** uses nonce + TTL; Redeemer burns first, then pays.  
- **Rate limits & circuit breakers** on Router/Redeemer for risk control.

