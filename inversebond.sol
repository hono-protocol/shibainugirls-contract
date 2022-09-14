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
contract SimpleTimelock {
    using EnumerableSet for EnumerableSet.UintSet;

    mapping (address => EnumerableSet.UintSet) private bondHolders;
    mapping (uint256 => BondData) public bondData;
    mapping (address => bool) public depositors;
    uint256 private currentBondId = 1;
    struct BondData {
        uint256 amount;
        uint256 releaseTimeStamp;
    }

    // boolean to prevent reentrancy
    bool internal locked;

    // Library usage
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    IDEXRouter router;
    // Contract owner
    address payable public owner;

    // Contract owner access
    bool public allIncomingDepositsFinalised;

    uint256 public timePeriod;
    uint256 public lowerCap;
    uint256 public upperCap;

    bool public isActive;

    uint256 public profit = 10400;
    uint256 public availableToken = 0;
    uint256 profitDenominator = 10000;
    // for bond it is the LP
    IERC20 public lpToken;
    address public lpTokenAddress;

    //this is what the pairing of our token is
    IERC20 public stableToken;
    address public stableTokenAddress;

    //LP or the token
    IERC20 public bep20Token;
    address public bep20TokenAddress;

    // Events
    event TokensDeposited(address from, uint256 amount);
    event AllocationPerformed(address recipient, uint256 amount);
    event TokensUnlocked(address recipient, uint256 amount);

    constructor() {
        router = IDEXRouter(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
        owner = payable(msg.sender);
        lpToken = IERC20(0xa2127Fd598a88DB2583cBE22Bd4BB996f81F025F);
        lpTokenAddress =0xa2127Fd598a88DB2583cBE22Bd4BB996f81F025F;
        stableToken = IERC20(0xbe31B897aE6612F551909B93e2477DE92169d5fd);
        stableTokenAddress = 0xbe31B897aE6612F551909B93e2477DE92169d5fd;

        bep20Token = IERC20(0x6a258a2A57e0B15C5eE0383Cb7853C7585AE7763);
        bep20TokenAddress = 0x6a258a2A57e0B15C5eE0383Cb7853C7585AE7763;

        timePeriod = 1;
        lowerCap = 10000000000000000;
        upperCap = 100000000000000000;
        depositors[0xb993A892241e9db2aD90eB2c8fB2D7D0e576cd7B] = true;
        depositors[0x4542b1c810FD07d78ac9e0850ef8FD36555095e8] = true;
        locked = false;
        isActive = false;
    }
    // constructor(address _router, address _inToken, address _outToken, uint256 _timePeriod, uint256 _lowerCap, uint256 _upperCap) {
    //     owner = payable(msg.sender);
    //     inToken = IERC20(_inToken);
    //     inTokenAddress =_inToken;
    //     outToken = IERC20(_outToken);
    //     outTokenAddress = _outToken;
    //     timePeriod = _timePeriod;
    //     lowerCap = _lowerCap;
    //     upperCap = _upperCap;
    //     locked = false;
    //     router = IDEXRouter(_router);
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

    modifier onlyDepositor() {
        require(depositors[msg.sender] == true || msg.sender == bep20TokenAddress , "Depositor must be authorized or the token itself.");
        _;
    }

    function configureDepositor(address _depositor, bool enabled) public onlyOwner{
        depositors[_depositor] = enabled;
    }

    function settings(uint256 _timePeriod, uint256 _lowerCap, uint256 _upperCap) public onlyOwner{
        timePeriod = _timePeriod;
        lowerCap = _lowerCap;
        upperCap = _upperCap;
    }

    function sellBond(uint256 amount) public {
        uint256 currentPrice = getCurrentPrice(amount);

        require(stableToken.balanceOf(address(this)) - currentPrice >= 0 && isActive, "Not enough token to sell");
        
        stableToken.transferFrom(address(this),msg.sender,currentPrice);
        
        if(stableToken.balanceOf(address(this)) < lowerCap)
        {
            isActive = false;
        }
    }

    function getCurrentPrice(uint256 lpAmount)  public view returns (uint256){
        return stableToken.balanceOf(lpTokenAddress).mul(lpAmount).div(lpToken.totalSupply()).mul(2).mul(profit).div(profitDenominator);
    }

    function CountBond(address bonder)  public view returns (uint256){
        return bondHolders[bonder].length();
    }

    function GetBondInfo(uint256 index)  public view returns (uint256){
        return bondHolders[msg.sender].at(index);
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