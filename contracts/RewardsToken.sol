// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardsToken is ERC20, Ownable {
    address public nftStakingContract;

    /** EVENTS */
    event StakingContractUpdated(address indexed nftStakingContract);
    event TokenMinted(address indexed to, uint256 amount);

    constructor(string memory tokenName,string memory tokenSymbol) ERC20(tokenName, tokenSymbol) {
    }

    /** MODIFIERS */
    modifier onlyStakingContract() {
        require(msg.sender == nftStakingContract, "Non staking contract");
        _;
    }

    /** SETTERS */
    function setNFTStakingContract(address _nftStakingContract) external onlyOwner {
        require(_nftStakingContract != address(0), "Invalid address");
        nftStakingContract = _nftStakingContract;

        emit StakingContractUpdated(_nftStakingContract);
    }

    function mint(address _to, uint256 _amount) external onlyStakingContract {
        require(_to != address(0), "Invalid address");

        _mint(_to, _amount);

        emit TokenMinted(_to, _amount);
    }
}
