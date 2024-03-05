pragma solidity 0.8.19;

/// @title interface for MErc20DelegateFixer
interface IMErc20DelegateFixer {
    /// @notice bad debt counter
    function badDebt() external view returns (uint256);

    /// @notice fix user
    function fixUser(address, address) external;

    /// @notice repay bad debt with underlying asset
    function repayBadDebtWithCash(uint256) external;

    /// @notice repay bad debt with reserves
    function repayBadDebtWithReserves() external;
}
