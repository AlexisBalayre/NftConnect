// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract CloneERC721 is ERC721Upgradeable {
    address public admin;
    address public safeContract;
    address public leaseContract;
    IERC721Metadata public nftContract;

    error UnauthorizedAccess(address caller);

    function initialize(
		address _admin, 
        address _leaseContract,
        IERC721Metadata _nftContract
	) public initializer {
        __ERC721_init(
            _nftContract.name(), 
            _nftContract.symbol()
        );
        admin =_admin;
        nftContract = _nftContract;
        leaseContract = _leaseContract;
        safeContract = msg.sender;
	}

    /// @notice Returns the URI of a NFT
    /// @param _tokenId ID of the NFT
    /// @return _uri URI of the NFT
    function tokenURI(uint256 _tokenId) 
        public 
        view 
        override (ERC721Upgradeable)
        returns (string memory _uri) 
    {
        _uri = nftContract.tokenURI(_tokenId);
    }

    /// @dev Only the safe contract can call this function
    /// @notice Mints a cloned nft
    /// @param _tokenId ID of the NFT
    function mintClone(uint256 _tokenId) external virtual {
        if (msg.sender != safeContract) revert UnauthorizedAccess(msg.sender);
        _safeMint(leaseContract, _tokenId);
    }

    /// @dev Only the safe contract can call this function
    /// @notice Burns a cloned nft
    /// @param _tokenId ID of the NFT
    function burnClone(uint256 _tokenId) external virtual {
        if (msg.sender != safeContract) revert UnauthorizedAccess(msg.sender);
        _burn(_tokenId);
    }

    /// @dev Only the safe contract can call this function
    /// @notice Transfers a cloned nft
    /// @param _to Address of the recipient
    /// @param _tokenId ID of the NFT
    function sendClone(address _to, uint256 _tokenId) external virtual {
        if (msg.sender != safeContract) revert UnauthorizedAccess(msg.sender);
        _transfer(leaseContract, _to, _tokenId);
    }

    /// @dev Only the safe contract or the admin contract can call this function
    /// @notice Recovers a cloned nft 
    /// @param _tokenId ID of the NFT
    function recoverClone(uint256 _tokenId) external virtual {
        if (msg.sender != admin && msg.sender != safeContract) revert UnauthorizedAccess(msg.sender);
        address from = _ownerOf(_tokenId);
        _transfer(from, leaseContract, _tokenId);
    }
}
    
    

