using MockERC20 as token;
using MockMErc20DelegateFixer as fixer;

methods {
    function getCash() external returns (uint256) envfree;
    function badDebt() external returns (uint256) envfree;
    function fixUser(address liquidator, address user) external;
    function borrowIndex() external returns (uint256) envfree;
    function totalBorrows() external returns (uint256) envfree;
    function totalReserves() external returns (uint256) envfree;
    function token.balanceOf(address) external returns (uint256) envfree;
    function balanceOf(address) external returns (uint256) envfree;
    function repayBadDebtWithCash(uint256) external;
    function accrueInterest() external returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
    function borrowBalanceCurrent(address account) external returns (uint256);
    function repayBadDebtWithReserves() external envfree;
    function getUserBorrowSnapshot(address user) external returns (uint256, uint256) envfree;
    function getUserBorrowInterestIndex(address user) external returns (uint256) envfree;
    function getInitialExchangeRateMantissa() external returns (uint256) envfree;

    /// mock out all calls to accrue interest to prevent needing to make calls to or mock out jrm
    function fixer.accrueInterest() internal returns uint256 => noError();
    function fixer.accrueInterest() external returns uint256 => noError();
}

function noError() returns uint256 {
    return 0;
}

function one() returns uint256 {
    return 1000000000000000000;
}

function uintMax() returns uint256 {
    return 2 ^ 256 - 1;
}

rule fixUserIncreasesBadDebt(env e) {
    address user;
    address liquidator;
    uint256 principle;
    uint256 interestIndex;

    principle, interestIndex = getUserBorrowSnapshot(user);

    uint256 badDebt = badDebt();

    fixUser(e, liquidator, user);

    uint256 badDebtAfter = badDebt();

    assert badDebtAfter > badDebt, "bad debt not increased from fixing a user";
}

rule fixingUserZeroUserBalance(env e) {
    address user;
    address liquidator;

    uint256 startingUserBalance = balanceOf(user);
    uint256 startingLiquidatorBalance = balanceOf(liquidator);

    fixUser(e, liquidator, user);

    assert balanceOf(user) == 0, "user balance should be zero after fix";
    assert startingLiquidatorBalance + startingUserBalance == to_mathint(balanceOf(liquidator)),
     "liquidator balance incorrect";
}

rule fixingUserDoesNotChangeSharePrice(env e) {
    address user;
    address liquidator;

    uint256 startingSharePrice = exchangeRateCurrent(e);

    fixUser(e, liquidator, user);

    assert exchangeRateCurrent(e) == startingSharePrice, "share price should not change fixing user";
}

rule repayBadDebtDecreasesBadDebt(env e, uint256 repayAmount) {
    require e.msg.sender != fixer;

    uint256 badDebt = badDebt();
    uint256 userBalance = token.balanceOf(e.msg.sender);
    uint256 mTokenBalance = token.balanceOf(fixer);

    repayBadDebtWithCash(e, repayAmount);

    assert to_mathint(token.balanceOf(e.msg.sender)) == userBalance - repayAmount,
     "underlying balance of user did not decrease";
    assert to_mathint(token.balanceOf(fixer)) == mTokenBalance + repayAmount,
     "underlying balance of fixer did not increase";
    assert badDebt - repayAmount == to_mathint(badDebt()),
     "bad debt not decreased by repay amt";
}

rule badDebtRules(method f, env e, calldataarg args)
filtered {
    f -> 
    f.selector == sig:fixUser(address,address).selector ||
    f.selector == sig:repayBadDebtWithCash(uint256).selector ||
    f.selector == sig:repayBadDebtWithReserves().selector
} {
    require e.msg.sender != fixer;

    uint256 startingSharePrice = exchangeRateCurrent(e);
    uint256 startingBadDebt = badDebt();
    uint256 startingCash = token.balanceOf(fixer);

    f(e, args);

    uint256 endingBadDebt = badDebt();

    assert startingCash + startingBadDebt <= to_mathint(uintMax()) =>
     exchangeRateCurrent(e) == startingSharePrice,
     "share price should not change repaying bad debt";

    assert (endingBadDebt > startingBadDebt) =>
     (f.selector == sig:fixUser(address,address).selector),
      "bad debt should only increase when fixing users";

    assert (startingBadDebt > endingBadDebt) => 
     (f.selector == sig:repayBadDebtWithCash(uint256).selector ||
     f.selector == sig:repayBadDebtWithReserves().selector),
     "bad debt should only increase when fixing users";
}

