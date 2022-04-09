export CARDANO_NODE_SOCKET_PATH=~/Library/Application\ Support/Daedalus\ Testnet/cardano-node.socket
export TESTNET_ID=1097911063
export TOKEN_NAME=myToken
export TOKEN_AMOUNT=1000000000

# Check cardano node & generate keys
cardano-cli query utxo \
  --testnet-magic $TESTNET_ID \
  --mary-era

cardano-cli stake-address key-gen \
  --verification-key-file stake.vkey \
  --signing-key-file stake.skey

cardano-cli address key-gen \
  --verification-key-file payment.vkey \
  --signing-key-file payment.skey

# Generate a payment address
cardano-cli address build \
  --payment-verification-key-file payment.vkey \
  --stake-verification-key-file stake.vkey \
  --out-file payment.addr \
  --testnet-magic $TESTNET_ID

# send some test token from your wallet to above address, if dont have, request it
https://developers.cardano.org/en/testnets/cardano/tools/faucet/

# Check tADA balance
cardano-cli query utxo --address $(< payment.addr) \
  --testnet-magic $TESTNET_ID \
  --mary-era

# Export protocol parameters to JSON file
cardano-cli query protocol-parameters \
  --testnet-magic $TESTNET_ID \
  --mary-era \
  --out-file protocol.json

#Generate policy ID
mkdir policy
cardano-cli address key-gen \
  --verification-key-file policy/policy.vkey \
  --signing-key-file policy/policy.skey

touch policy/policy.script && echo "" > policy/policy.script 

echo "{" >> policy/policy.script 
echo "  \"keyHash\": \"$(cardano-cli address key-hash --payment-verification-key-file policy/policy.vkey)\"," >> policy/policy.script 
echo "  \"type\": \"sig\"" >> policy/policy.script 
echo "}" >> policy/policy.script 
cardano-cli transaction policyid --script-file ./policy/policy.script >> policy/policyId

# Check wallet balance & Save TX
export TX_HASH="wallet hash"
export TX_IX=0
export AVAILABLE_LOVELACE=1000000000

# Build raw transaction using this data
cardano-cli transaction build-raw \
  --mary-era \
  --fee 0 \
  --tx-in $TX_HASH#$TX_IX \
  --tx-out $(< payment.addr)+$AVAILABLE_LOVELACE+"$TOKEN_AMOUNT $(< policy/policyId).$TOKEN_NAME" \
  --mint="$TOKEN_AMOUNT $(< policy/policyId).$TOKEN_NAME" \
  --out-file matx.raw

# Calculate the minimum fee
cardano-cli transaction calculate-min-fee \
  --tx-body-file matx.raw \
  --tx-in-count 1 \
  --tx-out-count 1 \
  --witness-count 1 \
  --testnet-magic $TESTNET_ID \
  --protocol-params-file protocol.json

export TX_FEE=174961 #Replace by returned value

#build the transaction
cardano-cli transaction build-raw \
  --mary-era \
  --fee $TX_FEE \
  --tx-in $TX_HASH#$TX_IX \
  --tx-out $(< payment.addr)+$(($AVAILABLE_LOVELACE - $TX_FEE))+"$TOKEN_AMOUNT $(< policy/policyId).$TOKEN_NAME" \
  --mint="$TOKEN_AMOUNT $(< policy/policyId).$TOKEN_NAME" \
  --out-file matx.raw

# Sign & submit the transaction
cardano-cli transaction sign \
  --signing-key-file payment.skey \
  --signing-key-file policy/policy.skey \
  --script-file policy/policy.script \
  --testnet-magic $TESTNET_ID \
  --tx-body-file matx.raw \
  --out-file matx.signed
cardano-cli transaction submit --tx-file  matx.signed --testnet-magic $TESTNET_ID

#check generated token
cardano-cli query utxo --address $(< payment.addr) \
  --testnet-magic $TESTNET_ID \
  --mary-era