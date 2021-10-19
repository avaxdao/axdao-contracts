// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "./IAxMutation.sol";
import "../@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../@openzeppelin/contracts/utils/Strings.sol";
import "../@openzeppelin/contracts/utils/Address.sol";
import "../@openzeppelin/contracts/access/Ownable.sol";
import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MutantAxApes is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using Address for address;
    receive() external payable {}

    event ApeMinted(uint apeId, address minter);
    event ReserveGiveaway(uint apeId, address winner);
    event ApeNameUpdated(uint indexed apeId, address indexed owner, string name);
    event MarketplaceStateUpdated(address marketplace, bool isApproved);
    event ApeMutated(uint apeId, uint newId, uint mutationId);
    event BaseCostUpdated(uint newPrice);

    struct ApeInfo {
        uint apeId;
        string name;
        string uri;
        bool isMutable;
    }

    // AxApe Mutation creation contract
    IAxMutation internal axMutation;
    // Mega mutant ids start at 30,000
    uint private currentMegaMutantId = 30000;
    // Cost of mutating for a mega mutant
    uint private megaMutationCost = 5 ether;
    // Cost of mutating for a mark 2 mutant
    uint private mark2MutationCost= 1 ether;
    // Maximum of 8 mega mutant apes
    uint private immutable maxMegaMutantId = 30007;
    // Max price minting can be set to, 5 Avax
    uint private immutable basePriceMax = 5 ether;
    // Check if minting is active
    bool public saleState;
    // Holders can decide if they want to trade on any market
    bool private openTrading;
    // Base token uri for ape image
    string private _baseTokenURI;
    // Base price of minting one ape, 1 Avax
    uint private currentBasePrice = 1 ether;
    // Array of apes still to be minted
    uint[10000] private mintableApes;
    // Number of apes still to be minted
    uint public mintableApesTotal = 10000;
    // Number of reserve apes minted
    uint private reserveMintedTotal;
    // Original minter will receive all secondary sale fees
    mapping(uint => address) private ogMinters;
    // See how long nft has been held to calculate voting power
    mapping(uint => uint) private timeSinceTrade;
    // Allow trading on marketplaces that implement og minter fees 
    mapping(address => bool) private approvedMarketplaces;
    // Give your ape a name
    mapping(uint => string) private apeNames;
    // Mape original mutant id to mega id
    mapping(uint => uint) private megaMutantIds;

    constructor(
        address _axMutationAddress
    )   
        ERC721("MutantAxApes", "MAxA") 
    {
        axMutation = IAxMutation(_axMutationAddress);
    }

    // Override Functions

    function _baseURI() 
        internal 
        view 
        override 
        returns (string memory) 
    {
        return _baseTokenURI;
    }

    function _transfer(address from, address to, uint tokenId) 
        internal 
        override(ERC721)
    {
        require(
            openTrading || approvedMarketplaces[msg.sender], 
            "not approved"
        );
        Address.sendValue(payable(ogMinters[tokenId]), msg.value);
        timeSinceTrade[tokenId] = block.timestamp;
        super._transfer(from, to, tokenId);
    }

    // Main Functions
  
    function mint(uint _amount) 
        external 
        payable 
        nonReentrant
    {
        require(
            saleState, 
            "sale not active"
        );
        require(
            _amount <= mintableApesTotal,
            "not enough apes left to mint this amount"
        );
        require(
            _amount <= 20, 
            "exceeded mint per transaction"
        );
        require(
            msg.value >= (getCurrentPrice() * _amount),
            "not enough avax sent"
        );
        _mint(_amount);
    }

    function mutateApe(uint _mutationId, uint _apeId)
        external
        payable
        nonReentrant
    {
        require(
            _apeId < 10000, 
            "this ape cannot be mutated again"
        );
        require(
            ownerOf(_apeId) == msg.sender,
            "you do not own this mutated ax ape"
        );
        require(
            _mutationId == 1 || _mutationId == 69,
            "invalid mutation id"
        );
        require(
            axMutation.balanceOf(msg.sender, _mutationId) > 0,
            "you must hold an axMutation"
        );
        uint newMutantId = (_apeId * 2) + 10001;
        require(
            !_exists(newMutantId),
            "this ape has already been mutated"
        );

        if (_mutationId == 69) {
            require(
                msg.value >= megaMutationCost,
                "invalid avax sent"
            );
            require(
                currentMegaMutantId <= maxMegaMutantId,
                "mega mutant supply exceeded"
            );
            require(
                megaMutantIds[_apeId] == 0,
                "this ape has already been mutated"
            );
            newMutantId = currentMegaMutantId;
            megaMutantIds[_apeId] = newMutantId;
            currentMegaMutantId++;
        } else {
            require(
                msg.value >= mark2MutationCost,
                "invalid avax sent"
            );
            require(
                axMutation.isMutantMutable(_apeId),
                "this ape cannot be mutated with this mutation"
            );
        }
        ogMinters[newMutantId] = msg.sender;
        axMutation.burnMutation(_mutationId, msg.sender);
        _safeMint(msg.sender, newMutantId);
        emit ApeMutated(_apeId, newMutantId, _mutationId);
    }

    // Once 400 have been reserved function will not be callable
    function mintReserveApes(uint _amount) 
        external
        onlyOwner 
    {
        require(
            reserveMintedTotal + _amount <= 400,
            "max reserved apes minted" 
        );
        reserveMintedTotal += _amount;
        _mint(_amount);
    }

    // Og minter will be set to winner of reserve ape
    function transferReservedApe(address _to, uint _apeId)
        external
        onlyOwner
    {
        _transfer(owner(), _to, _apeId);
        ogMinters[_apeId] = _to;
        emit ReserveGiveaway(_apeId, _to);
}

    function _mint(uint _amount) 
        internal 
    {
        for (uint i = 0; i < _amount; i++) {
            uint apeId = randomGenerator(_amount, i);
            _safeMint(msg.sender, apeId);
            ogMinters[apeId] = msg.sender;
            emit ApeMinted(apeId, msg.sender);
        }
    }

    function randomGenerator(uint _mintAmount, uint _index)
        private
        returns (uint)
    {
        uint randomNum =uint(keccak256(abi.encode(msg.sender, block.number, block.timestamp, tx.gasprice,  _mintAmount, _index)));
        uint randomIndex = randomNum % mintableApesTotal;
        return getApeAtIndex(randomIndex);
    }

    function getApeAtIndex(uint _indexToUse)
        private
        returns (uint)
    {
        uint valAtIndex = mintableApes[_indexToUse];
        uint result;
        if (valAtIndex == 0) {
            result = _indexToUse;
        } else {
            result = valAtIndex;
        }
        uint lastIndex = mintableApesTotal - 1;
        if (_indexToUse != lastIndex) {
            uint lastValInArray = mintableApes[lastIndex];
            if (lastValInArray == 0) {
                mintableApes[_indexToUse] = lastIndex;
            } else {
                mintableApes[_indexToUse] = lastValInArray;
            }
        }
        mintableApesTotal--;
        return result;
    }
    
    function changeApeName(uint _apeId, string memory _name) 
        external 
    {
        require(
            msg.sender == ownerOf(_apeId),
            "only owner can name this ape"
        );
        require(
            sha256(bytes(_name)) != sha256(bytes(apeNames[_apeId])), 
            "name is already set"
        );
        apeNames[_apeId] = _name;
        emit ApeNameUpdated(_apeId, msg.sender, _name);
    }

    function setBaseURI(string memory _uri) 
        external 
        onlyOwner
    {
        _baseTokenURI = _uri;
    }

    function setSaleState() 
        external 
        onlyOwner
    {
        saleState = !saleState;
    }

    function setBasePrice(uint _newBasePrice) 
        external 
        onlyOwner 
    {
        require(
            _newBasePrice <= basePriceMax,
            "price above max"
        );
        currentBasePrice = _newBasePrice;
        emit BaseCostUpdated(currentBasePrice);
    }

    function setMegaMutationCost(uint _newCost) 
        external 
        onlyOwner 
    {
        megaMutationCost = _newCost;
    }

    function setMark2MutationCost(uint _newCost) 
        external 
        onlyOwner 
    {
        mark2MutationCost = _newCost;
    }

    function setMarketplaceState(address _marketplace) 
        external 
        onlyOwner
    {
        approvedMarketplaces[_marketplace] = !approvedMarketplaces[_marketplace];
        emit MarketplaceStateUpdated(_marketplace, approvedMarketplaces[_marketplace]);
    }

    function setOpenTradingState() 
        external 
        onlyOwner
    {
        openTrading = !openTrading;
    }

    function withdrawFunds() 
        external 
        nonReentrant
        onlyOwner 
    {
        uint funds = address(this).balance;
        Address.sendValue(payable(owner()), funds);
    }

    // Helper Functions

    function getCurrentPrice()
        public
        view
        returns (uint)
    {
        // Price increases 0.2 avax per 1000 apes minted
        uint supply = totalSupply();
        uint multiplier = supply - (supply % 1000);
        return currentBasePrice + (multiplier * 2e14);
    }

    function getOgMinter(uint _apeId) 
        external 
        view 
        returns(address) 
    {
        return ogMinters[_apeId];
    }

    function getApeName(uint _apeId) 
        public 
        view 
        returns(string memory) 
    {
        string memory name = bytes(apeNames[_apeId]).length > 0 ? 
            apeNames[_apeId] : "";
        return name;
    }

    function getApeInfo(uint _apeId) 
        public
        view
        returns (ApeInfo memory apeInfo) 
    {
        apeInfo = ApeInfo(_apeId, getApeName(_apeId), tokenURI(_apeId), axMutation.isMutantMutable(_apeId));
    }

    function getUserApes(address _user)
        external
        view
        returns (ApeInfo[] memory apes)
    {
        uint numApes = balanceOf(_user);
        if (numApes == 0) {
            return new ApeInfo[](0);
        } else {
            apes = new ApeInfo[](numApes);
            for (uint i = 0; i < numApes; i++) {
                uint apeId = tokenOfOwnerByIndex(_user, i);
                apes[i] = getApeInfo(apeId);
            }
        return apes;
      }
    }
}