pragma solidity 0.8.19;

/// @title WELL token interface
interface IWell {
    /// @notice balance of a given address
    function balanceOf(address) external returns (uint256);
}
