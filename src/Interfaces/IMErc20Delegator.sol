pragma solidity 0.8.19;

import "./IInterestRateModel.sol";

/// @title interface for MErc20Delegator
interface IMErc20Delegator {
    /// @notice initialize the delegate contract, should always revert when called on the logic contract
    function initialize(
        address underlying_,
        address comptroller_,
        address interestRateModel_,
        uint initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external;

    /// @notice provide assets for the market and receive mTokens in exchange
    function mint(uint256) external returns (uint256);

    /// @notice borrow from the protocol
    function borrow(uint256) external returns (uint256);

    /// @notice returns the current amount of bad debt
    function badDebt() external view returns (uint256);

    /// @notice sweep all tokens to a given address
    function sweepAll(address) external;

    /// @notice accrue interest
    function accrueInterest() external returns (uint256);

    /// @notice block number that interest was last accrued at
    function accrualBlockTimestamp() external returns (uint256);

    function exchangeRateCurrent() external returns (uint);

    /// @notice get cash amount
    function getCash() external returns (uint256);

    /// @notice balance of a given address
    function balanceOf(address) external returns (uint256);

    /// @notice set implementation
    function _setImplementation(address, bool, bytes memory) external;

    /// @notice exchange rate
    function exchangeRateStored() external view returns (uint256);

    /// @notice total reserves
    function totalReserves() external returns (uint256);

    /// @notice reserve factor mantissa
    function reserveFactorMantissa() external returns (uint256);

    /// @notice total borrows
    function totalBorrows() external returns (uint256);

    /// @notice borrow index
    function borrowIndex() external returns (uint256);

    /// @notice borrow balanace stored
    function borrowBalanceStored(address) external view returns (uint);

    /// @notice total supply
    function totalSupply() external returns (uint256);

    /// @notice implementation
    function implementation() external returns (address);

    /// @notice underlying asset
    function underlying() external returns (address);

    /// @notice fix user
    function fixUser(address, address) external;

    /// @notice account tokens
    function getAccountTokens(address) external view returns (uint256);

    /// @notice redeem underlying token
    function redeem(uint256) external returns (uint256);

    /// @notice repay what was borrowed
    function repayBorrow(uint256) external returns (uint256);

    /// @notice repay what was borrowed on behalf of another user
    function repayBorrowBehalf(address, uint256) external returns (uint256);

    /// @notice liquidate a borrow
    function liquidateBorrow(
        address,
        uint256,
        address
    ) external returns (uint256);

    /// @notice IR model
    function interestRateModel() external returns (IInterestRateModel);
}
