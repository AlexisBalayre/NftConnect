// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./CloneERC721.sol";

contract ManagerERC721 {
    function mint(
        address _cloneContract,
        address _to,
        uint256 _tokenId
    ) internal {
        CloneERC721(_cloneContract).mint(_to, _tokenId);
    }

    function burn(
        address _cloneContract,
        uint256 _tokenId
    ) internal {
        CloneERC721(_cloneContract).burn(_tokenId);
    }
}