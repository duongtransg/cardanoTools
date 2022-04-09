export ADA_LEFT=$(cardano-cli query utxo $NETWORK_ID --address $PAYMENT_ADDR | tail -n1 | awk '{print $3;}')
export UTXO=$(cardano-cli query utxo $NETWORK_ID --address $PAYMENT_ADDR | tail -n1 | awk '{print $1;}')
export UTXO_TXIX=$(cardano-cli query utxo $NETWORK_ID --address $PAYMENT_ADDR | tail -n1 | awk '{print $2;}')

echo
echo "Building burn transaction..."
cardano-cli transaction build-raw \
  --mary-era \
  --fee 0 \
  --tx-in $UTXO#$UTXO_TXIX \
  --tx-out "$PAYMENT_ADDR+$ADA_LEFT" \
  --mint "-$AMT $POLICY_ID.$ASSET_NAME" \
  --out-file burn.raw

export FEE=$(cardano-cli transaction calculate-min-fee \
            $NETWORK_ID \
            --tx-body-file burn.raw \
            --tx-in-count 1 \
            --tx-out-count 1 \
            --witness-count 2 \
            --protocol-params-file protocol.json | awk '{print $1;}')
export AMT_OUT=$(expr $ADA_LEFT - $FEE)

cardano-cli transaction build-raw \
            --mary-era \
            --fee $FEE \
            --tx-in $UTXO#$UTXO_TXIX \
            --tx-out "$PAYMENT_ADDR+$AMT_OUT" \
            --mint "-$AMT $POLICY_ID.$ASSET_NAME" \
            --out-file burn.raw

cat burn.raw

cardano-cli transaction sign \
        --signing-key-file pay.skey \
        --signing-key-file policy/policy.skey \
        --script-file policy/policy.script \
        --tx-body-file burn.raw \
            --out-file burn.signed

echo
echo "Submitting burn transaction..."
cardano-cli transaction submit \
            $NETWORK_ID \
            --tx-file burn.signed

echo
echo "Awaiting burn..."
sleep 60
cardano-cli query utxo \
            $NETWORK_ID \
            --address $PAYMENT_ADDR

            