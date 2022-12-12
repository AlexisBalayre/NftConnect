// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { ISuperfluid } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import { CFAv1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

import "./CloneERC721.sol";
import "./SafeERC721.sol";
import "../FeesManager.sol";

contract LessorERC721 is IERC721Receiver {
    /// @dev CFAv1 Library
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData private cfaV1;

    SafeERC721 public immutable safeContract; 
    FeesManager public immutable feesManager;

    /// @notice Address of the super token address
    ISuperToken public superToken;

    /// @dev Address of the Superfluid Host contract
    ISuperfluid private host; // host

    /// @dev Address of the Superfluid CFA contract
    IConstantFlowAgreementV1 private cfa;

    error IsNotLessee(address caller);
    error IsNotAvailableForLease(address nftContract, uint256 tokenId);

    /// @notice Open or Update Stream Event
    event OpenUpdateStream(address receiver, int96 flowRate);
    /// @notice Close Stream Event
    event CloseStream(address receiver);

    constructor(
        address _admin,
        address _feesManager
    ) {
        safeContract = new SafeERC721(_admin);
        feesManager = FeesManager(_feesManager);
        cfaV1 = CFAv1Library.InitData(
            _host,
            IConstantFlowAgreementV1(
                address(
                    _host.getAgreementClass(
                        keccak256(
                            "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
                        )
                    )
                )
            )
        );
    }

    /// @notice Opens or Updates a reward stream
    /// @param _receiver Address of the receiver
    /// @param _tokenId ID of the NFT
    /// @param _rewardIndex Index of the reward flowrate
    /// @dev This function can only be called by the owner or the dev Wallet
    function createUpdateStream(
        address _receiver,
        uint256 _tokenId,
        uint256 _rewardIndex
    ) external {
        require(msg.sender == owner() || msg.sender == devWallet, "Access Forbidden");
        require(
            _receiver != address(this),
            "Receiver must be different than sender"
        );

        // Get NFT informations
        IBedroomNft.NftOwnership memory nftOwnership = bedroomNft
            .getNftOwnership(_tokenId);

        // Verifies that the recipient is the owner of the NFT
        require(nftOwnership.owner == _receiver, "Wrong receiver");

        // Gets flow rate
        int96 flowrate = rewardsByCategory[nftOwnership.category][_rewardIndex];

        (, int96 outFlowRate, , ) = cfa.getFlow(
            superToken,
            address(this),
            _receiver
        );

        if (outFlowRate == 0) {
            cfaV1.createFlow(_receiver, superToken, flowrate);
        } else {
            cfaV1.updateFlow(_receiver, superToken, flowrate);
        }

        emit OpenUpdateStream(_receiver, flowrate);
    }

    /// @notice Closes a reward stream
    /// @param _receiver Address of the receiver
    /// @dev This function can only be called by the owner or the dev Wallet
    function closeStream(address _receiver) external {
        require(msg.sender == owner() || msg.sender == devWallet, "Access Forbidden");
        require(
            _receiver != address(this),
            "Receiver must be different than sender"
        );

        cfaV1.deleteFlow(address(this), _receiver, superToken);

        emit CloseStream(_receiver);
    }

    function isAvailableForLease(
        address _nftContract,
        uint256 _tokenId
    ) external view returns (bool isAvailable) {
        isAvailable = safeContract.getStakeData(_nftContract, _tokenId).isAvailableForLease;
    }

    function getLeaseData(
        address _nftContract,
        uint256 _tokenId
    ) external view returns (
        bool isAvailable,
        address lessee,
        address cloneContract,
        int96 leasingFlowRatePrice,
        uint256 leasingStartTimestamp,
        uint256 leasingDuration
    ) {
        SafeERC721.LeaseData memory leaseData = safeContract.getStakeData(_nftContract, _tokenId);
        isAvailable = leaseData.isAvailableForLease;
        lessee = leaseData.lessee;
        cloneContract = leaseData.cloneContract;
        leasingFlowRatePrice = leaseData.leasingFlowRatePrice;
        leasingStartTimestamp = leaseData.leasingStartTimestamp;
        leasingDuration = leaseData.leasingDuration;
    }

    function getNftIdsAvailable(
        address _nftContract
    ) external view returns (uint256[] memory nftIds) {
        uint256[] memory _nftIds = safeContract.getNftIDsStaked(_nftContract);
        nftIds = new uint256[](_nftIds.length);
        for (uint256 i = 0; i < _nftIds.length; i++) {
            if (safeContract.getStakeData(_nftContract, _nftIds[i]).isAvailableForLease) {
                nftIds[i] = _nftIds[i];
            }
        }
    }

    function startLease(
        address _nftContract,
        uint256 _tokenId
    ) external {
        SafeERC721.LeaseData memory leaseData = safeContract.getStakeData(_nftContract, _tokenId);
        if (!leaseData.isAvailableForLease) {
            revert IsNotAvailableForLease(_nftContract, _tokenId);
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) 
        external   
        pure
        override 
        returns (bytes4) 
    {
        return this.onERC721Received.selector;
    }

}