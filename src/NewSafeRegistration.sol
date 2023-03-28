// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./libraries/Clones.sol";
import "./Safe.sol";

contract SAFEForDAORegistrationSummoner {
    event NewRegistration(address indexed safeAddress);
    error ArrayLengthsMismatch();

    address public template; /*Template contract to clone*/

    // Pass Safe.sol here
    constructor(address _template) {
        template = _template;
    }

    function summonRegistration(
        bytes32 salt,
        uint256 numShares,
        address manager
    ) external returns (address payable registration) {
        registration = payable(Clones.cloneDeterministic(
            template,
            _saltedSalt(msg.sender, salt)
        ));

        Safe(registration).initialize(registration, numShares, manager);

        emit NewRegistration(registration);
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
