// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    mapping(address => bool) private _authorizedContract;
    mapping(address => uint256) public totalDistributed;
    uint256 public maxDistributionPerWallet = 100 * 1e18;
    error TokenUnauthorizedAccount(address account);

    modifier onlyAuthorizedContract() {
        _checkAuthorized();
        _;
    }

    function _checkAuthorized() internal view {
        if (!_authorizedContract[msg.sender]) {
            revert TokenUnauthorizedAccount(address(msg.sender));
        }
    }

    function setAuthorizedContract(address _contract) external onlyOwner {
        _authorizedContract[_contract] = true;
    }

    constructor(
        uint256 initialSupply
    ) ERC20("IQryptoToken", "Ypto") Ownable(msg.sender) {
        _mint(address(this), initialSupply);
    }

    function distribute(
        address to,
        uint256 amount
    ) external onlyOwner returns (bool) {
        uint256 bal = balanceOf(address(this));
        require(bal >= amount, "Token: insufficient contract balance");
        _transfer(address(this), to, amount);
        return true;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);

        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _spendAllowance(sender, _msgSender(), amount);

        _transfer(sender, recipient, amount);

        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, value);
        return true;
    }

    function transferGenerationNumber(
        address generatorWallet
    ) external onlyAuthorizedContract returns (bool) {
        uint256 totalAmount = (balanceOf(address(this)) * (10 ** 18)) /
            (2 * totalSupply());
        require(
            totalDistributed[generatorWallet] + totalAmount <=
                maxDistributionPerWallet,
            "Limit reached"
        );

        uint256 toGenerator = (totalAmount * 80) / 100;
        uint256 toOwner = totalAmount - toGenerator;

        totalDistributed[generatorWallet] += toGenerator;

        _transfer(address(this), generatorWallet, toGenerator);
        _transfer(address(this), owner(), toOwner);
        return true;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
