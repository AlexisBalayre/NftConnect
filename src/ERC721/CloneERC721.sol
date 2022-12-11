// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract CloneERC721 is ERC721Upgradeable {
    address public admin;
    address public safeContract;
    address public leaseContract;
    IERC721Metadata public nftContract;

    error IsNotAdmin(address caller);
    error WrongReceiver(address receiver);

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

    function tokenURI(uint256 tokenId) 
        public 
        view 
        override (ERC721Upgradeable)
        returns (string memory _uri) 
    {
        _uri = nftContract.tokenURI(tokenId);
    }

    function mintClone(uint256 tokenId) external onlyAdmin {
        _safeMint(leaseContract, tokenId);
    }

    function burnClone(uint256 tokenId) external onlyAdmin {
        _burn(tokenId);
    }

    function sendClone(address to, uint256 tokenId) external onlyAdmin {
        _transfer(leaseContract, to, tokenId);
    }

    function recoverClone(address from, uint256 tokenId) external onlyAdmin {
        _transfer(from, leaseContract, tokenId);
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId, 
        uint256 _batchSize
    ) internal override (ERC721Upgradeable) {
        if (_from != leaseContract && _to != leaseContract) {
            revert WrongReceiver(_to);
        }
        super._beforeTokenTransfer(_from, _to, _tokenId, _batchSize);
    }

    modifier onlyAdmin {
        if (msg.sender != admin && msg.sender != safeContract) revert IsNotAdmin(msg.sender);
        _;
    }
}
    
    

