// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ERC721/CloneERC721.sol";
import "./Mock/NftERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


/* contract CloneERC721Test is Test, IERC721Receiver {
    NftERC721 nftContract;
    CloneERC721 public clonedNftContract;

    function setUp() public {
        nftContract = new NftERC721();
        clonedNftContract = new CloneERC721();
        clonedNftContract.initialize(address(this), nftContract);
    }

    function testCloneERC721() public {
        nftContract.safeMint(address(this), 1, "https://example.com");
        clonedNftContract.mint(address(this), 1);
        assertEq(clonedNftContract.ownerOf(1), address(this));
        assertEq(clonedNftContract.tokenURI(1), "https://example.com");
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) 
        external pure
        override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
 */