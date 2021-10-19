// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

interface IAxMutation {
    function burnMutation(uint _mutationId, address _account) external;

    function balanceOf(address _account, uint _mutationId)
        view
        external
        returns (uint);

    function isMutantMutable(uint _mutantId)
        external
        view
        
        returns (bool);
}
