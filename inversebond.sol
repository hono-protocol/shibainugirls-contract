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
contract InverseBond {
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

    uint256 public profit = 15000;
    uint256 public availableToken = 0;
    uint256 profitDenominator = 10000;

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
        stableToken = IERC20(0xbe31B897aE6612F551909B93e2477DE92169d5fd);
        stableTokenAddress = 0xbe31B897aE6612F551909B93e2477DE92169d5fd;
        bep20Token = IERC20(0x0570a1DF6339d79ebC858b44bfAE70985DF095c9);
        bep20TokenAddress = 0x0570a1DF6339d79ebC858b44bfAE70985DF095c9;
        bep20Token.approve(address(this),bep20Token.totalSupply());
        stableToken.approve(address(this),stableToken.totalSupply());

        timePeriod = 1;
        lowerCap = 5000000000000000000000;
        upperCap = 10000000000000000000000;
        locked = false;
        isActive = false;
    }
    // constructor(address _router, address _lpTokenAddress, address _stableTokenAddress, address _bep20TokenAddress, uint256 _timePeriod, uint256 _lowerCap, uint256 _upperCap) {
    //     router = IDEXRouter(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
    //     owner = payable(msg.sender);
    //     lpToken = IERC20(_lpTokenAddress);
    //     lpTokenAddress =_lpTokenAddress;
    //     stableToken = IERC20(_stableTokenAddress);
    //     stableTokenAddress = _stableTokenAddress;
    //     bep20Token = IERC20(_bep20TokenAddress);
    //     bep20TokenAddress = _bep20TokenAddress;
    //     bep20Token.approve(address(this),bep20Token.totalSupply());

    //     timePeriod = 1;
    //     lowerCap = 5000000000000000000000;
    //     upperCap = 1000000000000000000000;
    //     locked = false;
    //     isActive = false;
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

    function settings(uint256 _timePeriod, uint256 _lowerCap, uint256 _upperCap) public onlyOwner{
        timePeriod = _timePeriod;
        lowerCap = _lowerCap;
        upperCap = _upperCap;
    }

    function sellBond(uint256 amount) public {
        require(amount >= 0, "really mate!");
        if(stableToken.balanceOf(address(this)) >= upperCap)
        {
            isActive = true;
        }

        uint256 currentPrice = getCurrentPrice(amount);
        if(stableToken.balanceOf(address(this)) - currentPrice <= lowerCap)
        {
            amount = getTokenFromStableAmount(stableToken.balanceOf(address(this))-lowerCap);
            currentPrice = stableToken.balanceOf(address(this))-lowerCap;
        }

        require(stableToken.balanceOf(address(this)) - currentPrice >= 0 && isActive, "Not enough token to sell");

        bep20Token.transferFrom(msg.sender,address(this),amount);
        stableToken.transferFrom(address(this),msg.sender,currentPrice);
        
        if(stableToken.balanceOf(address(this)) <= lowerCap)
        {
            isActive = false;
        }
    }

    function getTokenFromStableAmount(uint256 stableCoinAmount)  public view returns (uint256){
        address[] memory path = new address[](2);
        //path[0] = WBNB;
        path[0] = stableTokenAddress;
        path[1] = bep20TokenAddress;
        return IDEXRouter(router).getAmountsOut(stableCoinAmount, path)[1].mul(profitDenominator).div(profit);
    }

    function getCurrentPrice(uint256 bep20Amount)  public view returns (uint256){
        address[] memory path = new address[](2);
        //path[0] = WBNB;
        path[0] = bep20TokenAddress;
        path[1] = stableTokenAddress;
        return IDEXRouter(router).getAmountsOut(bep20Amount, path)[1].mul(profit).div(profitDenominator);
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