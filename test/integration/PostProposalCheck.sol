pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import "@forge-std/console.sol";

import {mipm17} from "@protocol/proposals/mips/mip-m17/mip-m17.sol";
import {Exponential} from "@protocol/proposals/utils/Exponential.sol";

import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";
import {TestSuite} from "@forge-proposal-simulator/test/TestSuite.t.sol";

contract PostProposalCheck is Test, Exponential {
    string public constant ADDRESSES_PATH = "./addresses/addresses.json";
    TestSuite public suite;
    Addresses public addresses;

    function setUp() public virtual {
        mipm17 proposalTwo = new mipm17();

        address[] memory proposalsAddresses = new address[](1);
        proposalsAddresses[0] = address(proposalTwo);

        suite = new TestSuite(ADDRESSES_PATH, proposalsAddresses);
        suite.testProposals();

        addresses = suite.addresses();
    }
}
