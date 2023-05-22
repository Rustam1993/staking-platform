// SCH Course Copyright Policy (C): DO-NOT-SHARE-WITH-ANYONE
// https://smartcontractshacking.com/#copyright-policy
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


/**
 * @title DummyERC20
 * @author JohnnyTime (https://smartcontractshacking.com)
 */
contract DummyERC20 is ERC20 {

    address public owner;
    
    constructor(string memory _name, string memory _symbol)
     ERC20(_name, _symbol) {
        owner = msg.sender;
     }

     function adminMint(uint amount, address _to) external {
        require(msg.sender == owner, "Only owner");
         _mint(_to, amount);
     }
}