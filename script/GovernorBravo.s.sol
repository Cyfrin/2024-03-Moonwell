pragma solidity 0.8.19;

import {ScriptSuite} from "@script/ScriptSuite.s.sol";

import {mipm17} from "@protocol/proposals/mips/mip-m17/mip-m17.sol";
import {Constants} from "@utils/Constants.sol";
import {MockxcDOT} from "@tests/mock/MockxcDOT.sol";
import {MockxcUSDT} from "@tests/mock/MockxcUSDT.sol";
import {MockxcUSDC} from "@tests/mock/MockxcUSDC.sol";

// @dev Use this script to simulates or run a single proposal
// Use this as a template to create your own script
// `forge script script/GovernorBravo.s.sol:GovernorBravoScript -vvvv --rpc-url {rpc} --broadcast --verify --etherscan-api-key {key}`
contract GovernorBravoScript is ScriptSuite {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";

    constructor() ScriptSuite(ADDRESSES_PATH, new mipm17()) {}

    function run() public override {
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

            vm.etch(addresses.getAddress("xcDOT"), runtimeBytecode);
        }

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

            vm.etch(addresses.getAddress("xcUSDT"), runtimeBytecode);
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

            vm.etch(addresses.getAddress("xcUSDC"), runtimeBytecode);
        }

        /// @dev Execute proposal
        proposal.setDebug(true);
        super.run();
    }
}
