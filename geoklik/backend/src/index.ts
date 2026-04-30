import express from "express";
import multer from "multer";
import path from "path";
import fs from "fs";
import crypto from "crypto";
import { ethers } from "ethers";
import dotenv from "dotenv";
import cors from "cors";
import type { GeoProof } from "../types/ethers-contracts/GeoProof.js";

dotenv.config();
const app = express();
app.use(cors());
const PORT = 3000;

// ===== Ganache Blockchain Setup =====

const providerUrl = process.env.RPC_URL || "http://127.0.0.1:7545";
const provider = new ethers.JsonRpcProvider(providerUrl);

const privateKey = process.env.PRIVATE_KEY || "0xdac61d93b33c8cfc9cecadecce2a07d3f6897e3520e7faf95fe3950b4fa00045";

const wallet = new ethers.Wallet(privateKey, provider);

const contractAddress = process.env.CONTRACT_ADDRESS || "0x40a4d5f5f74E6303e4F446682152a96d1F2ba03B";

const contractABI = [
  "function storeProof(string memory _imageHash, string memory _latitude, string memory _longitude, string memory _timestamp) public",
  "function verifyProof(string memory _imageHash) public view returns (string memory, string memory, string memory, string memory, bool)"
];

const contract = new ethers.Contract(
  contractAddress,
  contractABI,
  wallet
) as unknown as GeoProof;

// ===== Multer Storage Setup =====

const uploadDir = path.join(process.cwd(), "src", "uploads");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname));
  },
});

const upload = multer({ storage });

// ===== Hash Generator =====

const generateFileHash = (filePath: string) => {
  const fileBuffer = fs.readFileSync(filePath);
  const hashSum = crypto.createHash("sha256");
  hashSum.update(fileBuffer);
  return hashSum.digest("hex");
};

// ===== Test Route =====

app.get("/test", (req, res) => {
  res.send("Backend is running");
});

// ===== Upload + Blockchain Store =====

app.post("/upload-proof", upload.single("image"), async (req, res) => {
  try {
    const { latitude, longitude, timestamp } = req.body;

    if (!req.file) {
      return res.status(400).send({ message: "No image uploaded" });
    }

    const filePath = req.file.path;
    const imageHash = generateFileHash(filePath);

    // Debug: log hash being stored
    console.log(`[UPLOAD] File size: ${req.file.size} bytes`);
    console.log(`[UPLOAD] Hash to store: ${imageHash}`);

    const tx = await contract.storeProof(imageHash, latitude, longitude, timestamp);
    await tx.wait();

    console.log(`[UPLOAD] Stored on blockchain. TX: ${tx.hash}`);

    res.send({
      message: "Image uploaded + stored on blockchain successfully",
      file: req.file.filename,
      latitude,
      longitude,
      timestamp,
      hash: imageHash,
      transactionHash: tx.hash,
    });

  } catch (error) {
    console.error("[UPLOAD ERROR]", error);
    res.status(500).send({ message: "Blockchain storage failed" });
  }
});

app.post("/verify-proof", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).send({ message: "No image uploaded" });
    }

    const filePath = req.file.path;
    const imageHash = generateFileHash(filePath);

    // Debug: log hash being verified
    console.log(`[VERIFY] File size: ${req.file.size} bytes`);
    console.log(`[VERIFY] Hash to check: ${imageHash}`);

    const result = await contract.verifyProof(imageHash);
    const exists = result[4];

    console.log(`[VERIFY] Found on blockchain: ${exists}`);

    if (exists) {
      res.send({
        message: "Image Verified Successfully ✅",
        verified: true,
        hash: imageHash,
        blockchainData: {
          latitude: result[1],
          longitude: result[2],
          timestamp: result[3],
        },
      });
    } else {
      res.send({
        message: "Image Not Found on Blockchain ❌",
        verified: false,
        hash: imageHash,  // returned so Flutter can show it
      });
    }

  } catch (error) {
    console.error("[VERIFY ERROR]", error);
    res.status(500).send({ message: "Verification failed" });
  }
});


// ===== Start Server =====

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
  console.log(`From phone, use: http://10.7.17.27:${PORT} or http://192.168.137.1:${PORT}`);
});