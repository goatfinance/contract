// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "./SafeMath.sol";
import "./ReentrancyGuard.sol";
import "./TransferHelper.sol";
import "./IBEP20.sol";
import "./GoatWallet.sol";
import "./GoatMinerPool.sol";


// GOAT Part1 interface
interface IGoatPart1 {
    function start() external;
    function getTotalHash() external view returns (uint256, uint256);
    function getBurn() external view returns (uint256, uint256);
    function getStartBlock() external view returns (uint256);
    function getTotalMint() external view returns (uint256);
    function setPctRate(uint256 pct, uint256 rate) external;
    function setSingleRate(address lpToken, uint256 rate) external;
    function getUserInfo(address user,uint idx) external view returns (uint256);
    function getUserLpHash(address user, address lpToken ) external view returns(uint256);
    function getUserInfoEx(address user) external view returns (uint256[] memory);
    function getChildHash(address user,address child) external view returns(uint256);
    function getHashRateByPct(address lpToken, uint256 pct) external view returns(uint256);
    function getInfoEx() external view returns (uint256[] memory);
    function bindParent(address user, address parent) external;
    function getParent(address user) external view returns (address);
    function setParentByAdmin(address user, address parent) external;
    function getChildren(address user) external view returns (address[] memory);
    function getChildren20MaxX(address user) external view returns (uint256);
    function getVipPrice(address user, uint256 newLevel) external view returns (uint256);
    function getRedeliveryPrice(address user) external view returns (uint256);
    function couldRedelivery(address user) external view returns(bool);
    function redelivery(address user) external  returns(uint256, uint256, uint256);
    function buyVip(address user, uint256 newLevel) external  returns (uint256, uint256, uint256);
    function getExchangeCountOfOneUsdt(address lpToken, address poolAddr) external view returns (uint256);
    function getPower(address lpToken, address poolAddr,uint256 amount, uint256 lpScale ) external view returns (uint256);
    function getLpPayGoat(
        address lpToken, 
        address poolAddr,
        uint256 amount, 
        uint256 lpScale 
    ) external view returns (uint256);
    function getOneshareNow() external view returns (uint256);
    function getPendingReward(address user) external view returns(uint256, uint256);
    function withdrawReward(address user) external  returns (uint256, uint256);
    function withdrawRebate(address user) external  returns (uint256, uint256);
    function takeBack(
        address user, 
        address tokenAddr,
        uint256 pct,
        uint256 burnGoat
    )  external;
    function deposit(
        address user,
        address lpToken,
        uint256 hashRate
    ) external;
}

// address index 
library AddrIndex {
    uint constant eOwner = 1;
    uint constant eGoat = 2;
    uint constant eGoatTrade = 3;
    uint constant eBNBTrade = 4;
    uint constant eFeeOwner = 5;
    uint constant eGotMinerPart1 = 6;
    uint constant eUsdt = 7;
}

