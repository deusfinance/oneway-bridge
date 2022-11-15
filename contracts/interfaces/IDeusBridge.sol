// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <=0.9.0;

import "./IMuonV02.sol";

    struct Transaction {
        uint txId;
        uint tokenId;
        uint amount;
        uint fromChain;
        uint toChain;
        address user;
        uint txBlockNo;
    }

interface IDeusBridge {
    /* ========== STATE VARIABLES ========== */

    function lastTxId() external view returns (uint);

    function network() external view returns (uint);

    function minReqSigs() external view returns (uint);

    function scale() external view returns (uint);

    function muonContract() external view returns (address);

    function ETH_APP_ID() external view returns (uint8);

    function sideContracts(uint) external view returns (address);

    function tokens(uint) external view returns (address);

    function claimedTxs(uint, uint) external view returns (bool);

    function tokenFees(uint) external view returns (uint);

    function collectedFees(uint) external view returns (uint);

    /* ========== PUBLIC FUNCTIONS ========== */
    function deposit(
        uint amount,
        uint toChain,
        uint tokenId
    ) external returns (uint txId);

    function depositFor(
        address user,
        uint amount,
        uint toChain,
        uint tokenId
    ) external returns (uint txId);

    function claim(
        address user,
        uint amount,
        uint fromChain,
        uint toChain,
        uint tokenId,
        uint txId,
        bytes calldata _reqId,
        SchnorrSign[] calldata sigs
    ) external;

    /* ========== VIEWS ========== */
    function pendingTxs(
        uint fromChain,
        uint[] calldata ids
    ) external view returns (bool[] memory unclaimedIds);

    function getUserDepositedTxs(
        address user,
        uint toChain
    ) external view returns (uint[] memory);

    function getUserClaimedTxs(
        address user,
        uint256 fromChain
    ) external view returns (uint[] memory);

    function getUserTxs(
        address user, uint chain, uint256 offset, uint256 limit
    ) external view returns (uint[] memory, uint[] memory);

    function getTransaction(uint txId_) external view returns (
        uint txId,
        uint tokenId,
        uint amount,
        uint fromChain,
        uint toChain,
        address user,
        uint txBlockNo,
        uint currentBlockNo
    );

    function getExecutingChainID() external view returns (uint);

    /* ========== RESTRICTED FUNCTIONS ========== */
    function setToken(uint tokenId, address tokenAddress) external;

    function setNetworkID(uint network_) external;

    function setFee(uint tokenId, uint fee_) external;

    function setMinReqSigs(uint minReqSigs_) external;

    function setSideContract(uint network_, address address_) external;

    function setEthAppId(uint8 ethAppId_) external;

    function setMuonContract(address muonContract_) external;

    function setDestChain(uint256 chain) external;

    function pause() external;

    function unpase() external;

    function withdrawFee(uint tokenId, address to) external;

    function emergencyWithdrawETH(address to, uint amount) external;

    function emergencyWithdrawERC20Tokens(address tokenAddr, address to, uint amount) external;
}
