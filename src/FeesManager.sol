// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";

contract FeesManager {
    address public admin;

    /// @notice Address of the super token address
    ISuperToken public paymentToken;

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

    /// @notice Downgrades SuperToken to ERC20
    /// @param _amount Number of tokens to be downgraded (in 18 decimals)
    /// @dev This function can only be called by the owner or the dev Wallet
    function unwrapTokens(uint256 _amount) external {
        paymentToken.downgrade(_amount);
    }

    /// @notice Returns balance of contract
    /// @return _balance Balance of contract
    function returnBalance() external view returns (uint256) {
        return paymentToken.balanceOf(address(this));
    }
}