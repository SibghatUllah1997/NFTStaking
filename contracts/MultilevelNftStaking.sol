// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IRewardsToken.sol";

contract MultilevelNftStaking is Ownable, ReentrancyGuard {
    using Address for address;

    uint256 public lockPeriod;

    struct LockInfo {
        address owner;
        uint256 lockedTime;
        uint256 claimedRewards;
        bool isUnlocked;
        IERC721 contractAddress;
    }
    // mapping collection address => tokenId => LockInfo
    mapping(IERC721 => mapping(uint256 => LockInfo)) public lockInfo;


       //  to save a token Info
   struct stakeNftInfo{
       IRewardsToken rewardsToken;
       uint256 rewardsPerWave;  
       uint256 rewardPercentage;
    }

    mapping(IERC721 => stakeNftInfo) public nftInfo;
   

    /** CONSTANTS */
    uint256 public WAVE;
    

    //-------------------------------------------------------------------------
    // EVENTS
    //-------------------------------------------------------------------------
    event LockPeriodUpdated(uint256 lockPeriod);
    event NFTLocked(address indexed owner, uint256[] tokenIds);
    event NFTUnLocked(address indexed owner, uint256[] tokenIds);
    event RewardsClaimed(address indexed owner, uint256[] tokenIds, uint256 rewards);
    event AddStaking(address collection, address rewardToken, uint256 rewardPerWave, uint256 _rewardPercentage);

    constructor(

        uint256 _lockPeriod,
        uint256 _wave 

    ) {
        require(_lockPeriod > 0, "Invalid lock period");

        lockPeriod = _lockPeriod;
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
     * @dev add the address NFT staking addresses and their corresponders
     * @param _stakeNFT, _rewardsToken, _rewardPerWave, _rewardPercentage
     */
    function addStakingNfts(
        address [] memory _stakeNFT,
        address [] memory _rewardsToken,
        uint256 [] memory _rewardPerWave,
        uint256 [] memory _rewardPercentage

    ) public onlyOwner{

        for (uint i = 0; i < _stakeNFT.length; i++) {
            require(_stakeNFT[i] != address(0), "Invalid Stake Token");
            require(_rewardsToken[i] != address(0), "Invalid Reward Token");
            require(IERC721(_stakeNFT[i]).supportsInterface(0x80ac58cd), "Non-erc721");

            nftInfo[IERC721(_stakeNFT[i])].rewardsToken = IRewardsToken(_rewardsToken[i]);
            nftInfo[IERC721(_stakeNFT[i])].rewardsPerWave = _rewardPerWave[i];
            nftInfo[IERC721(_stakeNFT[i])].rewardPercentage = _rewardPercentage[i];
            
            emit AddStaking(_stakeNFT[i],_rewardsToken[i], _rewardPerWave[i],_rewardPercentage[i]);
    }
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
    function claimedRewards(uint256 _tokenId, IERC721 nftAddress) external view returns (uint256) {
        return lockInfo[IERC721(nftAddress)][_tokenId].claimedRewards;
    }

    /** MUTATIVE FUNCTIONS */
    /**
     * @dev lock NFT into the contract
     * @param _tokenIds token ids to stake
     */
    function lockNFT(uint256[] calldata  _tokenIds, IERC721 nftAddress ) external notContract nonReentrant {

        require(nftInfo[nftAddress].rewardsToken != IRewardsToken(0x0000000000000000000000000000000000000000), "Staking: Register collection by addStakingNfts");
        require(_tokenIds.length > 0, "No tokens");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(nftAddress.ownerOf(_tokenIds[i]) == msg.sender, "You don't hold this token");
            nftAddress.transferFrom(msg.sender, address(this), _tokenIds[i]);
            lockInfo[IERC721(nftAddress)][_tokenIds[i]] = LockInfo(msg.sender, block.timestamp, 0, false,IERC721(nftAddress));
        }

        emit NFTLocked(msg.sender, _tokenIds);
    }

    /**
     * @dev unlock NFT from the contract
     * @param _tokenIds token ids to unlock
     */
    function unlockNFT(uint256[] calldata _tokenIds, IERC721 nftAddress) external notContract nonReentrant {
        require(nftInfo[nftAddress].rewardsToken != IRewardsToken(0x0000000000000000000000000000000000000000), "Staking: Register collection by addStakingNfts");
        require(_tokenIds.length > 0, "No tokens");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            LockInfo memory info = lockInfo[IERC721(nftAddress)][_tokenIds[i]];
            require(info.owner == msg.sender, "Not a token owner");
            require(info.lockedTime + lockPeriod < block.timestamp, "Not able to unlock yet");
            require(!info.isUnlocked, "Already unlocked");

            nftAddress.transferFrom(address(this), msg.sender, _tokenIds[i]);

            uint256 totalAmount = _rewardAmount(_tokenIds[i], nftAddress);
            uint256 unclaminedAmount = totalAmount - info.claimedRewards;
             nftInfo[nftAddress].rewardsToken.mint(msg.sender, unclaminedAmount);

            lockInfo[IERC721(nftAddress)][_tokenIds[i]].claimedRewards = totalAmount;
            lockInfo[IERC721(nftAddress)][_tokenIds[i]].isUnlocked = true;
        }

        emit NFTUnLocked(msg.sender, _tokenIds);
    }

    /**
     * @dev claim rewards
     * @param _tokenIds token ids to unlock
     */
    function claimRewards(uint256[] calldata _tokenIds,IERC721 nftAddress) external notContract {
        require(nftInfo[nftAddress].rewardsToken != IRewardsToken(0x0000000000000000000000000000000000000000), "Staking: Register collection by addStakingNfts");
        require(_tokenIds.length > 0, "No tokens");

        uint256 totalRewards;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            LockInfo memory info = lockInfo[IERC721(nftAddress)][_tokenIds[i]];
            require(info.owner == msg.sender, "Not a token owner");
            require(info.lockedTime + lockPeriod < block.timestamp, "Not able to claim yet");
            require(!info.isUnlocked, "Already unlocked");

            uint256 totalAmount = _rewardAmount(_tokenIds[i], nftAddress);
            uint256 unclaminedAmount = totalAmount - info.claimedRewards;
            nftInfo[nftAddress].rewardsToken.mint(msg.sender, unclaminedAmount);
            totalRewards += unclaminedAmount;

            lockInfo[IERC721(nftAddress)][_tokenIds[i]].claimedRewards = totalAmount;
        }

        emit RewardsClaimed(msg.sender, _tokenIds, totalRewards);
    }

    /**
     * @dev calculate reward amount
     */
    function _rewardAmount(uint256 _tokenId, IERC721 nftAddress) internal view returns (uint256) {
        LockInfo memory info = lockInfo[IERC721(nftAddress)][_tokenId];
        uint256 stakingDuration = block.timestamp - info.lockedTime;
        uint256 totalAmount;

        if (stakingDuration < lockPeriod) {
            return 0;
        } else {
            totalAmount = ( nftInfo[nftAddress].rewardsPerWave * (stakingDuration - lockPeriod)) / WAVE;
            return totalAmount;
        }
    }
}
