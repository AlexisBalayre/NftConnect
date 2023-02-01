// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./CloneERC721.sol";

contract SafeERC721 is IERC721Receiver {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public immutable admin;
    address public immutable leaseContract;

    /// Set of all clone ERC721 logic contracts
    EnumerableSet.AddressSet private clonesERC721Logic;

    /// Set of all NFT contracts that are cloned
    EnumerableSet.AddressSet private nftContracts;

    /// Maps the IDs of the NFTs staked to the address of the original NFT contract
    mapping(address => EnumerableSet.UintSet)
        private nftIDsStakedByContractAddress;
    /// Maps the address of a cloned nft contract to the address of the original NFT contract
    mapping(address => address) public cloneAddressByContractAddress;
    /// Maps the address of the original NFT Contract to the NFT ID staked to the Staking Informations
    struct StakingData {
        bool isStaked;
        address owner;
        address cloneContract;
        address leasingPaymentToken;
        int96 leasingFlowRatePrice;
        uint256 leasingDurationMin;
        uint256 leasingDurationMax;
    }
    mapping(address => mapping(uint256 => StakingData))
        private stakeDataByContractAddress;

    error IsNotAdmin(address caller);
    error IsNotNftOwner(address caller);
    error WrongOperator(address operator);
    error AmountTooHigh(uint256 amount, uint256 maxAmount);

    constructor(
        address _admin
    ) {
        admin =_admin;
        leaseContract = msg.sender;
        clonesERC721Logic.add(address(new CloneERC721()));
    }

    /// @notice Returns the staking data of a NFT 
    /// @param _nftContract Address of the NFT contract
    /// @param _tokenId ID of the NFT
    /// @return leaseData Staking data of the NFT
    function getStakeData(
        address _nftContract,
        uint256 _tokenId
    ) external view returns (StakingData memory leaseData) {
        leaseData = stakeDataByContractAddress[_nftContract][_tokenId];
    }

    /// @notice Returns the address of the cloned nft contract
    /// @param _index Index of the cloned nft contract in the set of all cloned nft contracts
    function getCloneERC721Logic(uint256 _index)
        external
        view
        returns (address cloneERC721LogicAddress)
    {
        cloneERC721LogicAddress = clonesERC721Logic.at(_index);
    }

    /// @notice Returns the addresses of all cloned nft contracts
    /// @return cloneERC721LogicAddresses Array of addresses of all cloned nft contracts
    function getClonesERC721Logic()
        external
        view
        returns (address[] memory cloneERC721LogicAddresses)
    {
        cloneERC721LogicAddresses = new address[](clonesERC721Logic.length());
        for (uint256 i = 0; i < clonesERC721Logic.length(); i++) {
            cloneERC721LogicAddresses[i] = clonesERC721Logic.at(i);
        }
    }

    /// @notice Returns the IDs of staked NFTs  
    /// @param _nftContract Address of the NFT contract
    /// @return nftIDs Array of IDs of staked NFTs
    function getNftIDsStaked(address _nftContract)
        external
        view
        returns (uint256[] memory nftIDs)
    {
        nftIDs = new uint256[](
            nftIDsStakedByContractAddress[_nftContract].length()
        );
        for (
            uint256 i = 0;
            i < nftIDsStakedByContractAddress[_nftContract].length();
            i++
        ) {
            nftIDs[i] = nftIDsStakedByContractAddress[_nftContract].at(i);
        }
    }

    /// @notice Returns the addresses of all NFT contracts that are cloned
    /// @return nftContractsStaked Array of addresses of all NFT contracts that are cloned
    function getNftContractsCloned()
        external
        view
        returns (address[] memory nftContractsStaked)
    {
        nftContractsStaked = new address[](nftContracts.length());
        for (uint256 i = 0; i < nftContracts.length(); i++) {
            nftContractsStaked[i] = nftContracts.at(i);
        }
    }

    /// @notice Locks out some NFTs and puts them on lease
    /// @param _nftContract The address of the original NFT contract
    /// @param _tokenIds The IDs of the NFTs 
    /// @param _leasingDurationMin The minimum leasing duration (seconds)
    /// @param _leasingDurationMax The maximum leasing duration (seconds)
    /// @param _indexERC721Logic The index of the clone ERC721 logic contract
    /// @param _leasingFlowRatePrice The leasing flow rate price (wei/second)
    function stakeERC721Assets(
        IERC721Metadata _nftContract,
        uint256[] calldata _tokenIds,
        uint256 _leasingDurationMin,
        uint256 _leasingDurationMax,
        uint256 _indexERC721Logic,
        int96 _leasingFlowRatePrice,
        address _leasingPaymentToken
    ) external {
        /// Check if the NFT contract is already cloned
        if (!nftContracts.contains(address(_nftContract))) {
            address cloneContract = Clones.clone(
                clonesERC721Logic.at(_indexERC721Logic)
            );
            CloneERC721(cloneContract).initialize(admin, leaseContract, _nftContract);
            nftContracts.add(address(_nftContract));
            cloneAddressByContractAddress[
                address(_nftContract)
            ] = cloneContract;
        }
        /// Transfer the NFTs to the SafeERC721 contract and mint the cloned nfts
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            /// Transfer the NFT from the owner to the SafeERC721 contract
            _nftContract.safeTransferFrom(
                msg.sender,
                address(this),
                _tokenIds[i]
            );
            /// Returns the address of the cloned nft contract
            address cloneContract = cloneAddressByContractAddress[
                address(_nftContract)
            ];
            /// Mint the cloned nft
            CloneERC721(cloneContract)
                .mintClone(_tokenIds[i]);
            /// Update the staking informations of the NFT
            stakeDataByContractAddress[address(_nftContract)][
                _tokenIds[i]
            ] = StakingData(
                {
                    isStaked: true,
                    owner: msg.sender,
                    cloneContract: cloneContract,
                    leasingPaymentToken: _leasingPaymentToken,
                    leasingDurationMin: _leasingDurationMin,
                    leasingDurationMax: _leasingDurationMax,
                    leasingFlowRatePrice: _leasingFlowRatePrice
                }
            );
            /// Update the set of NFT IDs staked
            nftIDsStakedByContractAddress[address(_nftContract)].add(
                _tokenIds[i]
            );
        }
    }

    /// @notice Unlocks some NFTs and removes them from leasing
    /// @param _nftContract The address of the original NFT contract
    /// @param _tokenIds The IDs of the NFTs 
    function unstakeERC721Assets(
        IERC721 _nftContract,
        uint256[] calldata _tokenIds
    ) external {
        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            /// Check if the sender is the owner of the NFT
            if (
                stakeDataByContractAddress[address(_nftContract)][_tokenIds[i]]
                    .owner != msg.sender
            ) {
                revert IsNotNftOwner(msg.sender);
            }
            /// Transfer the NFT from the SafeERC721 contract to the owner
            _nftContract.safeTransferFrom(
                address(this),
                msg.sender,
                _tokenIds[i]
            );
            /// Burn the cloned nft
            CloneERC721(cloneAddressByContractAddress[address(_nftContract)])
                .burnClone(_tokenIds[i]);
            /// Update the staking informations of the NFT
            stakeDataByContractAddress[address(_nftContract)][
                _tokenIds[i]
            ] = StakingData(
                {
                    isStaked: false,
                    owner: address(0),
                    cloneContract: address(0),
                    leasingPaymentToken: address(0),
                    leasingDurationMin: 0,
                    leasingDurationMax: 0,
                    leasingFlowRatePrice: 0 
                }
            );
            /// Update the set of NFT IDs staked
            nftIDsStakedByContractAddress[address(_nftContract)].remove(
                _tokenIds[i]
            );
        }
    }

    function onERC721Received(
        address operator,
        address,
        uint256,
        bytes calldata
    ) 
        external   
        view
        override 
        returns (bytes4) 
    {
        if (operator != address(this)) {
            revert WrongOperator(operator);
        } 
        return this.onERC721Received.selector;
    }
}