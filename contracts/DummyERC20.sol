// SCH Course Copyright Policy (C): DO-NOT-SHARE-WITH-ANYONE
// https://smartcontractshacking.com/#copyright-policy
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DummyERC20
 * @author JohnnyTime (https://smartcontractshacking.com)
 */
contract DummyERC20 is ERC20, Ownable {

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply)
     ERC20(_name, _symbol) {
        _mint(owner(), _initialSupply);
     }
}