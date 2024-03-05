pragma solidity 0.8.19;

/// @title IR interface
interface IInterestRateModel {
    /// @notice the current borrow interest rate per timestmp
    function getBorrowRate(uint, uint, uint) external view returns (uint);

    /// @notice the current supply interest rate per timestmp
    function getSupplyRate(uint, uint, uint, uint) external view returns (uint);
}
