pragma solidity 0.8.19;

import {ERC20} from "@forge-proposal-simulator/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockxcDOT is ERC20("Mock xcDOT", "xcDOT") {
    function name() public pure override returns (string memory) {
        return "Mock xcDOT";
    }

    function symbol() public pure override returns (string memory) {
        return "xcDOT";
    }
}
