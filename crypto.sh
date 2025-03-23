#!/bin/bash

# Ensuring at least one argument is provided
if [ $# -lt 1 ]; then
  echo "ERROR asnani.ma: No arguments provided." >&2
  exit 1
fi

MODE=$1  # First argument specifies the mode: -sender or -receiver

case "$MODE" in
  "-sender")
    # Checking if required arguments are provided
    if [ $# -ne 7 ]; then
      echo "ERROR asnani.ma: Incorrect number of arguments for sender mode." >&2
      echo "Usage: $0 -sender <receiver1_pub> <receiver2_pub> <receiver3_pub> <sender_priv> <plaintext_file> <zip_filename>" >&2
      exit 1
    fi

    REC1_PUB=$2
    REC2_PUB=$3
    REC3_PUB=$4
    SENDER_PRIV=$5
    PLAINTEXT_FILE=$6
    ZIP_FILENAME=$7

    # Verifying that all input files exist
    for file in "$REC1_PUB" "$REC2_PUB" "$REC3_PUB" "$SENDER_PRIV" "$PLAINTEXT_FILE"; do
      if [ ! -f "$file" ]; then
        echo "ERROR asnani.ma: File '$file' not found." >&2
        exit 1
      fi
    done

    # Random AES session key
    openssl rand -hex 32 > aes_key.key

    # Encrypting the plaintext file using AES with PBKDF2
    openssl enc -aes-256-cbc -salt -pbkdf2 -in "$PLAINTEXT_FILE" -out encrypted_file.enc -pass file:aes_key.key

    # Generating shared secrets and encrypting the session key for each recipient
    for i in 1 2 3; do
      RECEIVER_PUB="REC${i}_PUB"
      openssl pkeyutl -derive -inkey "$SENDER_PRIV" -peerkey "${!RECEIVER_PUB}" -out shared_secret_${i}.bin
      openssl dgst -sha256 -binary -out derived_key_${i}.key shared_secret_${i}.bin
      openssl enc -aes-256-cbc -salt -pbkdf2 -in aes_key.key -out envelope_${i}.enc -pass file:derived_key_${i}.key
    done

    # Signing the encrypted file with the sender's private key
    openssl dgst -sha256 -sign "$SENDER_PRIV" -out signature.sig encrypted_file.enc

    # Compressing all encrypted files and the signature into a ZIP file
    zip "$ZIP_FILENAME" encrypted_file.enc envelope_1.enc envelope_2.enc envelope_3.enc signature.sig

    # Cleanup temporary files
    rm -f aes_key.key shared_secret_*.bin derived_key_*.key envelope_*.enc encrypted_file.enc signature.sig
    
    echo "Encryption and signing complete. Output: $ZIP_FILENAME"
    ;;

  "-receiver")
    # Check if required arguments are provided
    if [ $# -ne 5 ]; then
      echo "ERROR asnani.ma: Incorrect number of arguments for receiver mode." >&2
      echo "Usage: $0 -receiver <receiver_priv> <sender_pub> <zip_file> <plaintext_file>" >&2
      exit 1
    fi

    RECEIVER_PRIV=$2
    SENDER_PUB=$3
    ZIP_FILE=$4
    DECRYPTED_FILE=$5

    # Verify that the ZIP file exists
    if [ ! -f "$ZIP_FILE" ]; then
      echo "ERROR asnani.ma: ZIP file '$ZIP_FILE' not found." >&2
      exit 1
    fi

    # Extracting files from the ZIP file
    unzip -o "$ZIP_FILE" || { echo "ERROR asnani.ma: Failed to extract ZIP file." >&2; exit 1; }

    # Verifying the sender's signature
    openssl dgst -sha256 -verify "$SENDER_PUB" -signature signature.sig encrypted_file.enc
    if [ $? -ne 0 ]; then
      echo "ERROR asnani.ma: Signature verification failed." >&2
      exit 1
    fi

    # Attempting to decrypt the AES key using the receiver's private key
    DECRYPTED=false
    for i in 1 2 3; do
      openssl pkeyutl -derive -inkey "$RECEIVER_PRIV" -peerkey "$SENDER_PUB" -out shared_secret_${i}.bin
      openssl dgst -sha256 -binary -out derived_key_${i}.key shared_secret_${i}.bin
      openssl enc -aes-256-cbc -d -pbkdf2 -in envelope_${i}.enc -out aes_key.key -pass file:derived_key_${i}.key 2>/dev/null
      if [ $? -eq 0 ]; then
        DECRYPTED=true
        break
      fi
    done

    if [ "$DECRYPTED" = false ]; then
      echo "ERROR asnani.ma: Digital Envelope Decryption failed. Private key provided cannot access any envelopes." >&2
      exit 1
    fi

    # Decrypting the encrypted file using the AES session key
    openssl enc -aes-256-cbc -d -pbkdf2 -in encrypted_file.enc -out "$DECRYPTED_FILE" -pass file:aes_key.key
    if [ $? -ne 0 ]; then
      echo "ERROR asnani.ma: File decryption failed." >&2
      exit 1
    fi

    # Cleanup temporary files
    rm -f envelope_*.enc signature.sig aes_key.key shared_secret_*.bin derived_key_*.key encrypted_file.enc

    echo "Decryption and signature verification successful. Output: $DECRYPTED_FILE"
    ;;

  *)
    echo "ERROR asnani.ma: Invalid mode. Use -sender or -receiver." >&2
    exit 1
    ;;
esac
