// SPDX-License-Identifier: MIT
// WARNING this contract has not been independently tested or audited
// DO NOT use this contract with funds of real value until officially tested and audited by an independent expert or group

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

interface IDEXRouter {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}
contract StakingLock {
    mapping (address => UserStakingInfo) private userInfos;
    struct UserStakingInfo {
        uint256 amount;
        uint256 releaseTimeStamp;
    }

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Contract owner
    address payable public owner;
    // boolean to prevent reentrancy
    bool internal locked;
    uint256 public timePeriod=20;

    bool public isActive;

    uint256 public profit = 15000;
    uint256 profitDenominator = 10000;

    //LP or the token
    IERC20 public bep20Token;
    address public bep20TokenAddress;

    // Events
    event TokensDeposited(address from, uint256 amount, uint256 totalAmount);
    event SettingChanged(uint256 newProfit,  uint256 newPeriod, bool status);
    event TokenUnstaked(address recipient, uint256 amount);

    constructor() {
        owner = payable(msg.sender);
        bep20Token = IERC20(0xc6F5Ba572D8775d85ACeC06e6427686e6678DEA6);
        bep20TokenAddress = 0xc6F5Ba572D8775d85ACeC06e6427686e6678DEA6;
        timePeriod = 1;
        isActive = true;
    }

    // constructor(address _bep20Token, uint256 _timePeriod) {
    //     owner = payable(msg.sender);
    //     bep20Token = IERC20(_bep20Token);
    //     bep20TokenAddress = _bep20Token;
    //     timePeriod = _timePeriod;
    //     isActive = true;
    // }

    // Modifier
    /**
     * @dev Prevents reentrancy
     */
    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    // Modifier
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Message sender must be the contract's owner.");
        _;
    }

    modifier active() {
        require(isActive == true, "Message sender must be the contract's owner.");
        _;
    }

    function settings(uint256 _timePeriod, uint256 _profit, bool _isActive) public onlyOwner{
        timePeriod = _timePeriod;
        profit = _profit;
        isActive = _isActive;
        emit SettingChanged(_profit, _timePeriod, _isActive);
    }

    function stake(uint256 amount) public {
        userInfos[msg.sender].amount =  userInfos[msg.sender].amount + amount;
        userInfos[msg.sender].releaseTimeStamp =  block.timestamp + timePeriod;
        bep20Token.transferFrom(msg.sender, address(this), amount);
        emit TokensDeposited(msg.sender, amount, userInfos[msg.sender].amount );
    }

    function claimAll() public noReentrant {
        require( userInfos[msg.sender].releaseTimeStamp > block.timestamp, "Not yet!");
        uint256 amountToUnstake = userInfos[msg.sender].amount;
        bep20Token.transferFrom(address(this), msg.sender, amountToUnstake);
        userInfos[msg.sender].amount = 0;
        emit TokenUnstaked(msg.sender, amountToUnstake);
    }
    
    function getUserShare(address staker) external view returns (uint256 amount){
        amount = userInfos[staker].amount.mul(profit).div(profitDenominator);
    }

    function transferAccidentallyLockedTokens(IERC20 token, uint256 amount) public onlyOwner noReentrant {
        require(address(token) != address(0), "Token address can not be zero");
        token.safeTransfer(owner, amount);
    }

    function withdrawEth(uint256 amount) public onlyOwner noReentrant{
        require(amount <= address(this).balance, "Insufficient funds");
        owner.transfer(amount);
    }
}