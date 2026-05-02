# GeoKlik – Geo-Tagged Image Verification App

## Overview
GeoKlik is a blockchain-based geo-tagged image verification system designed to ensure image authenticity and prevent tampering. The application captures images along with live location data (latitude, longitude), timestamps, and metadata, then securely verifies image integrity using raw pixel-level cryptographic hashing and blockchain storage.

The system helps confirm whether an image is original or modified by comparing the generated hash of the image with the hash stored on the blockchain.

This project provides a complete end-to-end workflow using Flutter (mobile app), Node.js + Express backend, and Ethereum smart contracts.

## Problem Statement
In many real-world scenarios such as field inspections, electricity meter verification, insurance claims, property surveys, and government reporting, images can easily be edited or manipulated after capture. Traditional image sharing does not provide proof of authenticity. GeoKlik solves this problem by creating tamper-proof image verification using blockchain technology.

## Key Features
- **Geo-tagged Image Capture**: Take photos with real-time GPS coordinates and timestamps.
- **Blockchain Authentication**: Hashes and metadata are stored on the blockchain for immutable verification.
- **Raw Pixel-Level Hashing**: Utilizes raw pixel data for hashing directly on the mobile app to prevent metadata manipulation or OS-level re-encoding issues.
- **Tamper-proof Verification**: Authenticity check using blockchain validation with results shown directly inside the app.
- **Interactive Maps**: View authenticated photo locations on an interactive Google Map.
- **Secure Gallery**: Browse captured images and verify their authenticity.

## System Workflow

### Image Capture Flow
1. User captures an image using the GeoKlik mobile app.
2. App fetches live latitude and longitude and generates a timestamp.
3. App generates a trusted raw pixel-level hash locally to avoid OS compression issues.
4. The hash and metadata are sent to the backend server.
5. Backend stores the hash + metadata on the blockchain using a smart contract.
6. Gas fee is deducted from the blockchain wallet.

### Verification Flow
1. User selects an image for verification from the gallery.
2. App recalculates the raw pixel-level image hash.
3. App sends the hash to the backend.
4. Smart contract checks whether the hash exists on the blockchain.
5. App displays the verification status (Verified ✅ or Not Verified ❌).

## Project Structure
This project is structured into two main components:
- **Flutter App** (`lib/`): Contains the mobile application source code (UI screens, camera, geolocation).
- **Backend** (`backend/`): Contains the Node.js backend, Express server, and Hardhat setup for Ethereum smart contract deployment.

## Getting Started

### Prerequisites
- Flutter SDK (>=3.11.0)
- Node.js & npm
- Hardhat (for local blockchain testing)

### Installation
1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd geoklik/geoklik
   ```

2. **Install Flutter Dependencies**
   ```bash
   flutter pub get
   ```

3. **Install Backend Dependencies**
   ```bash
   cd backend
   npm install
   ```

### Running the Application
1. **Start the Local Blockchain & Backend**
   Navigate to the `backend` directory and start your local Hardhat node and Express server.
   *(Please refer to the backend README for detailed instructions).*

2. **Run the Flutter App**
   Navigate back to the main Flutter project root and run the app on your preferred device or emulator.
   ```bash
   flutter run
   ```

## Tech Stack
- **Mobile App**: Flutter, Dart, Camera API, Geolocator
- **Backend**: Node.js, TypeScript, Express.js, Ethers.js
- **Blockchain**: Solidity, Hardhat, Ethereum Smart Contracts
- **Security**: Raw Pixel-Level Cryptographic Hashing

## Authors
Developed by:
**Akriti Bansal** <br>
**Shreya Sharma** <br>
**Vanshika Goyal**

## License
This project is licensed under the MIT License.
