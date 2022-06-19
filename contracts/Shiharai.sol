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

    IERC20 public communityToken;

    struct Token {
        address id;
        // Assuming additional status
    }
    mapping(address => Token) public supportedTokensMap;

    struct Agreement {
        address with;
        address token;
        uint256 amount;
        uint256 term;
        uint256 timestamp;
        bool isConfirmed;
        // potentially additional description
    }
    mapping(address => Agreement[]) public agreementsMap;

    constructor(address _erc20) {
        setSupportedToken(_erc20);
    }

    // evnet
    event Agreed(address with, uint256 amount, uint256 term, uint256 timestamp);
    event Claimed(address to);

    // modifier

    // onlyOwner
    function setCommunityToken(address _address) public onlyOwner {
        communityToken = IERC20(_address);
    }

    function setSupportedToken(address _address) public onlyOwner {
        supportedTokensMap[_address] = Token(_address);
    }

    function claimTokenFunds(address _tokenAddress) external onlyOwner {}

    function blockPayments() external onlyOwner {
        paymentsState = State.Blocked;
    }

    function allowPayments() external onlyOwner {
        paymentsState = State.Allowed;
    }

    // public
    function issueAgreement(
        address _with,
        address _token,
        uint256 _amount,
        uint256 _term
    ) public {
        // Maybe we should limit to one contract at the same time.
    }

    function withdrawalAgreement(address _with) public {}

    function confirmAgreement() public {
        // emit Agreed(with, amount, term, timestamp);
    }

    function depositSalary(uint256 _amount) public {}

    function claimToken() public {
        // emit Claimed(tokenAddress);
    }

    function depositToken(uint256 _amount) public {}

    function claimSalary() public {
        // emit Claimed(tokenAddress);
    }

    // internal

    function vestToken(address _to) internal {}
}
