using MockERC20 as token;
using MockMErc20DelegateFixer as fixer;
using MockComptroller as comptroller;
using JumpRateModel as jrm;

methods {
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

    function fixer.sweepToken(address) external => CONSTANT;
    function fixer.liquidateBorrow(address borrower, uint256 repayAmount, address) external returns (uint256) => CONSTANT;
    function fixer.seize(address liquidator, address borrower, uint256 seizeTokens) external returns (uint) => CONSTANT;

    function accrueInterest() external returns uint256 => CONSTANT;

    /// summarize these calls to prevent prover havoc
    function _.isComptroller() external => DISPATCHER(true);
    function _.isInterestRateModel() external => DISPATCHER(true);
    function _.admin() external => DISPATCHER(true);
    function _.borrowIndex() external => DISPATCHER(true);
    function _._acceptImplementation() external => CONSTANT;
    function comptroller._ external => NONDET;
    function jrm._ external => NONDET;
}

ghost uint256 borrowIndex {
    init_state axiom borrowIndex == 0;
}

ghost uint256 totalBorrows {
    init_state axiom totalBorrows == 0;
}

ghost uint256 initialExchangeRateMantissa {
    init_state axiom initialExchangeRateMantissa == 0;
}

hook Sstore borrowIndex uint256 newBorrowIndex (uint256 oldBorrowIndex) STORAGE {
    borrowIndex = newBorrowIndex;
}

hook Sstore totalBorrows uint256 newTotalBorrows (uint256 oldTotalBorrows) STORAGE {
    totalBorrows = newTotalBorrows;
}

hook Sstore initialExchangeRateMantissa uint256 newInitialExchangeRateMantissa (uint256 oldInitialExchangeRateMantissa) STORAGE {
    initialExchangeRateMantissa = newInitialExchangeRateMantissa;
}

function one() returns uint256 {
    return 1000000000000000000;
}

function uintMax() returns uint256 {
    return 2 ^ 256 - 1;
}

/// market initialization check

invariant ghostInitialExchangeRateMantissaMirrorsStorage()
    initialExchangeRateMantissa == getInitialExchangeRateMantissa();

invariant ghostBorrowIndexMirrorsStorage()
    borrowIndex == borrowIndex();

invariant ghostTotalBorrowsMirrorsStorage()
    totalBorrows == totalBorrows();

invariant initialBorrowIndexGteOne()
    borrowIndex() != 0 => borrowIndex() >= one();

invariant exchangeRateGteOne(env e)
    borrowIndex() >= one() => exchangeRateCurrent(e) >= one() {
        preserved {
            requireInvariant initialBorrowIndexGteOne();
        }
    }

invariant userBorrowIndexLteExchangeRateCurrent(env e, address user)
    getUserBorrowInterestIndex(user) != 0 =>
     (getUserBorrowInterestIndex(user) <= exchangeRateCurrent(e) && getUserBorrowInterestIndex(user) >= one()) {
        preserved {
            requireInvariant ghostBorrowIndexMirrorsStorage();
        }
     }

rule fixUserIncreasesBadDebt(env e) {
    address user;
    address liquidator;
    uint256 principle;
    uint256 interestIndex;

    principle, interestIndex = getUserBorrowSnapshot(user);

    uint256 badDebt = badDebt();
    uint256 liquidatorBalance = balanceOf(liquidator);
    uint256 userBalance = balanceOf(user);
    uint256 borrowBalance = borrowBalanceCurrent(e, user);

    fixUser(e, liquidator, user);

    uint256 badDebtAfter = badDebt();

    assert badDebtAfter >= badDebt, "bad debt decreased from fixing a user";
    assert balanceOf(user) == 0, "user balance not zero";
    assert (liquidatorBalance + userBalance == to_mathint(balanceOf(liquidator))), "liquidator balance not increased by user balance";
    assert borrowBalanceCurrent(e, user) == 0, "user borrow balance not zero";
    assert interestIndex >= one() => (badDebt + borrowBalance == to_mathint(badDebtAfter)), "bad debt not increased by user borrow amt";
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
    uint256 startingSharePrice = exchangeRateCurrent(e);

    repayBadDebtWithCash(e, repayAmount);

    uint256 badDebtAfter = badDebt();

    assert repayAmount != 0 => badDebtAfter < badDebt, "bad debt did not decrease from repaying";
    assert badDebtAfter <= badDebt, "bad debt increased from repaying";
    assert to_mathint(token.balanceOf(fixer)) == mTokenBalance + repayAmount, "underlying balance did not increase";
    assert badDebt - repayAmount == to_mathint(badDebt()), "bad debt not decreased by repay amt";
    assert exchangeRateCurrent(e) == startingSharePrice, "share price should not change repaying bad debt";
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

    assert (startingBadDebt >= endingBadDebt) => 
     (f.selector == sig:repayBadDebtWithCash(uint256).selector ||
     f.selector == sig:repayBadDebtWithReserves().selector),
     "bad debt should only increase when fixing users";
}

rule cannotChangeBadDebt(method f, env e, calldataarg args)
filtered {
    f -> 
    !f.isView &&
    f.selector != sig:fixUser(address,address).selector &&
    f.selector != sig:repayBadDebtWithCash(uint256).selector &&
    f.selector != sig:repayBadDebtWithReserves().selector
} {
    require e.msg.sender != fixer;

    uint256 startingBadDebt = badDebt();

    f(e, args);

    uint256 endingBadDebt = badDebt();

    assert endingBadDebt == startingBadDebt,
      "bad debt should not change";
}

rule repayBadDebtWithReserves(env e) {
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
