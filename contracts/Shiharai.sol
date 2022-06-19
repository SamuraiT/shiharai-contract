pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

contract Shiharai {
    IERC20 public communityToken;

    struct Token {
        address id;
        // Assuming additional status
    }
    mapping(address => Token) public supportedTokensMap;

    struct VestingCondition {
        uint256 cliff;
        uint256 duration;
        uint256 revokeDays; // anytime -> 1day, each 3month -> 90
    }

    struct Payment {
        address token;
        uint256 amount;
        VestingCondition condition;
    }

    struct DepositAmount {
        address token;
        uint256 amount;
    }

    struct Agreement {
        address issuer;
        address contracter;
        Payment[] payments;
        uint256 term;
        uint256 issuedAt;
        uint256 confirmedAt;
        uint256 depositedAt;
        // potentially additional description
    }

    mapping(address => Agreement[]) public agreementsMap;
    mapping(Agreement => DepositAmount) public depositedAmount;

    constructor(address _erc20) {
        setSupportedToken(_erc20);
    }

    // evnet
    event Agreed(address with, uint256 amount, uint256 term, uint256 timestamp);
    event Claimed(address to);

    // modifier

    // public
    function issueAgreement(
        address _with,
        address _token,
        uint256 _amount,
        uint256 _term
    ) public {
        // Maybe we should limit to one contract at the same time.
    }

    function getAgreements(address protocol) public {
    }

    function withdrawalAgreement(address _with) public {
    }

    function continueAgreements(uint256[] _id) public {
    }

    function continueAgreement(uint256 _id) public {
    }

    function confirmAgreement(uint256 _id) public {
        // emit Agreed(with, amount, term, timestamp);
    }

    function claim() public {
        // emit Claimed(tokenAddress);
    }

    function deposit(uint256 _amount, address token) public {}

    // internal

    function vestToken(address _to) internal {}
}
