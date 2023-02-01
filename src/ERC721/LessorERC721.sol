// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {ISuperfluid} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

import "./CloneERC721.sol";
import "./SafeERC721.sol";
import "../FeesManager.sol";

struct LeaseData {
    bool isAvailableForLease;
    address lessee;
    uint256 leasingStartTimestamp;
}

struct Lessee {
    bool isAllowed;
    uint16 nftNumberLeased;
}

contract LessorERC721 is IERC721Receiver {
    /// @dev CFAv1 Library
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData private cfaV1;

    SafeERC721 public immutable safeContract;
    FeesManager public immutable feesManager;

    /// @dev Address of the Superfluid Host contract
    ISuperfluid private host; // host

    /// @dev Address of the Superfluid CFA contract
    IConstantFlowAgreementV1 private cfa;

    /// @dev Lease Data by NFT Original Contract Address and Token ID
    mapping(address => mapping(uint256 => LeaseData))
        private leaseDataByContractAddress;
    /// @dev Lessee by Address
    mapping(address => Lessee) private lessees;

    error IsNotLessee(address caller);
    error IsNotAvailableForLease(address nftContract, uint256 tokenId);
    error FlowRateNotUpdated(address receiver, int96 outFlowRate, int96 expectedOutFlowRate);
    error IsNotAuthorized(address caller);

    /// @notice Open or Increase Stream Event
    event OpenIncreaseStream(
        address receiver,
        int96 leasingFlowRatePrice,
        int96 outFlowRateReceiver,
        int96 outFlowRateFees
    );
    /// @notice Close Stream Event
    event CloseStream(address receiver);

    constructor(ISuperfluid _host, address _admin, address _feesManager) {
        safeContract = new SafeERC721(_admin);
        feesManager = FeesManager(_feesManager);
        cfaV1 = CFAv1Library.InitData(
            _host,
            IConstantFlowAgreementV1(
                address(
                    _host.getAgreementClass(
                        keccak256(
                            "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
                        )
                    )
                )
            )
        );
    }

    function getNftIdsAvailable(
        address _nftContract
    ) external view returns (uint256[] memory nftIds) {
        uint256[] memory _nftIds = safeContract.getNftIDsStaked(_nftContract);
        nftIds = new uint256[](_nftIds.length);
        uint256 j = 0;
        for (uint256 i = 0; i < _nftIds.length; i++) {
            if (
                leaseDataByContractAddress[_nftContract][_nftIds[i]]
                    .isAvailableForLease
            ) {
                nftIds[j] = _nftIds[i];
                j++;
            }
        }
    }

    function getLeaseData(
        address _nftContract,
        uint256 _tokenId
    )
        external
        view
        returns (
            bool isAvailable,
            address lessee,
            address cloneContract,
            address leasingPaymentToken,
            int96 leasingFlowRatePrice,
            uint256 leasingStartTimestamp,
            uint256 leasingDurationMin,
            uint256 leasingDurationMax
        )
    {
        SafeERC721.StakingData memory stakingData = safeContract.getStakeData(
            _nftContract,
            _tokenId
        );
        LeaseData memory leaseData = leaseDataByContractAddress[_nftContract][
            _tokenId
        ];
        isAvailable = leaseData.isAvailableForLease;
        lessee = leaseData.lessee;
        cloneContract = stakingData.cloneContract;
        leasingFlowRatePrice = stakingData.leasingFlowRatePrice;
        leasingStartTimestamp = leaseData.leasingStartTimestamp;
        leasingDurationMin = stakingData.leasingDurationMin;
        leasingDurationMax = stakingData.leasingDurationMax;
        leasingPaymentToken = stakingData.leasingPaymentToken;
    }

    function startLease(address _nftContract, uint256 _tokenId) external {
        if (!lessees[msg.sender].isAllowed) {
            revert IsNotLessee(msg.sender);
        }
        SafeERC721.StakingData memory stakingData = safeContract.getStakeData(
            _nftContract,
            _tokenId
        );
        if (
            !stakingData.isStaked ||
            !leaseDataByContractAddress[_nftContract][_tokenId]
                .isAvailableForLease
        ) {
            revert IsNotAvailableForLease(_nftContract, _tokenId);
        }
        leaseDataByContractAddress[_nftContract][_tokenId]
            .isAvailableForLease = false;
        leaseDataByContractAddress[_nftContract][_tokenId].lessee = msg.sender;
        leaseDataByContractAddress[_nftContract][_tokenId]
            .leasingStartTimestamp = block.timestamp;
        openStreams(stakingData.owner, ISuperToken(stakingData.leasingPaymentToken), stakingData.leasingFlowRatePrice);
        CloneERC721 cloneContract = CloneERC721(stakingData.cloneContract);
        cloneContract.safeTransferFrom(address(this), msg.sender, _tokenId);
    }

    function stopLease(address _nftContract, uint256 _tokenId) external {
        if (!lessees[msg.sender].isAllowed) {
            revert IsNotLessee(msg.sender);
        }
        SafeERC721.StakingData memory stakingData = safeContract.getStakeData(
            _nftContract,
            _tokenId
        );
        if (
            leaseDataByContractAddress[_nftContract][_tokenId].lessee !=
            msg.sender
        ) {
            revert IsNotLessee(msg.sender);
        }
        leaseDataByContractAddress[_nftContract][_tokenId]
            .isAvailableForLease = true;
        leaseDataByContractAddress[_nftContract][_tokenId].lessee = address(0);
        leaseDataByContractAddress[_nftContract][_tokenId]
            .leasingStartTimestamp = 0;
        closeStreams(stakingData.owner, ISuperToken(stakingData.leasingPaymentToken), stakingData.leasingFlowRatePrice);
        CloneERC721 cloneContract = CloneERC721(stakingData.cloneContract);
        cloneContract.safeTransferFrom(msg.sender, address(this), _tokenId);
    }

    /// @dev Opens or increases streams
    /// @notice Caller must call 'cfaV1.authorizeFlowOperatorWithFullControl' before calling this function
    /// @param _receiver Address of the receiver
    /// @param _superToken Address of the payment token
    /// @param _flowRate Flow Rate
    function openStreams(
        address _receiver,
        ISuperToken _superToken,
        int96 _flowRate
    ) internal {
        // Gets the current flow rate from the lessee to the NFT owner
        (, int96 outFlowRateOwner, , ) = cfa.getFlow(
            _superToken,
            msg.sender,
            _receiver
        );
        // Gets the current flow rate from the lessee to the fees manager
        (, int96 outFlowRateFees, , ) = cfa.getFlow(
            _superToken,
            msg.sender,
            address(feesManager)
        );
        // Gets the fees flow rate 
        int96 feesFlowRate = feesManager.getFeesRate(msg.sender);
        // Opens or increases the flow rate from the lessee to the NFT owner
        outFlowRateOwner == 0
            ? cfaV1.createFlowByOperator(
                msg.sender,
                _receiver,
                _superToken,
                _flowRate
            )
            : cfaV1.updateFlowByOperator(
                msg.sender,
                _receiver,
                _superToken,
                _flowRate + outFlowRateOwner
            );
        // Opens or increases the flow rate from the lessee to the fees manager
        outFlowRateFees == 0
            ? cfaV1.createFlowByOperator(
                msg.sender,
                address(feesManager),
                _superToken,
                feesFlowRate
            )
            : cfaV1.updateFlowByOperator(
                msg.sender,
                address(feesManager),
                _superToken,
                feesFlowRate + outFlowRateFees
            );
        // Gets the new current flow rate from the lessee to the NFT owner
        (, int96 newOutFlowRateOwner, , ) = cfa.getFlow(
            _superToken,
            msg.sender,
            _receiver
        );
        if (newOutFlowRateOwner != _flowRate + outFlowRateOwner) {
            revert FlowRateNotUpdated(_receiver, newOutFlowRateOwner, _flowRate + outFlowRateOwner);
        }
        // Gets the new current flow rate from the lessee to the NFT owner
        (, int96 newOutFlowRateFees, , ) = cfa.getFlow(
            _superToken,
            msg.sender,
            address(feesManager)
        );
        if (newOutFlowRateFees != feesFlowRate + outFlowRateFees) {
            revert FlowRateNotUpdated(address(feesManager), newOutFlowRateFees, feesFlowRate + outFlowRateFees);
        }
    }

    /// @dev Closes or decreases streams
    /// @param _receiver Address of the receiver
    /// @param _superToken Address of the payment token
    /// @param _flowRate Flow Rate
    function closeStreams(
        address _receiver,
        ISuperToken _superToken,
        int96 _flowRate
    ) internal {
        // Gets the current flow rate from the lessee to the NFT owner
        (, int96 outFlowRateOwner, , ) = cfa.getFlow(
            _superToken,
            msg.sender,
            _receiver
        );
        // Gets the current flow rate from the lessee to the fees manager
        (, int96 outFlowRateFees, , ) = cfa.getFlow(
            _superToken,
            msg.sender,
            address(feesManager)
        );
        // Gets the data of the lessee
        Lessee memory lessee = lessees[msg.sender];
        // If the lessee has more than one NFT leased
        if (lessee.nftNumberLeased > 1) {
            // Decreases the flow rate from the lessee to the NFT owner
            cfaV1.updateFlowByOperator(
                msg.sender,
                _receiver,
                _superToken,
                outFlowRateOwner - _flowRate
            );
            // Decreases the flow rate from the lessee to the fees manager
            cfaV1.updateFlowByOperator(
                msg.sender,
                address(feesManager),
                _superToken,
                outFlowRateFees - feesManager.getFeesRate(msg.sender)
            );
        } 
        // If the lessee has only one NFT leased
        else {
            // Closes the flow rate from the lessee to the NFT owner
            cfaV1.deleteFlowByOperator(msg.sender, _receiver, _superToken);
            // Closes the flow rate from the lessee to the fees manager
            cfaV1.deleteFlowByOperator(
                msg.sender,
                address(feesManager),
                _superToken
            );
        }
        // Gets the new current flow rate from the lessee to the NFT owner
        (, int96 newOutFlowRateOwner, , ) = cfa.getFlow(
            _superToken,
            msg.sender,
            _receiver
        );
        if (newOutFlowRateOwner != outFlowRateOwner - _flowRate) {
            revert FlowRateNotUpdated(_receiver, newOutFlowRateOwner, outFlowRateOwner - _flowRate);
        }
        // Gets the new current flow rate from the lessee to the fees manager
        (, int96 newOutFlowRateFees, , ) = cfa.getFlow(
            _superToken,
            msg.sender,
            address(feesManager)
        );
        if (newOutFlowRateFees != outFlowRateFees - feesManager.getFeesRate(msg.sender)) {
            revert FlowRateNotUpdated(address(feesManager), newOutFlowRateFees, outFlowRateFees - feesManager.getFeesRate(msg.sender));
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
