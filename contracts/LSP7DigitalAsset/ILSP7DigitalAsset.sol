// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

// interfaces
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {
    IERC725Y
} from "@erc725/smart-contracts/contracts/interfaces/IERC725Y.sol";

/**
 * @title Interface of the LSP7 - Digital Asset standard, a fungible digital asset.
 */
interface ILSP7DigitalAsset is IERC165, IERC725Y {
    // --- Events

    /**
     * @dev Emitted when the `from` transferred successfully `amount` of tokens to `to`.
     * @param operator The address of the operator that executed the transfer.
     * @param from The address which tokens were sent from (balance decreased by `-amount`).
     * @param to The address that received the tokens (balance increased by `+amount`).
     * @param amount The amount of tokens transferred.
     * @param allowNonLSP1Recipient if the transferred enforced the `to` recipient address to be a contract that implements the LSP1 standard or not.
     * @param data Any additional data included by the caller during the transfer, and sent in the LSP1 hooks to the `from` and `to` addresses.
     */
    event Transfer(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bool allowNonLSP1Recipient,
        bytes data
    );

    /**
     * @dev Emitted when `tokenOwner` enables `operator` for `amount` tokens.
     * @param operator The address authorized as an operator
     * @param tokenOwner The token owner
     * @param amount The amount of tokens `operator` address has access to from `tokenOwner`
     */
    event AuthorizedOperator(
        address indexed operator,
        address indexed tokenOwner,
        uint256 indexed amount
    );

    /**
     * @dev Emitted when `tokenOwner` disables `operator` for `amount` tokens and set its {`authorizedAmountFor(...)`} to `0`.
     * @param operator The address revoked from operating
     * @param tokenOwner The token owner
     */
    event RevokedOperator(address indexed operator, address indexed tokenOwner);

    // --- Token queries

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * If the asset contract has been set to be non-divisible via the `isNonDivisible_` parameter in
     * the `constructor`, the decimals returned wiil be `0`. Otherwise `18` is the common value.
     *
     * @custom:notice This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {balanceOf} and {transfer}.
     *
     * @return the number of decimals. If `0` is returned, the asset is non-divisible.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the number of existing tokens that have been minted in this contract.
     * @return The number of existing tokens.
     */
    function totalSupply() external view returns (uint256);

    // --- Token owner queries

    /**
     * @dev Get the number of tokens owned by `tokenOwner`.
     * If the token is divisible (the `{decimals}` function returns `18`), the amount returned should be divided
     * by 1e18 to get a better picture of the actual balance of the `tokenOwner`.
     *
     * _Example:_
     *
     * ```
     * balanceOf(someAddress) -> 42_000_000_000_000_000_000 / 1e18 = 42 tokens
     * ```
     *
     * @param tokenOwner The address of the token holder to query the balance for.
     * @return The amount of tokens owned by `tokenOwner`.
     */
    function balanceOf(address tokenOwner) external view returns (uint256);

    // --- Operator functionality

    /**
     * @dev Sets an `amount` of tokens that an `operator` has access from the caller's balance (allowance). See {authorizedAmountFor}.
     *
     * @param operator The address to authorize as an operator.
     * @param amount The allowance amount of tokens operator has access to.
     *
     * @custom:requirements
     * - `operator` cannot be the zero address.
     *
     * @custom:events {AuthorizedOperator} when allowance is given to a new operator or
     * an existing operator's allowance is updated.
     */
    function authorizeOperator(address operator, uint256 amount) external;

    /**
     * @dev Removes the `operator` address as an operator of callers tokens, disallowing it to send any amount of tokens
     * on behalf of the token owner (the caller of the function `msg.sender`). See also {authorizedAmountFor}.
     *
     * @param operator The address to revoke as an operator.
     *
     * @custom:requirements
     * - `operator` cannot be calling address.
     * - `operator` cannot be the zero address.
     *
     * @custom:events {RevokedOperator} event with address of the operator being revoked for the caller (token holder).
     */
    function revokeOperator(address operator) external;

