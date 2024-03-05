pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";
import {IERC20} from "@forge-proposal-simulator/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@forge-proposal-simulator/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {IWell} from "@protocol/Interfaces/IWell.sol";
import {MockxcDOT} from "@tests/mock/MockxcDOT.sol";
import {MockxcUSDC} from "@tests/mock/MockxcUSDC.sol";
import {MockxcUSDT} from "@tests/mock/MockxcUSDT.sol";
import {IComptroller} from "@protocol/Interfaces/IComptroller.sol";
import {IMErc20Delegator} from "@protocol/Interfaces/IMErc20Delegator.sol";
import {PostProposalCheck} from "@tests/integration/PostProposalCheck.sol";
import {IInterestRateModel} from "@protocol/Interfaces/IInterestRateModel.sol";
import {IMErc20DelegateFixer} from "@protocol/Interfaces/IMErc20DelegateFixer.sol";
import {IMErc20DelegateMadFixer} from "@protocol/Interfaces/IMErc20DelegateMadFixer.sol";

/// @title MIP-M17 integration tests
/// @dev to run:
/// `forge test \
///     --match-contract MIPM17IntegrationTest \
///     --fork-url {rpc-url}`
contract MIPM17IntegrationTest is PostProposalCheck {
    event BadDebtRepayed(uint256);

    /// @notice bad debt repayed with reserves
    event BadDebtRepayedWithReserves(
        uint256 badDebt,
        uint256 previousBadDebt,
        uint256 reserves,
        uint256 previousReserves
    );

    /// @dev contracts
    IMErc20Delegator mxcDotDelegator;
    IMErc20Delegator fraxDelegator;
    IMErc20Delegator nomadUSDCDelegator;
    IMErc20Delegator nomadETHDelegator;
    IMErc20Delegator nomadBTCDelegator;
    IERC20 xcDotToken;
    IERC20 fraxToken;
    IComptroller comptroller;

    /// @dev values prior to calling parent setup
    uint256 public fraxTotalBorrows;
    uint256 public fraxTotalReserves;
    uint256 public fraxTotalSupply;
    uint256 public fraxBorrowIndex;
    uint256 public fraxSupplyRewardSpeeds;
    uint256 public fraxAccrualBlockTimestampPrior;
    uint256 public fraxBorrowRateMantissa;

    uint256 public xcDOTTotalBorrows;
    uint256 public xcDOTTotalReserves;
    uint256 public xcDOTTotalSupply;
    uint256 public xcDOTBorrowIndex;
    uint256 public xcDOTSupplyRewardSpeeds;
    uint256 public xcDOTAccrualBlockTimestampPrior;
    uint256 public xcDOTBorrowRateMantissa;

    uint256 public nomadUSDCBalance;
    uint256 public nomadETHBalance;
    uint256 public nomadBTCBalance;
    uint256 public multisigUSDCBalance;
    uint256 public multisigETHBalance;
    uint256 public multisigBTCBalance;

    /// @notice current balance of the mxcDOT token in the mxcDOT market
    /// on 2/12/24 to allow setting the balance in the mock contract
    uint256 public constant xcDotMtokenBalance = 3414954090440141;

    /// @dev addresses
    address multisig;

    function setUp() public override {
        /// @dev necessary to obtain borrows/reserves/ex.rate/supply before calling the parent setup
        Addresses _addresses = new Addresses("./addresses/addresses.json");

        {
            MockxcUSDT mockUSDT = new MockxcUSDT();
            address mockUSDTAddress = address(mockUSDT);
            uint256 codeSize;
            assembly {
                codeSize := extcodesize(mockUSDTAddress)
            }

            bytes memory runtimeBytecode = new bytes(codeSize);

            assembly {
                extcodecopy(
                    mockUSDTAddress,
                    add(runtimeBytecode, 0x20),
                    0,
                    codeSize
                )
            }

            vm.etch(_addresses.getAddress("xcUSDT"), runtimeBytecode);
        }

        {
            MockxcUSDC mockUSDC = new MockxcUSDC();
            address mockUSDCAddress = address(mockUSDC);
            uint256 codeSize;
            assembly {
                codeSize := extcodesize(mockUSDCAddress)
            }

            bytes memory runtimeBytecode = new bytes(codeSize);

            assembly {
                extcodecopy(
                    mockUSDCAddress,
                    add(runtimeBytecode, 0x20),
                    0,
                    codeSize
                )
            }

            vm.etch(_addresses.getAddress("xcUSDC"), runtimeBytecode);
        }

        {
            MockxcDOT mockDot = new MockxcDOT();
            address mockDotAddress = address(mockDot);
            uint256 codeSize;
            assembly {
                codeSize := extcodesize(mockDotAddress)
            }

            bytes memory runtimeBytecode = new bytes(codeSize);

            assembly {
                extcodecopy(
                    mockDotAddress,
                    add(runtimeBytecode, 0x20),
                    0,
                    codeSize
                )
            }

            vm.etch(_addresses.getAddress("xcDOT"), runtimeBytecode);

            deal(
                _addresses.getAddress("xcDOT"),
                _addresses.getAddress("MOONWELL_mxcDOT"),
                xcDotMtokenBalance,
                true
            );

            mockDot = MockxcDOT(_addresses.getAddress("xcDOT"));
            mockDot.balanceOf(address(this));
            assertEq(
                mockDot.balanceOf(_addresses.getAddress("MOONWELL_mxcDOT")),
                xcDotMtokenBalance,
                "incorrect xcDOT balance"
            );
            assertEq(
                mockDot.totalSupply(),
                xcDotMtokenBalance,
                "incorrect xcDOT total supply"
            );
        }

        fraxDelegator = IMErc20Delegator(
            payable(_addresses.getAddress("MOONWELL_mFRAX"))
        );

        mxcDotDelegator = IMErc20Delegator(
            payable(_addresses.getAddress("MOONWELL_mxcDOT"))
        );

        multisig = _addresses.getAddress("NOMAD_REALLOCATION_MULTISIG");

        /// @dev nomad remediation of USDC
        address mUSDC = _addresses.getAddress("MOONWELL_mUSDC");
        address madUSDC = _addresses.getAddress("madUSDC");
        nomadUSDCDelegator = IMErc20Delegator(mUSDC);
        nomadUSDCBalance = IERC20(madUSDC).balanceOf(mUSDC);
        multisigUSDCBalance = IERC20(madUSDC).balanceOf(multisig);

        /// @dev nomad remediation of ETH
        address mETH = _addresses.getAddress("MOONWELL_mETH");
        address madWETH = _addresses.getAddress("madWETH");
        nomadETHDelegator = IMErc20Delegator(mETH);
        nomadETHBalance = IERC20(madWETH).balanceOf(mETH);
        multisigETHBalance = IERC20(madWETH).balanceOf(multisig);

        /// @dev nomad remediation of BTC
        address mwBTC = _addresses.getAddress("MOONWELL_mwBTC");
        address madWBTC = _addresses.getAddress("madWBTC");
        nomadBTCDelegator = IMErc20Delegator(mwBTC);
        nomadBTCBalance = IERC20(madWBTC).balanceOf(mwBTC);
        multisigBTCBalance = IERC20(madWBTC).balanceOf(multisig);

        xcDotToken = IERC20(_addresses.getAddress("xcDOT"));
        fraxToken = IERC20(_addresses.getAddress("FRAX"));
        comptroller = IComptroller(_addresses.getAddress("UNITROLLER"));

        /// @dev borrows, reserves, supply and friends - prior to running the prop
        fraxTotalBorrows = fraxDelegator.totalBorrows();
        fraxTotalReserves = fraxDelegator.totalReserves();
        fraxTotalSupply = fraxDelegator.totalSupply();
        fraxBorrowIndex = fraxDelegator.borrowIndex();
        fraxSupplyRewardSpeeds = comptroller.supplyRewardSpeeds(
            0,
            address(fraxDelegator)
        );
        fraxAccrualBlockTimestampPrior = fraxDelegator.accrualBlockTimestamp();

        IInterestRateModel interestRateModel = fraxDelegator
            .interestRateModel();
        {
            uint256 fraxCashPrior = fraxToken.balanceOf(
                _addresses.getAddress("MOONWELL_mFRAX")
            );

            fraxBorrowRateMantissa = interestRateModel.getBorrowRate(
                fraxCashPrior,
                fraxTotalBorrows,
                fraxTotalReserves
            );
        }

        xcDOTTotalBorrows = mxcDotDelegator.totalBorrows();
        xcDOTTotalReserves = mxcDotDelegator.totalReserves();
        xcDOTTotalSupply = mxcDotDelegator.totalSupply();
        xcDOTBorrowIndex = mxcDotDelegator.borrowIndex();
        xcDOTSupplyRewardSpeeds = comptroller.supplyRewardSpeeds(
            0,
            address(mxcDotDelegator)
        );
        xcDOTAccrualBlockTimestampPrior = mxcDotDelegator
            .accrualBlockTimestamp();
        interestRateModel = mxcDotDelegator.interestRateModel();
        uint256 xcDOTCashPrior = xcDotToken.balanceOf(
            _addresses.getAddress("MOONWELL_mxcDOT")
        );

        xcDOTBorrowRateMantissa = interestRateModel.getBorrowRate(
            xcDOTCashPrior,
            xcDOTTotalBorrows,
            xcDOTTotalReserves
        );

        /// @dev accrueInterest() will be run when the prop is executed
        super.setUp();
    }

    /// initialization

    function testInitializationFails() public {
        IMErc20Delegator madFixer = IMErc20Delegator(
            addresses.getAddress("MERC20_DELEGATE_FIXER_NOMAD_LOGIC")
        );
        IMErc20Delegator badDebtFixer = IMErc20Delegator(
            addresses.getAddress("MERC20_BAD_DEBT_DELEGATE_FIXER_LOGIC")
        );

        vm.expectRevert("only admin may initialize the market");
        madFixer.initialize(address(0), address(0), address(0), 0, "", "", 0);

        vm.expectRevert("only admin may initialize the market");
        badDebtFixer.initialize(
            address(0),
            address(0),
            address(0),
            0,
            "",
            "",
            0
        );
    }

    function testCashEqualsUnderlyingBalancePlusBalance() public {
        assertEq(
            mxcDotDelegator.badDebt() +
                xcDotToken.balanceOf(address(mxcDotDelegator)),
            mxcDotDelegator.getCash(),
            "xcDot cash incorrect"
        );
        assertEq(
            fraxDelegator.badDebt() +
                fraxToken.balanceOf(address(fraxDelegator)),
            fraxDelegator.getCash(),
            "frax cash incorrect"
        );
    }

    function testEthMadMarketsCeaseFunction() public {
        address madEthMTokenHolder = 0xDD15c08320F01F1b6348b35EeBe29fDB5ca0cDa6;

        uint256 balance = nomadETHDelegator.balanceOf(madEthMTokenHolder);

        vm.prank(madEthMTokenHolder);
        uint256 returnCode = nomadETHDelegator.redeem(balance);

        assertTrue(returnCode != 0, "incorrect return code on redeem");
    }

    function testUsdcMadMarketsCeaseFunction() public {
        address madUsdcMTokenHolder = 0xE0B2026E3DB1606ef0Beb764cCdf7b3CEE30Db4A;

        uint256 balance = nomadUSDCDelegator.balanceOf(madUsdcMTokenHolder);

        vm.prank(madUsdcMTokenHolder);
        uint256 returnCode = nomadUSDCDelegator.redeem(balance);

        assertTrue(returnCode != 0, "incorrect return code on redeem");
    }

    function testBtcMadMarketsCeaseFunction() public {
        address madBTCMTokenHolder = 0xb587526953Ad321C1aB2eA26F7311d2aA1A98a4a;

        uint256 balance = nomadBTCDelegator.balanceOf(madBTCMTokenHolder);

        vm.prank(madBTCMTokenHolder);
        uint256 returnCode = nomadBTCDelegator.redeem(balance);

        assertTrue(returnCode != 0, "incorrect return code on redeem");
    }

    function testSetUpxcDot() public {
        {
            /// @dev check that the borrows, reserves and index calculations match
            (, uint256 blockDelta) = subUInt(
                block.timestamp,
                xcDOTAccrualBlockTimestampPrior
            );
            (, Exp memory simpleInterestFactor) = mulScalar(
                Exp({mantissa: xcDOTBorrowRateMantissa}),
                blockDelta
            );
            (, uint256 interestAccumulated) = mulScalarTruncate(
                simpleInterestFactor,
                xcDOTTotalBorrows
            );

            /// calculate the amount of xcDot that still should be borrowed post writeoffs
            (, uint256 _xcDotTotalBorrows) = addUInt(
                interestAccumulated,
                xcDOTTotalBorrows - mxcDotDelegator.badDebt()
            );
            (, uint256 _mxcDotTotalReserves) = mulScalarTruncateAddUInt(
                Exp({mantissa: mxcDotDelegator.reserveFactorMantissa()}),
                interestAccumulated,
                xcDOTTotalReserves
            );
            (, uint256 _xcDotBorrowIndex) = mulScalarTruncateAddUInt(
                simpleInterestFactor,
                xcDOTBorrowIndex,
                xcDOTBorrowIndex
            );

            assertEq(
                mxcDotDelegator.totalBorrows(),
                _xcDotTotalBorrows,
                "incorrect total borrows"
            );
            assertEq(
                mxcDotDelegator.totalReserves(),
                _mxcDotTotalReserves,
                "incorrect total reserves"
            );
            assertEq(
                mxcDotDelegator.borrowIndex(),
                _xcDotBorrowIndex,
                "incorrect borrow index"
            );

            uint256 _mxcDotCashPrior = xcDotToken.balanceOf(
                addresses.getAddress("MOONWELL_mxcDOT")
            ) + mxcDotDelegator.badDebt();
            (, uint256 cashPlusBorrowsMinusReserves) = addThenSubUInt(
                _mxcDotCashPrior,
                _xcDotTotalBorrows,
                _mxcDotTotalReserves
            );
            (, Exp memory _mxcDotExchangeRate) = getExp(
                cashPlusBorrowsMinusReserves,
                xcDOTTotalSupply
            );

            assertEq(
                mxcDotDelegator.exchangeRateStored(),
                _mxcDotExchangeRate.mantissa,
                "incorrect exchange rate"
            );
        }

        assertEq(
            mxcDotDelegator.totalSupply(),
            xcDOTTotalSupply,
            "incorrect total supply"
        );
        assertEq(
            comptroller.supplyRewardSpeeds(0, address(mxcDotDelegator)),
            xcDOTSupplyRewardSpeeds,
            "incorrect reward speeds"
        );
    }

    function testSetUp() public {
        {
            /// @dev check that the borrows, reserves and index calculations match
            (, uint256 blockDelta) = subUInt(
                block.timestamp,
                fraxAccrualBlockTimestampPrior
            );
            (, Exp memory simpleInterestFactor) = mulScalar(
                Exp({mantissa: fraxBorrowRateMantissa}),
                blockDelta
            );
            (, uint256 interestAccumulated) = mulScalarTruncate(
                simpleInterestFactor,
                fraxTotalBorrows
            );
            (, uint256 _fraxTotalBorrows) = addUInt(
                interestAccumulated,
                fraxTotalBorrows - fraxDelegator.badDebt()
            );
            (, uint256 _fraxTotalReserves) = mulScalarTruncateAddUInt(
                Exp({mantissa: fraxDelegator.reserveFactorMantissa()}),
                interestAccumulated,
                fraxTotalReserves
            );
            (, uint256 _fraxBorrowIndex) = mulScalarTruncateAddUInt(
                simpleInterestFactor,
                fraxBorrowIndex,
                fraxBorrowIndex
            );

            assertEq(fraxDelegator.totalBorrows(), _fraxTotalBorrows);
            assertEq(fraxDelegator.totalReserves(), _fraxTotalReserves);
            assertEq(fraxDelegator.borrowIndex(), _fraxBorrowIndex);

            uint256 _fraxCashPrior = fraxToken.balanceOf(
                addresses.getAddress("MOONWELL_mFRAX")
            ) + fraxDelegator.badDebt();
            (, uint256 cashPlusBorrowsMinusReserves) = addThenSubUInt(
                _fraxCashPrior,
                _fraxTotalBorrows,
                _fraxTotalReserves
            );
            (, Exp memory _fraxExchangeRate) = getExp(
                cashPlusBorrowsMinusReserves,
                fraxTotalSupply
            );

            assertEq(
                fraxDelegator.exchangeRateStored(),
                _fraxExchangeRate.mantissa
            );
        }

        assertEq(fraxDelegator.totalSupply(), fraxTotalSupply);
        assertEq(
            comptroller.supplyRewardSpeeds(0, address(fraxDelegator)),
            fraxSupplyRewardSpeeds
        );

        assertEq(nomadUSDCDelegator.getCash(), 0, "cash incorrect usdc");
        assertEq(nomadETHDelegator.getCash(), 0, "cash incorrect eth");
        assertEq(nomadBTCDelegator.getCash(), 0, "cash incorrect btc");

        assertEq(
            nomadUSDCDelegator.balanceOf(multisig),
            0,
            "msig should have no balance of nomad mUSDC"
        );
        assertEq(
            nomadETHDelegator.balanceOf(multisig),
            0,
            "msig should have no balance of nomad mETH"
        );
        assertEq(
            nomadBTCDelegator.balanceOf(multisig),
            0,
            "msig should have no balance of nomad mWBTC"
        );

        assertEq(
            fraxDelegator.implementation(),
            addresses.getAddress("MERC20_BAD_DEBT_DELEGATE_FIXER_LOGIC")
        );
        assertEq(
            mxcDotDelegator.implementation(),
            addresses.getAddress("MERC20_BAD_DEBT_DELEGATE_FIXER_LOGIC")
        );

        /// nomad
        assertEq(
            nomadBTCDelegator.implementation(),
            addresses.getAddress("MERC20_DELEGATE_FIXER_NOMAD_LOGIC")
        );
        assertEq(
            nomadETHDelegator.implementation(),
            addresses.getAddress("MERC20_DELEGATE_FIXER_NOMAD_LOGIC")
        );
        assertEq(
            nomadUSDCDelegator.implementation(),
            addresses.getAddress("MERC20_DELEGATE_FIXER_NOMAD_LOGIC")
        );
    }

    function testMarketPaused() public {
        assertTrue(
            comptroller.borrowGuardianPaused(
                addresses.getAddress("MOONWELL_mFRAX")
            )
        );
    }

    function testNonAdminCannotFixUser() public {
        vm.expectRevert("only the admin may call fixUser");
        IMErc20DelegateFixer(address(fraxDelegator)).fixUser(
            address(this),
            address(this)
        );
    }

    function testAccrueInterest() public {
        assertEq(
            fraxDelegator.accrueInterest(),
            0,
            "fraxDelegator accrue interest failed"
        );
        assertEq(
            mxcDotDelegator.accrueInterest(),
            0,
            "mxcDotDelegator accrue interest failed"
        );
        assertEq(
            nomadUSDCDelegator.accrueInterest(),
            0,
            "nomadUSDCDelegator accrue interest failed"
        );
        assertEq(
            nomadETHDelegator.accrueInterest(),
            0,
            "nomadETHDelegator accrue interest failed"
        );
        assertEq(
            nomadBTCDelegator.accrueInterest(),
            0,
            "nomadBTCDelegator accrue interest failed"
        );
    }

    function testAccrueInterestBlockTimestamp() public {
        assertEq(fraxDelegator.accrueInterest(), 0);
        assertEq(fraxDelegator.accrualBlockTimestamp(), block.timestamp);
    }

    function testRepayBadDebtFailsAmountExceedsBadDebt() public {
        uint256 existingBadDebt = fraxDelegator.badDebt();

        vm.expectRevert("amount exceeds bad debt");
        IMErc20DelegateFixer(address(fraxDelegator)).repayBadDebtWithCash(
            existingBadDebt + 1
        );
    }

    function testFixUserFailsNoUserBorrows() public {
        vm.prank(addresses.getAddress("MOONBEAM_TIMELOCK"));
        vm.expectRevert("cannot liquidate user without borrows");
        IMErc20DelegateFixer(address(fraxDelegator)).fixUser(
            address(2),
            address(1)
        );
    }

    function testFixUserFailsUserEqLiquidator() public {
        vm.prank(addresses.getAddress("MOONBEAM_TIMELOCK"));
        vm.expectRevert("liquidator cannot be user");
        IMErc20DelegateFixer(address(fraxDelegator)).fixUser(
            address(1),
            address(1)
        );
    }

    function testRepayBadDebtSucceeds(uint256 repayAmount) public {
        uint256 startingExchangeRate = fraxDelegator.exchangeRateStored();
        uint256 existingBadDebt = fraxDelegator.badDebt();

        repayAmount = _bound(repayAmount, 1, existingBadDebt);
        deal(address(fraxDelegator.underlying()), address(this), repayAmount);
        fraxToken.approve(address(fraxDelegator), repayAmount);

        vm.expectEmit(true, true, true, true, address(fraxDelegator));
        emit BadDebtRepayed(repayAmount);
        IMErc20DelegateFixer(address(fraxDelegator)).repayBadDebtWithCash(
            repayAmount
        );

        assertEq(
            fraxDelegator.badDebt(),
            existingBadDebt - repayAmount,
            "bad debt incorrect updated"
        );
        assertEq(
            fraxDelegator.exchangeRateStored(),
            startingExchangeRate,
            "exchange rate should not change on bad debt repayment"
        );
    }

    function testRepayBadDebtWithReservesSucceeds() public {
        uint256 startingExchangeRate = fraxDelegator.exchangeRateStored();
        uint256 existingBadDebt = fraxDelegator.badDebt();
        uint256 totalReserves = fraxDelegator.totalReserves();
        uint256 expectedBadDebt = existingBadDebt > totalReserves
            ? existingBadDebt - totalReserves
            : 0;
        uint256 expectedTotalReserves = totalReserves <= existingBadDebt
            ? 0
            : totalReserves - existingBadDebt;

        vm.expectEmit(true, true, true, true, address(fraxDelegator));
        emit BadDebtRepayedWithReserves(
            expectedBadDebt,
            existingBadDebt,
            expectedTotalReserves,
            totalReserves
        );

        IMErc20DelegateFixer(address(fraxDelegator)).repayBadDebtWithReserves();

        assertEq(
            fraxDelegator.totalReserves(),
            expectedTotalReserves,
            "reserves incorrectly updated"
        );
        assertEq(
            IMErc20DelegateFixer(address(fraxDelegator)).badDebt(),
            expectedBadDebt,
            "bad debt incorrectly updated"
        );
        assertEq(
            fraxDelegator.exchangeRateStored(),
            startingExchangeRate,
            "exchange rate should not change on bad debt repayment"
        );
    }

    function testRepayBadDebtWithNoReservesFails() public {
        testRepayBadDebtWithReservesSucceeds();

        vm.expectRevert("reserves are zero");
        IMErc20DelegateFixer(address(fraxDelegator)).repayBadDebtWithReserves();
    }

    function testRepayBadDebtWithNoBadDebtFails() public {
        /// bad debt stored at storage slot 20, write down to 0
        vm.store(address(fraxDelegator), bytes32(uint256(20)), 0);

        vm.expectRevert("bad debt is zero");
        IMErc20DelegateFixer(address(fraxDelegator)).repayBadDebtWithReserves();
    }

    function testIncreaseBadDebtIncreasesCash(uint256 increaseAmount) public {
        increaseAmount = _bound(increaseAmount, 1, type(uint128).max);

        uint256 startingCash = fraxDelegator.getCash();
        uint256 startingBadDebt = IMErc20DelegateFixer(address(fraxDelegator))
            .badDebt();

        /// bad debt stored at storage slot 20, write down to 0
        vm.store(
            address(fraxDelegator),
            bytes32(uint256(20)),
            bytes32(uint256(increaseAmount) + startingBadDebt)
        );

        assertEq(
            fraxDelegator.getCash(),
            startingCash + increaseAmount,
            "cash not increased"
        );
        assertEq(
            IMErc20DelegateFixer(address(fraxDelegator)).badDebt(),
            startingBadDebt + increaseAmount,
            "bad debt not increased"
        );
    }

    function testMint() public {
        fraxDelegator.accrueInterest();

        address minter = address(this);
        uint256 mintAmount = 100e18;

        uint256 startingTokenBalance = fraxToken.balanceOf(
            address(fraxDelegator)
        );

        deal(address(fraxToken), minter, mintAmount);
        fraxToken.approve(address(fraxDelegator), mintAmount);

        uint256 startingFraxTotalSupply = fraxDelegator.totalSupply();
        uint256 currentExchangeRate = fraxDelegator.exchangeRateStored();

        assertEq(fraxDelegator.mint(mintAmount), 0, "mfrax mint error");
        (, uint256 mintedAmount) = divScalarByExpTruncate(
            mintAmount,
            Exp({mantissa: fraxDelegator.exchangeRateStored()})
        );
        assertEq(
            fraxDelegator.balanceOf(minter),
            mintedAmount,
            "frax minter balance incorrect"
        );
        assertEq(
            fraxToken.balanceOf(address(fraxDelegator)) - startingTokenBalance,
            mintAmount,
            "frax balance of mfrax did not increase correctly"
        );
        assertEq(
            fraxDelegator.totalSupply(),
            startingFraxTotalSupply +
                ((mintAmount * 1e18) / currentExchangeRate),
            "delegator total"
        );
    }

    function testMintMoreThanUserBalance() public {
        address minter = address(this);
        uint256 dealAmount = 10e8;
        uint256 mintAmount = 100e8;

        deal(address(fraxToken), minter, dealAmount);
        fraxToken.approve(address(fraxDelegator), mintAmount);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        fraxDelegator.mint(mintAmount);
    }

    function testLiquidityShortfall() public {
        (uint256 err, , uint256 shortfall) = comptroller.getAccountLiquidity(
            address(this)
        );

        assertEq(err, 0);
        assertEq(shortfall, 0);
    }

    function testUnpauseMarket() public {
        assertTrue(
            comptroller.borrowGuardianPaused(
                addresses.getAddress("MOONWELL_mFRAX")
            ),
            "borrow guardian not paused"
        );

        vm.prank(addresses.getAddress("MOONBEAM_TIMELOCK"));
        comptroller._setBorrowPaused(address(fraxDelegator), false);

        assertFalse(
            comptroller.borrowGuardianPaused(
                addresses.getAddress("MOONWELL_mFRAX")
            ),
            "borrow guardian not paused"
        );
    }

    function testEnterMarket() public {
        address[] memory mTokens = new address[](1);
        mTokens[0] = address(fraxDelegator);
        assertFalse(
            comptroller.checkMembership(
                address(this),
                addresses.getAddress("MOONWELL_mFRAX")
            )
        );

        comptroller.enterMarkets(mTokens);

        assertTrue(
            comptroller.checkMembership(
                address(this),
                addresses.getAddress("MOONWELL_mFRAX")
            )
        );
    }

    function testMintEnterMarket() public {
        testMint();
        testEnterMarket();
    }

    function testEnterExitMarket() public {
        testMintEnterMarket();

        comptroller.exitMarket(address(fraxDelegator));
        assertFalse(
            comptroller.checkMembership(
                address(this),
                addresses.getAddress("MOONWELL_mFRAX")
            )
        );
    }

    function testExitMarketNotEntered() public {
        assertEq(comptroller.exitMarket(address(fraxDelegator)), 0);
    }

    function testExitMarketWithActiveBorrow() public {
        testMintEnterMarket();
        testLiquidityShortfall();
        testUnpauseMarket();

        address borrower = address(this);
        uint256 borrowAmount = 50e6;
        uint256 _fraxTotalBorrows = fraxDelegator.totalBorrows();

        assertEq(fraxDelegator.borrow(borrowAmount), 0);
        assertEq(
            fraxDelegator.totalBorrows(),
            (_fraxTotalBorrows + borrowAmount)
        );
        assertEq(fraxToken.balanceOf(borrower), borrowAmount);

        /// @dev Error.NONZERO_BORROW_BALANCE
        assertEq(comptroller.exitMarket(address(fraxDelegator)), 12);
    }

    function testMintNoLiquidityShortfall() public {
        testMintEnterMarket();
        testLiquidityShortfall();
    }

    function testMintBorrow() public {
        testMintEnterMarket();
        testLiquidityShortfall();
        testUnpauseMarket();

        address borrower = address(this);
        uint256 borrowAmount = 50e6;
        uint256 _fraxTotalBorrows = fraxDelegator.totalBorrows();

        assertEq(fraxDelegator.borrow(borrowAmount), 0);
        assertEq(
            fraxDelegator.totalBorrows(),
            (_fraxTotalBorrows + borrowAmount)
        );
        assertEq(fraxToken.balanceOf(borrower), borrowAmount);

        testBorrowRewardSpeeds();
    }

    function testMintBorrowPaused() public {
        testMintEnterMarket();

        uint256 borrowAmount = 50e6;

        vm.expectRevert("borrow is paused");
        fraxDelegator.borrow(borrowAmount);
    }

    function testMintBorrowLiquidityShortfall() public {
        testMintEnterMarket();
        testUnpauseMarket();

        address[] memory mTokens = new address[](1);
        mTokens[0] = address(fraxDelegator);

        uint256[] memory borrowCaps = new uint256[](1);
        borrowCaps[0] = type(uint256).max;

        vm.prank(comptroller.admin());
        comptroller._setMarketBorrowCaps(mTokens, borrowCaps);

        address borrower = address(this);
        uint256 borrowAmount = 1000e18;

        /// @dev Error.INSUFFICIENT_LIQUIDITY
        assertEq(
            fraxDelegator.borrow(borrowAmount),
            3,
            "incorrect borrow error"
        );
        assertEq(
            fraxToken.balanceOf(borrower),
            0,
            "incorrect frax token balance"
        );

        testBorrowRewardSpeeds();
    }

    function testMintBorrowMaxAmount() public {
        address borrower = address(this);
        uint256 mintAmount = 100_000_000e18;
        uint256 startingTokenBalance = fraxToken.balanceOf(
            address(fraxDelegator)
        );

        deal(address(fraxToken), borrower, mintAmount);

        fraxToken.approve(address(fraxDelegator), mintAmount);
        assertEq(fraxDelegator.mint(mintAmount), 0);

        (, uint256 mintedAmount) = divScalarByExpTruncate(
            mintAmount,
            Exp({mantissa: fraxDelegator.exchangeRateStored()})
        );
        assertEq(fraxDelegator.balanceOf(borrower), mintedAmount);
        assertEq(
            fraxToken.balanceOf(address(fraxDelegator)) - startingTokenBalance,
            mintAmount
        );

        testEnterMarket();
        testLiquidityShortfall();
        testUnpauseMarket();

        uint256 borrowCap = comptroller.borrowCaps(
            addresses.getAddress("MOONWELL_mFRAX")
        );
        uint256 _fraxTotalBorrows = fraxDelegator.totalBorrows();
        uint256 borrowAmount = borrowCap - _fraxTotalBorrows - 1;

        assertEq(fraxDelegator.borrow(borrowAmount), 0);
        assertEq(fraxToken.balanceOf(borrower), borrowAmount);
        assertEq(
            fraxDelegator.totalBorrows(),
            (_fraxTotalBorrows + borrowAmount)
        );
    }

    function testMintBorrowCapReached() public {
        address borrower = address(this);
        uint256 mintAmount = 100_000_000e18;
        uint256 startingTokenBalance = fraxToken.balanceOf(
            address(fraxDelegator)
        );

        deal(address(fraxToken), borrower, mintAmount);

        fraxToken.approve(address(fraxDelegator), mintAmount);
        assertEq(fraxDelegator.mint(mintAmount), 0);

        (, uint256 mintedAmount) = divScalarByExpTruncate(
            mintAmount,
            Exp({mantissa: fraxDelegator.exchangeRateStored()})
        );
        assertEq(fraxDelegator.balanceOf(borrower), mintedAmount);
        assertEq(
            fraxToken.balanceOf(address(fraxDelegator)) - startingTokenBalance,
            mintAmount
        );

        testEnterMarket();
        testLiquidityShortfall();
        testUnpauseMarket();

        uint256 borrowCap = comptroller.borrowCaps(
            addresses.getAddress("MOONWELL_mFRAX")
        );
        uint256 _fraxTotalBorrows = fraxDelegator.totalBorrows();
        uint256 borrowAmount = borrowCap - _fraxTotalBorrows;

        vm.expectRevert("market borrow cap reached");
        assertEq(fraxDelegator.borrow(borrowAmount), 0);
        assertEq(fraxDelegator.totalBorrows(), _fraxTotalBorrows);
    }

    function testMintBorrowRepay() public {
        testMintEnterMarket();
        testLiquidityShortfall();
        testUnpauseMarket();

        address borrower = address(this);
        uint256 borrowAmount = 50e6;
        uint256 _fraxTotalBorrows = fraxDelegator.totalBorrows();

        assertEq(fraxDelegator.borrow(borrowAmount), 0);
        assertEq(
            fraxDelegator.totalBorrows(),
            (_fraxTotalBorrows + borrowAmount)
        );
        assertEq(fraxToken.balanceOf(borrower), borrowAmount);

        fraxToken.approve(address(fraxDelegator), borrowAmount);
        assertEq(fraxDelegator.repayBorrow(borrowAmount), 0);
        assertEq(fraxDelegator.totalBorrows(), _fraxTotalBorrows);
        assertEq(fraxToken.balanceOf(borrower), 0);
    }

    function testMintBorrowRepayOnBehalf() public {
        testMintEnterMarket();
        testLiquidityShortfall();
        testUnpauseMarket();

        address borrower = address(this);
        uint256 mintAmount = 10e18;
        uint256 borrowAmount = 50e6;
        uint256 _fraxTotalBorrows = fraxDelegator.totalBorrows();
        uint256 balance = fraxDelegator.balanceOf(address(this));

        assertEq(fraxDelegator.borrow(borrowAmount), 0);
        assertEq(
            fraxDelegator.totalBorrows(),
            (_fraxTotalBorrows + borrowAmount)
        );
        assertEq(fraxToken.balanceOf(borrower), borrowAmount);

        address payer = vm.addr(1);

        vm.startPrank(payer);
        deal(address(fraxToken), payer, mintAmount);
        fraxToken.approve(address(fraxDelegator), borrowAmount);
        assertEq(
            fraxDelegator.repayBorrowBehalf(address(this), borrowAmount),
            0
        );
        vm.stopPrank();

        assertEq(fraxDelegator.totalBorrows(), _fraxTotalBorrows);
        assertEq(fraxDelegator.balanceOf(address(this)), balance);
    }

    function testMintBorrowRepayMorethanBorrowed() public {
        testMintEnterMarket();
        testLiquidityShortfall();
        testUnpauseMarket();

        address borrower = address(this);
        uint256 mintAmount = 10e18;
        uint256 borrowAmount = 50e6;
        uint256 _fraxTotalBorrows = fraxDelegator.totalBorrows();

        assertEq(fraxDelegator.borrow(borrowAmount), 0);
        assertEq(
            fraxDelegator.totalBorrows(),
            (_fraxTotalBorrows + borrowAmount)
        );
        assertEq(fraxToken.balanceOf(borrower), borrowAmount);

        address payer = vm.addr(1);

        vm.startPrank(payer);
        deal(address(fraxToken), payer, mintAmount);
        fraxToken.approve(address(fraxDelegator), borrowAmount + 1_000e6);
        vm.expectRevert(
            "REPAY_BORROW_NEW_ACCOUNT_BORROW_BALANCE_CALCULATION_FAILED"
        );
        fraxDelegator.repayBorrowBehalf(address(this), borrowAmount + 1_000e6);
        vm.stopPrank();
    }

    function testBorrowRewardSpeeds() public {
        assertEq(comptroller.borrowRewardSpeeds(0, address(fraxDelegator)), 1);
    }

    function testMintRedeem() public {
        testMint();

        uint256 balance = fraxDelegator.balanceOf(address(this));
        uint256 _fraxTotalSupply = fraxDelegator.totalSupply();

        assertEq(fraxDelegator.redeem(balance), 0);

        (, uint256 redeemed) = mulScalarTruncate(
            Exp({mantissa: fraxDelegator.exchangeRateStored()}),
            balance
        );
        assertEq(fraxToken.balanceOf(address(this)), redeemed);
        assertEq(fraxDelegator.totalSupply(), (_fraxTotalSupply - balance));
    }

    function testMintRedeemZeroTokens() public {
        testMint();

        uint256 balance = fraxDelegator.balanceOf(address(this));
        uint256 _fraxTotalSupply = fraxDelegator.totalSupply();

        assertEq(fraxDelegator.redeem(0), 0);
        assertEq(fraxDelegator.balanceOf(address(this)), balance);
        assertEq(fraxDelegator.totalSupply(), _fraxTotalSupply);
    }

    function testMintRedeemMoreTokens() public {
        testMint();

        uint256 balance = fraxDelegator.balanceOf(address(this));
        assertEq(fraxDelegator.redeem(balance + 1_000e6), 9);
    }

    function testMintClaimRewardsSupplier() public {
        testMintEnterMarket();
        testLiquidityShortfall();
        testUnpauseMarket();

        address supplier = address(this);
        uint256 mintAmount = 10e18;

        deal(address(fraxToken), supplier, mintAmount);
        fraxToken.approve(address(fraxDelegator), mintAmount);

        assertEq(fraxDelegator.mint(mintAmount), 0);

        IWell well = IWell(addresses.getAddress("WELL"));
        assertEq(well.balanceOf(supplier), 0);

        vm.warp(block.timestamp + 10);

        comptroller.claimReward(0, payable(supplier));
        assertTrue(well.balanceOf(supplier) > 0);
    }

    function testMintClaimInvalidRewardType() public {
        testMintEnterMarket();
        testLiquidityShortfall();
        testUnpauseMarket();

        address claimant = address(this);
        uint256 mintAmount = 10e18;

        deal(address(fraxToken), claimant, mintAmount);
        fraxToken.approve(address(fraxDelegator), mintAmount);

        assertEq(fraxDelegator.mint(mintAmount), 0);

        vm.roll(block.number + 100);
        vm.expectRevert("rewardType is invalid");
        comptroller.claimReward(2, payable(claimant));
    }

    function testLiquidateBorrowFrax() public {
        testUnpauseMarket(); /// unpause frax borrows

        uint256 supplyAmount = 1_000_000 * 1e18;
        IMErc20Delegator mToken = IMErc20Delegator(
            addresses.getAddress("MOONWELL_mFRAX")
        );

        deal(addresses.getAddress("FRAX"), address(this), supplyAmount);

        fraxToken.approve(address(mToken), supplyAmount);
        assertEq(mToken.mint(supplyAmount), 0, "error minting frax tokens");

        address[] memory markets = new address[](1);
        markets[0] = address(mToken);
        comptroller.enterMarkets(markets);

        {
            (, uint256 mintedAmount) = divScalarByExpTruncate(
                supplyAmount,
                Exp({mantissa: fraxDelegator.exchangeRateStored()})
            );
            assertEq(
                fraxDelegator.balanceOf(address(this)),
                mintedAmount,
                "frax minter balance incorrect"
            );
            assertEq(
                fraxToken.balanceOf(address(this)),
                0,
                "frax token balance post mint incorrect"
            );
        }

        assertEq(mToken.borrow(supplyAmount / 2), 0, "borrow failed");

        assertEq(
            mToken.borrowBalanceStored(address(this)),
            supplyAmount / 2,
            "incorrect borrow balance stored"
        );

        assertEq(
            fraxToken.balanceOf(address(this)),
            supplyAmount / 2,
            "frax token balance post borrow incorrect"
        );

        /// borrower is now underwater on loan as collateral value is cut in half
        deal(
            address(mToken),
            address(this),
            mToken.balanceOf(address(this)) / 2
        );

        (uint256 err, uint256 liquidity, uint256 shortfall) = comptroller
            .getHypotheticalAccountLiquidity(
                address(this),
                address(mToken),
                0,
                0
            );

        assertEq(err, 0);
        assertEq(liquidity, 0);
        assertGt(shortfall, 0);

        uint256 repayAmt = 50e6;
        address liquidator = address(100_000_000);
        IERC20 frax = IERC20(addresses.getAddress("FRAX"));

        deal(addresses.getAddress("FRAX"), liquidator, repayAmt);
        vm.prank(liquidator);
        frax.approve(address(mToken), repayAmt);

        _liquidateAccount(liquidator, address(this), mToken, repayAmt);
    }

    function testLiquidateBorrowxcDOT() public {
        uint256 supplyAmount = 1_000_000 * 1e18;
        IMErc20Delegator mToken = IMErc20Delegator(
            addresses.getAddress("MOONWELL_mxcDOT")
        );

        deal(addresses.getAddress("xcDOT"), address(this), supplyAmount);

        xcDotToken.approve(address(mToken), supplyAmount);
        assertEq(mToken.mint(supplyAmount), 0, "error minting xcDot tokens");

        address[] memory markets = new address[](1);
        markets[0] = address(mToken);
        comptroller.enterMarkets(markets);

        {
            (, uint256 mintedAmount) = divScalarByExpTruncate(
                supplyAmount,
                Exp({mantissa: mxcDotDelegator.exchangeRateStored()})
            );
            assertEq(
                mxcDotDelegator.balanceOf(address(this)),
                mintedAmount,
                "xcDot minter balance incorrect"
            );
            assertEq(
                xcDotToken.balanceOf(address(this)),
                0,
                "xcDot token balance post mint incorrect"
            );
        }

        address[] memory mTokens = new address[](1);
        mTokens[0] = address(mxcDotDelegator);

        uint256[] memory borrowCaps = new uint256[](1);
        borrowCaps[0] = type(uint256).max;

        vm.prank(comptroller.admin());
        comptroller._setMarketBorrowCaps(mTokens, borrowCaps);

        assertEq(mToken.borrow(supplyAmount / 2), 0, "borrow failed");

        assertEq(
            mToken.borrowBalanceStored(address(this)),
            supplyAmount / 2,
            "incorrect borrow balance stored"
        );

        assertEq(
            xcDotToken.balanceOf(address(this)),
            supplyAmount / 2,
            "xcDot token balance post borrow incorrect"
        );

        /// borrower is now underwater on loan as collateral value is cut in half
        deal(
            address(mToken),
            address(this),
            mToken.balanceOf(address(this)) / 2
        );

        (uint256 err, uint256 liquidity, uint256 shortfall) = comptroller
            .getHypotheticalAccountLiquidity(
                address(this),
                address(mToken),
                0,
                0
            );

        assertEq(err, 0);
        assertEq(liquidity, 0);
        assertGt(shortfall, 0);

        uint256 repayAmt = 50e6;
        address liquidator = address(100_000_000);

        deal(addresses.getAddress("xcDOT"), liquidator, repayAmt);
        vm.prank(liquidator);
        xcDotToken.approve(address(mToken), repayAmt);

        _liquidateAccount(liquidator, address(this), mToken, repayAmt);
    }

    function _liquidateAccount(
        address liquidator,
        address liquidated,
        IMErc20Delegator token,
        uint256 repayAmt
    ) private {
        uint256 borrowBalanceStored = token.borrowBalanceStored(liquidated);

        vm.prank(liquidator);
        assertEq(
            token.liquidateBorrow(liquidated, repayAmt, address(token)),
            0,
            "user liquidation failure"
        );

        uint256 borrowBalanceStoredPost = token.borrowBalanceStored(liquidated);

        assertEq(
            borrowBalanceStored - borrowBalanceStoredPost,
            repayAmt,
            "borrow balance incorrectly decreased"
        );
    }

    /// MErc20DelegateMadFixer

    function testSweepAllNonAdminFails() public {
        IMErc20DelegateMadFixer madEth = IMErc20DelegateMadFixer(
            addresses.getAddress("MOONWELL_mETH")
        );
        IMErc20DelegateMadFixer madBtc = IMErc20DelegateMadFixer(
            addresses.getAddress("MOONWELL_mwBTC")
        );
        IMErc20DelegateMadFixer madUsdc = IMErc20DelegateMadFixer(
            addresses.getAddress("MOONWELL_mUSDC")
        );
        address nomadMsig = addresses.getAddress("NOMAD_REALLOCATION_MULTISIG");

        vm.expectRevert("only admin may sweep all");
        madEth.sweepAll(nomadMsig);

        vm.expectRevert("only admin may sweep all");
        madBtc.sweepAll(nomadMsig);

        vm.expectRevert("only admin may sweep all");
        madUsdc.sweepAll(nomadMsig);
    }
}
