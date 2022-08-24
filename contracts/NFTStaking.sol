// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IRewardsToken.sol";

contract NFTStaking1 is Ownable, ReentrancyGuard {
    using Address for address;
    // Interfaces for ERC20 and ERC721
    IRewardsToken public immutable rewardsToken;
    IERC721 public immutable stakeNFT;

    uint256 public lockPeriod;

    struct LockInfo {
        address owner;
        uint256 lockedTime;
        uint256 claimedRewards;
        bool isUnlocked;
    }
    // mapping tokenId => LockInfo
    mapping(uint256 => LockInfo) internal lockInfo;

    /** CONSTANTS */
    uint256 public WAVE;
    uint256 public rewardsPerWave;

    //-------------------------------------------------------------------------
    // EVENTS
    //-------------------------------------------------------------------------
    event LockPeriodUpdated(uint256 lockPeriod);
    event NFTLocked(address indexed owner, uint256[] tokenIds);
    event NFTUnLocked(address indexed owner, uint256[] tokenIds);
    event RewardsClaimed(address indexed owner, uint256[] tokenIds, uint256 rewards);

    constructor(
        address _stakeNFT,
        address _rewardsToken,
        uint256 _lockPeriod,
        uint256 _rewardPerWave,
        uint256 _wave 

    ) {
        require(_rewardsToken != address(0), "Invalid reward token");
        require(_stakeNFT != address(0), "Invalid stake NFT");
        require(IERC165(_stakeNFT).supportsInterface(0x80ac58cd), "Non-erc721");
        require(_lockPeriod > 0, "Invalid lock period");

        rewardsToken = IRewardsToken(_rewardsToken);
        stakeNFT = IERC721(_stakeNFT);
        lockPeriod = _lockPeriod;
        rewardsPerWave = _rewardPerWave;
        WAVE = _wave;
    }

    /** MODIFIERS */
    modifier notContract() {
        require(!address(msg.sender).isContract(), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    /** SETTERS */
    /**
     * @dev update lock period
     * @param _lockPeriod lock period to set
     */
    function setLockPeriod(uint256 _lockPeriod) external onlyOwner {
        require(_lockPeriod > 0, "Invalid lock period.");
        lockPeriod = _lockPeriod;

        emit LockPeriodUpdated(_lockPeriod);
    }

    /** VIEW FUNCTIONS */
    /**
     * @dev get total claimed rewards for token id
     * @param _tokenId token id to get claimed Rewards amount
     */
    function claimedRewards(uint256 _tokenId) external view returns (uint256) {
        return lockInfo[_tokenId].claimedRewards;
    }

    /** MUTATIVE FUNCTIONS */
    /**
     * @dev lock NFT into the contract
     * @param _tokenIds token ids to stake
     */
    function lockNFT(uint256[] calldata _tokenIds) external notContract nonReentrant {
        require(_tokenIds.length > 0, "No tokens");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(stakeNFT.ownerOf(_tokenIds[i]) == msg.sender, "You don't hold this token");
            stakeNFT.transferFrom(msg.sender, address(this), _tokenIds[i]);
            lockInfo[_tokenIds[i]] = LockInfo(msg.sender, block.timestamp, 0, false);
        }

        emit NFTLocked(msg.sender, _tokenIds);
    }

    /**
     * @dev unlock NFT from the contract
     * @param _tokenIds token ids to unlock
     */
    function unlockNFT(uint256[] calldata _tokenIds) external notContract nonReentrant {
        require(_tokenIds.length > 0, "No tokens");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            LockInfo memory info = lockInfo[_tokenIds[i]];
            require(info.owner == msg.sender, "Not a token owner");
            require(info.lockedTime + lockPeriod < block.timestamp, "Not able to unlock yet");
            require(!info.isUnlocked, "Already unlocked");

            stakeNFT.transferFrom(address(this), msg.sender, _tokenIds[i]);

            uint256 totalAmount = _rewardAmount(_tokenIds[i]);
            uint256 unclaminedAmount = totalAmount - info.claimedRewards;
            rewardsToken.mint(msg.sender, unclaminedAmount);

            lockInfo[_tokenIds[i]].claimedRewards = totalAmount;
            lockInfo[_tokenIds[i]].isUnlocked = true;
        }

        emit NFTUnLocked(msg.sender, _tokenIds);
    }

    /**
     * @dev claim rewards
     * @param _tokenIds token ids to unlock
     */
    function claimRewards(uint256[] calldata _tokenIds) external notContract {
        require(_tokenIds.length > 0, "No tokens");

        uint256 totalRewards;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            LockInfo memory info = lockInfo[_tokenIds[i]];
            require(info.owner == msg.sender, "Not a token owner");
            require(info.lockedTime + lockPeriod < block.timestamp, "Not able to claim yet");
            require(!info.isUnlocked, "Already unlocked");

            uint256 totalAmount = _rewardAmount(_tokenIds[i]);
            uint256 unclaminedAmount = totalAmount - info.claimedRewards;
            rewardsToken.mint(msg.sender, unclaminedAmount);
            totalRewards += unclaminedAmount;

            lockInfo[_tokenIds[i]].claimedRewards = totalAmount;
        }

        emit RewardsClaimed(msg.sender, _tokenIds, totalRewards);
    }

    /**
     * @dev calculate reward amount
     */
    function _rewardAmount(uint256 _tokenId) internal view returns (uint256) {
        LockInfo memory info = lockInfo[_tokenId];
        uint256 stakingDuration = block.timestamp - info.lockedTime;
        uint256 totalAmount;

        if (stakingDuration < lockPeriod) {
            return 0;
        } else {
            totalAmount = (rewardsPerWave * (stakingDuration - lockPeriod)) / WAVE;
            return totalAmount;
        }
    }
}
