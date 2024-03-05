pragma solidity 0.5.17;

/// @notice mock comptroller for formal verification.
/// Every function is a no-op to prevent havoc and
/// enable the prover to reason about the state properly.
contract MockComptroller {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptroller = true;

    /// @notice The amount of gas to use when making a native asset transfer.
    uint16 public gasAmount;

    constructor() public {}

    /*** Assets You Are In ***/

    function enterMarkets(
        address[] calldata
    ) external pure returns (uint[] memory) {
        return new uint[](0);
    }

    function exitMarket(address) external pure returns (uint) {
        return 1 - 1;
    }

    /*** Policy Hooks ***/

    function mintAllowed(address, address, uint) external pure returns (uint) {
        return 0;
    }

    function mintVerify(address, address, uint, uint) external pure {}

    function redeemAllowed(
        address,
        address,
        uint
    ) external pure returns (uint) {
        return 0;
    }

    function redeemVerify(address, address, uint, uint) external pure {}

    function borrowAllowed(
        address,
        address,
        uint
    ) external pure returns (uint) {
        return 0;
    }

    function borrowVerify(address, address, uint) external pure {}

    function repayBorrowAllowed(
        address,
        address,
        address,
        uint
    ) external pure returns (uint) {
        return 0;
    }

    function repayBorrowVerify(
        address,
        address,
        address,
        uint,
        uint
    ) external pure {}

    function liquidateBorrowAllowed(
        address,
        address,
        address,
        address,
        uint
    ) external pure returns (uint) {
        return 0;
    }

    function liquidateBorrowVerify(
        address,
        address,
        address,
        address,
        uint,
        uint
    ) external pure {}

    function seizeAllowed(
        address,
        address,
        address,
        address,
        uint
    ) external pure returns (uint) {
        return 0;
    }

    function seizeVerify(address, address, address, address, uint) external {}

    function transferAllowed(
        address,
        address,
        address,
        uint
    ) external pure returns (uint) {
        return 0;
    }

    function transferVerify(address, address, address, uint) external pure {}

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateCalculateSeizeTokens(
        address,
        address,
        uint
    ) external pure returns (uint, uint) {
        return (0, 0);
    }
}
