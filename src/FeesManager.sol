// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract FeesManager {
    address public admin;

    mapping (uint256 => int96) private feesFlowRateByIndex;

    error IsNotAdmin(address caller);

    constructor(
        address _admin
    ) {
        admin = _admin;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert IsNotAdmin(msg.sender);
        }
        _;
    }

    function setFees(
        uint256 _index,
        int96 _feesFlowRate
    ) external onlyAdmin {
        feesFlowRateByIndex[_index] = _feesFlowRate;
    }

    function getFees(
        uint256 _index
    ) external view returns (int96 feesFlowRate) {
        feesFlowRate = feesFlowRateByIndex[_index];
    }
}