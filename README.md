# Secure Group File Sharing with ECDH + ECC
A Bash-based cryptographic tool for securely encrypting and signing files so a sender can share them with multiple recipients. Provides confidentiality, integrity, and authenticity by combining Elliptic Curve key exchange, hashing, and symmetric encryption.
________________________________________
## Table of Contents
1.	Overview
2.	Features
3.	Requirements
4.	Usage
5.	Testing & Validation
6.	Error Handling
7.	Notes
________________________________________
## Overview
This project implements ECDH (Elliptic-Curve Diffie–Hellman) key exchange to derive a shared secret for each recipient, then encrypts a file with AES, and finally signs the encrypted data with the sender’s ECC private key. Each recipient can verify the signature and decrypt the file if they have a matching private key.
Designed for a scenario where one sender wants to send a file to three recipients—but can be extended to more. The approach is:
1.	Symmetric Encryption (AES)
2.	ECC Key Pairs for sender and each recipient
3.	ECDH for deriving a per-user envelope, ensuring each recipient can decrypt but only with their valid private key
4.	SHA-256 or similar digest used for signature and key derivation
5.	Zipped output for easy distribution
________________________________________
## Features
- ECC Key Exchange: Utilizes ECDH for ephemeral shared secrets
- AES Encryption: Secures the file with a random AES-256 session key
- Digital Signatures: Sender signs the encrypted file so recipients can confirm authenticity
- Multiple Recipients: Generates a unique envelope for each recipient
- Cleanup: Removes temporary keys, signatures, etc. after creation or decryption
- Shell Script: Entire logic is in one Bash script (crypto.sh)
________________________________________
## Requirements
- OpenSSL (with ECC support)
- A Unix-like environment (tested with Bash on Linux/Mac; can also work on WSL for Windows)
- Generated ECC public/private keys for the sender and each recipient
- Additionally, you should have keys named similarly to:
  sender.priv     sender.pub
  receiver1.priv  receiver1.pub
  receiver2.priv  receiver2.pub
  receiver3.priv  receiver3.pub
________________________________________
## Usage
The script runs in two modes: -sender and -receiver.
1) Sender Mode
Encrypts and signs a plaintext file for multiple recipients, producing a single ZIP file containing all the necessary envelopes.
Syntax:
./crypto.sh -sender <receiver1_pub> <receiver2_pub> <receiver3_pub> \
            <sender_priv> <plaintext_file> <zip_filename>
- <receiverX_pub>: Public key file for each recipient (e.g., receiver1.pub)
- <sender_priv>: Sender’s private key file
- <plaintext_file>: The file you want to encrypt
- <zip_filename>: Name of the final ZIP output (e.g., encrypted_package.zip)
2) Receiver Mode
Extracts, verifies, and decrypts the ZIP file to recover the original plaintext.
Syntax:
./crypto.sh -receiver <receiver_priv> <sender_pub> <zip_file> <plaintext_file>
- <receiver_priv>: Recipient’s private key file
- <sender_pub>: Sender’s public key (used to verify signature)
- <zip_file>: The ZIP file produced by sender
- <plaintext_file>: The name you want for the decrypted output
________________________________________
## Testing & Validation
1.	Hash Comparison: After decryption, run sha256sum on both the original file and the decrypted file.
  If they match, your encryption/decryption is correct.
2.	Signature Tampering: Modify the .enc file or the .sig and try decrypting. The script should fail signature verification.
3.	Wrong Private Key: Attempt to decrypt with a different recipient’s private key. It should fail to derive the correct AES key.
________________________________________
## Error Handling
- Prints errors to stderr with the prefix ERROR <username> whenever arguments or file checks fail.
- Cleans up partial or temporary files on failure.
- Checks for missing arguments and missing files.
________________________________________
## Notes
- ECC is used for key derivation, AES for symmetric encryption, and SHA-256 for hashing.
- Make sure you have the correct file names and pass them in the right order.
