pragma solidity 0.5.17;

import "./MErc20Delegate.sol";

/// @title MErc20DelegateMadFixer contract
contract MErc20DelegateMadFixer is MErc20Delegate {
    /// @notice sweep underlying tokens
    /// @param sweeper address of the sweeper
    function sweepAll(address sweeper) external {
        /// @dev checks
        require(msg.sender == admin, "only admin may sweep all");
        EIP20Interface token = EIP20Interface(underlying);
        /// @dev take it, take it all
        bool success = token.transfer(sweeper, token.balanceOf(address(this)));
        require(success, "token sweep failed");
    }
}
