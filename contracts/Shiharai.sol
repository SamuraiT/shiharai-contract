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
        uint256 cliff; // days
        uint256 duration; // days
        uint256 revokeDays; // anytime -> 1day, each 3month -> 90
    }

    struct TokenAmount {
        address token;
        uint256 amount;
    }

    struct Agreement {
        address issuer;
        address undertaker;
        bytes32 name;
        // Supports stable token for payment as well as governce tokens for vestiges
        address payment;
        uint256 id;
        uint256 amount;
        uint256 term;
        uint256 issuedAt;
        uint256 confirmedAt;
        uint256 depositedAt;
        uint256 paysAt; // unixtime stamp for vesting it would be 0.
    }

    // key is protocol address
    mapping(address => Agreement[]) public issuedagreementsmap;
    // key is udertaker address
    mapping(address => Agreement[]) public undertakenAgreementsMap;
    // key is agreement id
    mapping(address => mapping(address => uint256)) public depositedAmountMap;
    mapping(uint256 => mapping(address => uint256)) public depositByAgreement;
    mapping(uint256 => TokenAmount) public redeemedAmountMap; // tokenX
    mapping(uint256 => VestingCondition) public vestingConditionMap;
    mapping(uint256 => Agreement) public agreements;
    mapping(address => uint256[]) public issuerAgreementsIds;

    constructor(address _erc20) {
        setSupportedToken(_erc20);
    }

    // evnet
    event Agreed(address with, uint256 amount, uint256 term, uint256 timestamp);
    event Claimed(address to);

    // modifier

    // public

    function setSupportedToken(address _address) public {
        address tokenX = createCToken(_address);
        supportedTokensMap[_address] = tokenX;
    }

    function issueAgreement(
        uint256 _id,
        bytes32 _name,
        address _with,
        address _token,
        uint256 _amount,
        uint256 _term,
        uint256 _depositAt,
        uint256 _paysAt
    ) public {
        // Maybe we should limit to one contract at the same time.
        uint256 _now = block.timestamp;
        Agreement memory ag = Agreement({
            issuer: msg.sender,
            undertaker: _with,
            name: _name,
            payment: _token,
            id: _id,
            amount: _amount,
            term: _term, // 1 month
            issuedAt: _now,
            confirmedAt: 0,
            depositedAt: _depositAt,
            paysAt: _paysAt
        });
        issuedagreementsmap[msg.sender].push(ag);
        agreements[_id] = ag;
        issuerAgreementsIds[msg.sender].push(_id);
    }

    function deposit(
        uint256 issueId,
        address _token,
        uint256 _amount
    ) public {
        bool success = IERC20(_token).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        require(success, "TX FAILED");
        depositedAmountMap[msg.sender][_token] += _amount;
        depositByAgreement[issueId][_token] += _amount;
    }

    function depositAndissueAgreement(
        bytes32 _name,
        address _with,
        address _token,
        uint256 _amount,
        uint256 _term,
        uint256 _paysAt
    ) public {
        _agreemtnIds.increment();
        uint256 _newAgId = _agreemtnIds.current();
        deposit(_newAgId, _token, _amount);
        issueAgreement(
            _newAgId,
            _name,
            _with,
            _token,
            _amount,
            _term,
            block.timestamp,
            _paysAt
        );
    }

    function getAgreements(address protocol)
        public
        view
        returns (Agreement[] memory)
    {
        // uint256 size = issuerAgreementsIds[protocol].length;
        // Agreement[] memory ags = new Agreement[](size);
        // for (uint256 i=1; i<=size; i++) {
        //     ags[i] = agreements[i];
        // }
        // return ags;
        return issuedagreementsmap[protocol];
    }

    function withdrawalAgreement(address _with) public {}

    function continueAgreements(uint256[] memory _ids) public {}

    function continueAgreement(uint256 _id) public {}

    function confirmAgreement(uint256 _id) public {
        require(
            agreements[_id].undertaker == msg.sender,
            "INVALID: NOT THE UNDERTAKER"
        );
        agreements[_id].confirmedAt = block.timestamp;
    }

    function claim() public {
        // exchange with ctoken
        // emit Claimed(tokenAddress);
    }

    function claimForLendingProctol() public {
        // lending protocol can claim
        // for lending proctol we will allow to transfer deposit money
    }

    function addLendingProtocol(address _protocol) public {
        // should be onlyOwner
        // add white list
        // better to be done with merkel root
    }

    // internal
    function createCToken(address _token) internal returns (address) {
        return _token; // need to create XToken
    }

    function approveof(address _spender) public {
        // approve of lending protocol with all tokens
        // only owner
    }
}
