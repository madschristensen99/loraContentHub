
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LoRAContentHub is ERC721, Ownable {
    uint256 public loRACounter;
    uint256 public licenseCounter;
    uint256 public disputeCounter;

    // Story Protocol Testnet Addresses (Sepolia, assumed)
    address public constant IP_ASSET_REGISTRY = 0x77319B4031e6eF1250907aa00018B8B1c67a244b;
    address public constant LICENSING_MODULE = 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f;
    address public constant ROYALTY_MODULE = 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086;
    address public constant DISPUTE_MODULE = 0x9b7A9c70AFF961C799110954fc06F3093aeb94C5;
    IERC20 public constant MERC20 = IERC20(0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E); // Whitelisted revenue token

    struct LoRA {
        string metadataURI;
        address creator;
        bool isLicensed;
    }

    struct License {
        uint256 loRAId;
        string videoURI;
        address licensee;
        uint256 royaltyRate; // Basis points (500 = 5%)
        bool active;
        uint256 disputeId; // 0 if no dispute
    }

    struct Dispute {
        uint256 licenseId;
        address complainant;
        string reason;
        bool resolved;
        bool approved;
    }

    mapping(uint256 => LoRA) public loRAs;
    mapping(uint256 => License) public licenses;
    mapping(uint256 => Dispute) public disputes;

    event LoRARegistered(uint256 loRAId, address creator, string metadataURI);
    event LicenseCreated(uint256 licenseId, uint256 loRAId, string videoURI);
    event RoyaltyDistributed(uint256 licenseId, address creator, uint256 amount);
    event DisputeRaised(uint256 disputeId, uint256 licenseId, string reason);
    event DisputeResolved(uint256 disputeId, bool approved);

    constructor() ERC721("LoRAHub", "LHUB") Ownable(msg.sender) {}

    // Register a LoRA and integrate with Story's IPAssetRegistry
    function registerLoRA(string memory _metadataURI) external {
        loRACounter++;
        uint256 loRAId = loRACounter;

        _mint(msg.sender, loRAId);
        loRAs[loRAId] = LoRA(_metadataURI, msg.sender, false);

        // Call Story's IPAssetRegistry (assumed signature)
        (bool success, ) = IP_ASSET_REGISTRY.call(
            abi.encodeWithSelector(
                bytes4(keccak256("registerIpAsset(address,uint256,string)")),
                address(this),
                loRAId,
                _metadataURI
            )
        );
        require(success, "IPAssetRegistry registration failed");

        emit LoRARegistered(loRAId, msg.sender, _metadataURI);
    }

    // Create a license with Story's LicensingModule
    function createLicense(uint256 _loRAId, string memory _videoURI, uint256 _royaltyRate) external {
        require(_exists(_loRAId), "LoRA does not exist");
        require(_royaltyRate <= 10000, "Royalty too high");
        require(MERC20.transferFrom(msg.sender, address(this), 500 * 10**18), "Stake 500 MERC20 failed"); // Stake 500 MERC20

        licenseCounter++;
        uint256 licenseId = licenseCounter;

        licenses[licenseId] = License(_loRAId, _videoURI, msg.sender, _royaltyRate, true, 0);
        loRAs[_loRAId].isLicensed = true;

        // Call Story's LicensingModule (assumed signature)
        (bool success, ) = LICENSING_MODULE.call(
            abi.encodeWithSelector(
                bytes4(keccak256("registerLicense(uint256,address,string,uint256)")),
                _loRAId,
                msg.sender,
                _videoURI,
                _royaltyRate
            )
        );
        require(success, "LicensingModule registration failed");

        emit LicenseCreated(licenseId, _loRAId, _videoURI);
    }

    // Distribute royalties using MERC20 via Story's RoyaltyModule
    function distributeRoyalties(uint256 _licenseId, uint256 _viewRevenue) external {
        License storage license = licenses[_licenseId];
        require(license.active, "License inactive");
        require(MERC20.transferFrom(msg.sender, address(this), _viewRevenue), "Revenue transfer failed");

        uint256 creatorShare = (_viewRevenue * license.royaltyRate) / 10000;
        address creator = loRAs[license.loRAId].creator;

        require(MERC20.transfer(creator, creatorShare), "Royalty payment failed");

        if (license.disputeId == 0) {
            require(MERC20.transfer(license.licensee, 500 * 10**18), "Stake refund failed"); // Refund stake
        }

        // Call Story's RoyaltyModule (assumed signature)
        (bool success, ) = ROYALTY_MODULE.call(
            abi.encodeWithSelector(
                bytes4(keccak256("distributeRoyalties(uint256,address,uint256)")),
                _licenseId,
                creator,
                creatorShare
            )
        );
        require(success, "RoyaltyModule distribution failed");

        emit RoyaltyDistributed(_licenseId, creator, creatorShare);
    }

    // Raise a dispute with Story's DisputeModule
    function raiseDispute(uint256 _licenseId, string memory _reason) external {
        License storage license = licenses[_licenseId];
        require(license.active, "License inactive");

        disputeCounter++;
        uint256 disputeId = disputeCounter;

        disputes[disputeId] = Dispute(_licenseId, msg.sender, _reason, false, false);
        license.disputeId = disputeId;

        // Call Story's DisputeModule (assumed signature)
        (bool success, ) = DISPUTE_MODULE.call(
            abi.encodeWithSelector(
                bytes4(keccak256("setDispute(uint256,bytes)")),
                _licenseId,
                abi.encode(msg.sender, _reason)
            )
        );
        require(success, "DisputeModule raise failed");

        emit DisputeRaised(disputeId, _licenseId, _reason);
    }

    // Resolve a dispute via Story's DisputeModule
    function resolveDispute(uint256 _disputeId, bool _approved) external onlyOwner {
        Dispute storage dispute = disputes[_disputeId];
        require(!dispute.resolved, "Already resolved");
        License storage license = licenses[dispute.licenseId];

        dispute.resolved = true;
        dispute.approved = _approved;

        if (_approved) {
            license.active = false;
            require(MERC20.transfer(dispute.complainant, 500 * 10**18), "Stake transfer failed"); // Complainant gets stake
        }

        // Call Story's DisputeModule (assumed signature)
        (bool success, ) = DISPUTE_MODULE.call(
            abi.encodeWithSelector(
                bytes4(keccak256("resolveDispute(uint256,uint256,bool)")),
                dispute.licenseId,
                uint256(keccak256(abi.encodePacked(dispute.complainant, dispute.reason))),
                _approved
            )
        );
        require(success, "DisputeModule resolve failed");

        emit DisputeResolved(_disputeId, _approved);
    }
}
