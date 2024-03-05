// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@forge-std/console.sol";
import {Address} from "@utils/Address.sol";
import {IVotes} from "@openzeppelin/governance/utils/IVotes.sol";
import {GovernorBravoDelegate} from "@comp-governance/GovernorBravoDelegate.sol";
import {TimelockInterface, GovernorBravoDelegateStorageV1 as Bravo} from "@comp-governance/GovernorBravoInterfaces.sol";

import {GovernorBravoProposal} from "@forge-proposal-simulator/proposals/GovernorBravoProposal.sol";

contract Governor is GovernorBravoProposal {
    using Address for address;

    /// @notice Simulate governance proposal
    /// @param governorAddress address of the Governor Bravo Delegator contract
    /// @param governanceToken address of the governance token of the system
    /// @param proposerAddress address of the proposer
    function simulateActions(
        address governorAddress,
        address governanceToken,
        address proposerAddress
    ) internal {
        GovernorBravoDelegate governor = GovernorBravoDelegate(governorAddress);

        {
            // Ensure proposer has meets minimum proposal threshold and quorum votes to pass the proposal
            uint256 quorumVotes = governor.quorumVotes();
            uint256 proposalThreshold = governor.proposalThreshold();
            uint256 votingPower = quorumVotes > proposalThreshold
                ? quorumVotes
                : proposalThreshold;
            deal(governanceToken, proposerAddress, votingPower);
            // Delegate proposer's votes to itself
            vm.prank(proposerAddress);
            IVotes(governanceToken).delegate(proposerAddress);
            vm.roll(block.number + 1);
        }

        bytes memory proposeCalldata = getProposeCalldata();

        // Register the proposal
        bytes memory data;
        {
            // Execute the proposal
            uint256 gas_start = gasleft();
            vm.prank(proposerAddress);
            data = address(payable(governorAddress)).functionCall(
                proposeCalldata
            );

            emit log_named_uint("Propose Gas Metering", gas_start - gasleft());
        }
        uint256 proposalId = abi.decode(data, (uint256));

        if (DEBUG) {
            console.log(
                "schedule batch calldata with ",
                actions.length,
                (actions.length > 1 ? "actions" : "action")
            );

            if (data.length > 0) {
                console.log("proposalId: %s", proposalId);
            }
        }

        // Check proposal is in Pending state
        require(governor.state(proposalId) == Bravo.ProposalState.Pending);

        // Roll to Active state (voting period)
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.warp(block.timestamp + governor.votingDelay() + 1);
        require(governor.state(proposalId) == Bravo.ProposalState.Active);

        // Vote YES
        vm.prank(proposerAddress);
        governor.castVote(proposalId, 0);

        // Roll to allow proposal state transitions
        vm.roll(block.number + governor.votingPeriod());
        vm.warp(block.timestamp + governor.votingPeriod());
        require(governor.state(proposalId) == Bravo.ProposalState.Succeeded);

        // Queue the proposal
        governor.queue(proposalId);
        require(governor.state(proposalId) == Bravo.ProposalState.Queued);

        // Warp to allow proposal execution on timelock
        TimelockInterface timelock = TimelockInterface(governor.timelock());
        vm.warp(block.timestamp + timelock.delay());

        {
            // Execute the proposal
            uint256 gas_start = gasleft();
            governor.execute(proposalId);

            emit log_named_uint(
                "Execution Gas Metering",
                gas_start - gasleft()
            );
        }

        require(
            governor.state(proposalId) == Bravo.ProposalState.Executed,
            "Proposal state not executed"
        );
    }
}
