// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
import "./SafeMath.sol";
import "./TransferHelper.sol";
import "./IBEP20.sol";

//https://docs.venus.io/docs/getstarted#guides
interface IVToken {
    function underlying() external returns (address);
    // for bep20
    function mint(uint256 mintAmount) external  returns (uint256);
    //for BNB
    function mint() external  payable ;
    function redeem(uint256 redeemTokens) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function balanceOfUnderlying(address owner) external returns (uint256);
}


//EMPTY CONTRACT TO HOLD THE USERS assetS
contract GoatWallet 
{
    using TransferHelper for address;
    address _lpToken;
    address _goatToken;
    address _mainContract;
    address _feeOwner;
    address _owner;
    address _vToken;
    uint256 _totalToken;
    uint256 _totalGoat;

    mapping(address=>uint256) _balanceToken;
    mapping(address=>uint256) _balanceGoat;

    using TransferHelper for address;
    using SafeMath for uint256;

    event eventWithDraw(address indexed to,uint256 indexed  amounta,uint256 indexed amountb);

    constructor(
        address lpToken,
        address goatToken,
        address feeOwner,
        address owner, 
        address vToken
    ) {
        _mainContract = msg.sender;
        _lpToken = lpToken;
        _goatToken = goatToken;
        _feeOwner = feeOwner;
        _owner = owner;
        _vToken = vToken;

        if (vToken != address(0) && _lpToken != address(2)) {
            // only call once
            _lpToken.safeApprove(vToken, type(uint256).max);
        }
    }
    
     // for receive BNB
    receive() external payable { }

    // for main contract update
    function setMainContract(address newContract) public {
        require(msg.sender == _owner);
        _mainContract = newContract;
    }

    function getMainContract() public view returns (address) {
        return _mainContract;
    }

    function setVToken(address vToken) public {
        require(_mainContract == msg.sender);
        if (vToken != address(0) && _lpToken != address(2) && vToken != _vToken) {
            // only call once
            _lpToken.safeApprove(vToken, type(uint256).max);
        }
        if (_vToken != vToken) {
            _vToken = vToken;
        }
    }

    function approveVToken(bool isApprove) public {
        require(_mainContract == msg.sender);
        if (_vToken == address(0) || _lpToken == address(2)) {
            return;
        }
        if (isApprove) {
             _lpToken.safeApprove(_vToken, type(uint256).max);
         } else {
             _lpToken.safeApprove(_vToken, 0);
         }
    }

    function deposite(address user, uint256 tokenAmt, uint256 goatAmt) public payable {
        require(_mainContract == msg.sender);
        _balanceToken[user] = _balanceToken[user].add(tokenAmt);
        _balanceGoat[user] = _balanceGoat[user].add(goatAmt);
        
        _totalToken = _totalToken.add(tokenAmt);
        _totalGoat = _totalGoat.add(goatAmt);

         // Venus 
        if (_vToken != address(0)) {
            if (_lpToken != address(2)) {
                uint256 code = IVToken(_vToken).mint(tokenAmt);
                require(code == 0, "Venus");
            } else {
                IVToken(_vToken).mint{value: tokenAmt}();
            }
        }
    }
    
    function getBalance(address user) public view returns (uint256, uint256){
        return (_balanceToken[user],_balanceGoat[user]);
    }

    function getBalance(address user,bool isToken) public view returns(uint256) {
        if(isToken) {
            return _balanceToken[user];
        } else {
           return _balanceGoat[user];
        }
    }

    function decBalance(address user,uint256 tokenAmt,uint256 goatAmt ) internal {
        _balanceToken[user] = _balanceToken[user].subBe0(tokenAmt);
        _balanceGoat[user] = _balanceGoat[user].subBe0(goatAmt);
        
        
        _totalToken = _totalToken.subBe0(tokenAmt);
        _totalGoat = _totalGoat.subBe0(goatAmt);
    }
    
    function getTotalLp() public view returns (uint256, uint256) {
        return (_totalToken, _totalGoat);
    }

    function redeemForTakeBack(uint256 amount) internal {
        if (_vToken == address(0)) {
            return;
        }
        // check balance 
        uint256 balance = 0;
        //BNB
        if(_lpToken != address(2)) {
            balance = IBEP20(_lpToken).balanceOf(address(this));
        } else {
            balance = address(this).balance;
        }
        if (balance >= amount) {
            return;
        }
        
        uint256 code = IVToken(_vToken).redeemUnderlying(amount);
        require(code == 0, "Venus");
    }
    
    function takeBack(address user, uint256 pct) public returns (uint256)  {
        require(_mainContract == msg.sender || msg.sender == _owner);

        (uint256 amount,uint256 amountGoat) = getBalance(user);
        amount = amount.mul(pct).div(100);
        amountGoat = amountGoat.mul(pct).div(100);
        require(amount >= 100, "amount");

        redeemForTakeBack(amount);

        uint256 burnGoat = 0 ;
        if (amountGoat >= 100) {
            // fee = 1%
            burnGoat = amountGoat.div(100);
        } 
        if (_lpToken == _goatToken && amount >= 100) {
             // fee = 1%
            burnGoat = amount.div(100);
        }

        //NOT BNB
        if(_lpToken != address(2)) {
            uint256 mainFee= amount.div(100);
            _lpToken.safeTransfer(user, amount.sub(mainFee));
            if (_lpToken != _goatToken) {
                _lpToken.safeTransfer(_feeOwner, mainFee);
            }
        } else {
            uint256 fee2 = amount.div(100);
            (bool success, ) = user.call{value: amount.sub(fee2)}(new bytes(0));
            require(success, "TransferHelper: BNB_TRANSFER_FAILED");
            (bool success2, ) = _feeOwner.call{value: fee2}(new bytes(0));
            require(success2, "TransferHelper: BNB_TRANSFER_FAILED");
        }

        if (burnGoat > 0) {
            IBEP20(_goatToken).burn(burnGoat);
        }
        if (amountGoat.subBe0(burnGoat) > 0) {
            _goatToken.safeTransfer(user, amountGoat.subBe0(burnGoat));
        }    

        decBalance(user, amount, amountGoat);
        return burnGoat;
    }

    function reedeemFromVenus(address to) public {
        require(_mainContract == msg.sender || msg.sender == _owner);
        if (_vToken == address(0)) {
            return;
        }
        uint256 balance = IBEP20(_vToken).balanceOf(address(this));
        if (balance == 0) {
            return;
        }
        uint256 code = IVToken(_vToken).redeem(balance);
        require(code == 0, "Venus");

        uint256 curBalance = 0;
        if (_lpToken == address(2)) {
            curBalance = address(this).balance;
        } else {
            curBalance = IBEP20(_lpToken).balanceOf(address(this));
        }
        if (curBalance <= _totalToken) {
            return;
        }
        uint256  earnings = curBalance.subBe0(_totalToken);
        if (_lpToken == address(2)) {
            (bool success, ) = to.call{value: earnings}(new bytes(0));
            require(success, "BNB_TRANSFER_FAILED");
        } else {
            _lpToken.safeTransfer(to, earnings);
        }
    }


    function depositeToVenus() public {
        require(_mainContract == msg.sender || msg.sender == _owner);
        if (_vToken == address(0)) {
            return;
        }
        uint256 balance = 0;
        if (_lpToken != address(2)) {
            balance = IBEP20(_lpToken).balanceOf(address(this));
        } else {
            balance = address(this).balance;
        }
        if (balance == 0) {
            return;
        }
        if (_lpToken != address(2)) {
            uint256 code = IVToken(_vToken).mint(balance);
            require(code == 0, "Venus");
        } else {
            IVToken(_vToken).mint{value: balance}();
        }
    }
}