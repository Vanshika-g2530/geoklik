# GeoKlik – Geo-Tagged Image Verification App

## Overview

GeoKlik is a blockchain-based geo-tagged image verification system designed to ensure image authenticity and prevent tampering. The application captures images along with live location data (latitude, longitude), timestamp, and metadata, then securely verifies image integrity using SHA-256 hashing and blockchain storage.

The system helps confirm whether an image is original or modified by comparing the generated hash of the image with the hash stored on the blockchain.

This project provides a complete end-to-end workflow using Flutter (mobile app), Node.js + TypeScript backend, and Ethereum smart contracts.

---

## Problem Statement

In many real-world scenarios such as field inspections, electricity meter verification, insurance claims, property surveys, and government reporting, images can be edited or manipulated after capture.

Traditional image sharing does not provide proof of authenticity.

GeoKlik solves this problem by creating tamper-proof image verification using blockchain technology.

---

## Key Features

* Capture images directly from the mobile app
* Automatic geo-tagging using live GPS location
* Timestamp generation at the moment of capture
* SHA-256 secure image hash generation
* Smart contract-based blockchain storage
* Tamper-proof proof verification
* Image authenticity check using blockchain validation
* Verification result shown directly inside the app
* Secure backend handling for trusted hash generation

---

## System Workflow

### Image Capture Flow

1. User captures an image using the GeoKlik mobile app
2. App fetches live latitude and longitude
3. Timestamp is generated automatically
4. Image is sent to backend server
5. Backend stores the image securely
6. Backend generates trusted SHA-256 hash
7. Hash + metadata are stored on blockchain using smart contract
8. Gas fee is deducted from blockchain wallet

### Verification Flow

1. User selects an image for verification
2. App sends image to backend
3. Backend regenerates image hash
4. Smart contract checks whether hash exists on blockchain
5. App shows:

   * Verified ✅
   * Not Verified ❌

---

## Tech Stack

### Mobile App

* Flutter
* Dart
* Camera API
* Geolocator

### Backend

* Node.js
* TypeScript
* Express.js
* Ethers.js

### Blockchain

* Solidity
* Hardhat
* Ganache (Local Blockchain Testing)
* Ethereum Smart Contracts

### Security

* SHA-256 Cryptographic Hashing

---

## Smart Contract Functions

### storeProof()

Stores:

* Image Hash
* Latitude
* Longitude
* Timestamp

on the blockchain.

### verifyProof()

Checks whether the image hash exists on-chain and returns verification status.

---

## Project Structure

```text
GeoKlik/
│
├── lib/                    # Flutter App
│   ├── main.dart
│   ├── camera_screen.dart
│   ├── splash_screen.dart
│   ├── map_screen.dart
│   └── other UI screens
│
├── backend/                # Node.js Backend
│   ├── src/
│   │   ├── index.ts
│   │   └── uploads/
│   │
│   ├── contracts/
│   │   └── GeoProof.sol
│   │
│   ├── scripts/
│   │   └── deploy.ts
│   │
│   └── hardhat.config.ts
│
└── README.md
```

---

## Authors

Developed by:

**Akriti Bansal**
**Shreya Sharma**
**Vanshika Goyal**
