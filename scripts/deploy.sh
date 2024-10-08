#! /bin/bash

set -euo pipefail

# We need some infos
PRIVATE_KEY=${PRIVATE_KEY:-}
RPC_URL=${RPC_URL:-}
CHAIN_ID=${CHAIN_ID:-}
OCWEBSITE_FACTORY_ADDRESS=${OCWEBSITE_FACTORY_ADDRESS:-}
STATIC_FRONTEND_PLUGIN_ADDRESS=${STATIC_FRONTEND_PLUGIN_ADDRESS:-}
OCWEB_ADMIN_PLUGIN_ADDRESS=${OCWEB_ADMIN_PLUGIN_ADDRESS:-}
ETHERSCAN_API_KEY=${ETHERSCAN_API_KEY:-}
if [ -z "$PRIVATE_KEY" ]; then
  echo "PRIVATE_KEY env var is not set"
  exit 1
fi
if [ -z "$RPC_URL" ]; then
  echo "RPC_URL env var is not set"
  exit 1
fi
if [ -z "$CHAIN_ID" ]; then
  echo "CHAIN_ID env var is not set"
  exit 1
fi
if [ -z "$OCWEBSITE_FACTORY_ADDRESS" ]; then
  echo "OCWEBSITE_FACTORY_ADDRESS env var is not set"
  exit 1
fi
if [ -z "$STATIC_FRONTEND_PLUGIN_ADDRESS" ]; then
  echo "STATIC_FRONTEND_PLUGIN_ADDRESS env var is not set"
  exit 1
fi
if [ -z "$OCWEB_ADMIN_PLUGIN_ADDRESS" ]; then
  echo "OCWEB_ADMIN_PLUGIN_ADDRESS env var is not set"
  exit 1
fi
if [ -z "$ETHERSCAN_API_KEY" ]; then
  echo "ETHERSCAN_API_KEY env var is not set"
  exit 1
fi

# check that forge is installed
if ! command -v forge &> /dev/null
then
    echo "forge could not be found. Please install foundry (toolkit for Ethereum application development)"
    exit
fi

# Compute the plugin root folder (which is the parent folder of this script)
PLUGIN_ROOT=$(cd $(dirname $(readlink -f $0)) && cd .. && pwd)


#
# Create an OCWebsite
#

exec 5>&1
OUTPUT="$(PRIVATE_KEY=$PRIVATE_KEY \
  npx ocweb --rpc $RPC_URL --skip-tx-validation mint --factory-address $OCWEBSITE_FACTORY_ADDRESS $CHAIN_ID about-me-theme | tee >(cat - >&5))"

# Get the address of the OCWebsite
OCWEBSITE_ADDRESS=$(echo "$OUTPUT" | grep -oP 'New OCWebsite smart contract: \K0x\w+')


#
# Build and upload the admin frontend
#

# Go to the admin frontend folder
cd $PLUGIN_ROOT/admin

# Build the admin frontend
npm run build

# Upload the admin frontend
PRIVATE_KEY=$PRIVATE_KEY \
WEB3_ADDRESS=web3://$OCWEBSITE_ADDRESS:$CHAIN_ID \
npx ocweb --rpc $RPC_URL --skip-tx-validation upload dist/* /themes/about-me/


#
# Build and upload the frontend
#

# Go to the frontend folder
cd $PLUGIN_ROOT/frontend

# Build the frontend
npm run build

# Upload the frontend
PRIVATE_KEY=$PRIVATE_KEY \
WEB3_ADDRESS=web3://$OCWEBSITE_ADDRESS:$CHAIN_ID \
npx ocweb --rpc $RPC_URL --skip-tx-validation upload dist/* / --exclude 'dist/pages/*' --exclude 'dist/themes/about-me/*' --exclude 'dist/variables.json'


#
# Build the plugin
# 

FORGE_CREATE_OPTIONS=
if [ "$CHAIN_ID" != "31337" ]; then
  FORGE_CREATE_OPTIONS="--verify"
fi
forge create --private-key $PRIVATE_KEY $FORGE_CREATE_OPTIONS \
--constructor-args $OCWEBSITE_ADDRESS $STATIC_FRONTEND_PLUGIN_ADDRESS $OCWEB_ADMIN_PLUGIN_ADDRESS \
--rpc-url $RPC_URL \
src/ThemeAboutMePlugin.sol:ThemeAboutMePlugin


