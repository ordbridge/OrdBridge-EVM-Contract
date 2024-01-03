// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./ZUTToken.sol";

/**
 * @title OrdBridge contract
 *
 * @notice OrdBridge contract is upgradeable/pausable contract
 */
contract OrdBridgeV2 is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;
    using Strings for uint256;

    struct BurnForBRCEntry {
        uint256 id; // same as index of burnForBRCEntries
        string chain;
        string ticker;
        address user;
        uint256 amount;
        string addr;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // The signer of the claim
    mapping(address => bool) public singers;

    // Setting Signers
    function setSigner(address signer, bool ok) external onlyOwner {
        singers[signer] = ok;
    }

    /**
     * When users claim ERC from BRC, we deduct 1% as fees (configurable)
     * When users claim BRC by depositing ERC, we take 0.01 Eth payable (configurable)
     */
    address public feeRecipient;
    uint256 public TOKEN_FEE_PERCENT_IN_BPS;
    uint256 public BURN_ETH_FEE;

    // ticker => contractAddress
    mapping(string => address) public tokenContracts;
    mapping(string => uint256) maxSupplyForTicker;
    mapping(string => bool) txIdsMap;

    ///////// for Mint
    // ticker => address => amount
    mapping(string => mapping(address => uint256)) public mintableERCTokens;

    ///////// for Burn
    // BurnForBRCEntry[] public burnForBRCEntries;
    EnumerableSet.UintSet private burnEntriesSet;
    Counters.Counter private counters;
    mapping(uint => BurnForBRCEntry) burnEntriesMap;

    event ERCTokenContractCreated(string indexed ticker, address indexed token);
    event MintableERCEntryAdded(
        string indexed ticker,
        address indexed user,
        uint256 amount,
        string txId
    );
    event MintableERCEntryClaimed(
        string indexed ticker,
        address indexed user,
        uint256 amount,
        uint256 real,
        uint256 fee
    );

    event BurnForBRCEntryAdded(
        string chain,
        string indexed ticker,
        address indexed user,
        string indexed addr,
        uint256 id,
        uint256 amount
    );

    event BurnForBRCEntryProcessed(
        string chain,
        string indexed ticker,
        address indexed user,
        string indexed addr,
        uint256 id,
        uint256 count
    );

    // Pause/Unpause
    event Unpause();
    event Pause();

    function initialize() public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __Pausable_init_unchained();
        __UUPSUpgradeable_init_unchained();
    }

    ///////////////////////////////////////////////////////
    // read functions
    /**
     * @notice get burn entries to process
     */
    function getBurnForBRCEntriesCountToProcess()
        public
        view
        returns (uint256 count)
    {
        return burnEntriesSet.length();
    }

    function checkPendingERCToClaimForWalletWithTickers(
        address wallet,
        string[] memory tickers,
        uint256[] calldata multiples
    ) external view returns (string[] memory, uint256[] memory) {
        string[] memory pendingTickers = new string[](tickers.length);
        uint256[] memory pendingCounts = new uint256[](tickers.length);
        uint256 pendingIndex = 0;

        for (uint256 i = 0; i < tickers.length; i++) {
            string memory uppercaseTicker = multipleTicker(
                uppercase(tickers[i]),
                multiples[i]
            );

            if (mintableERCTokens[uppercaseTicker][wallet] > 0) {
                pendingTickers[pendingIndex] = uppercaseTicker;
                pendingCounts[pendingIndex] = mintableERCTokens[
                    uppercaseTicker
                ][wallet];
                pendingIndex++;
            }
        }

        // Resize the arrays to remove unused elements
        assembly {
            mstore(pendingTickers, pendingIndex)
            mstore(pendingCounts, pendingIndex)
        }

        return (pendingTickers, pendingCounts);
    }

    /**
     * @notice get {count} of burn entries to process
     */
    function getBurnForBRCEntriesToProcess(
        uint256 count
    )
        external
        view
        returns (
            BurnForBRCEntry[] memory entries,
            uint256 entriesCount,
            uint256 totalEntriesToProcess
        )
    {
        require(count > 0, "Invalid count");
        totalEntriesToProcess = getBurnForBRCEntriesCountToProcess();
        entriesCount = totalEntriesToProcess < count
            ? totalEntriesToProcess
            : count;

        entries = new BurnForBRCEntry[](entriesCount);
        uint[] memory setEntry = burnEntriesSet.values();

        for (
            uint index = 0;
            index < totalEntriesToProcess && index < entriesCount;
            index += 1
        ) {
            entries[index] = burnEntriesMap[setEntry[index]];
        }
    }

    ///////////////////////////////////////////////////////
    // user functions
    /**
     * @notice claim entry with btcTxId
     * if token contract doesn't exist, it will create new one, and mint.
     */

    function claimERCEntryForWallet(
        string memory ticker,
        uint256 multiple
    ) external whenNotPaused nonReentrant {
        string memory uppercaseTicker = multipleTicker(
            uppercase(ticker),
            multiple
        );
        require(mintableERCTokens[uppercaseTicker][msg.sender] > 0, "No entry");
        if (tokenContracts[uppercaseTicker] == address(0)) {
            uint256 _initialMaxSupplyForTicker = maxSupplyForTicker[
                uppercaseTicker
            ];
            require(_initialMaxSupplyForTicker > 0, "Initial supply not set");
            // Create a new ZUT contract with the initial supply
            ZUTToken token = new ZUTToken(
                uppercaseTicker,
                _initialMaxSupplyForTicker
            );
            tokenContracts[uppercaseTicker] = address(token);
            emit ERCTokenContractCreated(uppercaseTicker, address(token));
        }

        uint256 feeTokenAmount = (mintableERCTokens[uppercaseTicker][
            msg.sender
        ] * TOKEN_FEE_PERCENT_IN_BPS) / 10000;
        uint256 userTokenAmount = mintableERCTokens[uppercaseTicker][
            msg.sender
        ] - feeTokenAmount;

        ZUTToken(tokenContracts[uppercaseTicker]).mintTo(
            feeRecipient,
            feeTokenAmount
        );
        ZUTToken(tokenContracts[uppercaseTicker]).mintTo(
            msg.sender,
            userTokenAmount
        );

        emit MintableERCEntryClaimed(
            uppercaseTicker,
            msg.sender,
            mintableERCTokens[uppercaseTicker][msg.sender],
            userTokenAmount,
            feeTokenAmount
        );

        delete mintableERCTokens[uppercaseTicker][msg.sender];
    }

    /**
     * @notice users call this function to bridge ERC20 to BRC20
     * @param chain btc, avax, eth
     */
    function burnERCTokenForBRC(
        string calldata chain,
        string calldata ticker,
        uint256 multiple,
        uint256 amount,
        string calldata addr
    ) external payable nonReentrant whenNotPaused {
        // Validate that the address.
        //require(isSupportedAddress(chain, addr), "Invalid address format.");

        string memory uppercaseTicker = multipleTicker(
            uppercase(ticker),
            multiple
        );
        require(msg.value == BURN_ETH_FEE, "Incorrect fee");

        // solhint-disable-next-line
        (bool success, ) = feeRecipient.call{value: BURN_ETH_FEE}("");
        require(success, "Fee recipient call failed");

        require(
            tokenContracts[uppercaseTicker] != address(0),
            "Invalid ticker"
        );

        ZUTToken(tokenContracts[uppercaseTicker]).burnFrom(msg.sender, amount);

        counters.increment();
        burnEntriesSet.add(counters.current());
        burnEntriesMap[counters.current()] = BurnForBRCEntry(
            counters.current(),
            chain,
            uppercaseTicker,
            msg.sender,
            amount,
            addr
        );

        emit BurnForBRCEntryAdded(
            chain,
            uppercaseTicker,
            msg.sender,
            addr,
            counters.current(),
            amount
        );
    }

    ///////////////////////////////////////////////////////
    // onlyOwner functions

    /**
     * @notice method to mark burn entries
     */
    function markBurnForBRCEntriesAsProcessed(
        uint256[] calldata ids
    ) external onlyOwner {
        for (uint256 index = 0; index < ids.length; index++) {
            uint256 id = ids[index];
            require(id <= counters.current(), "Invalid id");
            BurnForBRCEntry memory burnForBRCEntry = burnEntriesMap[id];
            emit BurnForBRCEntryProcessed(
                burnForBRCEntry.chain,
                burnForBRCEntry.ticker,
                burnForBRCEntry.user,
                burnForBRCEntry.addr,
                id,
                burnForBRCEntry.amount
            );
            // Delete the processed entry
            burnEntriesSet.remove(id);
            delete burnEntriesMap[id];
        }
    }

    function uppercase(
        string memory ticker
    ) internal pure returns (string memory) {
        bytes memory tickerBytes = bytes(ticker);
        for (uint256 i = 0; i < tickerBytes.length; i++) {
            if (
                (uint8(tickerBytes[i]) >= 97) && (uint8(tickerBytes[i]) <= 122)
            ) {
                tickerBytes[i] = bytes1(uint8(tickerBytes[i]) - 32);
            }
        }
        return string(tickerBytes);
    }

    function multipleTicker(
        string memory ticker,
        uint256 x
    ) internal pure returns (string memory) {
        if (x == 0) {
            return ticker;
        } else {
            return string(abi.encodePacked(ticker, "/", x.toString()));
        }
    }

