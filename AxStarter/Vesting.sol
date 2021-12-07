// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

interface AXS {
    function mint(address _to, uint256 _amount) external;
}

/**
 * @title AxStarterVesting
 *
 * @dev This contract handles the vesting of AxStarter - (AxS) ERC20 tokens for given beneficiaries.
 *
 * Gas optimization has not been considered as the structure of this contract is designed for
 * transparency and readability so that beneficiaries can entrust they will receive the tokens
 * agreed upon via a SAFT.
 *
 * All token claim functions are public so that no central authority is entrusted with distributing the tokens.
 */
contract AxStarterVesting {
    struct Beneficiary {
        address addr;
        uint256 amount;
    }

    uint256 private constant MONTH = 30 days;
    uint256 private immutable beneficiaryCliff;
    uint256 private immutable teamCliff;
    uint256 private immutable advisorCliff;
    uint256 private immutable reserveCliff;
    uint256 public immutable startTime;

    address private owner;
    address private teamWallet;
    address private advisorWallet;
    address private reserveWallet;

    Beneficiary[] private seed;
    Beneficiary[] private privateOne;
    Beneficiary[] private privateTwo;

    AXS private axsContract_;
    bool private tokenContractSet;
    bool private distributedTge;
    uint256 private seedCount;
    uint256 private privateOneCount;
    uint256 private privateTwoCount;
    uint256 public claimNonce;
    uint256 public teamClaimNonce;
    uint256 public advisorClaimNonce;
    uint256 public reserveClaimNonce;

    constructor(
        uint256 _startTime,
        Beneficiary[] memory _seed,
        Beneficiary[] memory _privateOne,
        Beneficiary[] memory _privateTwo,
        address _reserveWallet,
        address _advisorWallet,
        address _teamWallet
    ) {
        startTime = _startTime;

        beneficiaryCliff = _startTime + (MONTH * 2);
        reserveCliff = _startTime + (MONTH * 6);
        advisorCliff = _startTime + (MONTH * 6);
        teamCliff = _startTime + (MONTH * 8);

        reserveWallet = _reserveWallet;
        advisorWallet = _advisorWallet;
        teamWallet = _teamWallet;

        _initializeBeneficiaries(_seed, _privateOne, _privateTwo);
    }

    function _initializeBeneficiaries(
        Beneficiary[] memory _seed,
        Beneficiary[] memory _privateOne,
        Beneficiary[] memory _privateTwo
    ) private {
        seedCount = _seed.length;
        privateOneCount = _privateOne.length;
        privateTwoCount = _privateTwo.length;

        uint256 seedAmount;
        uint256 privateOneAmount;
        uint256 privateTwoAmount;

        for (uint256 i = 0; i < seedCount; i++) {
            seed.push(_seed[i]);
            seedAmount += _seed[i].amount;
        }
        for (uint256 i = 0; i < privateOneCount; i++) {
            privateOne.push(_privateOne[i]);
            privateOneAmount += _privateOne[i].amount;
        }
        for (uint256 i = 0; i < privateTwoCount; i++) {
            privateTwo.push(_privateTwo[i]);
            privateTwoAmount += _privateTwo[i].amount;
        }

        // final checks to validate correct token amounts allocated to each round
        require(seedAmount == 65_000_000 ether, "invalid seed amount");
        require(
            privateOneAmount == 160_000_000 ether,
            "invalid private1 amount"
        );
        require(
            privateTwoAmount == 80_000_000 ether,
            "invalid private2 amount"
        );
    }

    /**
     * @dev Checks token claim is valid.
     *
     * At nonce 0 first claim will be at block.timestamp > startTime + cliff,
     * after which nonce will increase by 1 adding on a months vesting
     * before each subsequent claim can be made.
     */
    function _canClaim(
        uint256 cliff,
        uint256 nonce,
        uint256 maxNonce
    ) private view {
        require(
            block.timestamp > (startTime + cliff + nonce * MONTH),
            "claim unavailable"
        );
        require(nonce < maxNonce, "all tokens distributed");
    }

    function _mintTokens(
        Beneficiary[] memory _beneficiarys,
        uint256 _count,
        uint256 _basisPoints
    ) private {
        for (uint256 i = 0; i < _count; i++) {
            axsContract_.mint(
                _beneficiarys[i].addr,
                ((_beneficiarys[i].amount * 10000) / _basisPoints)
            );
        }
    }

    /**
     * @dev Distributes unvested tokens at TGE.
     *
     * Can only be executed once.
     */
    function distributeTgeTokens() external {
        require(block.timestamp > startTime, "TGE has not started");
        require(!distributedTge, "all tokens distributed");

        _mintTokens(seed, seedCount, 650);
        _mintTokens(privateOne, privateOneCount, 1000);
        _mintTokens(privateTwo, privateTwoCount, 1000);

        distributedTge = true;
    }

    function distributeTokens() external {
        _canClaim(beneficiaryCliff, claimNonce, 11);

        // seed - 11 distributions of 8.5%
        _mintTokens(seed, seedCount, 850);

        // private one - 8 distributions of 11.25%
        if (claimNonce < 8) {
            _mintTokens(privateOne, privateOneCount, 1125);

            // private two - 8 distributions of 15.0%
            if (claimNonce < 6) {
                _mintTokens(privateTwo, privateTwoCount, 1500);
            }
        }
        claimNonce++;
    }

    function distributeReserveTokens() external {
        _canClaim(reserveCliff, reserveClaimNonce, 48);
        // reserve - 48 equal distributions
        axsContract_.mint(reserveWallet, 2_395_833 ether);
        reserveClaimNonce++;
    }

    function distributeAdvisorTokens() external {
        _canClaim(advisorCliff, advisorClaimNonce, 18);

        // advisors - first 2 distributions of 10%
        if (advisorClaimNonce < 2) {
            axsContract_.mint(advisorWallet, 5_000_000 ether);
        } else {
            // there after 16 distributions of 5%
            axsContract_.mint(advisorWallet, 2_500_000);
        }
        advisorClaimNonce++;
    }

    function distributeTeamTokens() external {
        _canClaim(teamCliff, teamClaimNonce, 24);

        // team - first distribution of 8%
        if (teamClaimNonce == 0) {
            axsContract_.mint(teamWallet, 12_000_000 ether);
        } else {
            // there after 23 distributions of 4%
            axsContract_.mint(teamWallet, 6_000_000 ether);
        }
        teamClaimNonce++;
    }

    function setTokenContract(AXS _axs) external {
        require(msg.sender == owner, "not owner");
        require(!tokenContractSet, "contract has been set");
        axsContract_ = _axs;
        tokenContractSet = !tokenContractSet;
    }
}
