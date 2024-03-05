pragma solidity 0.8.19;

import {ERC20} from "@forge-proposal-simulator/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockxcUSDC is ERC20("USD Coin", "xcUSDC") {
    function name() public pure override returns (string memory) {
        return "USD Coin";
    }

    function symbol() public pure override returns (string memory) {
        return "xcUSDC";
    }
}
