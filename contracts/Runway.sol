pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/ownership/HasNoEther.sol';
import 'zeppelin-solidity/contracts/ownership/CanReclaimToken.sol';
import 'zeppelin-solidity/contracts/ReentrancyGuard.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/token/ERC20Basic.sol';

contract Runway is HasNoEther, CanReclaimToken, ReentrancyGuard {
    using SafeMath for uint;
    ERC20Basic public token;
    bool public claimsEnabled;
    uint public totalRegistrants;
    uint public tokensHeld;
    
    mapping (bytes32 => bool) public nameStatus;
    mapping (address => address) public referrers;
    mapping (address => Registrant) public registrants;

    struct Registrant {
        bytes32 username;
        bool claimStatus;
        uint referralCount;
    }

    modifier onlyRegistered(address _address) {
        require(_address != address(this) && _address != msg.sender && referrers[_address] != 0x0);
        _;
    }

    modifier onlyBlankOrUnique(bytes32 _username) {
        require(!nameStatus[_username] || _username == "");
        _;
    }

    modifier onlyOneClaimPer(address _claimant) {
        require(!registrants[_claimant].claimStatus);
        _;
        registrants[_claimant].claimStatus = true;
    }

    modifier onlyBeforeClaimsEnabled() {
        require(!claimsEnabled);
        _;
    }

    modifier onlyWhenClaimsEnabled() {
        require(claimsEnabled);
        _;
    }

    modifier onlyNew() {
        require(referrers[msg.sender] == 0x0);
        _;
    }

    function Runway() public {
        claimsEnabled = false;
        totalRegistrants = 1;
        referrers[msg.sender] = msg.sender;
        registrants[msg.sender] = Registrant("", false, 1);
    }

    function getShare() private view returns(uint) {
        return (tokensHeld.div(totalRegistrants).mul(5)).div(10);
    }

    function getBonus(uint _referrals) private view returns(uint) {
        return ((tokensHeld.mul(5)).div(10)).mul(_referrals.mul(100000000)).div(totalRegistrants).mul(100000000).div(10000000000000000);
    }

    function register(address _referrer, bytes32 _username) onlyRegistered(_referrer) onlyBlankOrUnique(_username) onlyNew onlyBeforeClaimsEnabled nonReentrant external {
        if (!(_username == ""))
            nameStatus[_username] = true;
        referrers[msg.sender] = _referrer;
        registrants[msg.sender] = Registrant(_username, false, 0);
        registrants[_referrer].referralCount = registrants[_referrer].referralCount.add(1);
        totalRegistrants = totalRegistrants.add(1);
        Registered(msg.sender, _username, _referrer);
    }

    function claim() onlyRegistered(msg.sender) onlyOneClaimPer(msg.sender) onlyWhenClaimsEnabled nonReentrant external {
        token.transfer(owner, getShare().add(getBonus(registrants[msg.sender].referralCount)));
    }

    function openRunway(address _tokenAddress) onlyOwner onlyBeforeClaimsEnabled public {
        token = ERC20Basic(_tokenAddress);
        tokensHeld = token.balanceOf(address(this));
        claimsEnabled = true;
    }

    event Registered(address indexed _registrant, bytes32 _username, address indexed _referrer);
}