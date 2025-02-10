// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "@forge-std/Script.sol";
import {console2 as console} from "@forge-std/console2.sol";
import {AxisMetadataRegistry} from "../src/MetadataRegistry.sol";

contract Deploy is Script {
    function deploy() public {
        // Set constructor parameters
        address serviceSigner = msg.sender;
        address[] memory auctionHouses = new address[](1);
        auctionHouses[0] = 0xBA0000c28179CE533233a943d432eddD154E62A3; // base-sepolia batch auction house

        console.log("Deploying AxisMetadataRegistry...");
        console.log("Service Signer:", serviceSigner);
        uint256 len = auctionHouses.length;
        console.log("Number of auctionHouses:", len);
        for (uint256 i = 0; i < len; i++) {
            console.log(string.concat("Auction House ", vm.toString(i), ": "), auctionHouses[i]);
        }

        // Deploy the metadata registry
        vm.broadcast();
        AxisMetadataRegistry metadataRegistry = new AxisMetadataRegistry(serviceSigner, auctionHouses);

        console.log("AxisMetadataRegistry deployed at:", address(metadataRegistry));
    }
}
