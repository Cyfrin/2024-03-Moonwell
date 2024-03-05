pragma solidity 0.8.19;

/// @title interface for MErc20Delegator
interface IComptroller {
    /// @notice reward market state
    struct RewardMarketState {
        uint224 index;
        uint32 timestamp;
    }

    /// @notice check membership
    function checkMembership(address, address) external view returns (bool);

    /// @notice add assets to be included in account liquidity calculation
    function enterMarkets(address[] memory) external returns (uint256[] memory);

    /// @notice removes an asset from account liquidity calculation
    function exitMarket(address) external returns (uint256);

    /// @notice set state of a market
    function _setBorrowPaused(address, bool) external returns (bool);

    /// @notice borrow caps
    function borrowCaps(address) external returns (uint256);

    /// @notice is the borrow guardian paused for a market
    function borrowGuardianPaused(address) external returns (bool);

    /// @notice account liquidity
    function getAccountLiquidity(
        address
    ) external view returns (uint256, uint256, uint256);

    /// @notice supply reward speeds
    function supplyRewardSpeeds(uint8, address) external returns (uint256);

    /// @notice borrow reward speeds
    function borrowRewardSpeeds(uint8, address) external returns (uint256);

    /// @notice claim reward
    function claimReward(uint8, address payable) external;

    /// @notice accrued rewards
    function rewardAccrued(uint8, address) external returns (uint256);

    /// @notice reward supply state
    function rewardSupplyState(
        uint8,
        address
    ) external returns (RewardMarketState memory);

    /// @notice reward borrow state
    function rewardBorrowState(
        uint8,
        address
    ) external returns (RewardMarketState memory);

    /// @notice reward supplier index
    function rewardSupplierIndex(
        uint8,
        address,
        address
    ) external returns (uint256);

    /// @notice reward borrower index
    function rewardBorrowerIndex(
        uint8,
        address,
        address
    ) external returns (uint256);

    function _setMarketBorrowCaps(address[] memory, uint256[] memory) external;

    /// @notice returns the current admin address
    function admin() external view returns (address);

    function getHypotheticalAccountLiquidity(
        address account,
        address mTokenModify,
        uint redeemTokens,
        uint borrowAmount
    ) external view returns (uint, uint, uint);
}
