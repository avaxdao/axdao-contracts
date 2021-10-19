// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "../@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../@openzeppelin/contracts/utils/Strings.sol";
import "../@openzeppelin/contracts/access/Ownable.sol";

contract AxMutation is ERC1155, Ownable {
    using Strings for uint256;
    
    uint private constant mark2MutationId = 1;
    uint private constant megaMutationId = 69;

    uint[] public mutableMutantIds;
    address private mutantAxApesAddress;
    string private baseURI;

    mapping(uint => bool) private _isMutantMutable;

    constructor(string memory _baseURI) 
        ERC1155(_baseURI) 
    {
        baseURI = _baseURI;
    }

    function mintBatch(uint[] memory _ids, uint[] memory _amounts)
        external
        onlyOwner
    {
        _mintBatch(owner(), _ids, _amounts, "");
    }

    function setMutantAxApesAddress(address _mutantAxApesAddress)
        external
        onlyOwner
    {
        mutantAxApesAddress = _mutantAxApesAddress;
    }

    function burnMutation(uint _mutationId, address _account)
        external
    {
        require(
            msg.sender == mutantAxApesAddress, 
            "not mutant contract"
        );
        _burn(_account, _mutationId, 1);
    }

    function setBaseURI(string memory _uri) 
        external 
        onlyOwner
    {
        baseURI = _uri;
    }

    function uri(uint _mutationId)
        public
        view                
        override
        returns (string memory)
    {
        require(
            _mutationId == 1 || _mutationId == 69,
            "invalid mutation id"
        );
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, _mutationId.toString()))
                : baseURI;
    }

    function addMutableIds(uint _num, uint[] memory _ids) 
        external 
        onlyOwner
    {
        for (uint i = 0; i < _num; i++) {
            uint id = _ids[i];
            mutableMutantIds.push(id);
            _isMutantMutable[id] = true;
        }
    }

    function getMutableIds() 
        external 
        view
        returns (uint[] memory)
    {
        uint total = mutableMutantIds.length;
        uint[] memory ids = new uint[](total);

        for (uint i = 0; i < total; i++) {
            ids[i] = mutableMutantIds[i];
        }
        return ids;
    }

    function isMutantMutable(uint _mutantId)
        external 
        view
        returns (bool)
    {
        return _isMutantMutable[_mutantId];
    }
}