contract GoatMiner is ReentrancyGuard {
    
    using TransferHelper for address;
    using SafeMath for uint256;
    
    mapping(uint => address) _mapAddr;
    mapping(address => PoolInfo) _lpPools;
    mapping(address => bool) _mgr;
    GoatMinerPool private _minePool;
    
    struct PoolInfo {
        GoatWallet poolWallet;
        address tradeContract;
        uint256 minPct;
        uint256 maxPct;
    }
    
    modifier onlyMgr() {
        // require(_owner == msg.sender, 'Owner');
        require(_mgr[msg.sender], 'Owner');
        _;
    }

    function init(
        address goatToken, 
        address goatTradeAddr,
        address feeOwner,
        address bnbTradeAddr,
        address goatPart1
    ) public nonReentrant {
        require(_mapAddr[AddrIndex.eOwner] == address(0), "inited");
        
        _mapAddr[AddrIndex.eOwner] = msg.sender;
        _mgr[msg.sender] = true;
        _mapAddr[AddrIndex.eGoat] = goatToken;
        _mapAddr[AddrIndex.eGoatTrade] = goatTradeAddr;
        _mapAddr[AddrIndex.eFeeOwner] = feeOwner;
        _mapAddr[AddrIndex.eBNBTrade] = bnbTradeAddr;
        _mapAddr[AddrIndex.eGotMinerPart1] = goatPart1;
        _minePool = new GoatMinerPool(goatToken, feeOwner, msg.sender);
    }
    
    function setManager(address mgr, bool isSet) public onlyMgr {
        if (mgr == _mapAddr[AddrIndex.eOwner]) {
            return;
        }
        if (_mgr[mgr] == isSet) {
            return;
        }
        _mgr[mgr] = isSet;
    }

    function setAddr(uint idx, address addr) public onlyMgr {
        _mapAddr[idx] = addr;
    }
    
    function start() public nonReentrant onlyMgr {
        IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).start();
    }
 
    function getTotalBurn() public view returns (uint256, uint256) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getBurn();
    }

    function getMinerPoolAddress() public view returns (address) {
        return address(_minePool);
    }

    function getWalletAddress(address lpToken) public view returns (address) {
        return address(_lpPools[lpToken].poolWallet);
    }
    
    function setPctRate(uint256 pct, uint256 rate) public onlyMgr {
        IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).setPctRate(pct, rate);
    }
    
    function setSingleRate(address lpToken, uint256 rate) public onlyMgr {
        IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).setSingleRate(lpToken, rate);
    }

    function getTotalHashRate() public view returns (uint256, uint256) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getTotalHash();
    }
   
    function getLpInfo(address user, address lpToken)
        public
        view
        returns (uint256[3] memory) {
        uint256[3] memory balance;
        (uint256 amount,uint256 amountGoat) = _lpPools[lpToken].poolWallet.getBalance(user);
        balance[0] = amount;
        balance[1] = amountGoat;
        balance[2] = IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getUserLpHash(user, lpToken);
        
        return balance; 
    }
    
    function getLpInfo() public  view returns (uint256[] memory) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getInfoEx();
    }
    
    function getTokenLp(address lpToken) public view returns(uint256, uint256) {
        require(address(_lpPools[lpToken].poolWallet) != address(0), "addr0");
        return _lpPools[lpToken].poolWallet.getTotalLp();
    }
    
    function getUserInfo(address user,uint idx) public view returns (uint256){
        return  IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getUserInfo(user, idx);
    }

    function getUserInfoEx(address user) public view returns (uint256[] memory) {
        return  IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getUserInfoEx(user);
    }

    function getChildHash(address user,address child) external view returns(uint256) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getChildHash(user, child);
    }

    function fixTradingPool(
        address lpToken,
        address tradeContract,
        address vToken,
        uint256 minPct,
        uint256 maxPct
    ) public  onlyMgr {
        _lpPools[lpToken].tradeContract = tradeContract;
        _lpPools[lpToken].minPct = minPct;
        _lpPools[lpToken].maxPct = maxPct;
        _lpPools[lpToken].poolWallet.setVToken(vToken);
    }

    function addTradingPool(
        address lpToken,
        address tradeContract,
        address vToken,
        uint256 minPct,
        uint256 maxPct
    ) public onlyMgr  {
        require(_lpPools[lpToken].maxPct == 0, "EXISTS");

        GoatWallet wallet = new GoatWallet(
            lpToken, 
            _mapAddr[AddrIndex.eGoat], 
            _mapAddr[AddrIndex.eFeeOwner], 
            _mapAddr[AddrIndex.eOwner],
            vToken
        );
        _lpPools[lpToken] = PoolInfo({
            poolWallet: wallet,
            tradeContract: tradeContract,
            minPct: minPct,
            maxPct: maxPct
        });
    }
    
    function unApprove(address lpToken, bool isApprove)  public onlyMgr {
        _lpPools[lpToken].poolWallet.approveVToken(isApprove); 
    }

    function getHashRateByPct(address lpToken, uint256 pct) public view returns(uint256) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getHashRateByPct(lpToken, pct);
    }

    function bindParent(address parent) public {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).bindParent(msg.sender, parent);
    }

    function getParent(address user) public view returns (address) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getParent(user);
    }

    function authOwner() internal view {
        require(msg.sender == _mapAddr[AddrIndex.eOwner]);
    }

    function setParentByAdmin(address user, address parent) public {
        authOwner();
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).setParentByAdmin(user, parent);
    }

    function getChildren(address user)
        public
        view
        returns (address[] memory) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getChildren(user);
    }
    
    function getChildren20MaxX(address user) public view returns (uint256) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getChildren20MaxX(user);
    }

    function getVipPrice(address user, uint256 newLevel)
        public
        view
        returns (uint256) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getVipPrice(user, newLevel);
    }

    function getRedeliveryPrice(address user) public view returns (uint256) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getRedeliveryPrice(user);
    }
    
    function getTotalMint() public view returns (uint256, uint256) {
        return (IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getTotalMint(), block.number);
    }

    function redelivery() public nonReentrant {
        address user = msg.sender;
        bool could = IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).couldRedelivery(user);
        require(could, "Can not");
        
        (uint256 burnGoat, uint256 rebate, uint256 reserved ) = IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).redelivery(user);
        address goatAddr = _mapAddr[AddrIndex.eGoat];
        if (rebate > 0) {
            goatAddr.safeTransferFrom(user, address(_minePool), rebate);
        }
        if (reserved > 0) {
            goatAddr.safeTransferFrom(user, address(_mapAddr[AddrIndex.eFeeOwner]), reserved);
        }
        if (burnGoat > 0) {
            IBEP20(goatAddr).burnFrom(user, burnGoat);
        }
    }

    function buyVip(uint256 newLevel) public nonReentrant  {
        (uint256 burnGoat, uint256 rebate, uint256 reserved) = IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).buyVip(msg.sender, newLevel);
        address goatAddr = _mapAddr[AddrIndex.eGoat];
       if (rebate > 0) {
            goatAddr.safeTransferFrom(msg.sender, address(_minePool), rebate);
        }
        if (reserved > 0) {
            goatAddr.safeTransferFrom(msg.sender, address(_mapAddr[AddrIndex.eFeeOwner]), reserved);
        }
        if (burnGoat > 0) {
            IBEP20(goatAddr).burnFrom(msg.sender, burnGoat);
        }
    }

    function getExchangeCountOfOneUsdt(address lpToken)
        public
        view
        returns (uint256) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getExchangeCountOfOneUsdt(lpToken, _lpPools[lpToken].tradeContract);
    }
 
    function getPower(
        address lpToken, 
        uint256 amount,  
        uint256 lpScale 
    ) public view returns (uint256) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getPower(lpToken,_lpPools[lpToken].tradeContract, amount,  lpScale );
    }

    function getLpPayGoat(
        address lpToken, 
        uint256 amount, 
        uint256 lpScale 
    ) public view returns (uint256) {
        require(lpScale <= 100);
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getLpPayGoat(lpToken,_lpPools[lpToken].tradeContract, amount,  lpScale );
    }

    function getOneshareNow() public view returns (uint256) {
        return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getOneshareNow();
    }

    function getPendingReward(address user) public view returns (uint256, uint256) {
       return IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).getPendingReward(user);
    }

    function withdrawLpReward() public nonReentrant   {
        (uint256 reward, uint256 fee) =  IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).withdrawReward(msg.sender);
        _minePool.MineOut(msg.sender, reward, fee);
    }
    
    function withdrawRebate() public nonReentrant {
        (uint256 reward, uint256 fee) =  IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).withdrawRebate(msg.sender);
        _minePool.MineOut(msg.sender, reward, fee);
    }

   
    // for receive BNB
    receive() external payable { }
    
    function takeBack(address lpToken, uint256 pct)
        public
        nonReentrant {
        require(pct >= 1 && pct <= 100, "pct");
        require(address(_lpPools[lpToken].poolWallet) != address(0), "NON");
        
        address user = msg.sender;
        uint256 burnGoat = _lpPools[lpToken].poolWallet.takeBack(user, pct);
        IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).takeBack(user, lpToken, pct, burnGoat);
    }
    
    function deposit(
        address lpToken, 
        uint256 amount,
        uint256 percent
    ) public payable nonReentrant {
        
        require(percent >= _lpPools[lpToken].minPct, ">min pct");
        require(percent <= _lpPools[lpToken].maxPct, "<max pct");
        // BNB
        if (lpToken == address(2)) {
            amount = msg.value;
        }
        require(amount > 10000);
        
        uint256 price = getExchangeCountOfOneUsdt(lpToken);
        uint256 goatPrice = getExchangeCountOfOneUsdt(_mapAddr[AddrIndex.eGoat]);
        uint256 hashRate = amount.mul(1e20).div(percent).div(price);
        uint256 costGoat = hashRate.mul(goatPrice).mul(100 - percent).div(1e20);
        hashRate = hashRate.mul(getHashRateByPct(lpToken, percent)).div(100);
        uint256 balanceGoat = IBEP20(_mapAddr[AddrIndex.eGoat]).allowance(msg.sender, address(this));

        if (balanceGoat < costGoat) {
            amount = amount.mul(balanceGoat).div(costGoat);
            hashRate = amount.mul(balanceGoat).div(costGoat);
            costGoat = balanceGoat;
        }
        
        IGoatPart1(_mapAddr[AddrIndex.eGotMinerPart1]).deposit(msg.sender, lpToken, hashRate);

        //BNB
        if (lpToken == address(2)) {
            // transfer back 
            if (msg.value > amount) {
                TransferHelper.safeTransferBNB(msg.sender, msg.value - amount);
            }

            _lpPools[lpToken].poolWallet.deposite{value:amount}(msg.sender, amount, costGoat);
        } else {
            lpToken.safeTransferFrom( msg.sender, address(_lpPools[lpToken].poolWallet),amount);

            _lpPools[lpToken].poolWallet.deposite{value:0}(msg.sender, amount, costGoat);
        }
        
        if (costGoat > 0) {
            _mapAddr[AddrIndex.eGoat].safeTransferFrom(msg.sender, address(_lpPools[lpToken].poolWallet), costGoat);
        }
    }
    
    function harvest(address lpToken, address to) public nonReentrant onlyMgr {
        _lpPools[lpToken].poolWallet.reedeemFromVenus(to);
    }
    
    function supplyToVenus(address lpToken) public nonReentrant onlyMgr {
        _lpPools[lpToken].poolWallet.depositeToVenus();
    }
}