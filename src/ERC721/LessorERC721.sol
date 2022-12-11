// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "./CloneERC721.sol";
import "./SafeERC721.sol";
import "../FeesManager.sol";

contract LessorERC721 is IERC721Receiver {
    SafeERC721 public immutable safeContract; 
    FeesManager public immutable feesManager;

    error IsNotLessee(address caller);
    error IsNotAvailableForLease(address nftContract, uint256 tokenId);

    constructor(
        address _admin,
        address _feesManager
    ) {
        safeContract = new SafeERC721(_admin);
        feesManager = FeesManager(_feesManager);
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