pragma solidity 0.8.19;

import {ERC20} from "@forge-proposal-simulator/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockxcUSDT is ERC20("Mock xcUSDT", "xcUSDT") {
    function name() public pure override returns (string memory) {
        return "Mock xcUSDT";
    }

    function symbol() public pure override returns (string memory) {
        return "xcUSDT";
    }
}
