// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// --------------
// IMPORTS
// --------------
import { LibDiamond } from "./Libraries/LibDiamond.sol"; // Contains the core logic for handling Diamond storage, facets, and upgrades.
import { IDiamondCut } from "./Interfaces/IDiamondCut.sol";// Defines the diamondCut function, which is central to EIP-2535 for managing facets (modular contract logic).
import { LibUtil } from "./Libraries/LibUtil.sol"; //  Utility functions for auxiliary operations.

// --------------
// METADATA
// --------------
/// @title LIFI Diamond
/// @author LI.FI (https://li.fi)
/// @notice Base EIP-2535 Diamond Proxy Contract.
/// @custom:version 1.0.0
contract LiFiDiamond {
    // --------------
    // CONSTRUCTOR
    constructor(address _contractOwner, address _diamondCutFacet) payable {
        LibDiamond.setContractOwner(_contractOwner); // Calls setContractOwner from LibDiamond to assign _contractOwner as the owner of the contract.

        // Add the diamondCut external function from the diamondCutFacet
        LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](1); // Creates a new array of bytes4 with a length of 1.
        functionSelectors[0] = IDiamondCut.diamondCut.selector;
        // Fills the first element of the cut array with the following:
        cut[0] = LibDiamond.FacetCut({
            facetAddress: _diamondCutFacet, // facetAddress: The address of the _diamondCutFacet.
            action: LibDiamond.FacetCutAction.Add, // action: Specifies that this facet is being added.
            functionSelectors: functionSelectors // functionSelectors: Contains the selector of the diamondCut function.
        });
        LibDiamond.diamondCut(cut, address(0), "");
        // cut: The facet modification data.
        // address(0): No initialization function is specified.
        // "": No calldata is passed.
    }
    // --------------
    // --------------

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    // solhint-disable-next-line no-complex-fallback
    fallback() external payable { // Executes when a function that doesn't exist in the contract is called.
        LibDiamond.DiamondStorage storage ds; // Declares ds as the DiamondStorage structure and ...
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION; // ...retrieves its position using DIAMOND_STORAGE_POSITION.

        // get diamond storage
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ds.slot := position //Uses assembly to set the storage slot of ds to DIAMOND_STORAGE_POSITION.
        }

        // get facet from function selector
        // Retrieves the address of the facet associated with the function selector (msg.sig).
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;

        if (facet == address(0)) {
            revert LibDiamond.FunctionDoesNotExist();
        } // Reverts if the selector is not mapped to any facet.

        // Execute external function from facet using delegatecall and return any value.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    // Able to receive ether
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
