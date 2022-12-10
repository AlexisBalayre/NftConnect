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

    address public immutable manager;
    address public immutable cloneERC721Logic;

    struct StakeInfo {
        bool isStaked;
        address owner;
        uint256 startLocking;
        uint256 lockDuration;
    }

    /// Set of all NFT contracts that are cloned
    EnumerableSet.AddressSet private nftContracts;

    /// Maps the IDs of the NFTs staked to the address of the original NFT contract
    mapping(address => EnumerableSet.UintSet)
        private nftIDsStakedByContractAddress;
    /// Maps the address of a clone NFT contract to the address of the original NFT contract
    mapping(address => address) public cloneAddressByContractAddress;
    /// Maps the address of the original NFT Contract to the NFT ID staked to the Staking Informations
    mapping(address => mapping(uint256 => StakeInfo))
        public stakeInfoByContractAddress;

    error IsNotManager(address caller);
    error IsNotNftOwner(address caller);
    error WrongOperator(address operator);
    error AmountTooHigh(uint256 amount, uint256 maxAmount);

    constructor() {
        manager = msg.sender;
        cloneERC721Logic = address(new CloneERC721());
    }

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

    function stakeERC721Assets(
        IERC721Metadata _nftContract,
        uint256[] calldata _tokenIds,
        uint256 _lockDuration
    ) external {
        /// Check if the NFT contract is already cloned
        if (!nftContracts.contains(address(_nftContract))) {
            address cloneContract = Clones.clone(cloneERC721Logic);
            CloneERC721(cloneContract).initialize(manager, _nftContract);
            nftContracts.add(address(_nftContract));
            cloneAddressByContractAddress[
                address(_nftContract)
            ] = cloneContract;
        }
        /// Transfer the NFTs to the SafeERC721 contract and mint the clone NFTs
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            /// Transfer the NFT from the owner to the SafeERC721 contract
            _nftContract.safeTransferFrom(
                msg.sender,
                address(this),
                _tokenIds[i]
            );
            /// Mint the clone NFT
            CloneERC721(cloneAddressByContractAddress[address(_nftContract)])
                .mint(msg.sender, _tokenIds[i]);
            /// Update the staking informations of the NFT
            stakeInfoByContractAddress[address(_nftContract)][
                _tokenIds[i]
            ] = StakeInfo({
                isStaked: true,
                owner: msg.sender,
                startLocking: block.timestamp,
                lockDuration: _lockDuration
            });
            /// Update the set of NFT IDs staked
            nftIDsStakedByContractAddress[address(_nftContract)].add(
                _tokenIds[i]
            );
        }
    }

    function unstakeERC721Assets(
        IERC721 _nftContract,
        uint256[] calldata _tokenIds
    ) external {
        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            /// Check if the sender is the owner of the NFT
            if (
                stakeInfoByContractAddress[address(_nftContract)][_tokenIds[i]]
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
            /// Burn the clone NFT
            CloneERC721(cloneAddressByContractAddress[address(_nftContract)])
                .burn(_tokenIds[i]);
            /// Update the staking informations of the NFT
            stakeInfoByContractAddress[address(_nftContract)][
                _tokenIds[i]
            ] = StakeInfo({
                isStaked: false,
                owner: address(0),
                startLocking: 0,
                lockDuration: 0
            });
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