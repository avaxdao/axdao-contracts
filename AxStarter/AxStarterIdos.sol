//SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IdoStorage {
    function getUserTier(address _addr) external view returns (uint256);
}

/**
 * @title AxStarterIdos
 *
 * @dev This contract is used for IDOs on the AxStarter launchpad.
 *
 */
contract AxStarterIdos {
    struct UserData {
        address userAddress;
        uint256 allocation;
    }

    struct IdoInfo {
        uint32 id;
        uint32 openTime;
        uint32 fcfsTime;
        uint32 closeTime;
        uint256 amount;
        uint256 remainingAmount;
    }

    IERC20 private usdt_;
    IERC20 private axStarter_;
    IdoStorage private idoStorage_;

    address private owner;
    address private fundsWallet;
    uint32 private totalIdos;
    uint256[9] private tierWeight = [2000, 1400, 1000, 1600, 1000, 700, 800, 1300, 200];
    uint256[9] private tierSizes = [25, 25, 50, 200, 200, 200, 300, 1000, 250];
    uint256 public fcfsTokenAmount;

    mapping(address => bool) private admins;
    mapping(uint256 => IdoInfo) public idos;
    mapping(address => mapping(uint256 => bool)) public userJoined;

    event NewIdo(
        uint32 indexed id,
        uint32 indexed openTime,
        uint32 fcfsTime,
        uint32 closeTime,
        uint256 amount
    );
    event JoinedIdo(address indexed user, uint256 amount);
    event FcfsTokenAmountUpdated(uint256 prevAmount, uint256 newAmount);

    modifier onlyAdmin() {
        require(admins[msg.sender], "not admin");
        _;
    }

    constructor(
        IERC20 _usdt,
        IERC20 _axStarter,
        IdoStorage _idoStorage,
        address _fundsWallet
    ) {
        owner = msg.sender;
        admins[msg.sender] = true;
        usdt_ = _usdt;
        axStarter_ = _axStarter;
        idoStorage_ = _idoStorage;
        fundsWallet = _fundsWallet;
    }

    function createIdo(
        uint32 open,
        uint32 fcfs,
        uint32 close,
        uint256 amount
    ) external onlyAdmin {
        idos[totalIdos] = IdoInfo(totalIdos, open, fcfs, close, amount, amount);
        emit NewIdo(totalIdos, open, fcfs, close, amount);
    }

    function joinIdo(uint256 _idoId, uint256 _amount) external {
        IdoInfo storage ido = idos[_idoId];

        require(block.timestamp > ido.openTime, "not started");
        require(block.timestamp < ido.closeTime, "closed");
        require(!userJoined[msg.sender][_idoId], "already joined");
        require(ido.remainingAmount >= _amount, "exceeded remaining amount");

        if (block.timestamp < ido.fcfsTime) {
            require(
                calculateAllocation(_idoId, msg.sender) >= _amount,
                "exceeded allocation"
            );
        }

        userJoined[msg.sender][_idoId] = true;
        ido.remainingAmount -= _amount;
        usdt_.transferFrom(msg.sender, address(this), _amount);
        emit JoinedIdo(msg.sender, _amount);
    }

    function calculateAllocation(uint256 idoId, address user)
        public
        view
        returns (uint256)
    {
        uint256 tier = idoStorage_.getUserTier(user);
        return (idos[idoId].amount * tierWeight[tier]) / (tierSizes[tier] * 10000);
    }

    function updateFcfsTokenAmount(uint256 _amount) external onlyAdmin {
        uint256 prevAmount = fcfsTokenAmount;
        fcfsTokenAmount = _amount;
        emit FcfsTokenAmountUpdated(prevAmount, _amount);
    }

    function updateAdmin(address _adminAddress) external {
        require(msg.sender == owner, "not owner");
        admins[_adminAddress] = !admins[_adminAddress];
    }

    function withdraw(uint256 _amount) external onlyAdmin {
        usdt_.transfer(fundsWallet, _amount);
    }
}
