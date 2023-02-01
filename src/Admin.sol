// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ERC721/CloneERC721.sol";

contract ManagerERC721 {
    function recoverNFT(
        address _cloneContract,
        uint256 _tokenId
    ) internal {
        CloneERC721(_cloneContract).recoverClone(_tokenId);
    }
}