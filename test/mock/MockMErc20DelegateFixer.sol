pragma solidity 0.5.17;

import {MErc20DelegateFixer} from "@protocol/MErc20DelegateFixer.sol";

contract MockMErc20DelegateFixer is MErc20DelegateFixer {
    /// function for formal verification
    function getUserBorrowSnapshot(
        address user
    ) external view returns (uint256 principal, uint256 interestIndex) {
        principal = accountBorrows[user].principal;
        interestIndex = accountBorrows[user].interestIndex;
    }

    function getUserBorrowInterestIndex(
        address user
    ) external view returns (uint256 interestIndex) {
        interestIndex = accountBorrows[user].interestIndex;
    }

    function getInitialExchangeRateMantissa() external view returns (uint256) {
        return initialExchangeRateMantissa;
    }
}
