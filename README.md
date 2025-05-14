# 🐄 Livestock Identity & Ownership Registry 🐄

## 🌟 Overview
This smart contract provides a secure, transparent system for tracking livestock identity, ownership, and health records using blockchain technology and NFC chips. It helps reduce theft and improves veterinary care tracking in the agricultural sector.

## 🔑 Key Features
- 📝 Register livestock with unique identifiers
- 🔄 Transfer ownership with complete history
- 💉 Record and track health treatments
- 🏷️ NFC chip integration for physical-digital linking
- 🔍 Transparent ownership verification

## 📋 Contract Functions

### Read-Only Functions
- `get-livestock`: Retrieve livestock details by ID
- `get-livestock-health-record`: Get a specific health record
- `get-livestock-ownership-record`: Get a specific ownership transfer record
- `get-last-livestock-id`: Get the latest livestock ID in the system
- `get-last-health-record-id`: Get the latest health record ID for a specific livestock
- `get-last-transfer-id`: Get the latest transfer ID for a specific livestock
- `check-livestock-owner`: Verify if a principal is the owner of a specific livestock

### Public Functions
- `register-livestock`: Register a new livestock with species, breed, birth date, and NFC chip ID
- `add-health-record`: Add a new health treatment record for livestock
- `transfer-ownership`: Transfer ownership of livestock to a new owner
- `update-nfc-chip`: Update the NFC chip ID for a livestock

## 🚀 Usage Examples

### Registering New Livestock
```clarity
(contract-call? .livestock-identity-ownership-registry register-livestock "Bovine" "Angus" u1620000000 "NFC123456789")
```

### Adding a Health Record
```clarity
(contract-call? .livestock-identity-ownership-registry add-health-record u1 "Vaccination" "Annual vaccination against foot and mouth disease")
```

### Transferring Ownership
```clarity
(contract-call? .livestock-identity-ownership-registry transfer-ownership u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM u5000000 "Sale at county auction")
```

### Updating NFC Chip
```clarity
(contract-call? .livestock-identity-ownership-registry update-nfc-chip u1 "NEW-NFC-987654321")
```

## 🔧 Error Codes
- `u400`: Invalid operation (e.g., transferring to self)
- `u403`: Unauthorized (not the owner)
- `u404`: Livestock not found

## 📱 Integration with NFC Technology
This contract is designed to work with NFC chips attached to livestock. The physical NFC chip ID is stored on the blockchain, creating a secure link between the physical animal and its digital record.
```