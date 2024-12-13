// SPDX-License-Identifier: TBD
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {SignatureChecker} from "@openzeppelin/utils/cryptography/SignatureChecker.sol";

import {IAuctionHouse} from "@axis-core/interfaces/IAuctionHouse.sol";

contract AxisMetadataRegistry is Ownable {
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

    // ========== STATE VARIABLES ========== //

    // Typed Data Variables
    uint256 public chainId;
    bytes32 internal domainSeparator;

    bytes32 internal constant CURATOR_REGISTRATION_TYPEHASH =
        keccak256("CuratorRegistration(address curator,uint256 xId,string ipfsCID)");

    /// @notice Address that signs registration payloads after being verified by an offchain service
    address public serviceSigner;

    mapping(address => bool) public isAuctionHouse;
    mapping(address curator => uint256 xId) public curatorId;
    mapping(uint256 xId => string ipfsCID) public curatorMetadata;

    mapping(address auctionHouse => mapping(uint96 lotId => string ipfsCID)) public auctionMetadata;

    // ========== CONSTRUCTOR ========== //

    constructor(address serviceSigner_, address[] memory auctionHouses_) {
        for (uint256 i = 0; i < auctionHouses_.length; i++) {
            isAuctionHouse[auctionHouses_[i]] = true;
        }

        serviceSigner = serviceSigner_;
    }

    // ========== INIT ========== //

    function registerCurator(CuratorRegistration calldata payload_, bytes calldata signature_) external {
        // Validate the sender is the curator listed in the payload
        if (msg.sender != payload_.curator) revert NotAuthorized();

        // Validate the xId is not zero
        if (payload_.xId == 0) revert InvalidParam("payload.xId");

        // Validate that the curator address is not already assigned an xId
        if (curatorId[payload_.curator] != 0) revert AlreadyAssigned();

        // Validate that the ipfsCID string is not empty
        if (bytes(payload_.ipfsCID).length == 0) revert InvalidParam("payload.ipfsCID");

        // Validate the service signer signed the payload
        if (!isValidSignature(serviceSigner, payload_, signature_)) revert InvalidSignature();

        // Store the curator's xId
        curatorId[payload_.curator] = payload_.xId;

        // Store the metadata
        curatorMetadata[payload_.xId] = payload_.ipfsCID;

        // Emit event
        emit CuratorRegistered(payload_.curator, payload_.xId, payload_.ipfsCID);
    }

    // This function allows an auction to be registered multiple times, which allows updating the data
    function registerAuction(address auctionHouse_, uint96 lotId_, string calldata ipfsCID_) external {
        // Validate the auction house is supported
        if (!isAuctionHouse[auctionHouse_]) revert InvalidParam("auctionHouse");
        IAuctionHouse auctionHouse = IAuctionHouse(auctionHouse_);

        // Validate the lotId is valid on the auction house by comparing against the lotCounter
        if (lotId_ >= auctionHouse.lotCounter()) revert InvalidParam("lotId");

        // Validate the caller is the seller of the lot
        (address seller,,,,,,,,) = auctionHouse.lotRouting(lotId_);
        if (msg.sender != seller) revert NotAuthorized();

        // Validate the ipfsCID string is not empty
        if (bytes(ipfsCID_).length == 0) revert InvalidParam("ipfsCID");

        // Store the metadata
        auctionMetadata[auctionHouse_][lotId_] = ipfsCID_;

        // Emit event
        emit AuctionRegistered(auctionHouse_, lotId_, ipfsCID_);
    }

    // ========== UPDATE ========== //

    function updateCurator(uint256 xId_, string calldata ipfsCID_) external {
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
    }

    // ========== ADMIN ========== //

    function updateServiceSigner(address serviceSigner_) external onlyOwner {
        serviceSigner = serviceSigner_;
    }

    function addAuctionHouse(address auctionHouse_) external onlyOwner {
        isAuctionHouse[auctionHouse_] = true;
    }

    function removeAuctionHouse(address auctionHouse_) external onlyOwner {
        delete isAuctionHouse[auctionHouse_];
    }

    // ========== SIGNATURE VALIDATION ========== //

    function isValidSignature(address signer_, CuratorRegistration calldata payload_, bytes calldata signature_)
        public
        view
        returns (bool)
    {
        return SignatureChecker.isValidSignatureNow(signer_, getDigest(payload_), signature_);
    }

    function getDigest(CuratorRegistration calldata payload_) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                hex"1901",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        CURATOR_REGISTRATION_TYPEHASH,
                        payload_.curator,
                        payload_.xId,
                        keccak256(bytes(payload_.ipfsCID))
                    )
                )
            )
        );
    }

    /* ========== DOMAIN SEPARATOR ========== */

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == chainId ? domainSeparator : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Axis Metadata Registry"),
                keccak256("v1.0.0"),
                block.chainid,
                address(this)
            )
        );
    }

    function updateDomainSeparator() external {
        require(block.chainid != chainId, "DOMAIN_SEPARATOR_ALREADY_UPDATED");

        chainId = block.chainid;

        domainSeparator = computeDomainSeparator();
    }
}
