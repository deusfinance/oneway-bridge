// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// =================================================================================================================
//  _|_|_|    _|_|_|_|  _|    _|    _|_|_|      _|_|_|_|  _|                                                       |
//  _|    _|  _|        _|    _|  _|            _|            _|_|_|      _|_|_|  _|_|_|      _|_|_|    _|_|       |
//  _|    _|  _|_|_|    _|    _|    _|_|        _|_|_|    _|  _|    _|  _|    _|  _|    _|  _|        _|_|_|_|     |
//  _|    _|  _|        _|    _|        _|      _|        _|  _|    _|  _|    _|  _|    _|  _|        _|           |
//  _|_|_|    _|_|_|_|    _|_|    _|_|_|        _|        _|  _|    _|    _|_|_|  _|    _|    _|_|_|    _|_|_|     |
// =================================================================================================================
// ======================= DEUS Bridge ======================
// ==========================================================
// DEUS Finance: https://github.com/DeusFinance

// Primary Author(s)
// Sadegh: https://github.com/sadeghte
// Reza: https://github.com/bakhshandeh
// Vahid: https://github.com/vahid-dev
// Mahdi: https://github.com/Mahdi-HF

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IDeusBridge.sol";
import "./interfaces/IERC20.sol";

contract DeusBridge is IDeusBridge, Initializable, OwnableUpgradeable, PausableUpgradeable {
    using ECDSA for bytes32;

    /* ========== STATE VARIABLES ========== */
    uint256 public lastTxId ; // unique id for deposit tx
    uint256 public network; // current chain id
    uint256 public minReqSigs; // minimum required tss
    uint256 public scale;
    uint256 public destChain;
    address public muonContract; // muon signature verifier contract
    uint8 public ETH_APP_ID; // muon's eth app id

    // we assign a unique ID to each chain (default is CHAIN-ID)
    mapping(uint256 => address) public sideContracts;

    // tokenId => tokenContractAddress
    mapping(uint256 => address) public tokens;

    mapping(uint256 => Transaction) private txs;

    // user => (destination chain => user's txs id)
    mapping(address => mapping(uint256 => uint256[])) private userDepositedTxs;

    // user => (source chain => user's txs id)
    mapping(address => mapping(uint256 => uint256[])) private userClaimedTxs;

    // source chain => (tx id => false/true)
    mapping(uint256 => mapping(uint256 => bool)) public claimedTxs;

    // tokenId => tokenFee
    mapping(uint256 => uint256) public tokenFees;

    // tokenId => collectedFee
    mapping(uint256 => uint256) public collectedFees;

    /* ========== EVENTS ========== */
    event Deposit(
        address indexed user,
        uint256 tokenId,
        uint256 amount,
        uint256 indexed toChain,
        uint256 txId
    );
    event Claim(
        address indexed user,
        uint256 tokenId,
        uint256 amount,
        uint256 indexed fromChain,
        uint256 txId
    );

    /* ========== initializer ========== */
    function initialize(
        uint256 minReqSigs_,
        uint8 ETH_APP_ID_,
        address muon_,
        address legacyDei_
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        network = getExecutingChainID();
        minReqSigs = minReqSigs_;
        ETH_APP_ID = ETH_APP_ID_;
        muonContract = muon_;
        lastTxId = 0;
        scale = 1e6;
        destChain = 250; //FTM
        tokens[0] = legacyDei_;
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function deposit(
        uint256 amount,
        uint256 toChain,
        uint256 tokenId
    ) external returns (uint256 txId) {
        txId = _deposit(msg.sender, amount, toChain, tokenId);
        emit Deposit(msg.sender, tokenId, amount, toChain, txId);
    }

    function depositFor(
        address user,
        uint256 amount,
        uint256 toChain,
        uint256 tokenId
    ) external returns (uint256 txId) {
        txId = _deposit(user, amount, toChain, tokenId);
        emit Deposit(user, tokenId, amount, toChain, txId);
    }

    function _deposit(
        address user,
        uint256 amount,
        uint256 toChain,
        uint256 tokenId
    ) internal whenNotPaused returns (uint256 txId) {
        require(
            toChain == destChain,
            "Bridge: Transferring to requested chain is not possible"
        );
        require(
            sideContracts[toChain] != address(0),
            "Bridge: unknown toChain"
        );
        require(toChain != network, "Bridge: selfDeposit");
        require(tokens[tokenId] != address(0), "Bridge: unknown tokenId");

        IERC20 token = IERC20(tokens[tokenId]);

        token.transferFrom(msg.sender, address(this), amount);

        if (tokenFees[tokenId] > 0) {
            uint256 feeAmount = (amount * tokenFees[tokenId]) / scale;
            amount -= feeAmount;
            collectedFees[tokenId] += feeAmount;
        }

        txId = ++lastTxId;
        txs[txId] = Transaction({
        txId : txId,
        tokenId : tokenId,
        fromChain : network,
        toChain : toChain,
        amount : amount,
        user : user,
        txBlockNo : block.number
        });
        userDepositedTxs[user][toChain].push(txId);
    }

    function claim(
        address user,
        uint256 amount,
        uint256 fromChain,
        uint256 toChain,
        uint256 tokenId,
        uint256 txId,
        bytes calldata _reqId,
        SchnorrSign[] calldata sigs
    ) external {
        require(
            toChain == destChain,
            "Bridge: Transferring to requested chain is not possible"
        );
        require(
            sideContracts[fromChain] != address(0),
            "Bridge: source contract not exist"
        );
        require(toChain == network, "Bridge: toChain should equal network");
        require(
            sigs.length >= minReqSigs,
            "Bridge: insufficient number of signatures"
        );
        {
            bytes32 hash = keccak256(
                abi.encodePacked(
                    abi.encodePacked(
                        sideContracts[fromChain],
                        txId,
                        tokenId,
                        amount
                    ),
                    abi.encodePacked(fromChain, toChain, user, ETH_APP_ID)
                )
            );

            IMuonV02 muon = IMuonV02(muonContract);
            require(
                muon.verify(_reqId, uint256(hash), sigs),
                "Bridge: not verified"
            );
        }

        require(!claimedTxs[fromChain][txId], "Bridge: already claimed");
        require(tokens[tokenId] != address(0), "Bridge: unknown tokenId");

        IERC20 token = IERC20(tokens[tokenId]);

        token.transfer(user, amount);

        claimedTxs[fromChain][txId] = true;
        userClaimedTxs[user][fromChain].push(txId);

        emit Claim(user, tokenId, amount, fromChain, txId);
    }

    /* ========== VIEWS ========== */

    function pendingTxs(uint256 fromChain, uint256[] calldata ids)
    public
    view
    returns (bool[] memory unclaimedIds)
    {
        unclaimedIds = new bool[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            unclaimedIds[i] = claimedTxs[fromChain][ids[i]];
        }
    }

    function getUserDepositedTxs(address user, uint256 toChain)
    public
    view
    returns (uint256[] memory)
    {
        return userDepositedTxs[user][toChain];
    }

    function getUserClaimedTxs(address user, uint256 fromChain)
    public
    view
    returns (uint256[] memory)
    {
        return userClaimedTxs[user][fromChain];
    }

    function getUserTxs(address user, uint chain, uint256 offset, uint256 limit)
    public
    view
    returns (uint256[] memory, uint256[] memory)
    {
        uint256[] memory claimed = new uint256[](limit);
        uint256[] memory deposited = new uint256[](limit);

        uint256 index = 0;
        if (offset < userClaimedTxs[user][chain].length)
            for (uint256 i = offset; i < Math.min(userClaimedTxs[user][chain].length, offset + limit); i++)
                claimed[index++] = userClaimedTxs[user][chain][i];

        index = 0;

        if (offset < userDepositedTxs[user][chain].length)
            for (uint256 i = offset; i < Math.min(userDepositedTxs[user][chain].length, offset + limit); i++)
                deposited[index++] = userDepositedTxs[user][chain][i];

        return (claimed, deposited);
    }

    function getTransaction(uint256 txId_)
    public
    view
    returns (
        uint256 txId,
        uint256 tokenId,
        uint256 amount,
        uint256 fromChain,
        uint256 toChain,
        address user,
        uint256 txBlockNo,
        uint256 currentBlockNo
    )
    {
        txId = txs[txId_].txId;
        tokenId = txs[txId_].tokenId;
        amount = txs[txId_].amount;
        fromChain = txs[txId_].fromChain;
        toChain = txs[txId_].toChain;
        user = txs[txId_].user;
        txBlockNo = txs[txId_].txBlockNo;
        currentBlockNo = block.number;
    }

    function getExecutingChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setToken(uint256 tokenId, address tokenAddress)
    external
    onlyOwner
    {
        tokens[tokenId] = tokenAddress;
    }

    function setNetworkID(uint256 network_) external onlyOwner {
        network = network_;
        delete sideContracts[network];
    }

    function setFee(uint256 tokenId, uint256 fee_) external onlyOwner {
        tokenFees[tokenId] = fee_;
    }

    function setMinReqSigs(uint256 minReqSigs_) external onlyOwner {
        minReqSigs = minReqSigs_;
    }

    function setSideContract(uint256 network_, address address_)
    external
    onlyOwner
    {
        require(network != network_, "Bridge: current network");
        sideContracts[network_] = address_;
    }

    function setEthAppId(uint8 ETH_APP_ID_) external onlyOwner {
        ETH_APP_ID = ETH_APP_ID_;
    }

    function setMuonContract(address muonContract_) external onlyOwner {
        muonContract = muonContract_;
    }

    function setDestChain(uint256 chain) external onlyOwner {
        destChain = chain;
    }

    function pause() external onlyOwner {
        super._pause();
    }

    function unpase() external onlyOwner {
        super._unpause();
    }

    function withdrawFee(uint256 tokenId, address to) external onlyOwner {
        require(collectedFees[tokenId] > 0, "Bridge: No fee to collect");

        IERC20(tokens[tokenId]).pool_mint(to, collectedFees[tokenId]);
        collectedFees[tokenId] = 0;
    }

    function emergencyWithdrawETH(address to, uint256 amount)
    external
    onlyOwner
    {
        require(to != address(0));
        payable(to).transfer(amount);
    }

    function emergencyWithdrawERC20Tokens(
        address tokenAddr,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0));
        IERC20(tokenAddr).transfer(to, amount);
    }
}
