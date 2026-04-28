// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract GeoProof {

    struct Proof {
        string imageHash;
        string latitude;
        string longitude;
        string timestamp;
        bool exists;
    }

    mapping(string => Proof) public proofs;

    function storeProof(
        string memory _imageHash,
        string memory _latitude,
        string memory _longitude,
        string memory _timestamp
    ) public {
        proofs[_imageHash] = Proof(
            _imageHash,
            _latitude,
            _longitude,
            _timestamp,
            true
        );
    }

    function verifyProof(string memory _imageHash)
        public
        view
        returns (
            string memory,
            string memory,
            string memory,
            string memory,
            bool
        )
    {
        Proof memory proof = proofs[_imageHash];

        return (
            proof.imageHash,
            proof.latitude,
            proof.longitude,
            proof.timestamp,
            proof.exists
        );
    }
}