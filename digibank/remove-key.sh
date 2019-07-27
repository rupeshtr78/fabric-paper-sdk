echo 'Renaming private keys '
# Rename the key files we use to be key.pem instead of a uuid
for KEY in $(find ./crypto-config -type f -name "*_sk"); do
    KEY_DIR=$(dirname ${KEY})
    mv ${KEY} ${KEY_DIR}/key.pem
done
echo 'Renaming keys complete'