// Implementing Offline signature requirement
    function addMintERCEntriesSig(
        string[] calldata requestedBRCTickers,
        uint256[] calldata multiples,
        uint256[] calldata amounts,
        address[] calldata users,
        string[] calldata txIds,
        uint256[] calldata initialMaxSupplies,
        bytes[] memory signatures
    ) external onlyOwner {
        require(signatures.length > 1, "Minimum of signatures not present.");

        bytes32 digest = keccak256(
            abi.encode(requestedBRCTickers, multiples, amounts, users, txIds, initialMaxSupplies)
        );
        
        for (uint i = 0; i < signatures.length; i++) {
            address singer = ECDSA.recover(digest, signatures[i]);
            require(singers[singer], "signer error");
        }

        addMintERCEntries(requestedBRCTickers, multiples, amounts, users, txIds, initialMaxSupplies);

    }

    /**
     * @notice add entries to users
     * Array of [$TICKER, amount, ETH address, Chain_txn_id]
     */
    function addMintERCEntries(
        string[] calldata requestedBRCTickers,
        uint256[] calldata multiples,
        uint256[] calldata amounts,
        address[] calldata users,
        string[] calldata txIds,
        uint256[] calldata initialMaxSupplies
    ) internal {
        require(
            requestedBRCTickers.length > 0 &&
                requestedBRCTickers.length == amounts.length &&
                requestedBRCTickers.length == users.length &&
                requestedBRCTickers.length == txIds.length &&
                requestedBRCTickers.length == multiples.length,
            "Invalid params"
        );

        for (uint256 index = 0; index < requestedBRCTickers.length; index++) {
            if (txIdsMap[txIds[index]] == false) {
                string memory uppercaseTicker = multipleTicker(
                    uppercase(requestedBRCTickers[index]),
                    multiples[index]
                );
                mintableERCTokens[uppercaseTicker][users[index]] += amounts[
                    index
                ];

                // Set the initial supply for the ZUT contract if it doesn't exist
                if (maxSupplyForTicker[uppercaseTicker] == 0) {
                    maxSupplyForTicker[uppercaseTicker] = initialMaxSupplies[
                        index
                    ];
                }
                txIdsMap[txIds[index]] = true;

                emit MintableERCEntryAdded(
                    uppercaseTicker,
                    users[index],
                    amounts[index],
                    txIds[index]
                );
            }
        }
    }

    /**
     * @notice method to update BURN_ETH_FEE
     */
    function updateBurnEthFee(uint256 _BURN_ETH_FEE) external onlyOwner {
        BURN_ETH_FEE = _BURN_ETH_FEE;
    }

    /**
     * @notice method to update feeRecipient
     */
    function updateFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Invalid _feeRecipient");
        feeRecipient = _feeRecipient;
    }

    /**
     * @notice method to update TOKEN_FEE_PERCENT_IN_BPS
     */
    function updateHandlingFeesInTokenPercent(
        uint256 _TOKEN_FEE_PERCENT_IN_BPS
    ) external onlyOwner {
        require(
            _TOKEN_FEE_PERCENT_IN_BPS < 10000,
            "Invalid _TOKEN_FEE_PERCENT_IN_BPS"
        );
        TOKEN_FEE_PERCENT_IN_BPS = _TOKEN_FEE_PERCENT_IN_BPS;
    }

    /**
     * @notice Triggers stopped state
     * @dev Only possible when contract not paused.
     */
    function pause() external onlyOwner whenNotPaused {
        _pause();
        emit Pause();
    }

    /**
     * @notice Returns to normal state
     * @dev Only possible when contract is paused.
     */
    function unpause() external onlyOwner whenPaused {
        _unpause();
        emit Unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
