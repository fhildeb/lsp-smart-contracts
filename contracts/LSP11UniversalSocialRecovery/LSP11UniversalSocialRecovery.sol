// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Interfaces
import {
    ILSP11UniversalSocialRecovery
} from "./ILSP11UniversalSocialRecovery.sol";

// Libraries
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// Errors
// solhint-disable no-global-import
import "./LSP11Errors.sol";

/**
 * @title LSP11UniversalSocialRecovery
 * @notice Contract providing a mechanism for account recovery through a designated set of guardians.
 * @dev Guardians can be regular Ethereum addresses or secret guardians represented by a salted hash of their address.
 * The contract allows for voting mechanisms where guardians can vote for a recovery address. Once the threshold is met, the recovery process can be initiated.
 */
contract LSP11UniversalSocialRecovery is ILSP11UniversalSocialRecovery {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**
     * @dev This mapping stores the set of guardians associated with each account.
     */
    mapping(address => EnumerableSet.AddressSet) internal _guardiansOf;

    /**
     * @dev This mapping stores the set of secret guardians associated with each account.
     */
    mapping(address => EnumerableSet.Bytes32Set) internal _secretGuardiansOf;

    /**
     * @dev This mapping stores the guardian threshold for each account.
     */
    mapping(address => uint256) internal _guardiansThresholdOf;

    /**
     * @dev This mapping stores the secret hash associated with each account.
     */
    mapping(address => bytes32) internal _secretHashOf;

    /**
     * @dev This mapping stores the successful recovery counter for each account.
     */
    mapping(address => uint256) internal _recoveryCounterOf;

    /**
     * @dev This mapping stores the address voted for recovery by guardians for each account in a specific recovery counter.
     */
    mapping(address => mapping(uint256 => mapping(address => address)))
        internal _guardiansVotedFor;

    /**
     * @dev This mapping stores the number of votes an address has received from guardians for each account in a specific recovery counter.
     */
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        internal _votesOfguardianVotedAddress;

    /**
     * @dev This mapping stores the commitment associated with an address for recovery for each account in a specific recovery counter.
     */
    mapping(address => mapping(uint256 => mapping(address => bytes32)))
        internal _commitmentOf;

    /**
     * @notice Modifier to ensure that a function is called only by designated guardians for a specific account.
     * @dev Throws if called by any account other than the guardians
     * @param account The account to check against for guardian status.
     */
    modifier onlyGuardians(address account, address guardian) virtual {
        if (guardian != msg.sender)
            revert CallerIsNotGuardian(guardian, msg.sender);
        if (
            !(_guardiansOf[account].contains(guardian) ||
                _secretGuardiansOf[account].contains(
                    keccak256(abi.encode(account, guardian))
                ))
        ) revert CallerIsNotAGuardianOfTheAccount(account, guardian);
        _;
    }

    /**
     * @notice Modifier to ensure that the account provided is the same as the caller
     * @dev Throws if the caller is writing to another account
     * @param account The account to check against the caller.
     */
    modifier accountIsCaller(address account) virtual {
        if (account != msg.sender)
            revert CallerIsNotTheAccount(account, msg.sender);
        _;
    }

    /**
     * @notice Executes multiple calls in a single transaction.
     * @param data An array of calldata bytes to be executed.
     * @return results An array of bytes containing the results of each executed call.
     * @dev This function allows for multiple calls to be made in a single transaction, improving efficiency.
     * If a call fails, the function will attempt to bubble up the revert reason or revert with a default message.
     */
    function batchCalls(
        bytes[] calldata data
    ) public virtual returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i; i < data.length; ) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );

            if (!success) {
                // Look for revert reason and bubble it up if present
                if (result.length != 0) {
                    // The easiest way to bubble the revert reason is using memory via assembly
                    // solhint-disable no-inline-assembly
                    /// @solidity memory-safe-assembly
                    assembly {
                        let returndata_size := mload(result)
                        revert(add(32, result), returndata_size)
                    }
                } else {
                    revert BatchCallsFailed(i);
                }
            }

            results[i] = result;

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Get the array of addresses representing guardians associated with an account.
     * @param account The account for which guardians are queried.
     * @return An array of addresses representing guardians for the given account.
     */
    function getGuardiansOf(
        address account
    ) public view returns (address[] memory) {
        return _guardiansOf[account].values();
    }

    /**
     * @notice Check if an address is a guardian for a specific account.
     * @param account The account to check for guardian status.
     * @param guardianAddress The address to verify if it's a guardian for the given account..
     * @return A boolean indicating whether the address is a guardian for the given account.
     */
    function isGuardianOf(
        address account,
        address guardianAddress
    ) public view returns (bool) {
        return _guardiansOf[account].contains(guardianAddress);
    }

    /**
     * @notice Get the array of addresses representing guardians associated with an account.
     * @param account The account for which guardians are queried.
     * @return An array of addresses representing guardians for the given account.
     */
    function getSecretGuardiansOf(
        address account
    ) public view returns (bytes32[] memory) {
        return _secretGuardiansOf[account].values();
    }

    /**
     * @notice Check if an address is a guardian for a specific account.
     * @param account The account to check for guardian status.
     * @param _saltedGuardianHash The hash salted address to check for guardian status.
     * @return A boolean indicating whether the address is a guardian for the given account.
     */
    function isSecretGuardianOf(
        address account,
        bytes32 _saltedGuardianHash
    ) public view returns (bool) {
        return _secretGuardiansOf[account].contains(_saltedGuardianHash);
    }

    /**
     * @notice Get the guardian threshold for a specific account.
     * @param account The account for which the guardian threshold is queried.
     * @return The guardian threshold set for the given account.
     */
    function getGuardiansThresholdOf(
        address account
    ) public view returns (uint256) {
        return _guardiansThresholdOf[account];
    }

    /**
     * @notice Get the secret hash associated with a specific account.
     * @param account The account for which the secret hash is queried.
     * @return The secret hash associated with the given account.
     */
    function getSecretHashOf(address account) public view returns (bytes32) {
        return _secretHashOf[account];
    }

    /**
     * @notice Get the successful recovery counter for a specific account.
     * @param account The account for which the recovery counter is queried.
     * @return The successful recovery counter for the given account.
     */
    function getRecoveryCounterOf(
        address account
    ) public view returns (uint256) {
        return _recoveryCounterOf[account];
    }

    /**
     * @notice Get the address voted for recovery by a guardian for a specific account and recovery counter.
     * @param account The account for which the vote is queried.
     * @param recoveryCounter The recovery counter for which the vote is queried.
     * @param guardian The guardian whose vote is queried.
     * @return The address voted for recovery by the specified guardian for the given account and recovery counter.
     */
    function getAddressVotedByGuardian(
        address account,
        uint256 recoveryCounter,
        address guardian
    ) public view returns (address) {
        return _guardiansVotedFor[account][recoveryCounter][guardian];
    }

    /**
     * @notice Get the number of votes an address has received from guardians for a specific account and recovery counter.
     * @param account The account for which the votes are queried.
     * @param recoveryCounter The recovery counter for which the votes are queried.
     * @param votedAddress The address for which the votes are queried.
     * @return The number of votes the specified address has received from guardians for the given account and recovery counter.
     */
    function getVotesOfGuardianVotedAddress(
        address account,
        uint256 recoveryCounter,
        address votedAddress
    ) public view returns (uint256) {
        return
            _votesOfguardianVotedAddress[account][recoveryCounter][
                votedAddress
            ];
    }

    /**
     * @notice Get the commitment associated with an address for recovery for a specific account and recovery counter.
     * @param account The account for which the commitment is queried.
     * @param recoveryCounter The recovery counter for which the commitment is queried.
     * @param committedBy The address who made the commitment.
     * @return The commitment associated with the specified address for recovery for the given account and recovery counter.
     */
    function getCommitmentOf(
        address account,
        uint256 recoveryCounter,
        address committedBy
    ) public view returns (bytes32) {
        return _commitmentOf[account][recoveryCounter][committedBy];
    }

    /**
     * @notice Adds a new guardian to the calling account.
     * @param account The address of the account to which the guardian will be added.
     * @param newGuardian The address of the new guardian to be added.
     * @dev This function allows the account holder to add a new guardian to their account.
     * If the provided address is already a guardian for the account, the function will revert.
     * Emits a `GuardianAdded` event upon successful addition of the guardian.
     */
    function addGuardian(
        address account,
        address newGuardian
    ) public virtual accountIsCaller(account) {
        if (_guardiansOf[account].contains(newGuardian))
            revert GuardianAlreadyExists(account, newGuardian);

        _guardiansOf[account].add(newGuardian);
        emit GuardianAdded(account, newGuardian);
    }

    /**
     * @notice Removes an existing guardian from the calling account.
     * @param account The address of the account to which the guardian will be removed.
     * @param existingGuardian The address of the existing guardian to be removed.
     * @dev This function allows the account holder to remove an existing guardian from their account.
     * If the provided address is not a current guardian or the removal would violate the guardian threshold, the function will revert.
     * Emits a `GuardianRemoved` event upon successful removal of the guardian.
     */
    function removeGuardian(
        address account,
        address existingGuardian
    ) public virtual accountIsCaller(account) {
        if (!_guardiansOf[account].contains(existingGuardian))
            revert GuardianNotFound(account, existingGuardian);
        if (
            _guardiansOf[account].length() +
                _secretGuardiansOf[account].length() ==
            _guardiansThresholdOf[account]
        )
            revert GuardianNumberCannotGoBelowThreshold(
                account,
                _guardiansThresholdOf[account]
            );

        _guardiansOf[account].remove(existingGuardian);
        emit GuardianRemoved(account, existingGuardian);
    }

    /**
     * @notice Adds a new guardian to the calling account.
     * @param account The address of the account to which the guardian will be added.
     * @param newGuardian The salted hash of the new guardian to be added.
     * @dev This function allows the account holder to add a new guardian to their account.
     * If the provided address is already a guardian for the account, the function will revert.
     * Emits a `GuardianAdded` event upon successful addition of the guardian.
     */
    function addSecretGuardian(
        address account,
        bytes32 newGuardian
    ) public virtual accountIsCaller(account) {
        if (_secretGuardiansOf[account].contains(newGuardian))
            revert SecretGuardianAlreadyExists(account, newGuardian);

        _secretGuardiansOf[account].add(newGuardian);
        emit SecretGuardianAdded(account, newGuardian);
    }

    /**
     * @notice Removes an existing guardian from the calling account.
     * @param account The address of the account to which the guardian will be removed.
     * @param existingGuardian The salted hash of the existing guardian to be removed.
     * @dev This function allows the account holder to remove an existing guardian from their account.
     * If the provided address is not a current guardian or the removal would violate the guardian threshold, the function will revert.
     * Emits a `GuardianRemoved` event upon successful removal of the guardian.
     */
    function removeSecretGuardian(
        address account,
        bytes32 existingGuardian
    ) public virtual accountIsCaller(account) {
        if (!_secretGuardiansOf[account].contains(existingGuardian))
            revert SecretGuardianNotFound(account, existingGuardian);
        if (
            _secretGuardiansOf[account].length() +
                _guardiansOf[account].length() ==
            _guardiansThresholdOf[account]
        )
            revert GuardianNumberCannotGoBelowThreshold(
                account,
                _guardiansThresholdOf[account]
            );

        _secretGuardiansOf[account].remove(existingGuardian);
        emit SecretGuardianRemoved(account, existingGuardian);
    }

    /**
     * @notice Sets the guardian threshold for the calling account.
     * @param account The address of the account to which the threshold will be set.
     * @param newThreshold The new guardian threshold to be set for the calling account.
     * @dev This function allows the account holder to set the guardian threshold for their account.
     * If the provided threshold exceeds the number of current guardians, the function will revert.
     * Emits a `GuardiansThresholdChanged` event upon successful threshold modification.
     */
    function setGuardiansThreshold(
        address account,
        uint256 newThreshold
    ) public virtual accountIsCaller(account) {
        if (
            newThreshold >
            _guardiansOf[account].length() +
                _secretGuardiansOf[account].length()
        ) revert ThresholdExceedsGuardianNumber(account, newThreshold);

        _guardiansThresholdOf[account] = newThreshold;
        emit GuardiansThresholdChanged(account, newThreshold);
    }

    /**
     * @notice Sets the recovery secret hash for the calling account.
     * @param account The address of the account to which the recovery secret hash will be set.
     * @param newRecoverSecretHash The new recovery secret hash to be set for the calling account.
     * @dev This function allows the account holder to set a new recovery secret hash for their account.
     * If the provided secret hash is zero, the function will revert.
     * Emits a `SecretHashChanged` event upon successful secret hash modification.
     */
    function setRecoverySecretHash(
        address account,
        bytes32 newRecoverSecretHash
    ) public virtual accountIsCaller(account) {
        _secretHashOf[account] = newRecoverSecretHash;
        emit SecretHashChanged(account, newRecoverSecretHash);
    }

    /**
     * @notice Allows a guardian to vote for an address to be recovered.
     * @param account The account for which the vote is being cast.
     * @param guardianVotedAddress The address voted by the guardian for recovery.
     * @dev This function allows a guardian to vote for an address to be recovered in a recovery process.
     * If the guardian has already voted for the provided address, the function will revert.
     * Emits a `GuardianVotedFor` event upon successful vote.
     */
    function voteForRecoverer(
        address account,
        address guardian,
        address guardianVotedAddress
    ) public virtual onlyGuardians(account, guardian) {
        uint256 accountRecoveryCounter = _recoveryCounterOf[account];
        address previousVotedForAddressByGuardian = _guardiansVotedFor[account][
            accountRecoveryCounter
        ][guardian];

        // Cannot vote to the same person twice
        if (guardianVotedAddress == previousVotedForAddressByGuardian)
            revert CannotVoteToAddressTwice(
                account,
                guardian,
                guardianVotedAddress
            );

        // If didn't vote before or reset
        if (previousVotedForAddressByGuardian == address(0)) {
            _guardiansVotedFor[account][accountRecoveryCounter][
                guardian
            ] = guardianVotedAddress;
            _votesOfguardianVotedAddress[account][accountRecoveryCounter][
                guardianVotedAddress
            ]++;
        }

        if (
            guardianVotedAddress != previousVotedForAddressByGuardian &&
            previousVotedForAddressByGuardian != address(0)
        ) {
            _guardiansVotedFor[account][accountRecoveryCounter][
                guardian
            ] = guardianVotedAddress;
            _votesOfguardianVotedAddress[account][accountRecoveryCounter][
                previousVotedForAddressByGuardian
            ]--;

            // If the voted address for is address(0) the intention is to reset, not vote for address 0
            if (guardianVotedAddress != address(0)) {
                _votesOfguardianVotedAddress[account][accountRecoveryCounter][
                    guardianVotedAddress
                ]++;
            }
        }

        emit GuardianVotedFor(
            account,
            accountRecoveryCounter,
            guardian,
            guardianVotedAddress
        );
    }

    /**
     * @notice Cancels the ongoing recovery process for the account by increasing the recovery counter.
     * @param account The address of the account to which the recovery process will be canceled.
     * @dev This function allows the account holder to cancel the ongoing recovery process by incrementing the recovery counter.
     * Emits a `RecoveryCancelled` event upon successful cancellation of the recovery process.
     */
    function cancelRecoveryProcess(
        address account
    ) public accountIsCaller(account) {
        uint256 previousRecoveryCounter = _recoveryCounterOf[account];
        _recoveryCounterOf[account]++;
        emit RecoveryCancelled(account, previousRecoveryCounter);
    }

    /**
     * @notice Commits a plain secret for an address to be recovered.
     * @param account The account for which the plain secret is being committed.
     * @param commitment The commitment associated with the plain secret.
     * @dev This function allows an address to commit a plain secret for the recovery process.
     * If the guardian has not voted for the provided address, the function will revert.
     */
    function commitPlainSecret(
        address account,
        address recoverer,
        bytes32 commitment
    ) public {
        if (recoverer != msg.sender)
            revert CallerIsNotRecoverer(recoverer, msg.sender);
        uint256 recoveryCounter = _recoveryCounterOf[account];
        _commitmentOf[account][recoveryCounter][recoverer] = commitment;

        emit PlainSecretCommitted(
            account,
            recoveryCounter,
            recoverer,
            commitment
        );
    }

    /**
     * @notice Initiates the account recovery process.
     * @param account The account for which the recovery is being initiated.
     * @param plainHash The plain hash associated with the recovery process.
     * @param newSecretHash The new secret hash to be set for the account.
     * @param calldataToExecute The calldata to be executed during the recovery process.
     * @dev This function initiates the account recovery process and executes the provided calldata.
     * If the new secret hash is zero or the number of votes is less than the guardian threshold, the function will revert.
     * Emits a `RecoveryProcessSuccessful` event upon successful recovery process.
     */
    function recoverAccess(
        address account,
        address recoverer,
        bytes32 plainHash,
        bytes32 newSecretHash,
        bytes calldata calldataToExecute
    ) public payable {
        if (recoverer != msg.sender)
            revert CallerIsNotRecoverer(recoverer, msg.sender);
        // retreive current secret hash
        bytes32 _secretHash = _secretHashOf[account];

        // if there is no secret and no guardians yet, disallow recovering
        if (
            _secretHash == bytes32(0) &&
            (_guardiansOf[account].length() +
                _secretGuardiansOf[account].length()) ==
            0
        ) revert AccountNotSetupYet();

        // retreive current recovery counter
        uint256 accountRecoveryCounter = _recoveryCounterOf[account];

        // retreive current guardians threshold
        uint256 guardiansThresholdOfAccount = _guardiansThresholdOf[account];

        // retreive number of votes caller have
        uint256 votesOfGuardianVotedAddress_ = _votesOfguardianVotedAddress[
            account
        ][accountRecoveryCounter][recoverer];

        // votes validation
        // if the threshold is 0, and the caller does not have votes
        // will rely on the hash
        if (votesOfGuardianVotedAddress_ < guardiansThresholdOfAccount)
            revert CallerVotesHaveNotReachedThreshold(account, recoverer);

        // if there is a secret require a commitment first
        if (_secretHash != bytes32(0)) {
            bytes32 saltedHash = keccak256(abi.encode(account, plainHash));
            if (
                keccak256(abi.encode(recoverer, saltedHash)) !=
                _commitmentOf[account][accountRecoveryCounter][recoverer]
            ) revert InvalidCommitment(account, recoverer);

            if (saltedHash != _secretHash)
                revert InvalidSecretHash(account, plainHash);
        }

        _recoveryCounterOf[account]++;
        _secretHashOf[account] = newSecretHash;
        emit SecretHashChanged(account, newSecretHash);

        (bool success, bytes memory returnedData) = account.call{
            value: msg.value
        }(calldataToExecute);

        Address.verifyCallResult(
            success,
            returnedData,
            "LSP11: Failed to call function on account"
        );

        emit RecoveryProcessSuccessful(
            account,
            accountRecoveryCounter,
            recoverer
        );
    }
}