// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakeNFT is ERC721A, Ownable {
    string private _baseTokenURI;

    /** EVENTS */
    event TokenMinted(address indexed to, uint256 amount);

    constructor(string memory _baseuri) ERC721A(" NFT 3", "2") {
        _baseTokenURI = _baseuri;
    }

    /** VIEW FUNCTIONS */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    /** MUTATIVE FUNCTIONS */

    function ownerMint(address _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Invalid address");

        _mint(_to, _amount);

        emit TokenMinted(_to, _amount);
    }
}
