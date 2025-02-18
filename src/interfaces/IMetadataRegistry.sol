// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IMetadataRegistry {
    // ========== ERRORS ========== //

    error AlreadyAssigned();
    error InvalidParam(string param);
    error InvalidSignature();
    error NotAuthorized();

    // ========== EVENTS ========== //

    event AuctionRegistered(address auctionHouse, uint96 lotId, string ipfsCID);
    event CuratorRegistered(address curator, uint256 xId, string ipfsCID);
    event CuratorUpdated(uint256 xId, string ipfsCID);

    // ========== DATA STRUCTURES ========== //

    struct CuratorRegistration {
        address curator;
        uint256 xId;
        string ipfsCID;
    }

    struct AuctionRegistration {
        address auctionHouse;
        uint96 lotId;
        string ipfsCID;
    }

    // ========== INIT ========== //

    function registerCurator(CuratorRegistration calldata payload_, bytes calldata signature_) external;

    function registerAuction(address auctionHouse_, uint96 lotId_, string calldata ipfsCID_) external;

    // ========== UPDATE ========== //

    function updateCurator(uint256 xId_, string calldata ipfsCID_) external;

    function addCuratorAddress(uint256 xId_, address curator_) external;

    function removeCuratorAddress(uint256 xId_, address curator_) external;

    // ========== GETTERS ========== //

    function isAuctionHouse(address auctionHouse_) external view returns (bool);

    function curatorId(address curator_) external view returns (uint256);

    function curatorMetadata(uint256 xId_) external view returns (string memory);

    function auctionMetadata(address auctionHouse_, uint96 lotId_) external view returns (string memory);
}
