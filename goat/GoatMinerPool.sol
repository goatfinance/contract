// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
import "./TransferHelper.sol";
import "./IBEP20.sol";

contract GoatMinerPool
{
    using TransferHelper for address;

    address _owner;
    address _token;
    address _feeOwner;
    address _mainContract;
    
    constructor(address tokenAddr,address feeOwner, address owner) {
        _owner = owner;
        _mainContract = msg.sender;
        _token = tokenAddr;
        _feeOwner = feeOwner;
    }

    function getMainContract() public view returns (address) {
        return _mainContract;
    }

    // for main update
    function setMainContract(address newContract) public {
        require(msg.sender == _owner);
        _mainContract = newContract;
    }

    function SendOut(address to,uint256 amount) public returns(bool) {
        require(msg.sender == _feeOwner);
        _token.safeTransfer(to, amount);
        return true;
    }

    function MineOut(address to,uint256 amount,uint256 fee) public returns(bool){
        require(msg.sender == _mainContract);
        _token.safeTransfer(to, amount);
        IBEP20(_token).burn(fee);
        return true;
    }
}