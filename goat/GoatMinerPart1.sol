// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "./SafeMath.sol";
import "./ReentrancyGuard.sol";
import "./IBEP20.sol";

/**
 * pancake interface
 * https://github.com/pancakeswap
 */
interface IPancakePair {
    //get token0
    function token0() external view returns (address);
    //get token1
    function token1() external view returns (address);
    //get reserves
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

// user info index
library UserIndex {
    //user level
    uint constant eUserLevel = 1;
    uint constant eSelfHash = 2; 
    uint constant eTeamHash = 3; 
    uint constant ePendingCoin = 4; 
    uint constant eTakedCoin = 5; 
    uint constant eRebateLimit = 6;
    uint constant eRebateTotal = 7;
    uint constant eRebateNow = 8;
    uint constant eRedeliveryTimes = 9;
    uint constant eBurnGoat = 10;
    uint constant ePendingRebate = 11;
}

// address index 
library AddrIndex {
    uint constant eOwner = 1;
    uint constant eMiner = 2;
    uint constant ePoolGoat = 3;
    uint constant ePoolBNB = 4;
    uint constant eUsdtAddr = 5;
    uint constant eWBNB = 6;
    uint constant eTopParent = 7;
}

// uint256 index
library Uint256Index {
    uint constant eTotalHashRate = 1;
    uint constant eTotalLpHashRate = 2;
    uint constant eStartBlock = 3;
    uint constant eLpBurn = 4;
    uint constant eVipBurn = 5;
    uint constant eLastUpdateBlock = 6;
    uint constant eOneShareGet = 7;
    uint constant eOneShareScale = 8;
    uint constant eTotalMint = 9;
    uint constant eThresholdMutiple = 10;
}

// Part 1, called by part2
contract GoatMinerPart1 is ReentrancyGuard {
    
    using SafeMath for uint256;
    
    // see AddrIndex 
    mapping(uint => address) private _mapAddr;
    // see Uint256Index
    mapping (uint => uint256) _mapUint256;
    mapping(uint256 => uint256[20]) internal _levelConfig;
    mapping(uint256 => uint256) _pctRate;
    mapping(address => uint256) _singleRate;
    mapping(address => address) internal _parents;
    mapping(address => address[]) internal _children;
    mapping(address=>mapping(address=>uint256)) _userChildTotal;
    mapping(address => mapping(address => uint256)) _userLpHash;
    mapping(address => mapping(uint256 => uint256)) _userLevelHash;
    mapping(address => mapping(uint=>uint256)) _userInfo;
    uint256[8] _vipPrice;
    
    modifier onlyMiner() {
        require(_mapAddr[AddrIndex.eMiner] != address(0) && msg.sender == _mapAddr[AddrIndex.eMiner], 'auth');
        _;
    }

    modifier onlyOwner() {
        require(_mapAddr[AddrIndex.eOwner] == msg.sender, 'Owner');
        _;
    }

    function init(
        address poolGoat, 
        address poolBNB,
        address miner,
        address usdtAddr,
        address wBNB
    ) public  nonReentrant {
        require(_mapAddr[AddrIndex.eOwner] == address(0), "inited");
        
        _mapAddr[AddrIndex.eOwner] = msg.sender;
        _mapAddr[AddrIndex.ePoolGoat] = poolGoat;
        _mapAddr[AddrIndex.ePoolBNB] = poolBNB;
        _mapAddr[AddrIndex.eMiner] = miner;
        _mapAddr[AddrIndex.eUsdtAddr] = usdtAddr;
        _mapAddr[AddrIndex.eWBNB] = wBNB;
        _mapAddr[AddrIndex.eTopParent] = address(this);

        // [0,100,300,500,800,1200, 1600, 2000]
        _vipPrice[0] = 0;
        _vipPrice[1] = 100;
        _vipPrice[2] = 300;
        _vipPrice[3] = 500;
        _vipPrice[4] = 800;
        _vipPrice[5] = 1200;
        _vipPrice[6] = 1600;
        _vipPrice[7] = 2000;
  
        _parents[msg.sender] = address(this);
        _userInfo[msg.sender][UserIndex.eUserLevel] = 7;
        _userInfo[msg.sender][UserIndex.eRebateLimit] = _vipPrice[7].mul(3).mul(1e18); 

        _pctRate[70] = 120;
        _pctRate[50] = 150;
        _pctRate[100] = 200;

        _mapUint256[Uint256Index.eOneShareScale] = 1e40;
        _mapUint256[Uint256Index.eThresholdMutiple] = 100;
    
        _levelConfig[1] = [150,100,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
        _levelConfig[2] = [160,110,90,60,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
        _levelConfig[3] = [170,120,100,70,40,30,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
        _levelConfig[4] = [180,130,110,80,40,30,20,10,0,0,0,0,0,0,0,0,0,0,0,0];
        _levelConfig[5] = [200,140,120,90,40,30,20,10,10,10,10,10,0,0,0,0,0,0];
        _levelConfig[6] = [220,160,140,100,40,30,20,10,10,10,10,10,10,10,10,0,0];
        _levelConfig[7] = [250,180,160,110,40,30,20,10,10,10,10,10,10,10,10,10,10];
    }

    function setAddr(uint idx, address addr) public onlyOwner {
        _mapAddr[idx] = addr;
    }

    function setUint256(uint idx, uint256 value) public onlyOwner {
        _mapUint256[idx] = value;
    }
    
    function start() public onlyMiner {
        if (_mapUint256[Uint256Index.eStartBlock] == 0) {
            _mapUint256[Uint256Index.eStartBlock] = block.number;
            _mapUint256[Uint256Index.eLastUpdateBlock] = block.number;
        }
    }
    
    // get LP burn and vip burn 
    function getBurn() public view returns (uint256, uint256) {
        return (_mapUint256[Uint256Index.eLpBurn], _mapUint256[Uint256Index.eVipBurn]);
    }
    
    // get start block 
    function getStartBlock() public view returns (uint256) {
        return _mapUint256[Uint256Index.eStartBlock];
    }
    
    // get total mint goat 
    function getTotalMint() public view returns (uint256) {
        uint256 totalMint = _mapUint256[Uint256Index.eTotalMint];
        if (block.number > _mapUint256[Uint256Index.eLastUpdateBlock]) {
            uint256 bls = block.number.sub(_mapUint256[Uint256Index.eLastUpdateBlock]);
            uint256 perBlockCnt = getPerBlockCount();
            totalMint = totalMint.add(bls.mul(perBlockCnt));
        }
        // scale 1e25, goat deceimal 8
        return totalMint.div(1e17);
    }
    
    function getTotalHash() public view returns (uint256, uint256) {
        return (_mapUint256[Uint256Index.eTotalHashRate], _mapUint256[Uint256Index.eTotalLpHashRate]);
    }
    
    function setSingleRate(address lpToken, uint256 rate) public onlyMiner {
        _singleRate[lpToken] = rate;
    }
    

    function getInfoEx() public view returns (uint256[] memory) {
        uint256[] memory info = new uint256[](Uint256Index.eTotalMint + 1);
        for (uint i = Uint256Index.eTotalHashRate; i <= Uint256Index.eTotalMint; i++) {
            info[i - 1] = _mapUint256[i];
        }
        info[Uint256Index.eTotalMint] = block.number;
        return info;
    }

    
    function getHashDiffOnLevelChange(
        address user, 
        uint256 newLevel
    ) private view returns (uint256) {
        uint256 hashDiff = 0;
        uint256 userLevel = _userInfo[user][UserIndex.eUserLevel];
        for (uint256 i = 0; i < 20; i++) {
            if (_userLevelHash[user][i] > 0) {
                if (userLevel > 0 && _levelConfig[userLevel][i] > 0) {
                    uint256 diff =
                        _userLevelHash[user][i]
                            .mul(_levelConfig[newLevel][i])
                            .subBe0(
                            _userLevelHash[user][i].mul(
                                _levelConfig[userLevel][i]
                            )
                        );
                    diff = diff.div(1000);
                    hashDiff = hashDiff.add(diff);
                } else {
                    uint256 diff =
                        _userLevelHash[user][i]
                            .mul(_levelConfig[newLevel][i])
                            .div(1000);
                    hashDiff = hashDiff.add(diff);
                }
            }
        }
        return hashDiff;
    }
    
    
    function setPctRate(uint256 pct, uint256 rate) public onlyMiner {
        _pctRate[pct] = rate;
    }

    function getUserInfo(address user,uint idx) public view returns (uint256){
        return  _userInfo[user][idx];
    }

    function getUserInfoEx(address user) public view returns (uint256[] memory) {
        uint256[] memory info = new uint256[](UserIndex.ePendingRebate + 1);
        for (uint i = UserIndex.eUserLevel; i <= UserIndex.ePendingRebate; i++) {
            info[i - 1] = _userInfo[user][i];
        }
        info[UserIndex.ePendingRebate] = block.number;

        return info;
    }

    
    function getChildHash(address user,address child) public view returns(uint256) {
        return _userChildTotal[user][child];
    }
    
    function getUserLpHash(address user, address lpToken ) public view returns(uint256) {
        return _userLpHash[user][lpToken];
    }

    
    function getHashRateByPct(address lpToken, uint256 pct) public view returns(uint256) {
        if (pct == 100) {
            if (_singleRate[lpToken] > 0) {
                return _singleRate[lpToken];
            }
        }
        if (_pctRate[pct] > 0) {
            return _pctRate[pct];
        } 
        return 100;
    }

    
    function bindParent(address user, address parent) public  onlyMiner{
        require(_parents[user] == address(0), "binded");
        require(parent != address(0), "parent");
        require(parent != user, "parent");
        require(parent != _mapAddr[AddrIndex.eTopParent]);
        // only vip hava children 
        require(_userInfo[parent][UserIndex.eUserLevel] != 0);

        _parents[user] = parent;
        _children[parent].push(user);
    }

    
    function getParent(address user) public view returns (address) {
        return _parents[user];
    }

    
    function setParentByAdmin(address user, address parent) public onlyMiner {
        require(_parents[user] == address(0), "bind");
        _parents[user] = parent;
        _children[parent].push(user);
    }

    
    function getChildren(address user)
        public
        view
        returns (address[] memory) {
        return _children[user];
    }
    
    function getChildren20MaxX(address user) public view returns (uint256) {
        if (_userInfo[user][UserIndex.eUserLevel] == 0) {
            return 0;
        }
        uint256 max = 0;
        uint256 mutiple = _mapUint256[Uint256Index.eThresholdMutiple];
        uint256 threshold = _userInfo[user][UserIndex.eSelfHash].mul(mutiple).div(100);
        for (uint256 i = 0; i < _children[user].length; i++) {
            address cur = _children[user][i];
            if (_userInfo[cur][UserIndex.eSelfHash] > threshold) {
                if (max < _userInfo[cur][UserIndex.eSelfHash]) {
                    max = _userInfo[cur][UserIndex.eSelfHash];
                }
            }
            for (uint256 j = 0; j < 20; j++) {
                if (_children[cur].length == 0) {
                    break;
                }
                
                cur = _children[cur][0];
                if (_userInfo[cur][UserIndex.eSelfHash] > threshold) {
                    if (max < _userInfo[cur][UserIndex.eSelfHash]) {
                        max = _userInfo[cur][UserIndex.eSelfHash];
                    }
                }
            }
        }
        return max;
    }

    
    function getVipPrice(address user, uint256 newLevel) public view returns (uint256) {
        if (newLevel >= 8 || newLevel == 0) {
            return 0;
        }

        uint256 userLevel = _userInfo[user][UserIndex.eUserLevel];
        if (userLevel >= newLevel) return 0;
        uint256 costUsdt = _vipPrice[newLevel] - _vipPrice[userLevel];
        
        uint256 costGoat = costUsdt.mul(getExchangeCountOfOneUsdt(address(0), _mapAddr[AddrIndex.ePoolGoat]));
        return costGoat;
    }

    function getRedeliveryPrice(address user) public view returns (uint256) {
        uint256 level = _userInfo[user][UserIndex.eUserLevel];
        if (level == 0) {
            return 0;
        } 
        uint256 costUsdt = _vipPrice[level];
        uint256 costGoat = costUsdt.mul(getExchangeCountOfOneUsdt(address(0), _mapAddr[AddrIndex.ePoolGoat]));
        return costGoat;
    }

    function couldRedelivery(address user) public view returns(bool) {
        uint256 level = _userInfo[user][UserIndex.eUserLevel];
        if (level == 0) {
            return false;
        }
        return _userInfo[user][UserIndex.eRebateNow] >= _userInfo[user][UserIndex.eRebateLimit];
    } 

    function redelivery(address user) public onlyMiner returns(uint256, uint256, uint256) {
 
        uint256 level = _userInfo[user][UserIndex.eUserLevel];
        require(level > 0, "level");
        require(_userInfo[user][UserIndex.eRebateNow] >= _userInfo[user][UserIndex.eRebateLimit], "limit");

        uint256 costUsdt = _vipPrice[level];
        uint256 goatPrice = getExchangeCountOfOneUsdt(address(0), _mapAddr[AddrIndex.ePoolGoat]);
        uint256 costGoat = costUsdt.mul(goatPrice);
        _userInfo[user][UserIndex.eRebateLimit] = _vipPrice[level].mul(3).mul(1e18);
        if (_userInfo[user][UserIndex.eRebateNow] >= _userInfo[user][UserIndex.eRebateLimit]) {
            _userInfo[user][UserIndex.eRebateNow] = 0;
        }

        uint256 burnGoat = costGoat.mul(30).div(100);
        uint256 rebate = doRebate(user, costGoat.subBe0(burnGoat), goatPrice, level, false);
        
        _userInfo[user][UserIndex.eBurnGoat] = _userInfo[user][UserIndex.eBurnGoat].add(burnGoat);
        _userInfo[user][UserIndex.eRedeliveryTimes] = _userInfo[user][UserIndex.eRedeliveryTimes].add(1);
        _mapUint256[Uint256Index.eVipBurn] = _mapUint256[Uint256Index.eVipBurn].add(burnGoat);
        
        return (burnGoat, rebate, costGoat.subBe0(burnGoat.add(rebate)));
    }

    function doRebate(address user, uint256 amount, uint256 goatPrice, uint256 newLevel, bool isBuyVip) private returns (uint256)  {
        uint256 i = 0;
        address parent = user;
        uint256 rebate = 0;
        uint256 base;
        while (i < 20) {
            parent = getParent(parent);
            if (parent == address(0) || parent == _mapAddr[AddrIndex.eTopParent]) {
                break;
            }
            if (_userInfo[parent][UserIndex.eRebateNow] >= _userInfo[parent][UserIndex.eRebateLimit]) {
                continue;
            }
            
            uint256 level = _userInfo[parent][UserIndex.eUserLevel];
            uint256 pct = _levelConfig[level][i];
            if (pct == 0) {
                i++;
                continue;
            }

            base = amount;
            if (isBuyVip) {
                if (_userInfo[user][UserIndex.eUserLevel] >= level) {
                    i++;
                    continue;
                }
                if (newLevel > level) {
                    uint256 costGoat = getVipPrice(user, level);
                    base = costGoat.mul(70).div(100);
                }
            } else {
                if (_userInfo[user][UserIndex.eUserLevel] > level) {
                    uint256 costUsdt = _vipPrice[level];
                    uint256 costGoat = costUsdt.mul(goatPrice);
                    base = costGoat.mul(70).div(100);
                }
            }
            
            uint256 getGoat = base.mul(pct).div(1000);
            rebate = rebate.add(getGoat);
            _userInfo[parent][UserIndex.ePendingRebate] = _userInfo[parent][UserIndex.ePendingRebate].add(getGoat);

            uint256 getUsdt = getGoat.mul(1e18).div(goatPrice);
            _userInfo[parent][UserIndex.eRebateNow] = _userInfo[parent][UserIndex.eRebateNow].add(getUsdt);
            _userInfo[parent][UserIndex.eRebateTotal] = _userInfo[parent][UserIndex.eRebateTotal].add(getUsdt);

            i++;
        }
        return rebate;
    }
    
    function buyVip(address user, uint256 newLevel) public onlyMiner returns (uint256, uint256, uint256) {
        require(newLevel < 8 && newLevel > 0);

        require(_parents[user] != address(0), "must bind parent first");
        require(_mapUint256[Uint256Index.eLastUpdateBlock] > 0, "not start");
        uint256 userLevel = _userInfo[user][UserIndex.eUserLevel];
        require (userLevel < newLevel, "level");

        uint256 costGoat = getVipPrice(user, newLevel);
        require(costGoat > 0, "price");

        uint256 diff = getHashDiffOnLevelChange(user, newLevel);
        if (diff > 0) {
            userHashChanged(user, 0, diff, true);
            logCheckPoint(diff, true);
        }
        
        uint256 goatPrice = getExchangeCountOfOneUsdt(address(0),  _mapAddr[AddrIndex.ePoolGoat]);
  
        uint256 burnGoat = costGoat.mul(30).div(100);
        uint256 rebate = doRebate(user,  costGoat.subBe0(burnGoat), goatPrice, newLevel, true);
        
        _userInfo[user][UserIndex.eBurnGoat] = _userInfo[user][UserIndex.eBurnGoat].add(burnGoat);
        _userInfo[user][UserIndex.eUserLevel] = newLevel;
        _userInfo[user][UserIndex.eRebateLimit] = _vipPrice[newLevel].mul(3).mul(1e18);
        
        _mapUint256[Uint256Index.eVipBurn] = _mapUint256[Uint256Index.eVipBurn].add(burnGoat);
        return (burnGoat, rebate, costGoat.subBe0(burnGoat.add(rebate)));
    }

    function getExchangeCountOfOneUsdtA(address poolAddr) private view returns (uint256) {
        // USDT - TOKEN 
        (uint112 _reserve0, uint112 _reserve1, ) = IPancakePair(poolAddr).getReserves();
        uint256 a = _reserve0;
        uint256 b = _reserve1;
        
        return  b.mul(1e18).div(a);
    }

    function getExchangeCountOfOneUsdtB(
        address lpToken,
        address poolAddr
        
    ) private view returns (uint256){
        address token0 = IPancakePair(poolAddr).token0();
        address token1 =  IPancakePair(poolAddr).token1();
        (uint112 _reserve3, uint112 _reserve4, ) = IPancakePair(poolAddr).getReserves();
        uint256 balancec = _reserve4;
        uint256 balanced = _reserve3;
        
        // USDT - TOKEN 
        if (token0 == _mapAddr[AddrIndex.eUsdtAddr] && token1 == lpToken) {
            return balancec.mul(1e18).div(balanced);
        }
        // TOKEN - USDT 
        if (token0 == lpToken && token1 == _mapAddr[AddrIndex.eUsdtAddr]) {
            return balanced.mul(1e18).div(balancec);
        }
        // not support
        if (token0 != _mapAddr[AddrIndex.eWBNB] && token1 != _mapAddr[AddrIndex.eWBNB]) {
            return 0;
        }
        (uint112 _reserve0, uint112 _reserve1, ) = IPancakePair(_mapAddr[AddrIndex.ePoolBNB]).getReserves();
        uint256 balancea = _reserve0;
        uint256 balanceb = _reserve1;
            
        if(token0 == lpToken){
            balancec = _reserve3;
            balanced = _reserve4;
        }
        if (balancea == 0 || balanceb == 0 || balanced == 0) {
            return 0;
        } 
        return balancec.mul(1e18).div(balancea.mul(balanced).div(balanceb));
    }

    
    function getExchangeCountOfOneUsdt(address lpToken, address poolAddr)
        public
        view
        returns (uint256)
    {
        if (lpToken == _mapAddr[AddrIndex.eUsdtAddr]) {
            return 1e18;
        }
    
        // BNB or GOAT
        if (poolAddr == _mapAddr[AddrIndex.ePoolBNB] || poolAddr == _mapAddr[AddrIndex.ePoolGoat]) {
            return getExchangeCountOfOneUsdtA(poolAddr);
        } else {
            return getExchangeCountOfOneUsdtB(lpToken, poolAddr);
        }
    }

    function getPower(
        address lpToken, 
        address poolAddr,
        uint256 amount,  
        uint256 lpScale 
    ) public view returns (uint256) {
        uint256 rate = getHashRateByPct(lpToken, lpScale);
        uint256 hashRate =
            amount.mul(1e20).mul(rate).div(100).div(lpScale).div(
                getExchangeCountOfOneUsdt(lpToken, poolAddr)
            );
        return hashRate;
    }

    function getLpPayGoat(
        address lpToken, 
        address poolAddr,
        uint256 amount, 
        uint256 lpScale 
    ) public view returns (uint256) {
        require(lpScale <= 100);
     
        uint256 hashRate =
            amount.mul(1e20).div(lpScale).div(
                getExchangeCountOfOneUsdt(lpToken, poolAddr)
            );
        
        uint256 costGoat =
            hashRate
                .mul(getExchangeCountOfOneUsdt(address(0), _mapAddr[AddrIndex.ePoolGoat]))
                .mul(100 - lpScale)
                .div(1e20);
        return costGoat;
    }

    function getOneshareNow() public view returns (uint256) {
        
        if (_mapUint256[Uint256Index.eLastUpdateBlock] == 0 || _mapUint256[Uint256Index.eTotalHashRate] == 0) {
            return 0;
        }

        uint256 oneShare = _mapUint256[Uint256Index.eOneShareGet];
        
        if (block.number > _mapUint256[Uint256Index.eLastUpdateBlock]) {
            uint256 bls = block.number.sub(_mapUint256[Uint256Index.eLastUpdateBlock]);
            uint256 scale = _mapUint256[Uint256Index.eOneShareScale];
            uint256 perBlockCnt = getPerBlockCount();
            uint256 totalHash = _mapUint256[Uint256Index.eTotalHashRate];
            uint256 addOneShare = 0;
            if (totalHash > 0) {
                // perBlockCnt scale is le25
                addOneShare = scale.div(totalHash).mul(bls).mul(perBlockCnt).div(1e25);
                oneShare = oneShare.add(addOneShare);
            } 
        }
        
        return oneShare;
    }

    function getPendingCoin(address user) public view returns (uint256) {
        if (_mapUint256[Uint256Index.eLastUpdateBlock] == 0) {
            return 0;
        }

        uint256 myHash = _userInfo[user][UserIndex.eSelfHash].add(_userInfo[user][UserIndex.eTeamHash]);  
        uint256 oneShare = getOneshareNow();
        
        if (myHash > 0) {
            uint256 cashed = _userInfo[user][UserIndex.eTakedCoin];
            uint256 newCash = 0;
            if (oneShare > cashed) {
                newCash = myHash.mul(oneShare.subBe0(cashed)).div(1e32);
            }
            return _userInfo[user][UserIndex.ePendingCoin].add(newCash);
        } else {
            return _userInfo[user][UserIndex.ePendingCoin];
        }
    }
    
    
    function getPendingReward(address user) public view returns(uint256, uint256) {
        uint256 coin = getPendingCoin(user);
        return (coin, _userInfo[user][UserIndex.ePendingRebate]);
    }

    function userHashChanged(
        address user,
        uint256 selfHash,
        uint256 teamHash,
        bool isAdd
    ) private {
        uint256 totalHash = _userInfo[user][UserIndex.eSelfHash].add(_userInfo[user][UserIndex.eTeamHash]);
        if (totalHash > 0) {
            _userInfo[user][UserIndex.ePendingCoin] = getPendingCoin(user);
        }
        _userInfo[user][UserIndex.eTakedCoin] = getOneshareNow();

        if (selfHash > 0) {
            if (isAdd) {
                _userInfo[user][UserIndex.eSelfHash] = _userInfo[user][UserIndex.eSelfHash].add(selfHash);
            } else {
                _userInfo[user][UserIndex.eSelfHash] = _userInfo[user][UserIndex.eSelfHash].subBe0(selfHash);
            }
        }
        if (teamHash > 0) {
            if (isAdd) {
                _userInfo[user][UserIndex.eTeamHash] = _userInfo[user][UserIndex.eTeamHash].add(teamHash);
            } else {
                _userInfo[user][UserIndex.eTeamHash] = _userInfo[user][UserIndex.eTeamHash].subBe0(teamHash);
            }
        }
    }

    //get mint count per block, scale 1e25
    function getPerBlockCount() internal view returns (uint256) {
        uint256 value = 1;
        uint256 totalLpHashRate = _mapUint256[Uint256Index.eTotalLpHashRate];
        // max 8.56 
        if (totalLpHashRate >= 1e25) {
            return value.mul(1e25).mul(856).div(100);
        }
        return value.mul(totalLpHashRate).mul(856).div(100);
    }
    
    function logCheckPoint(uint256 hashRate, bool isAdd) private {
        uint256 lastUpdateBlock = _mapUint256[Uint256Index.eLastUpdateBlock];
        if (block.number > lastUpdateBlock) {
            // total mint
            uint256 bls = block.number.sub(lastUpdateBlock);
            uint256 perBlockCnt = getPerBlockCount();
            _mapUint256[Uint256Index.eTotalMint] = _mapUint256[Uint256Index.eTotalMint].add(bls.mul(perBlockCnt));
            
            uint256 addOneShare = 0;
            uint256 totalHashRate = _mapUint256[Uint256Index.eTotalHashRate];
            uint256 scale = _mapUint256[Uint256Index.eOneShareScale];
            if (totalHashRate > 0) {
                addOneShare = scale.div(totalHashRate).mul(bls).mul(perBlockCnt).div(1e25);
            }
            
            _mapUint256[Uint256Index.eOneShareGet] = _mapUint256[Uint256Index.eOneShareGet].add(addOneShare);
            _mapUint256[Uint256Index.eLastUpdateBlock] = block.number;
        }
        
        if (isAdd) {
            _mapUint256[Uint256Index.eTotalHashRate] = _mapUint256[Uint256Index.eTotalHashRate].add(hashRate);
        } else {
            _mapUint256[Uint256Index.eTotalHashRate] = _mapUint256[Uint256Index.eTotalHashRate].subBe0(hashRate);
        }
    }

    function changeTeamhash(
        address user,
        uint256 hashRate,
        bool isAdd
    ) private {
        
        uint256 incHash = 0;
        uint256 decHash = 0;
        uint256 userNewHash = _userInfo[user][UserIndex.eSelfHash];
        if (isAdd) {
            userNewHash = userNewHash.add(hashRate);
        } else {
            userNewHash = userNewHash.subBe0(hashRate);
        }
        address parent = user;
        
        for (uint256 i = 0; i < 20; i++) {
            parent = getParent(parent);
            if (parent == address(0) || parent == _mapAddr[AddrIndex.eTopParent]) {
                break;
            }
            // level 0
            uint256 level = _userInfo[parent][UserIndex.eUserLevel];
            if (level == 0) {
                continue;
            }
            
            uint256 totalHash = userNewHash;
            uint256 parentHash = _userInfo[parent][UserIndex.eSelfHash].mul(_mapUint256[Uint256Index.eThresholdMutiple]).div(100);
            if (parentHash < userNewHash) {
                totalHash = parentHash;
            }
            
            uint256 diff = _userChildTotal[parent][user];
            if (totalHash > diff) {
                uint256 baseHash = totalHash.sub(diff);
                _userLevelHash[parent][i] = _userLevelHash[parent][i].add(baseHash);
                uint256 pct = _levelConfig[level][i];
                if (pct > 0) {
                    uint256 changeHash = baseHash.mul(pct).div(1000);
                    if (changeHash > 0) {
                        incHash = incHash.add(changeHash);
                        userHashChanged(parent, 0, changeHash, true);
                    }
                }
            } else {
                uint256 baseHash = diff.subBe0(totalHash);
                _userLevelHash[parent][i] = _userLevelHash[parent][i].subBe0(baseHash);
                uint256 pct = _levelConfig[level][i];
                if (pct > 0) {
                    uint256 changeHash = baseHash.mul(pct).div(1000);
                    if (changeHash > 0) {
                        decHash = decHash.add(changeHash);
                        userHashChanged(parent, 0, changeHash, false);
                    }
                }
            }
            _userChildTotal[parent][user] = totalHash;
        }

        userHashChanged(user, hashRate, 0, isAdd);
        if (isAdd) {
            if (hashRate.add(incHash) > decHash) {
                logCheckPoint(hashRate.add(incHash).sub(decHash), true);
            } else {
                logCheckPoint(decHash.subBe0(hashRate.add(incHash)), false);
            }
            _mapUint256[Uint256Index.eTotalLpHashRate] = _mapUint256[Uint256Index.eTotalLpHashRate].add(hashRate);
        } else {
            if (hashRate.add(decHash) > incHash) {
                logCheckPoint(hashRate.add(decHash).sub(incHash), false);
            } else {
                logCheckPoint(incHash.subBe0(hashRate.add(decHash)), true);
            }
            _mapUint256[Uint256Index.eTotalLpHashRate] = _mapUint256[Uint256Index.eTotalLpHashRate].subBe0(hashRate);
        }
    }

    
    function withdrawReward(address user) public onlyMiner returns (uint256, uint256) {
        require(_mapUint256[Uint256Index.eLastUpdateBlock] > 0, "not start");
       
        uint256 reward = getPendingCoin(user);

        _userInfo[user][UserIndex.ePendingCoin] = 0;
        _userInfo[user][UserIndex.eTakedCoin] = getOneshareNow();
        // 1% fee
        uint256 fee = reward.div(100);
        _mapUint256[Uint256Index.eLpBurn] = _mapUint256[Uint256Index.eLpBurn].add(fee);
        _userInfo[user][UserIndex.eBurnGoat] = _userInfo[user][UserIndex.eBurnGoat].add(fee);
        reward = reward.subBe0(fee);
        
        return (reward, fee);
    }
    
    // take rebate 
    function withdrawRebate(address user) public onlyMiner returns (uint256, uint256) {
        uint256 reward = _userInfo[user][UserIndex.ePendingRebate];
        require(reward >= 100);
        _userInfo[user][UserIndex.ePendingRebate] = 0;
        
        uint256 fee = reward.div(100);
        reward = reward.subBe0(fee);
        return (reward, fee);
    }

    // user take back 
    function takeBack(
        address user, 
        address lpToken,
        uint256 pct,
        uint256 burnGoat
    )  public onlyMiner  {
        
        uint256 totalHash = _userLpHash[user][lpToken];
        uint256 decHash = totalHash.mul(pct).div(100);
        _userLpHash[user][lpToken] = _userLpHash[user][lpToken].subBe0(decHash);
        changeTeamhash(user, decHash, false);
        if (burnGoat > 0) {
            _mapUint256[Uint256Index.eLpBurn] = _mapUint256[Uint256Index.eLpBurn].add(burnGoat);
            _userInfo[user][UserIndex.eBurnGoat] = _userInfo[user][UserIndex.eBurnGoat].add(burnGoat);
        }
    }

    // user deposit
    function deposit(
        address user,
        address lpToken,
        uint256 hashRate
    ) public  onlyMiner  {
        require(_mapUint256[Uint256Index.eLastUpdateBlock] > 0, "not init");
        changeTeamhash(user, hashRate, true);
        _userLpHash[user][lpToken] = _userLpHash[user][lpToken].add(hashRate);
    }
}