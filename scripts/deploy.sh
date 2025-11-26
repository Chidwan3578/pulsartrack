#!/usr/bin/env bash
set -euo pipefail

# PulsarTrack - Stellar Testnet Deployment Script
# Deploys all 39 Soroban contracts to Stellar testnet

NETWORK="${STELLAR_NETWORK:-testnet}"
IDENTITY="${STELLAR_IDENTITY:-pulsartrack-deployer}"
OUTPUT_DIR="$(dirname "$0")/../deployments"
CONTRACTS_DIR="$(dirname "$0")/../contracts"
WASM_DIR="$(dirname "$0")/../target/wasm32-unknown-unknown/release"

echo "=============================================="
echo "  PulsarTrack - Soroban Contract Deployment"
echo "  Network: $NETWORK"
echo "  Identity: $IDENTITY"
echo "=============================================="

# Ensure deployer identity exists
if ! stellar keys show "$IDENTITY" &>/dev/null; then
  echo "[Setup] Generating deployer keypair: $IDENTITY"
  stellar keys generate --network "$NETWORK" "$IDENTITY"
fi

DEPLOYER_ADDRESS=$(stellar keys address "$IDENTITY")
echo "[Info] Deployer address: $DEPLOYER_ADDRESS"

# Fund account on testnet if needed
if [ "$NETWORK" = "testnet" ]; then
  echo "[Funding] Requesting testnet XLM from Friendbot..."
  curl -s "https://friendbot.stellar.org?addr=$DEPLOYER_ADDRESS" > /dev/null || true
  sleep 2
fi

# Build all contracts
echo ""
echo "[Build] Building all Soroban contracts..."
cargo build --release --target wasm32-unknown-unknown 2>&1 | tail -5

# Create output file
DEPLOY_FILE="$OUTPUT_DIR/deployed-$NETWORK-$(date +%Y%m%d-%H%M%S).json"
mkdir -p "$OUTPUT_DIR"
echo '{"network": "'"$NETWORK"'", "deployer": "'"$DEPLOYER_ADDRESS"'", "contracts": {}}' > "$DEPLOY_FILE"

# Deploy function
deploy_contract() {
  local NAME="$1"
  local WASM_NAME="$2"
  local WASM_PATH="$WASM_DIR/${WASM_NAME}.wasm"

  if [ ! -f "$WASM_PATH" ]; then
    echo "[Skip] $NAME - WASM not found: $WASM_PATH"
    return 1
  fi

  echo "[Deploy] $NAME..."
  local CONTRACT_ID
  CONTRACT_ID=$(stellar contract deploy \
    --wasm "$WASM_PATH" \
    --source "$IDENTITY" \
    --network "$NETWORK" \
    2>/dev/null) || {
    echo "[Error] Failed to deploy $NAME"
    return 1
  }

  echo "  -> $CONTRACT_ID"

  # Update deploy file
  local TMP
  TMP=$(mktemp)
  python3 -c "
import json, sys
with open('$DEPLOY_FILE') as f:
    d = json.load(f)
d['contracts']['$NAME'] = '$CONTRACT_ID'
with open('$DEPLOY_FILE', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || true

  echo "$CONTRACT_ID"
}

echo ""
echo "[Deploying] Core contracts..."
deploy_contract "ad_registry"           "pulsar_ad_registry"
deploy_contract "campaign_orchestrator" "pulsar_campaign_orchestrator"
deploy_contract "escrow_vault"          "pulsar_escrow_vault"
deploy_contract "fraud_prevention"      "pulsar_fraud_prevention"
deploy_contract "payment_processor"     "pulsar_payment_processor"

echo ""
echo "[Deploying] Governance contracts..."
deploy_contract "governance_token"      "pulsar_governance_token"
deploy_contract "governance_dao"        "pulsar_governance_dao"
deploy_contract "governance_core"       "pulsar_governance_core"
deploy_contract "timelock_executor"     "pulsar_timelock_executor"

echo ""
echo "[Deploying] Publisher contracts..."
deploy_contract "publisher_verification" "pulsar_publisher_verification"
deploy_contract "publisher_network"      "pulsar_publisher_network"
deploy_contract "publisher_reputation"   "pulsar_publisher_reputation"

echo ""
echo "[Deploying] Analytics contracts..."
deploy_contract "analytics_aggregator"  "pulsar_analytics_aggregator"
deploy_contract "campaign_analytics"    "pulsar_campaign_analytics"
deploy_contract "campaign_lifecycle"    "pulsar_campaign_lifecycle"

echo ""
echo "[Deploying] Privacy & Targeting contracts..."
deploy_contract "privacy_layer"         "pulsar_privacy_layer"
deploy_contract "targeting_engine"      "pulsar_targeting_engine"
deploy_contract "audience_segments"     "pulsar_audience_segments"
deploy_contract "identity_registry"     "pulsar_identity_registry"
deploy_contract "kyc_registry"          "pulsar_kyc_registry"

echo ""
echo "[Deploying] Marketplace contracts..."
deploy_contract "auction_engine"        "pulsar_auction_engine"
deploy_contract "creative_marketplace"  "pulsar_creative_marketplace"

echo ""
echo "[Deploying] Financial contracts..."
deploy_contract "subscription_manager"  "pulsar_subscription_manager"
deploy_contract "subscription_benefits" "pulsar_subscription_benefits"
deploy_contract "liquidity_pool"        "pulsar_liquidity_pool"
deploy_contract "milestone_tracker"     "pulsar_milestone_tracker"
deploy_contract "multisig_treasury"     "pulsar_multisig_treasury"
deploy_contract "oracle_integration"    "pulsar_oracle_integration"
deploy_contract "payout_automation"     "pulsar_payout_automation"
deploy_contract "performance_oracle"    "pulsar_performance_oracle"
deploy_contract "recurring_payment"     "pulsar_recurring_payment"
deploy_contract "refund_processor"      "pulsar_refund_processor"
deploy_contract "revenue_settlement"    "pulsar_revenue_settlement"
deploy_contract "rewards_distributor"   "pulsar_rewards_distributor"

echo ""
echo "[Deploying] Bridge & Utility contracts..."
deploy_contract "token_bridge"          "pulsar_token_bridge"
deploy_contract "wrapped_token"         "pulsar_wrapped_token"
deploy_contract "dispute_resolution"    "pulsar_dispute_resolution"
deploy_contract "budget_optimizer"      "pulsar_budget_optimizer"
deploy_contract "anomaly_detector"      "pulsar_anomaly_detector"

echo ""
echo "=============================================="
echo "  Deployment complete!"
echo "  Results saved to: $DEPLOY_FILE"
echo "=============================================="
