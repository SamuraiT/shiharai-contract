pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

contract Shiharai is Ownable {
    IERC20 public erc20;

    constructor(address _erc20) {
        setERC20(_erc20);
    }

    // onlyOwner //
    function setERC20(address _addr) public onlyOwner {
        erc20 = IERC20(_addr);
    }

    // public //
}
