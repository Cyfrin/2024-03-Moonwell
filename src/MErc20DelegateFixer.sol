pragma solidity 0.5.17;

import "./MErc20Delegate.sol";
import "./SafeMath.sol";

//// @title MErc20DelegateMadFixer contract
contract MErc20DelegateFixer is MErc20Delegate {
    /// @notice bad debt counter
    uint256 public badDebt;

    /// @notice user fixed event (user, liquidator, amount)
    event UserFixed(address, address, uint256);

    /// @notice bad debt repayed event (amount)
    event BadDebtRepayed(uint256);

    /// @notice bad debt repayed with reserves
    event BadDebtRepayedWithReserves(
        uint256 badDebt,
        uint256 previousBadDebt,
        uint256 reserves,
        uint256 previousReserves
    );

    /// @notice repay bad debt with cash, can only reduce the bad debt
    /// @param amount the amount of bad debt to repay
    /// invariant, calling this function can only reduce the bad debt
    /// it cannot increase it, which is what would happen on an underflow
    /// this function cannot change the share price of the mToken
    function repayBadDebtWithCash(uint256 amount) external nonReentrant {
        /// Checks and Effects
        badDebt = SafeMath.sub(badDebt, amount, "amount exceeds bad debt");

        EIP20Interface token = EIP20Interface(underlying);

        /// Interactions
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "transfer in failed"
        );

        emit BadDebtRepayed(amount);
    }

    /// @notice function can only decrease bad debt and reserves
    /// if this function is called, both bad debt and reserves will be decreased
    /// calling this function cannot change the share price
    /// both bad debt and reserves will decrement by the same amount
    function repayBadDebtWithReserves() external nonReentrant {
        uint256 currentReserves = totalReserves;
        uint256 currentBadDebt = badDebt;

        require(currentReserves != 0, "reserves are zero");
        require(currentBadDebt != 0, "bad debt is zero");

        /// no reverts possible past this point

        /// take the lesser of the two, subtract it from both numbers
        uint256 subtractAmount = currentBadDebt < currentReserves
            ? currentBadDebt
            : currentReserves;

        /// bad debt -= subtract amount
        badDebt = SafeMath.sub(currentBadDebt, subtractAmount);

        /// current reserves -= subtract amount
        totalReserves = SafeMath.sub(currentReserves, subtractAmount);

        emit BadDebtRepayedWithReserves(
            badDebt,
            currentBadDebt,
            totalReserves,
            currentReserves
        );
    }

    /// @notice fix a user
    /// @param liquidator the account to transfer the tokens to
    /// @param user the account with bad debt
    /// invariant, this can only reduce or keep user and total debt the same
    /// liquidator will never be the same as user, only governance can call this function
    /// assumes governance is non malicious, and that all users liquidated have active borrows
    function fixUser(address liquidator, address user) external {
        /// @dev check user is admin
        require(msg.sender == admin, "only the admin may call fixUser");

        /// ensure nothing strange can happen with incorrect liquidator
        require(liquidator != user, "liquidator cannot be user");

        require(accrueInterest() == 0, "accrue interest failed");

        /// @dev fetch user's current borrow balance, first updating interest index
        uint256 principal = borrowBalanceStored(user);

        require(principal != 0, "cannot liquidate user without borrows");

        /// user effects

        /// @dev zero balance
        accountBorrows[user].principal = 0;
        accountBorrows[user].interestIndex = borrowIndex;

        /// @dev current amount for a user that we'll transfer to the liquidator
        uint256 liquidated = accountTokens[user];

        /// can only seize collateral assets if they exist
        if (liquidated != 0) {
            /// if assets were liquidated, give them to the liquidator
            accountTokens[liquidator] = SafeMath.add(
                accountTokens[liquidator],
                liquidated
            );

            /// zero out the user's tokens
            delete accountTokens[user];
        }

        /// global effects

        /// @dev increment the bad debt counter
        badDebt = SafeMath.add(badDebt, principal);

        /// @dev subtract the previous balance from the totalBorrows balance
        totalBorrows = SafeMath.sub(totalBorrows, principal);

        emit UserFixed(user, liquidator, liquidated);
    }

    /// @notice get cash for the market, including bad debt in this calculation
    /// bad debt must be included in order to maintain the market share price
    function getCashPrior() internal view returns (uint256) {
        /// safe math unused intentionally, should never overflow as the sum
        /// should never be greater than UINT_MAX
        return EIP20Interface(underlying).balanceOf(address(this)) + badDebt;
    }
}
