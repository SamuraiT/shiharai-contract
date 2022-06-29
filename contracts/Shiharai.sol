pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "hardhat/console.sol";
import "./Ctoken.sol";

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
        uint256 continuesAt;
        uint256 paysAt; // unixtime stamp for vesting it would be 0.
    }

    mapping(address => mapping(address => uint256)) public depositedAmountMap;
    mapping(address => mapping(address => uint256)) public noneReservedAmount;
    mapping(uint256 => TokenAmount) public redeemedAmountMap; // tokenX
    mapping(uint256 => VestingCondition) public vestingConditionMap;
    mapping(uint256 => Agreement) public agreements;
    mapping(address => uint256[]) public issuerAgreementsIds;
    mapping(address => uint256[]) public undertakenAgreementIds;

    constructor(address _erc20) {}

    // evnet
    event Agreed(address with, uint256 amount, uint256 term, uint256 timestamp);
    event IssuedAgreement(
        uint256 indexed id,
        address indexed issuer,
        address indexed with,
        address token,
        uint256 amount,
        uint256 paysAt
    );
    event Deposit(address indexed issuer, address token, uint256 amount);
    event Claimed(address indexed by, address indexed token, uint256 amount);

    // modifier
    modifier nonExistAgreement(uint256 _id) {
        require(_id > _agreemtnIds.current(), "INVALID: EXIST ID");
        _;
    }

    modifier onlyIssure(uint256 _agreementId) {
        require(
            agreements[_agreementId].issuer == msg.sender,
            "INVLAID: ONLY ISSURE"
        );
        _;
    }

    // public

    function setSupportedToken(address _address) public {
        address tokenX = createOrGetCToken(_address);
        supportedTokensMap[_address] = tokenX;
    }

    function issueAgreement(
        bytes32 _name,
        address _with,
        address _token,
        uint256 _amount,
        uint256 _term,
        uint256 _paysAt
    ) public {
        _agreemtnIds.increment();
        uint256 _newAgId = _agreemtnIds.current();
        _issueAgreement(
            _newAgId,
            _name,
            _with,
            _token,
            _amount,
            _term,
            _paysAt
        );
    }

    function _issueAgreement(
        uint256 _id,
        bytes32 _name,
        address _with,
        address _token,
        uint256 _amount,
        uint256 _term,
        uint256 _paysAt
    ) private {
        require(
            depositedAmountMap[msg.sender][_token] >= _amount,
            "INSUFFICIENT AMOUNT"
        );
        require(
            noneReservedAmount[msg.sender][_token] >= _amount,
            "INSUFFICIENT DEPOSIT"
        );
        // also reuqire
        // amount(all agreed contract) + amount >= _amount
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
            continuesAt: 0,
            paysAt: _paysAt
        });
        noneReservedAmount[msg.sender][_token] -= _amount;
        issuerAgreementsIds[msg.sender].push(_id);
        agreements[_id] = ag;
        emit IssuedAgreement(_id, msg.sender, _with, _token, _amount, _paysAt);
    }

    function deposit(address _token, uint256 _amount) public {
        IERC20Metadata oToken = IERC20Metadata(_token);
        require(oToken.balanceOf(msg.sender) >= _amount, "INSUFFICIENT AMOUNT");
        bool success = oToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "TX FAILED");
        depositedAmountMap[msg.sender][_token] += _amount;
        noneReservedAmount[msg.sender][_token] += _amount;
        ICtoken cToken = ICtoken(createOrGetCToken(_token));
        cToken.mint(_amount);
        emit Deposit(msg.sender, _token, _amount);
    }

    function depositAndissueAgreement(
        bytes32 _name,
        address _with,
        address _token,
        uint256 _amount,
        uint256 _term,
        uint256 _paysAt
    ) public {
        deposit(_token, _amount);
        issueAgreement(_name, _with, _token, _amount, _term, _paysAt);
    }

    function getIssuersAgreements(address protocol)
        public
        view
        returns (Agreement[] memory)
    {
        uint256 size = issuerAgreementsIds[protocol].length;
        uint256 _id;
        Agreement[] memory ags = new Agreement[](size);
        for (uint256 i = 0; i < size; i++) {
            _id = issuerAgreementsIds[protocol][i];
            ags[i] = agreements[_id];
        }
        return ags;
    }

    function getUnderTakersAgreements(address _taker)
        public
        view
        returns (Agreement[] memory)
    {
        uint256 size = undertakenAgreementIds[_taker].length;
        uint256 _id;
        Agreement[] memory ags = new Agreement[](size);
        for (uint256 i = 0; i < size; i++) {
            _id = undertakenAgreementIds[_taker][i];
            ags[i] = agreements[_id];
        }
        return ags;
    }

    function withdrawalAgreement(address _with) public {
    }

    function continueAgreements(uint256[] memory _ids) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            continueAgreement(_ids[i]);
        }
    }

    function continueAgreement(uint256 _id) public onlyIssure(_id) {
        require(
            depositedAmountMap[msg.sender][agreements[_id].payment] >= agreements[_id].amount,
            "INSUFFICIENT AMOUNT"
        );
        require(
            noneReservedAmount[msg.sender][agreements[_id].payment] >= agreements[_id].amount,
            "INSUFFICIENT DEPOSIT"
        );
        noneReservedAmount[msg.sender][agreements[_id].payment] -= agreements[_id].amount;
        agreements[_id].continuesAt = block.timestamp;
        uint256 month = 60 * 60 * 24 * 30; // it should be same days not after 30days
        agreements[_id].paysAt += month;
    }

    function confirmAgreement(uint256 _id) public {
        require(
            agreements[_id].undertaker == msg.sender,
            "INVALID: NOT THE UNDERTAKER"
        );
        agreements[_id].confirmedAt = block.timestamp;
        ICtoken cToken = ICtoken(createOrGetCToken(agreements[_id].payment));
        cToken.transfer(msg.sender, agreements[_id].amount);
    }

    function claim(uint256 _id) public {
        require(
            agreements[_id].undertaker == msg.sender,
            "INVALID: NOT THE UNDERTAKER"
        );
        // exchange with ctoken
        ICtoken cToken = ICtoken(createOrGetCToken(agreements[_id].payment));
        require(
            cToken.balanceOf(msg.sender) >= agreements[_id].amount,
            "cToken is insufficient"
        );
        require(
            block.timestamp >= agreements[_id].paysAt,
            "INVALID: BEFORE PAY DAY"
        );
        bool cSuccess = cToken.transferFrom(
            msg.sender,
            address(this),
            agreements[_id].amount
        );
        require(cSuccess, "cToken TRANSFER FAILED");
        cToken.burn(agreements[_id].amount);

        depositedAmountMap[agreements[_id].issuer][
            agreements[_id].payment
        ] -= agreements[_id].amount;
        bool oSuccess = IERC20(agreements[_id].payment).transfer(
            msg.sender,
            agreements[_id].amount
        );
        require(oSuccess, "oToken TRANSFER FAILED");
        emit Claimed(
            msg.sender,
            agreements[_id].payment,
            agreements[_id].amount
        );
    }

    function modifyPayDay(uint256 _id, uint256 payDay) public onlyIssure(_id) {
        require(payDay <= agreements[_id].paysAt, "INVALID: SET EALIER DATE");
        agreements[_id].paysAt = payDay;
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
    function createOrGetCToken(address _token) private returns (address) {
        IERC20Metadata oToken = IERC20Metadata(_token);
        if (supportedTokensMap[_token] == address(0x0)) {
            Ctoken cToken = new Ctoken(oToken.name(), oToken.symbol(), _token);
            supportedTokensMap[_token] = address(cToken);
        }
        return supportedTokensMap[_token];
    }

    function approveof(address _spender) public {
        // approve of lending protocol with all tokens
        // only owner
    }
}