rule badDebtRulesCash(env e, uint256 amount) {
    require e.msg.sender != fixer;

    uint256 startingBadDebt = badDebt();
    uint256 startingCash = token.balanceOf(fixer);

    /// bound input as to not overflow (safe math is not used)
    require startingCash + startingBadDebt <= to_mathint(uintMax());

    repayBadDebtWithCash(e, amount);

    uint256 endingBadDebt = badDebt();

    /// starting cash + starting bad debt == ending bad debt + ending cash == getCash()

    assert startingCash + startingBadDebt == endingBadDebt + to_mathint(token.balanceOf(fixer)),
     "cash not the same";

    assert startingCash + startingBadDebt == to_mathint(getCash()),
     "bad debt should not increase when repaying with cash";
}

rule allBadDebtRulesCash(method f, env e, calldataarg args)
filtered {
    f -> 
    f.selector == sig:repayBadDebtWithCash(uint256).selector ||
    f.selector == sig:repayBadDebtWithReserves().selector
} {
    require e.msg.sender != fixer;

    uint256 startingBadDebt = badDebt();
    uint256 startingCash = token.balanceOf(fixer);

    /// bound input as to not overflow (safe math is not used)
    require startingCash + startingBadDebt <= to_mathint(uintMax());

    f(e, args);

    uint256 endingBadDebt = badDebt();

    /// bad debt + cash == getCash()

    assert to_mathint(getCash()) == endingBadDebt + to_mathint(token.balanceOf(fixer)),
     "cash not correct";
}

rule repayBadDebtWithReservesSuccess(env e) {
    uint256 startingReserves = totalReserves();
    uint256 startingBadDebt = badDebt();

    repayBadDebtWithReserves();

    uint256 endingReserves = totalReserves();
    uint256 endingBadDebt = badDebt();

    assert (startingReserves >= startingBadDebt) =>
     (endingBadDebt == 0),
      "bad debt not fully paid off";

    assert (startingReserves < startingBadDebt) =>
     (to_mathint(endingBadDebt) == startingBadDebt - startingReserves),
      "bad debt not paid off by reserve amount";
}

rule repayBadDebtWithReservesDoesNotChangeSharePrice(env e) {
    require e.msg.sender != fixer;

    uint256 startingSharePrice = exchangeRateCurrent(e);

    repayBadDebtWithReserves();

    uint256 endingSharePrice = exchangeRateCurrent(e);

    assert endingSharePrice == startingSharePrice, "share price should remain unchanged";
}

rule badDebtSymmetry(env e, method f, calldataarg args) 
filtered {
        f -> 
    f.selector == sig:fixUser(address,address).selector ||
    f.selector == sig:repayBadDebtWithCash(uint256).selector ||
    f.selector == sig:repayBadDebtWithReserves().selector
}
{
    require e.msg.sender != fixer;

    uint256 totalBorrowsBefore = totalBorrows();
    uint256 totalBadDebtBefore = badDebt();
    uint256 totalReservesBefore = totalReserves();

    f(e, args);

    uint256 totalBorrowsAfter = totalBorrows();
    uint256 totalBadDebtAfter = badDebt();
    uint256 totalReservesAfter = totalReserves();

    assert totalBorrowsAfter != totalBorrowsBefore =>
     totalBorrowsBefore - totalBorrowsAfter == totalBadDebtAfter - totalBadDebtBefore,
     "borrows bad debt incorrect";

    assert totalReservesBefore != totalReservesAfter =>
     totalReservesBefore - totalReservesAfter == totalBadDebtBefore - totalBadDebtAfter,
     "reserves bad debt incorrect";
}
