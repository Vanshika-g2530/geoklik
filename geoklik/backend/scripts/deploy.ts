import { network } from "hardhat";

async function main() {
  const { ethers } = await network.connect();

  const GeoProof = await ethers.getContractFactory("GeoProof");

  const geoProof = await GeoProof.deploy({
    gasLimit: 3000000
  });

  await geoProof.waitForDeployment();

  console.log("GeoProof deployed to:", await geoProof.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});