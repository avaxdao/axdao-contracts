// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "../@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract AxDaoProfile is ERC721Holder {

    struct User {
        uint64 userId;
        uint64 points;
        uint64 timestamp;
        uint64 tokenId;
        address nftAddress;
        string username;
        bool isActive;
    }

    uint public activeProfileCount;
    uint64 public userCount;
    uint public registerFee;
    uint public updateFee;
    uint public pauseFee;
    uint public reactivateFee;
    address private owner;

    mapping(address => bool) private validNftAddress;
    mapping(address => bool) private approvedContract;
    mapping(address => bool) public hasRegistered;
    mapping(address => User) public users;

    event UserNew(address indexed userAddress, address nftAddress, uint tokenId, string username);
    event UserUpdate(address indexed userAddress, address nftAddress, uint tokenId);
    event UserPause(address indexed userAddress);
    event UserReactivate(address indexed userAddress, address nftAddress, uint tokenId);
    event UserPointIncrease(address indexed userAddress, uint points, uint indexed taskId);
    event UserPointDecrease(address indexed userAddress, uint points, uint indexed taskId);
    event UserPointIncreaseMultiple(address[] userAddresses, uint points, uint indexed taskId);
    event UserPointDecreaseMultiple(address[] userAddresses, uint points, uint indexed taskId);

    constructor(
        uint _pauseFee,
        uint _reactivateFee,
        address _governanceNftAddress
    ) {
        owner = msg.sender;
        pauseFee = _pauseFee;
        reactivateFee = _reactivateFee;
        validNftAddress[_governanceNftAddress] = true;
    }

    // create profile by locking a single governance nft
    function createProfile(address _nftAddress, uint64 _tokenId, string calldata _username) 
        external 
        payable 
    {
        require(
            !hasRegistered[msg.sender], 
            "already registered"
        );
        require(
            validNftAddress[_nftAddress], 
            "NFT address invalid"
        );
        require(
            msg.value >= registerFee,
            "not enough avax sent"
        );
        IERC721 nftToken = IERC721(_nftAddress);
        require(
            msg.sender == nftToken.ownerOf(_tokenId),
            "only NFT owner can register"
        );

        // transfer nft to contract
        nftToken.safeTransferFrom(
            msg.sender, 
            address(this), 
            _tokenId
        );

        users[msg.sender] = User(
            userCount,
            0,
            uint64(block.timestamp),
            _tokenId,
            _nftAddress,
            _username,
            true
        );
        userCount++;
        activeProfileCount++;
        hasRegistered[msg.sender] = true;

        emit UserNew(
            msg.sender, 
            _nftAddress, 
            _tokenId,
            _username
        );
    }

    // profile can be paused to allow user to withdraw nft
    function pauseProfile() 
        external
        payable
    {
        require(
            hasRegistered[msg.sender], 
            "not registered"
        );
        require(
            msg.value >= pauseFee,
            "not enough avax sent"
        );
        User storage user = users[msg.sender];
        require(
            user.isActive, 
            "user not active"
        );

        user.isActive = false;
        activeProfileCount--;
        IERC721 nftToken = IERC721(user.nftAddress);

        // remove nft address for safety
        user.nftAddress = address(0x0000000000000000000000000000000000000000);

        // transfer nft back to user
        nftToken.safeTransferFrom(
            address(this), 
            msg.sender,
            user.tokenId
        );

        emit UserPause(msg.sender);
    }


    // profile can be updated to change the locked nft
    function updateProfile(address _nftAddress, uint64 _tokenId) 
        external
        payable
    {
        require(
            hasRegistered[msg.sender], 
            "not registered"
        );
        require(
            validNftAddress[_nftAddress], 
            "NFT address invalid"
        );
        require(
            msg.value >= updateFee,
            "not enough avax sent"
        );
        User storage user = users[msg.sender];
        require(
            user.isActive, 
            "user not active"
        );

        IERC721 nftNewToken = IERC721(_nftAddress);

        require(
            msg.sender == nftNewToken.ownerOf(_tokenId),
            "only NFT owner can update"
        );

        // transfer new nft to contract
        nftNewToken.safeTransferFrom(
            msg.sender, 
            address(this), 
            _tokenId
        );

        IERC721 nftCurrentToken = IERC721(user.nftAddress);

        // transfer old nft back to owner
        nftCurrentToken.safeTransferFrom(
            address(this),
            msg.sender,
            user.tokenId
        );

        user.nftAddress = _nftAddress;
        user.tokenId = _tokenId;

        emit UserUpdate(
            msg.sender, 
            _nftAddress, 
            _tokenId
        );
    }

    // paused profile can be reactivated by locking up a single governance nft
    function reactivateProfile(address _nftAddress, uint64 _tokenId) 
        external
        payable
    {
        require(
            hasRegistered[msg.sender], 
            "not registered"
        );
        require(
            validNftAddress[_nftAddress], 
            "NFT address invalid"
        );
        require(
            msg.value >= reactivateFee,
            "not enough avax sent"
        );
        User storage user = users[msg.sender];
        require(
            !user.isActive, 
            "user active"
        );
        IERC721 nftToken = IERC721(_nftAddress);
        require(
            msg.sender == nftToken.ownerOf(_tokenId),
            "only NFT owner can update"
        );

        // Transfer NFT to contract
        nftToken.safeTransferFrom(msg.sender, address(this), _tokenId);

        user.isActive = true;
        user.timestamp = uint64(block.timestamp);
        user.tokenId = _tokenId;
        user.nftAddress = _nftAddress;
        activeProfileCount++;

        emit UserReactivate(
            msg.sender, 
            _nftAddress, 
            _tokenId
        );
    }

    // update user points for completing a task etc
    function updateUserPoints(
        address _userAddress,
        uint64 _points,
        uint64 _taskId,
        uint addOrSubtract
    )   
        external 
    {
        require(
            approvedContract[msg.sender] || msg.sender == owner,
            "not approved"
        );

        if (addOrSubtract == 0) {
            // increase number of points for user
            users[_userAddress].points +=  _points;

            emit UserPointIncrease(
                _userAddress, 
                _points, 
                _taskId
            );
        } else {
            // decrease number of points for user in case of exploit
            users[_userAddress].points -= _points;

            emit UserPointDecrease(
                _userAddress, 
                _points, 
                _taskId
            );
        }  
    }

    // update multiple users points for completing a task etc
    function updateUserPointsMultiple(
        address[] calldata _userAddresses,
        uint64 _points,
        uint64 _taskId,
        uint addOrSubtract
    ) 
        external 
    {
        require(
            approvedContract[msg.sender] || msg.sender == owner,
            "not approved"
        );
        require(
            _userAddresses.length < 1001, 
            "length must be < 1001"
        );

        if (addOrSubtract == 0) {
            for (uint i = 0; i < _userAddresses.length; i++) {
                users[_userAddresses[i]].points += _points;
            }
            
            emit UserPointIncreaseMultiple(
                 _userAddresses,
                 _points,
                 _taskId
            );
        } else {
            for (uint i = 0; i < _userAddresses.length; i++) {
                users[_userAddresses[i]].points -= _points;
            }
    
            emit UserPointDecreaseMultiple(
                _userAddresses,
                _points,
                _taskId
            );
        }
    }

    // update governance nft address when collection is switched 
    function updateNftAddressState(address _nftAddress) 
        external 
    {
        require(
            msg.sender == owner,
            "not owner"
        );
        validNftAddress[_nftAddress] = !validNftAddress[_nftAddress];
    }

    // approve external tasks contracts to grant points 
    function updateApprovedContractState(address _contract) 
        external
    {
        require(
            msg.sender == owner,
            "not owner"
        );
        approvedContract[_contract] = !approvedContract[_contract];
    }

    // change username in case of inappropriate name and slash points 
    function updateUsername(address _userAddress, string calldata _randomName) 
        external
    {
        require(
            msg.sender == owner,
            "not owner"
        );
        users[_userAddress].points -= users[_userAddress].points * 50 / 100;
        users[_userAddress].username = _randomName;
    }

    // register fee may be implemented in future
    function updateFees(
        uint _newRegisterFee,
        uint _newUpdateFee,
        uint _newPauseFee,
        uint _newReactivateFee
    ) 
        external
    {
        require(
            msg.sender == owner,
            "not owner"
        );
        registerFee = _newRegisterFee;
        updateFee = _newUpdateFee;
        pauseFee = _newPauseFee;
        reactivateFee = _newReactivateFee;
    }

    // withdraw contract balance
    function withdraw() 
        external
    {
        require(
            msg.sender == owner,
            "not owner"
        );
        (bool sent, ) = owner.call{value: address(this).balance}("");
        require(
            sent, 
            "failed to send avax"
        );
    }

    function transferOwnership(address _newOwner) 
        external 
    {
        require(
            msg.sender == owner,
            "not owner"
        );
        owner = _newOwner;
    }

    receive() external payable {}

    /* --- Frontend Helpers --- */

    function getUserProfile(address _userAddress)
        external
        view
        returns (
            uint userId,
            uint points,
            uint timestamp,
            uint tokenId,
            address nftAddress,
            string memory username,
            bool isActive
        )
    {
        require(
            hasRegistered[_userAddress], 
            "not registered"
        );
        User memory usr = users[_userAddress];
        return (
            usr.userId,
            usr.points,
            usr.timestamp,
            usr.tokenId,
            usr.nftAddress,
            usr.username,
            usr.isActive
        );
    }

    function getUserStatus(address _userAddress) 
        external 
        view 
        returns (bool) 
    {
        return (users[_userAddress].isActive);
    }
}