// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "./TransparentUpgradeableProxy.sol";


contract GoatMimerPart1Proxy is TransparentUpgradeableProxy {
    constructor(address _implementation, address _admin, bytes memory _data)
     TransparentUpgradeableProxy(_implementation, _admin, _data){}
}