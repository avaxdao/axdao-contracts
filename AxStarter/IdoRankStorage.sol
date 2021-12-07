//SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive types.
 *
 * Modified version of OpenZeppelin Contracts v4.4.0 (utils/structs/EnumerableSet.sol)
 * for storing the tier information of AxStarter IDOs.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 */
library Enum {
    struct Set {
        // Storage of set values
        address[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(address => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Set storage set, address value) internal returns (bool) {
        if (!contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    function reset(Set storage set) internal {
        uint256 len = set._values.length;

        for (uint256 i = 0; i < len; i++) {
            delete set._indexes[set._values[i]];
        }

        delete set._values;
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Set storage set, address value) internal returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                address lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Set storage set, address value) internal view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(Set storage set) internal view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Set storage set, uint256 index) internal view returns (address) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Set storage set) internal view returns (address[] memory) {
        return set._values;
    }
}

contract IdoRankStorage {
    using Enum for Enum.Set;

    address private immutable owner;
    uint256 private constant UPDATE_BATCH_LIMIT = 500;
    uint256[9] private tierSizes = [25, 25, 50, 200, 200, 200, 300, 1000, 250];

    /* Tier  |     Rank    | Size
    -------------------------------
     *   0   |    1 - 25   |   25
     *   1   |   26 - 50   |   25
     *   2   |   51 - 100  |   50
     *   3   |  101 - 300  |  200
     *   4   |  301 - 500  |  200
     *   5   |  501 - 700  |  200
     *   6   |  701 - 1000 |  300
     *   7   | 1001 - 2000 | 1000
     *   8   | 2001 - 3000 |  250
     */

    mapping(uint256 => Enum.Set) private tierSets;
    mapping(address => bool) private admins;

    modifier onlyAdmin() {
        require(admins[msg.sender], "not admin");
        _;
    }

    constructor() {
        owner = msg.sender;
        admins[msg.sender] = true;
    }

    function addUsersMultiple(address[] calldata users, uint256 tier) external onlyAdmin {
        uint256 len = users.length;
        require(len <= UPDATE_BATCH_LIMIT, "exceeded update batch limit");

        Enum.Set storage set = tierSets[tier];

        for (uint256 i = 0; i < len; i++) {
            set.add(users[i]);
        }

        require(set.length() <= tierSizes[tier], "exceeded tier size");
    }

    function removeUsersMultiple(address[] calldata users, uint256 tier)
        external
        onlyAdmin
    {
        uint256 len = users.length;
        require(len <= UPDATE_BATCH_LIMIT, "exceeded update batch limit");

        Enum.Set storage set = tierSets[tier];

        for (uint256 i = 0; i < len; i++) {
            set.remove(users[i]);
        }
    }

    function addUsersSingle(address user, uint256 tier) external onlyAdmin {
        Enum.Set storage set = tierSets[tier];
        set.add(user);

        require(set.length() <= tierSizes[tier], "exceeded tier size");
    }

    function removeUsersSingle(address user, uint256 tier) external onlyAdmin {
        Enum.Set storage set = tierSets[tier];
        set.remove(user);
    }

    function resetTier(uint256 tier) external onlyAdmin {
        Enum.Set storage set = tierSets[tier];
        set.reset();
    }

    function getUserTier(address value) external view returns (uint256) {
        for (uint256 tier = 0; tier <= 8; tier++) {
            if (tierSets[tier].contains(value)) {
                return tier;
            }
        }
        return 9; // user has no allocation
    }

    function getUsersInTier(uint256 tier) external view returns (address[] memory) {
        return tierSets[tier].values();
    }

    function getUserInTierAtIndex(uint256 tier, uint256 index)
        external
        view
        returns (address)
    {
        return tierSets[tier].at(index);
    }

    function updateAdmin(address _adminAddress) external {
        require(msg.sender == owner, "not owner");
        admins[_adminAddress] = !admins[_adminAddress];
    }
}
