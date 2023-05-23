/**
 *Submitted for verification at Etherscan.io on 2017-12-12
*/

// Copyright (C) 2015, 2016, 2017 Dapphub

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WETH is ERC20{

    bool private reentrancyLock;    
    constructor() ERC20("Wrapped Ether", "WETH") {}

    modifier nonReentrant() {
        require(!reentrancyLock, "Reentrant call.");
        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }    

    function mint() external payable {
        _mint(msg.sender, msg.value);
    }

    function burn(uint amount) external nonReentrant{
        payable(msg.sender).transfer(amount);
        _burn(msg.sender, amount);
    }
}
