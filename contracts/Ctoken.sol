pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

interface ICtoken is IERC20 {
    function mint(uint256 amount) external;
    function burn(uint256 amount) external;
}

contract Ctoken is ERC20 {
    IERC20 public oToken;
    address public factory;

    constructor(
        string memory name,
        string memory symbol,
        address token
    )
        ERC20(
            string(abi.encodePacked("c", name)),
            string(abi.encodePacked("c", symbol))
        )
    {
        oToken = IERC20(token);
        factory = msg.sender;
    }

    function mint(uint256 amount) public {
        require(msg.sender == factory, "ONLY Factory");
        _mint(factory, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
