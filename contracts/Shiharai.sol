pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

contract Shiharai is Ownable {
    State public paymentsState;
    enum State {
        Allowed,
        Blocked
    }

    struct Token {
        address id;
    }
    mapping(address => Token) public supportedTokensMap;

    constructor(address _erc20) {
        setERC20(_erc20);
    }

    // modifier

    // onlyOwner

    function setERC20(address _addr) public onlyOwner {
        supportedTokensMap[_addr] = Token(_addr);
    }

    function claimTokenFunds(address tokenAddress) external onlyOwner {}

    function blockPayments() external onlyOwner {
        paymentsState = State.Blocked;
    }

    function allowPayments() external onlyOwner {
        paymentsState = State.Allowed;
    }

    // public

    // internal
}
