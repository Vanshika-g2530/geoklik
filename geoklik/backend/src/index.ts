import express from "express";
import multer from "multer";
import path from "path";
import fs from "fs";
import crypto from "crypto";
import { ethers } from "ethers";

const app = express();
const PORT = 3000;

// ===== Ganache Blockchain Setup =====

const provider = new ethers.JsonRpcProvider("http://127.0.0.1:7545");

const privateKey = "0xdd7f2c7a3498b2827a6dd2f78e195384c3b8c61de500de8dd4d152519842a2ed";

const wallet = new ethers.Wallet(privateKey, provider);

const contractAddress = "0x40a4d5f5f74E6303e4F446682152a96d1F2ba03B";

const contractABI = [
  "function storeProof(string memory _imageHash, string memory _latitude, string memory _longitude, string memory _timestamp) public",
  "function verifyProof(string memory _imageHash) public view returns (string memory, string memory, string memory, string memory, bool)"
];

const contract = new ethers.Contract(
  contractAddress,
  contractABI,
  wallet
);

// ===== Multer Storage Setup =====

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "src/uploads/");
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
      return res.status(400).send({
        message: "No image uploaded",
      });
    }

    const filePath = req.file.path;
    const imageHash = generateFileHash(filePath);

    const tx = await contract.storeProof(
      imageHash,
      latitude,
      longitude,
      timestamp
    );

    await tx.wait();

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
    console.error(error);
    res.status(500).send({
      message: "Blockchain storage failed",
    });
  }
});

app.post("/verify-proof", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).send({
        message: "No image uploaded",
      });
    }

    const filePath = req.file.path;
    const imageHash = generateFileHash(filePath);

    const result = await contract.verifyProof(imageHash);

    const exists = result[4];

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
        hash: imageHash,
      });
    }

  } catch (error) {
    console.error(error);
    res.status(500).send({
      message: "Verification failed",
    });
  }
});


// ===== Start Server =====

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});