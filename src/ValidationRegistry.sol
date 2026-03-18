// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ValidationRegistry
 * @notice ERC-8004 Validation Registry for b1e55ed Review Council verdicts.
 *
 * Stores on-chain attestations from the Review Council after each PR review.
 * Verdicts: "pass", "concern", "block", "human-required"
 *
 * Based on ERC-8004 Validation Registry specification:
 * https://eips.ethereum.org/EIPS/eip-8004
 */
interface IIdentityRegistry {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract ValidationRegistry {
    enum Verdict { Pass, Concern, Block, HumanRequired }

    struct ValidationEntry {
        uint256 agentId;      // ERC-8004 agentId of the system being validated
        address validator;    // who posted the verdict (oracle address)
        Verdict verdict;
        string verdictStr;    // human-readable: "pass", "concern", "block", "human-required"
        string context;       // PR URL or context reference
        string validationURI; // link to full council verdict JSON
        bytes32 verdictHash;  // keccak256 of verdict JSON
        uint256 timestamp;
    }

    IIdentityRegistry public immutable identityRegistry;

    // agentId → list of validation entries
    mapping(uint256 => ValidationEntry[]) private _validations;

    // Counts by verdict type per agent
    mapping(uint256 => mapping(Verdict => uint256)) public verdictCounts;

    uint256 public totalValidationCount;

    event ValidationPosted(
        uint256 indexed agentId,
        address indexed validator,
        Verdict verdict,
        string context,
        string validationURI,
        bytes32 verdictHash
    );

    error AgentNotRegistered(uint256 agentId);
    error InvalidVerdict(string verdict);

    constructor(address identityRegistry_) {
        identityRegistry = IIdentityRegistry(identityRegistry_);
    }

    /**
     * @notice Post a Review Council verdict for an agent.
     * @param agentId       ERC-8004 token ID of the agent being validated
     * @param verdictStr    "pass", "concern", "block", or "human-required"
     * @param context       PR URL or build context reference
     * @param validationURI Link to full council verdict JSON
     * @param verdictHash   keccak256(verdict JSON bytes)
     */
    function postValidation(
        uint256 agentId,
        string calldata verdictStr,
        string calldata context,
        string calldata validationURI,
        bytes32 verdictHash
    ) external {
        // Verify agent exists
        try identityRegistry.ownerOf(agentId) returns (address) {
            // valid
        } catch {
            revert AgentNotRegistered(agentId);
        }

        Verdict v = _parseVerdict(verdictStr);

        _validations[agentId].push(ValidationEntry({
            agentId: agentId,
            validator: msg.sender,
            verdict: v,
            verdictStr: verdictStr,
            context: context,
            validationURI: validationURI,
            verdictHash: verdictHash,
            timestamp: block.timestamp
        }));

        verdictCounts[agentId][v]++;
        totalValidationCount++;

        emit ValidationPosted(agentId, msg.sender, v, context, validationURI, verdictHash);
    }

    function getValidations(uint256 agentId) external view returns (ValidationEntry[] memory) {
        return _validations[agentId];
    }

    function getValidationCount(uint256 agentId) external view returns (uint256) {
        return _validations[agentId].length;
    }

    function getPassRate(uint256 agentId) external view returns (uint256 passes, uint256 total) {
        passes = verdictCounts[agentId][Verdict.Pass];
        total = _validations[agentId].length;
    }

    function getIdentityRegistry() external view returns (address) {
        return address(identityRegistry);
    }

    function _parseVerdict(string calldata v) internal pure returns (Verdict) {
        if (keccak256(bytes(v)) == keccak256(bytes("pass"))) return Verdict.Pass;
        if (keccak256(bytes(v)) == keccak256(bytes("concern"))) return Verdict.Concern;
        if (keccak256(bytes(v)) == keccak256(bytes("block"))) return Verdict.Block;
        if (keccak256(bytes(v)) == keccak256(bytes("human-required"))) return Verdict.HumanRequired;
        revert InvalidVerdict(v);
    }
}