    /**
     * @dev Get the amount of tokens `operator` address has access to from `tokenOwner`.
     * Operators can send and burn tokens on behalf of their owners.
     *
     * @param operator The operator's address to query the authorized amount for.
     * @param tokenOwner The token owner that `operator` has allowance on.
     *
     * @return The amount of tokens the `operator`'s address has access on the `tokenOwner`'s balance.
     *
     * @custom:info If this function is called with the same address for `operator` and `tokenOwner`, it will simply read the `tokenOwner`'s balance
     * (since a tokenOwner is its own operator).
     */
    function authorizedAmountFor(
        address operator,
        address tokenOwner
    ) external view returns (uint256);

    // --- Transfer functionality

    /**
     * @dev Transfers an `amount` of tokens from the `from` address to the `to` address and notify both sender and recipients via the LSP1 {`universalReceiver(...)`} function.
     * If the tokens are transferred by an operator on behalf of a token holder, the allowance for the operator will be decreased by `amount` once the token transfer
     * has been completed (See {authorizedAmountFor}).
     *
     * @param from The sender address.
     * @param to The recipient address.
     * @param amount The amount of tokens to transfer.
     * @param allowNonLSP1Recipient When set to `true`, the `to` address CAN be any address. When set to `false`, the `to` address MUST be a contract that supports the LSP1 UniversalReceiver standard.
     * @param data Any additional data the caller wants included in the emitted event, and sent in the hooks of the `from` and `to` addresses.
     *
     * @custom:requirements
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` and `to` cannot be the same address (`from` cannot send tokens to itself).
     * - `from` MUST have a balance of at least `amount` tokens.
     * - If the caller is not `from`, it must be an operator for `from` with an allowance of at least `amount` of tokens.
     *
     * @custom:events
     * - {Transfer} event when tokens get successfully transferred.
     * - if the transfer is triggered by an operator, either the {AuthorizedOperator} event will be emitted with the updated allowance or the {RevokedOperator}
     * event will be emitted if the operator has no more allowance left.
     *
     * @custom:hint The `allowNonLSP1Recipient` parameter **MUST be set to `true`** to transfer tokens to Externally Owned Accounts (EOAs)
     * or contracts that do not implement the LSP1 Universal Receiver Standard. Otherwise the function will revert making the transfer fail.
     *
     * @custom:info if the `to` address is a contract that implements LSP1, it will always be notified via its `universalReceiver(...)` function, regardless if `allowNonLSP1Recipient` is set to `true` or `false`.
     *
     * @custom:warning Be aware that when either the sender or the recipient can have logic that revert in their `universalReceiver(...)` function when being notified.
     * This even if the `allowNonLSP1Recipient` was set to `true`.
     */
    function transfer(
        address from,
        address to,
        uint256 amount,
        bool allowNonLSP1Recipient,
        bytes memory data
    ) external;

    /**
     * @dev Same as {`transfer(...)`} but transfer multiple tokens based on the arrays of `from`, `to`, `amount`.
     *
     * @custom:info If any transfer in the batch fail or revert, the whole call will revert.
     *
     * @param from An array of sending addresses.
     * @param to An array of receiving addresses.
     * @param amount An array of amount of tokens to transfer for each `from -> to` transfer.
     * @param allowNonLSP1Recipient For each transfer, when set to `true`, the `to` address CAN be any address. When set to `false`, the `to` address MUST be a contract that supports the LSP1 UniversalReceiver standard.
     * @param data An array of additional data the caller wants included in the emitted event, and sent in the hooks to `from` and `to` addresses.
     *
     * @custom:requirements
     * - `from`, `to`, `amount` lists MUST be of the same length.
     * - no values in `from` can be the zero address.
     * - no values in `to` can be the zero address.
     * - each `amount` tokens MUST be owned by `from`.
     * - for each transfer, if the caller is not `from`, it MUST be an operator for `from` with access to at least `amount` tokens.
     *
     * @custom:events {Transfer} event **for each token transfer**.
     */
    function transferBatch(
        address[] memory from,
        address[] memory to,
        uint256[] memory amount,
        bool[] memory allowNonLSP1Recipient,
        bytes[] memory data
    ) external;
}
