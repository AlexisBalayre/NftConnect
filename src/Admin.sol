// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ERC721/CloneERC721.sol";

contract ManagerERC721 {
    function mint(
        address _cloneContract,
        uint256 _tokenId
    ) internal {
        CloneERC721(_cloneContract).mintClone(_tokenId);
    }

    function burn(
        address _cloneContract,
        uint256 _tokenId
    ) internal {
        CloneERC721(_cloneContract).burnClone(_tokenId);
    }
}