// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./libraries/Clones.sol";
import "./Safe.sol";

contract SAFEForDAORegistrationSummoner {
    event NewRegistration(address indexed safeAddress);

    address public template; /*Template contract to clone*/

    // Pass Safe.sol here
    constructor(address _template) {
        template = _template;
    }

    function registrationAddress(address by, bytes32 salt)
        external
        view
        returns (address addr, bool exists)
    {
        addr = Clones.predictDeterministicAddress(
            template,
            _saltedSalt(by, salt),
            address(this)
        );
        exists = addr.code.length > 0;
    }

    function summonRegistration(
        bytes32 salt,
        uint256 numShares,
        address manager,
        address[] calldata contracts,
        bytes[] calldata data
    ) external returns (address registration, bytes[] memory results) {
        registration = Clones.cloneDeterministic(
            template,
            _saltedSalt(msg.sender, salt)
        );

        if (manager == address(0)) {
            Safe(registration).initialize(msg.sender, numShares);
        } else {
            Safe(registration).initialize(msg.sender, numShares);
        }

        results = _callContracts(contracts, data);

        emit NewRegistration(registration);
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Call the `contracts` in order with `data`.
     * @param contracts The addresses of the contracts.
     * @param data      The `abi.encodeWithSelector` calldata for each of the contracts.
     * @return results The results of calling the contracts.
     */
    function _callContracts(address[] calldata contracts, bytes[] calldata data)
        internal
        returns (bytes[] memory results)
    {
        if (contracts.length != data.length) revert ArrayLengthsMismatch();

        assembly {
            // Grab the free memory pointer.
            // We will use the free memory to construct the `results` array,
            // and also as a temporary space for the calldata.
            results := mload(0x40)
            // Set `results.length` to be equal to `data.length`.
            mstore(results, data.length)
            // Skip the first word, which is used to store the length
            let resultsOffsets := add(results, 0x20)
            // Compute the location of the last calldata offset in `data`.
            // `shl(5, n)` is a gas-saving shorthand for `mul(0x20, n)`.
            let dataOffsetsEnd := add(data.offset, shl(5, data.length))
            // This is the start of the unused free memory.
            // We use it to temporarily store the calldata to call the contracts.
            let m := add(resultsOffsets, shl(5, data.length))

            // Loop through `contacts` and `data` together.
            // prettier-ignore
            for { let i := data.offset } iszero(eq(i, dataOffsetsEnd)) { i := add(i, 0x20) } {
                // Location of `bytes[i]` in calldata.
                let o := add(data.offset, calldataload(i))
                // Copy `bytes[i]` from calldata to the free memory.
                calldatacopy(
                    m, // Start of the unused free memory.
                    add(o, 0x20), // Location of starting byte of `data[i]` in calldata.
                    calldataload(o) // The length of the `bytes[i]`.
                )
                // Grab `contracts[i]` from the calldata.
                // As `contracts` is the same length as `data`,
                // `sub(i, data.offset)` gives the relative offset to apply to
                // `contracts.offset` for `contracts[i]` to match `data[i]`.
                let c := calldataload(add(contracts.offset, sub(i, data.offset)))
                // Call the contract, and revert if the call fails.
                if iszero(
                    call(
                        gas(), // Gas remaining.
                        c, // `contracts[i]`.
                        0, // `msg.value` of the call: 0 ETH.
                        m, // Start of the copy of `bytes[i]` in memory.
                        calldataload(o), // The length of the `bytes[i]`.
                        0x00, // Start of output. Not used.
                        0x00 // Size of output. Not used.
                    )
                ) {
                    // Bubble up the revert if the call reverts.
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                // Append the current `m` into `resultsOffsets`.
                mstore(resultsOffsets, m)
                resultsOffsets := add(resultsOffsets, 0x20)

                // Append the `returndatasize()` to `results`.
                mstore(m, returndatasize())
                // Append the return data to `results`.
                returndatacopy(add(m, 0x20), 0x00, returndatasize())
                // Advance `m` by `returndatasize() + 0x20`,
                // rounded up to the next multiple of 32.
                // `0x3f = 32 + 31`. The mask is `type(uint64).max & ~31`,
                // which is big enough for all purposes (see memory expansion costs).
                m := and(add(add(m, returndatasize()), 0x3f), 0xffffffffffffffe0)
            }
            // Allocate the memory for `results` by updating the free memory pointer.
            mstore(0x40, m)
        }
    }

    function _saltedSalt(address by, bytes32 salt)
        internal
        pure
        returns (bytes32 result)
    {
        assembly {
            // Store the variables into the scratch space.
            mstore(0x00, by)
            mstore(0x20, salt)
            // Equivalent to `keccak256(abi.encode(by, salt))`.
            result := keccak256(0x00, 0x40)
        }
    }
}
