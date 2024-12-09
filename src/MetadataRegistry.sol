// SPDX-License-Identifier: TBD
pragma solidity 0.8.19;


// TODO make ownable
contract AxisMetadataRegistry {

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
    
    
    // ========== STATE VARIABLES ========== //

    address public serviceSigner;

    mapping(address curator => uint256 xId) public curatorId;
    mapping(uint256 xId => string ipfsCID) public curatorMetadata;

    mapping(address auctionHouse => mapping(uint96 lotId => string ipfsCID)) public auctionMetadata;

    // ========== CONSTRUCTOR ========== //

    constructor(address serviceSigner_, address[] calldata auctionHouses_) {
        for (uint256 i = 0; i < auctionHouses_.length; i++) {
            isAuctionHouse[auctionHouses_[i]] = true;
        }

        serviceSigner = serviceSigner_;
    }

    // ========== INIT ========== //

    // TODO is it necessary to store ipfsCID onchain and emit an event? Can we just emit that part in an event?

    function registerCurator(CuratorRegistration calldata payload_, bytes calldata signature_) external {
        // Validate the sender is the curator listed in the payload
        if (msg.sender != payload_.curator) NotAuthorized();

        // Validate the xId is not zero
        if (payload_.xId == 0) InvalidParam("payload.xId");

        // Validate that the curator address is not already assigned an xId
        if (curatorId[payload_.curator] != 0) AlreadyAssigned();

        // Validate that the ipfsCID string is not empty
        if (bytes(payload_.ipfsCID).length == 0) InvalidParam("payload.ipfsCID");

        // Validate the service signer signed the payload
        // TODO add signature validation library

        // Store the curator's xId
        curatorId[payload_.curator] = payload_.xId;

        // Store the metadata
        curatorMetadata[payload_.xId] = payload_.ipfsCID;

        // Emit event
        emit CuratorRegistered(payload_.curator, payload_.xId, payload_.ipfsCID);
    }

    function registerAuction(address auctionHouse_, uint96 lotId_, string ipfsCID_) external {
        // Validate the auction house is supported
        if (!isAuctionHouse[auctionHouse_]) revert InvalidParam("auctionHouse");
        IAuctionHouse auctionHouse = IAuctionHouse(auctionHouse_);

        // Validate the lotId is valid on the auction house by comparing against the lotCounter
        if (lotId_ >= auctionHouse.lotCounter()) revert InvalidParam("lotId");

        // Validate the caller is the seller of the lot
        (address seller, ,,,,,,,) = auctionHouse.lotRouting();
        if (msg.sender != seller) revert NotAuthorized();

        // Validate the ipfsCID string is not empty
        if (bytes(ipfsCID_).length == 0) revert InvalidParam("ipfsCID");

        // Store the metadata
        auctionMetadata[auctionHouse_][lotId_] = ipfsCID_;

        // Emit event
        emit AuctionRegistered(auctionHouse_, lotId_, ipfsCID_);
    }

    // ========== UPDATE ========== //

    function updateCurator(uint256 xId_, string ipfsCID_) external {
        // Validate the xId is not zero
        if (xId_ == 0) revert InvalidParam("xId");

        // Validate the caller is the curator
        if (curatorId[msg.sender] != xId_) revert NotAuthorized();

        // Validate the ipfsCID string is not empty
        if (bytes(ipfsCID_).length == 0) revert InvalidParam("ipfsCID");

        // Store the metadata
        curatorMetadata[xId_] = ipfsCID_;

        // Emit event
        emit CuratorUpdated(xId_, ipfsCID_);
    }

    function addCuratorAddress(uint256 xId_, address curator_) external {
        // Validate the xId is not zero
        if (xId_ == 0) revert InvalidParam("xId");

        // Validate the caller is a currently a valid address for the curator
        if (curatorId[msg.sender] != xId_) revert NotAuthorized();

        // Validate the curator address is not already assigned an xId
        if (curatorId[curator_] != 0) revert AlreadyAssigned();

        // Store the curator's xId
        curatorId[curator_] = xId_;

        // Emit event
        emit CuratorAddressAdded(xId_, curator_);
    }

    function removeCuratorAddress(uint256 xId_, address curator_) external {
        // Validate the xId is not zero
        if (xId_ == 0) revert InvalidParam("xId");

        // Validate the caller is a currently a valid address for the curator
        if (curatorId[msg.sender] != xId_) revert NotAuthorized();

        // Validate the curator address is assigned to the xId
        if (curatorId[curator_] != xId_) revert InvalidParam("curator");

        // Remove the curator's xId
        delete curatorId[curator_];

        // Emit event
        emit CuratorAddressRemoved(xId_, curator_);
    }

    // ========== ADMIN ========== //

    function forceRegisterCurator(address curator_, uint256 xId_, string ipfsCID_) external onlyOwner {
        // Validate the xId is not zero
        if (xId_ == 0) revert InvalidParam("xId");

        // Validate the curator address is not already assigned an xId
        if (curatorId[curator_] != 0) revert AlreadyAssigned();

        // Validate the ipfsCID string is not empty
        if (bytes(ipfsCID_).length == 0) revert InvalidParam("ipfsCID");

        // Store the curator's xId
        curatorId[curator_] = xId_;

        // Store the metadata
        curatorMetadata[xId_] = ipfsCID_;

        // Emit event
        emit CuratorRegistered(curator_, xId_, ipfsCID_);
    }

    function forceAddCuratorAddress(uint256 xId_, address curator_) external onlyOwner {
        // Validate the xId is not zero
        if (xId_ == 0) revert InvalidParam("xId");

        // Validate the curator address is not already assigned an xId
        if (curatorId[curator_] != 0) revert AlreadyAssigned();

        // Store the curator's xId
        curatorId[curator_] = xId_;

        // Emit event
        emit CuratorAddressAdded(xId_, curator_);
    }

    function forceRemoveCuratorAddress(uint256 xId_, address curator_) external onlyOwner {
        // Validate the xId is not zero
        if (xId_ == 0) revert InvalidParam("xId");

        // Validate the curator address is assigned to the xId
        if (curatorId[curator_] != xId_) revert InvalidParam("curator");

        // Remove the curator's xId
        delete curatorId[curator_];

        // Emit event
        emit CuratorAddressRemoved(xId_, curator_);
    }

    function updateServiceSigner(address serviceSigner_) external onlyOwner {
        serviceSigner = serviceSigner_;
    }


}
