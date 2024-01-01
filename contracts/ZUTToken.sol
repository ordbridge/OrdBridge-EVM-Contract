// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title ZUTToken contract
 *
 * @notice ZUTToken is a simple ERC20 token with mint/burn functions and a maximum supply limit
 */
contract ZUTToken is Ownable, ERC20 {
    using Strings for string;

    uint256 private immutable _maxSupply;
    uint256 private _currentMinted;

    constructor(
        string memory name,
        uint256 initialMaxSupply
    ) ERC20(concat("Wrapped-", name), concat("w", name)) {
        _maxSupply = initialMaxSupply;
    }

    function concat(
        string memory a,
        string memory b
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    function currentlyMintedSupply() public view returns (uint256) {
        return _currentMinted;
    }

    function mintTo(address to, uint256 amount) external onlyOwner {
        require(
            _currentMinted + amount <= _maxSupply,
            "Exceeds maximum supply"
        );
        _mint(to, amount);
        _currentMinted += amount;
    }

    function burnFrom(address fromAddress, uint256 amount) external onlyOwner {
        _burn(fromAddress, amount);
        _currentMinted -= amount;
    }
}
