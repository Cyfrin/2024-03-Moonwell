//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {Strings} from "@openzeppelin/utils/Strings.sol";
import {IERC20} from "@forge-proposal-simulator/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "@forge-std/Test.sol";
import "@forge-std/console.sol";

import {Governor} from "@tests/integration/helpers/Governor.sol";
import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";
import {IMErc20Delegator} from "@protocol/Interfaces/IMErc20Delegator.sol";
import {IComptroller as Comptroller} from "@protocol/Interfaces/IComptroller.sol";

contract mipm17 is Governor {
    /// @dev nomad balances
    uint256 public constant mwBTCCash = 4425696499;
    uint256 public constant mUSDCCash = 10789300371738;
    uint256 public constant mETHCash = 2269023504004122147416;

    /// @notice struct to read in JSON file
    struct Accounts {
        address addr;
    }

    string public constant override name = "MIP-M17";

    function description() public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    vm.readFile("./src/proposals/mips/mip-m17/MIP-M17.md")
                )
            );
    }

    function _deploy(Addresses addresses, address) internal override {
        address mErc20DelegateFixerAddress = deployCode(
            "MErc20DelegateFixer.sol:MErc20DelegateFixer"
        );
        addresses.addAddress(
            "MERC20_BAD_DEBT_DELEGATE_FIXER_LOGIC",
            mErc20DelegateFixerAddress
        );

        address mErc20DelegateMadFixerAddress = deployCode(
            "MErc20DelegateMadFixer.sol:MErc20DelegateMadFixer"
        );
        addresses.addAddress(
            "MERC20_DELEGATE_FIXER_NOMAD_LOGIC",
            mErc20DelegateMadFixerAddress
        );
    }

    function _build(Addresses addresses) internal override {
        address mErc20DelegateFixerAddress = addresses.getAddress(
            "MERC20_BAD_DEBT_DELEGATE_FIXER_LOGIC"
        );
        /// @dev set delegate for mFRAX
        _pushAction(
            addresses.getAddress("MOONWELL_mFRAX"),
            abi.encodeWithSignature(
                "_setImplementation(address,bool,bytes)",
                mErc20DelegateFixerAddress,
                false,
                new bytes(0)
            ),
            "Upgrade MErc20Delegate for mFRAX to MErc20DelegateFixer"
        );

        /// @dev set delegate for mxcDOT
        _pushAction(
            addresses.getAddress("MOONWELL_mxcDOT"),
            abi.encodeWithSignature(
                "_setImplementation(address,bool,bytes)",
                mErc20DelegateFixerAddress,
                false,
                new bytes(0)
            ),
            "Upgrade MErc20Delegate for mxcDOT to MErc20DelegateFixer"
        );

        address reallocationMultisig = addresses.getAddress(
            "NOMAD_REALLOCATION_MULTISIG"
        );
        /// @dev mFRAX
        {
            string memory debtorsRaw = string(
                abi.encodePacked(
                    vm.readFile("./src/proposals/mips/mip-m17/mFRAX.json")
                )
            );
            bytes memory debtorsParsed = vm.parseJson(debtorsRaw);
            Accounts[] memory mFRAXDebtors = abi.decode(
                debtorsParsed,
                (Accounts[])
            );
            address mFRAXAddress = addresses.getAddress("MOONWELL_mFRAX");
            IMErc20Delegator mFRAXDelegator = IMErc20Delegator(mFRAXAddress);

            for (uint256 i = 0; i < mFRAXDebtors.length; i++) {
                if (
                    mFRAXDelegator.borrowBalanceStored(mFRAXDebtors[i].addr) > 0
                ) {
                    _pushAction(
                        mFRAXAddress,
                        abi.encodeWithSignature(
                            "fixUser(address,address)",
                            reallocationMultisig,
                            mFRAXDebtors[i].addr
                        ),
                        string(
                            abi.encodePacked(
                                "Liquidate bad mFRAX debt for user: ",
                                Strings.toHexString(mFRAXDebtors[i].addr)
                            )
                        )
                    );
                }
            }
        }

        /// @dev xcDOT
        {
            string memory debtorsRaw = string(
                abi.encodePacked(
                    vm.readFile("./src/proposals/mips/mip-m17/mxcDOT.json")
                )
            );
            bytes memory debtorsParsed = vm.parseJson(debtorsRaw);
            Accounts[] memory mxcDOTDebtors = abi.decode(
                debtorsParsed,
                (Accounts[])
            );
            address mxcDOTAddress = addresses.getAddress("MOONWELL_mxcDOT");
            IMErc20Delegator mxcDOTDelegator = IMErc20Delegator(mxcDOTAddress);

            for (uint256 i = 0; i < mxcDOTDebtors.length; i++) {
                if (
                    mxcDOTDelegator.borrowBalanceStored(mxcDOTDebtors[i].addr) >
                    0
                ) {
                    _pushAction(
                        mxcDOTAddress,
                        abi.encodeWithSignature(
                            "fixUser(address,address)",
                            reallocationMultisig,
                            mxcDOTDebtors[i].addr
                        ),
                        string(
                            abi.encodePacked(
                                "Liquidate bad mxcDOT debt for user ",
                                Strings.toHexString(mxcDOTDebtors[i].addr)
                            )
                        )
                    );
                }
            }
        }

        address mUSDCAddress = addresses.getAddress("MOONWELL_mUSDC");
        address mETHAddress = addresses.getAddress("MOONWELL_mETH");
        address mwBTCAddress = addresses.getAddress("MOONWELL_mwBTC");
        address mErc20DelegateMadFixerAddress = addresses.getAddress(
            "MERC20_DELEGATE_FIXER_NOMAD_LOGIC"
        );

        /// @dev mUSDC.mad
        _pushAction(
            mUSDCAddress,
            abi.encodeWithSignature(
                "_setImplementation(address,bool,bytes)",
                mErc20DelegateMadFixerAddress,
                false,
                new bytes(0)
            ),
            "Upgrade MErc20Delegate for mUSDC.mad to MErc20DelegateMadFixer"
        );

        _pushAction(
            mUSDCAddress,
            abi.encodeWithSignature("sweepAll(address)", reallocationMultisig),
            "Sweep all mUSDC.mad"
        );

        /// @dev mETH.mad
        _pushAction(
            mETHAddress,
            abi.encodeWithSignature(
                "_setImplementation(address,bool,bytes)",
                mErc20DelegateMadFixerAddress,
                false,
                new bytes(0)
            ),
            "Upgrade MErc20Delegate for mETH.mad to MErc20DelegateMadFixer"
        );

        _pushAction(
            mETHAddress,
            abi.encodeWithSignature("sweepAll(address)", reallocationMultisig),
            "Sweep all mETH.mad"
        );

        /// @dev mwBTC.mad
        _pushAction(
            mwBTCAddress,
            abi.encodeWithSignature(
                "_setImplementation(address,bool,bytes)",
                mErc20DelegateMadFixerAddress,
                false,
                new bytes(0)
            ),
            "Upgrade MErc20Delegate for mwBTC.mad to MErc20DelegateMadFixer"
        );

        _pushAction(
            mwBTCAddress,
            abi.encodeWithSignature("sweepAll(address)", reallocationMultisig),
            "Sweep all mwBTC.mad"
        );
    }

    function _run(Addresses addresses, address) internal override {
        /// @dev set debug

        simulateActions(
            addresses.getAddress("ARTEMIS_GOVERNOR"),
            addresses.getAddress("WELL"),
            address(this)
        );
    }

    function _validate(Addresses addresses, address) internal override {
        /// @dev check debtors have had their debt zeroed
        {
            string memory debtorsRaw = string(
                abi.encodePacked(
                    vm.readFile("./src/proposals/mips/mip-m17/mFRAX.json")
                )
            );

            bytes memory debtorsParsed = vm.parseJson(debtorsRaw);
            Accounts[] memory debtors = abi.decode(debtorsParsed, (Accounts[]));

            IMErc20Delegator mErc20Delegator = IMErc20Delegator(
                addresses.getAddress("MOONWELL_mFRAX")
            );

            assertTrue(
                mErc20Delegator.badDebt() != 0,
                "mFRAX bad debt should not start at 0"
            );

            Comptroller comptroller = Comptroller(
                addresses.getAddress("UNITROLLER")
            );

            for (uint256 i = 0; i < debtors.length; i++) {
                (uint256 err, , ) = comptroller.getAccountLiquidity(
                    debtors[i].addr
                );

                assertEq(
                    err,
                    0,
                    string(
                        abi.encodePacked(
                            "error code getting liquidity for account: ",
                            Strings.toHexString(debtors[i].addr)
                        )
                    )
                );
                assertEq(
                    mErc20Delegator.borrowBalanceStored(debtors[i].addr),
                    0,
                    "mfrax borrow balance after seizing not zero"
                );
                assertEq(
                    mErc20Delegator.balanceOf(debtors[i].addr),
                    0,
                    "mfrax balance after seizing"
                );
            }
        }

        {
            string memory debtorsRaw = string(
                abi.encodePacked(
                    vm.readFile("./src/proposals/mips/mip-m17/mxcDOT.json")
                )
            );
            bytes memory debtorsParsed = vm.parseJson(debtorsRaw);
            Accounts[] memory debtors = abi.decode(debtorsParsed, (Accounts[]));

            IMErc20Delegator mErc20Delegator = IMErc20Delegator(
                addresses.getAddress("MOONWELL_mxcDOT")
            );
            for (uint256 i = 0; i < debtors.length; i++) {
                assertEq(
                    mErc20Delegator.balanceOf(debtors[i].addr),
                    0,
                    "mxcDOT balanceOf after seizing not zero"
                );
                assertEq(
                    mErc20Delegator.borrowBalanceStored(debtors[i].addr),
                    0,
                    "mxcDOT borrow balance after seizing not zero"
                );
            }
        }

        IMErc20Delegator mUSDCMErc20Delegator = IMErc20Delegator(
            addresses.getAddress("MOONWELL_mUSDC")
        );
        IMErc20Delegator mETHMErc20Delegator = IMErc20Delegator(
            addresses.getAddress("MOONWELL_mETH")
        );
        IMErc20Delegator mwBTCMErc20Delegator = IMErc20Delegator(
            addresses.getAddress("MOONWELL_mwBTC")
        );
        address reallocationMultisig = addresses.getAddress(
            "NOMAD_REALLOCATION_MULTISIG"
        );

        /// @dev check that the Nomad assets have been swept
        assertEq(
            IERC20(addresses.getAddress("madUSDC")).balanceOf(
                reallocationMultisig
            ),
            mUSDCCash,
            "mad usdc msig balance incorrect"
        );
        assertEq(mUSDCMErc20Delegator.getCash(), 0, "mad usdc cash incorrect");
        assertEq(
            mUSDCMErc20Delegator.balanceOf(reallocationMultisig),
            0,
            "musdc balance of msig incorrect"
        );

        assertEq(
            IERC20(addresses.getAddress("madWETH")).balanceOf(
                reallocationMultisig
            ),
            mETHCash,
            "mad eth msig balance incorrect"
        );
        assertEq(
            mETHMErc20Delegator.balanceOf(reallocationMultisig),
            0,
            "meth balance of msig incorrect"
        );
        assertEq(mETHMErc20Delegator.getCash(), 0, "mad eth cash incorrect");

        assertEq(
            IERC20(addresses.getAddress("madWBTC")).balanceOf(
                reallocationMultisig
            ),
            mwBTCCash,
            "mad btc msig balance incorrect"
        );
        assertEq(
            mwBTCMErc20Delegator.balanceOf(reallocationMultisig),
            0,
            "mwbtc balance of msig incorrect"
        );
        assertEq(mwBTCMErc20Delegator.getCash(), 0, "mad btc cash incorrect");
    }
}
