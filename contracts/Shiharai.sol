pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

contract Shiharai {
    using Counters for Counters.Counter;
    Counters.Counter private _agreemtnIds;

    // key is token address to pay, and value is redeemable tokenX
    mapping(address => address) public supportedTokensMap;

    struct VestingCondition {
        uint256 cliff;
        uint256 duration;
        uint256 revokeDays; // anytime -> 1day, each 3month -> 90
    }

    struct TokenAmount {
        address token;
        uint256 amount;
    }

    struct Agreement {
        address issuer;
        address undertaker;
        // Supports stable token for payment as well as governce tokens for vestiges
        address payment;
        uint256 id;
        uint256 amount;
        uint256 term;
        uint256 issuedAt;
        uint256 confirmedAt;
        uint256 depositedAt;
    }

    // key is protocol address
    mapping(address => Agreement[]) public issuedAgreementsMap;
    // key is udertaker address
    mapping(address => Agreement[]) public undertakenAgreementsMap;
    // key is agreement id
    mapping(uint256 => TokenAmount) public depositedAmountMap;
    mapping(uint256 => TokenAmount) public redeemedAmountMap; // tokenX
    mapping(uint256 => VestingCondition) public vestingConditionMap;

    constructor(address _erc20) {
        setSupportedToken(_erc20);
    }

    // evnet
    event Agreed(address with, uint256 amount, uint256 term, uint256 timestamp);
    event Claimed(address to);

    // modifier

    // public

    function setSupportedToken(address _address) public {
        address tokenX = createXToken(_address);
        supportedTokensMap[_address] = tokenX;
    }

    function issueAgreement(
        address _with,
        address _token,
        uint256 _amount,
        uint256 _term
    ) public {
        // Maybe we should limit to one contract at the same time.
    }

    function deposit(address _token, uint256 _amount) public {}

    function getAgreements(address protocol) public {}

    function withdrawalAgreement(address _with) public {}

    function continueAgreements(uint256[] memory _ids) public {}

    function continueAgreement(uint256 _id) public {}

    function confirmAgreement(uint256 _id) public {
        // emit Agreed(with, amount, term, timestamp);
    }

    function claim() public {
        // emit Claimed(tokenAddress);
    }

    // internal
    function createXToken(address _token) internal returns (address) {
        return _token; // need to create XToken
    }
}
