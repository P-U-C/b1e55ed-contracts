// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ReputationRegistry
 * @notice ERC-8004 Reputation Registry for b1e55ed oracle karma outcomes.
 *
 * Receives signed karma feedback events after each forecast resolution.
 * Anyone can query an agent's feedback history to verify their track record.
 *
 * Based on ERC-8004 Reputation Registry specification:
 * https://eips.ethereum.org/EIPS/eip-8004
 */
interface IIdentityRegistry {
    function ownerOf(uint256 tokenId) external view returns (address);
    function getAgentWallet(uint256 agentId) external view returns (address);
}

contract ReputationRegistry {
    // ERC-8004 Reputation Registry interface
    // giveFeedback(agentId, value, valueDecimals, tag1, tag2, endpoint, feedbackURI, feedbackHash)

    struct FeedbackEntry {
        uint256 agentId;
        address giver;        // who gave the feedback (oracle address)
        int128 value;         // karma delta (signed, scaled by valueDecimals)
        uint8 valueDecimals;  // decimal places for value precision
        string tag1;          // "karma"
        string tag2;          // "forecast_outcome"
        string endpoint;      // oracle endpoint that generated this
        string feedbackURI;   // link to full outcome JSON
        bytes32 feedbackHash; // keccak256 of outcome JSON
        uint256 timestamp;
    }

    IIdentityRegistry public immutable identityRegistry;

    // agentId → list of feedback entries
    mapping(uint256 => FeedbackEntry[]) private _feedback;

    // agentId → aggregate karma (sum of all value * 10^(-valueDecimals))
    mapping(uint256 => int256) private _aggregateKarma;

    // Total feedback count across all agents
    uint256 public totalFeedbackCount;

    event FeedbackGiven(
        uint256 indexed agentId,
        address indexed giver,
        int128 value,
        uint8 valueDecimals,
        string tag1,
        string tag2,
        string feedbackURI,
        bytes32 feedbackHash
    );

    error AgentNotRegistered(uint256 agentId);

    constructor(address identityRegistry_) {
        identityRegistry = IIdentityRegistry(identityRegistry_);
    }

    /**
     * @notice Submit karma feedback for an agent.
     * @param agentId       ERC-8004 token ID of the agent receiving feedback
     * @param value         Karma delta (signed int128, use valueDecimals for precision)
     * @param valueDecimals Decimal places: value=420, decimals=2 → 4.20 karma
     * @param tag1          Primary category tag (e.g. "karma")
     * @param tag2          Secondary tag (e.g. "forecast_outcome")
     * @param endpoint      Oracle endpoint that generated this feedback
     * @param feedbackURI   Link to outcome JSON (oracle API or IPFS)
     * @param feedbackHash  keccak256(outcome JSON bytes)
     */
    function giveFeedback(
        uint256 agentId,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external {
        // Verify agent exists in Identity Registry
        try identityRegistry.ownerOf(agentId) returns (address) {
            // valid
        } catch {
            revert AgentNotRegistered(agentId);
        }

        _feedback[agentId].push(FeedbackEntry({
            agentId: agentId,
            giver: msg.sender,
            value: value,
            valueDecimals: valueDecimals,
            tag1: tag1,
            tag2: tag2,
            endpoint: endpoint,
            feedbackURI: feedbackURI,
            feedbackHash: feedbackHash,
            timestamp: block.timestamp
        }));

        // Update aggregate (store scaled by 6 decimals for precision)
        int256 scaled = int256(value);
        if (valueDecimals < 6) {
            scaled *= int256(10 ** uint256(6 - valueDecimals));
        } else if (valueDecimals > 6) {
            scaled /= int256(10 ** uint256(valueDecimals - 6));
        }
        _aggregateKarma[agentId] += scaled;
        totalFeedbackCount++;

        emit FeedbackGiven(agentId, msg.sender, value, valueDecimals, tag1, tag2, feedbackURI, feedbackHash);
    }

    /**
     * @notice Get all feedback entries for an agent.
     */
    function getFeedback(uint256 agentId) external view returns (FeedbackEntry[] memory) {
        return _feedback[agentId];
    }

    /**
     * @notice Get feedback count for an agent.
     */
    function getFeedbackCount(uint256 agentId) external view returns (uint256) {
        return _feedback[agentId].length;
    }

    /**
     * @notice Get aggregate karma for an agent (scaled by 1e6).
     * Divide by 1e6 to get the actual karma value.
     */
    function getAggregateKarma(uint256 agentId) external view returns (int256) {
        return _aggregateKarma[agentId];
    }

    /**
     * @notice Get paginated feedback for an agent.
     */
    function getFeedbackPaginated(
        uint256 agentId,
        uint256 offset,
        uint256 limit
    ) external view returns (FeedbackEntry[] memory entries, uint256 total) {
        FeedbackEntry[] storage all = _feedback[agentId];
        total = all.length;
        if (offset >= total) return (new FeedbackEntry[](0), total);
        uint256 end = offset + limit > total ? total : offset + limit;
        uint256 size = end - offset;
        entries = new FeedbackEntry[](size);
        for (uint256 i = 0; i < size; i++) {
            entries[i] = all[offset + i];
        }
    }

    /**
     * @notice Get the Identity Registry address this contract is bound to.
     */
    function getIdentityRegistry() external view returns (address) {
        return address(identityRegistry);
    }
}
