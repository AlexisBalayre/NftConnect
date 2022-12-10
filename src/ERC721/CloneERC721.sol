// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract CloneERC721 is ERC721Upgradeable {
    address public manager;
    address public safeContract;
    IERC721Metadata public nftContract;

    error IsNotManager(address caller);

    function initialize(
		address _manager, 
        IERC721Metadata _nftContract
	) public initializer {
        __ERC721_init(
            _nftContract.name(), 
            _nftContract.symbol()
        );
        manager =_manager;
        nftContract = _nftContract;
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

    function mint(address to, uint256 tokenId) external onlyManager {
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) external onlyManager {
        _burn(tokenId);
    }

    modifier onlyManager {
        if (msg.sender != manager && msg.sender != safeContract) revert IsNotManager(msg.sender);
        _;
    }
}
    
    

