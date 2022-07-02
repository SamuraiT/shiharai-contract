pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "hardhat/console.sol";
import "./Ctoken.sol";

contract Shiharai {
    using Counters for Counters.Counter;
    Counters.Counter private _agreemtnIds;
    Counters.Counter private _vestingId;

    // key is token address to pay, and value is redeemable tokenX
    mapping(address => address) public supportedTokensMap;

    struct VestingCondition {
        uint256 agreementId;
        uint256 cliffEndedAt; // should be date
        uint256 vestingDuration; // days
        uint256 revokeDays; // anytime -> 1day, each 3month -> 90
        uint256 paidAt;
        uint256 paidAmount;
        uint256 amount;
    }

    struct TokenAmount {
        address token;
        uint256 amount;
    }

    struct Agreement {
        address issuer;
        address undertaker;
        bytes32 name;
        address payment;
        uint256 id;
        uint256 amount;
        uint256 term;
        uint256 issuedAt;
        uint256 confirmedAt;
        uint256 paysAt;
        uint256 endedAt;
        uint256 nextAgreementId;
    }

    mapping(address => mapping(address => uint256)) public depositedAmountMap;
    // reserveed amount is the amount which will be used for payout.
    // so after x amount of despoisit, reservedAmount will be increased by x.
    // after agreement with y amount, reservedAmount will be decreased by y.
    // this way we can confirm reserved amount for payout
    mapping(address => mapping(address => uint256)) public reservedAmount;
    mapping(uint256 => TokenAmount) public redeemedAmountMap; // tokenX
    mapping(uint256 => VestingCondition) public vestings;
    mapping(uint256 => Agreement) public agreements;
    mapping(uint256 => uint256) public vestingOfAgreement;
    mapping(address => uint256[]) public issuerAgreementsIds;
    mapping(address => uint256[]) public undertakenAgreementIds;

    constructor(address erc20) {
        setSupportedToken(erc20);
    }

    // evnet
    event ConfirmAgreement(
        uint256 indexed id,
        address indexed issure,
        address indexed with,
        address token,
        uint256 amount,
        uint256 paysAt,
        uint256 confirmedAt
    );
    event IssuedAgreement(
        uint256 indexed id,
        address indexed issuer,
        address indexed with,
        address token,
        uint256 amount,
        uint256 paysAt
    );
    event ContinueAgreement(
        uint256 indexed id,
        address indexed issuer,
        address indexed with,
        uint256 previousId,
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
    ) public returns (uint256 id) {
        return
            vestingAgreement(
                _name,
                _with,
                _token,
                _amount,
                _term,
                _paysAt,
                _paysAt,
                0,
                0
            );
    }

    function vestingAgreement(
        bytes32 _name,
        address _with,
        address _token,
        uint256 _amount,
        uint256 _term,
        uint256 _paysAt,
        uint256 _cliffEnededAt,
        uint256 _vestingDuration,
        uint256 _revokeDays
    ) public returns (uint256 agreementId) {
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
        _vestingId.increment();
        uint256 vid = _vestingId.current();
        // if cliffEnededAt 0 and vesting duration is 0 and revokeDays is same as pays at then it will be same as normal payment
        vestings[vid] = VestingCondition({
            agreementId: _newAgId,
            cliffEndedAt: _cliffEnededAt,
            vestingDuration: _vestingDuration,
            revokeDays: _revokeDays,
            paidAt: 0,
            paidAmount: 0,
            amount: _amount
        });
        vestingOfAgreement[_newAgId] = vid;
        return _newAgId;
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
            reservedAmount[msg.sender][_token] >= _amount,
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
            paysAt: _paysAt,
            endedAt: 0,
            nextAgreementId: 0
        });
        reservedAmount[msg.sender][_token] -= _amount;
        issuerAgreementsIds[msg.sender].push(_id);
        agreements[_id] = ag;
        emit IssuedAgreement(_id, msg.sender, _with, _token, _amount, _paysAt);
    }

    function getVestingInfo(uint256 _agreementId) public view returns(VestingCondition memory) {
        return vestings[
            vestingOfAgreement[_agreementId]
        ];
    }

    function deposit(address _token, uint256 _amount) public {
        IERC20Metadata oToken = IERC20Metadata(_token);
        require(oToken.balanceOf(msg.sender) >= _amount, "INSUFFICIENT AMOUNT");
        bool success = oToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "TX FAILED");
        depositedAmountMap[msg.sender][_token] += _amount;
        reservedAmount[msg.sender][_token] += _amount;
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

    function depositAndissueVestingAgreement(
        bytes32 _name,
        address _with,
        address _token,
        uint256 _amount,
        uint256 _term,
        uint256 _paysAt,
        uint256 _cliffEnededAt,
        uint256 _vestingDuration,
        uint256 _revokeDays
    ) public {
        deposit(_token, _amount);
        vestingAgreement(
            _name,
            _with,
            _token,
            _amount,
            _term,
            _paysAt,
            _cliffEnededAt,
            _vestingDuration,
            _revokeDays
        );
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

    function withdrawalAgreement(uint256 _id) public onlyIssure(_id) {
        require(agreements[_id].endedAt == 0, "INVALID: ALREADY TERMINATED");
        agreements[_id].endedAt = block.timestamp;
        // payBack some amount if necessary
    }

    function continueAgreements(uint256[] memory _ids) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            continueAgreement(_ids[i]);
        }
    }

    function continueAgreement(uint256 _id) public onlyIssure(_id) {
        require(
            depositedAmountMap[msg.sender][agreements[_id].payment] >=
                agreements[_id].amount,
            "INSUFFICIENT AMOUNT"
        );
        require(
            reservedAmount[msg.sender][agreements[_id].payment] >=
                agreements[_id].amount,
            "INSUFFICIENT DEPOSIT"
        );
        uint256 month = 60 * 60 * 24 * 30; // it should be same days not after 30days
        uint256 newId = issueAgreement(
            agreements[_id].name,
            agreements[_id].undertaker,
            agreements[_id].payment,
            agreements[_id].amount,
            agreements[_id].term,
            agreements[_id].paysAt + month
        );
        uint256 _now = block.timestamp;
        agreements[_id].endedAt = _now;
        agreements[_id].nextAgreementId = newId;
        emit ContinueAgreement(
            newId,
            msg.sender,
            agreements[newId].undertaker,
            _id,
            agreements[newId].payment,
            agreements[newId].amount,
            agreements[newId].paysAt
        );
    }

    function confirmAgreement(uint256 _id) public {
        require(agreements[_id].confirmedAt == 0, "INVALID: ALREADY CONFIRMED");
        require(
            agreements[_id].undertaker == msg.sender,
            "INVALID: NOT THE UNDERTAKER"
        );
        agreements[_id].confirmedAt = block.timestamp;
        ICtoken cToken = ICtoken(createOrGetCToken(agreements[_id].payment));
        cToken.transfer(msg.sender, agreements[_id].amount);
        emit ConfirmAgreement(
            _id,
            agreements[_id].issuer,
            agreements[_id].undertaker,
            agreements[_id].payment,
            agreements[_id].amount,
            agreements[_id].paysAt,
            agreements[_id].confirmedAt
        );
    }

    // let t2 be current time. and t1 be the time which undertaker claimed (contract paid out)
    // let amount be total amount to be paid to undertaker
    // let vDuration be the vesting duration
    // paidAmount(t1, t2) =
    // amount/vDuration * (t2 - cliff_time)/1 day | if vDuration > 0 and t1(paid_at) == 0
    // amount | if vDuration == 0 and t1(paid_at) == 0
    // amount/vDuration * (t2 - t1)/1 day - paidAmount(0, t1) | if vDuration == 0 and t1(paid_at) == 0
    function amountToBePiad(uint256 _id) public view returns (uint256 amount) {
        uint256 _now = block.timestamp;
        uint256 vid = vestingOfAgreement[_id];
        require(_now >= vestings[vid].cliffEndedAt, "INVALID: BEFORE PAYDAYS");
        uint256 passedDays;
        if (vestings[vid].vestingDuration > 0 && vestings[vid].paidAt == 0) {
            passedDays = (_now - vestings[vid].cliffEndedAt) / 1 days;
            uint256 delta = vestings[vid].amount /
                vestings[vid].vestingDuration;
            return delta * ((_now - vestings[vid].cliffEndedAt) / 1 days);
        }

        if (vestings[vid].vestingDuration == 0 && vestings[vid].paidAt == 0) {
            return vestings[vid].amount;
        }

        if (vestings[vid].vestingDuration > 0 && vestings[vid].paidAt > 0) {
            passedDays = (_now - vestings[vid].paidAt) / 1 days;
            uint256 delta = vestings[vid].amount /
                vestings[vid].vestingDuration;
            return
                delta *
                ((_now - vestings[vid].paidAt) / 1 days) -
                vestings[vid].paidAmount;
        }
    }

    function isExceedingRevokeDays(uint256 _id) public view returns (bool) {
        uint256 _now = block.timestamp;
        uint256 vid = vestingOfAgreement[_id];
        if (vestings[vid].paidAt == 0) {
            return
                ((_now - vestings[vid].cliffEndedAt) / 1 days) >=
                vestings[vid].revokeDays;
        }
        return
            ((_now - vestings[vid].paidAt) / 1 days) >=
            vestings[vid].revokeDays;
    }

    function claim(uint256 _id) public {
        require(
            agreements[_id].undertaker == msg.sender,
            "INVALID: NOT THE UNDERTAKER"
        );
        // exchange with ctoken
        uint256 vid = vestingOfAgreement[_id];
        require(
            vestings[vid].paidAmount < vestings[vid].amount,
            "INVALID: PAID ALL AMOUNT"
        );
        require(
            block.timestamp >= vestings[vid].cliffEndedAt,
            "INVALID: BEFORE PAY DAY OR CLIFF"
        );
        ICtoken cToken = ICtoken(createOrGetCToken(agreements[_id].payment));
        require(
            cToken.balanceOf(msg.sender) >=
                (agreements[_id].amount - vestings[vid].paidAmount),
            "cToken is insufficient"
        );
        uint256 amount = amountToBePiad(_id);
        require(isExceedingRevokeDays(_id), "INVALID: WAIT UNTILS REVOKE DAYS");
        bool cSuccess = cToken.transferFrom(msg.sender, address(this), amount);
        require(cSuccess, "cToken TRANSFER FAILED");
        cToken.burn(amount);

        depositedAmountMap[agreements[_id].issuer][
            agreements[_id].payment
        ] -= amount;
        vestings[vid].paidAmount += amount;
        vestings[vid].paidAt = block.timestamp;
        bool oSuccess = IERC20(agreements[_id].payment).transfer(
            msg.sender,
            amount
        );
        require(oSuccess, "oToken TRANSFER FAILED");
        emit Claimed(msg.sender, agreements[_id].payment, amount);
    }

    function modifyPayDay(uint256 _id, uint256 payDay) public onlyIssure(_id) {
        require(payDay <= agreements[_id].paysAt, "INVALID: SET EALIER DATE");
        agreements[_id].paysAt = payDay;
        uint256 vid = vestingOfAgreement[_id];
        vestings[vid].cliffEndedAt = payDay;
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
