// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;

contract AuctionFactory {
    Auction[] public auctions;

    function createAuction() public {
        Auction newAuction = new Auction(msg.sender);
        auctions.push(newAuction);
    }
}

contract Auction {
    address payable public owner;
    uint256 public startBlock;
    uint256 public endBlock;
    string public ipfsHash;

    enum State {
        Started,
        Running,
        Ended,
        Canceled
    }
    State public auctionState;

    uint256 public highestBindingBid;
    address payable public highestBidder;

    mapping(address => uint256) public bids;

    uint256 bidIncrement;

    constructor(address eoa) {
        owner = payable(eoa);
        auctionState = State.Running;
        startBlock = block.number;
        endBlock = startBlock + 40320;
        ipfsHash = "";
        bidIncrement = 10;
    }

    modifier ownerOnly {
        require(
            msg.sender == owner,
            "you must be the ownwer to perform this action!"
        );
        _;
    }

    modifier notOwner {
        require(
            msg.sender != owner,
            "you must not be the ownwer to perform this action!"
        );
        _;
    }

    modifier afterStart() {
        require(block.number >= startBlock);
        _;
    }

    modifier beforeEnd() {
        require(block.number <= endBlock);
        _;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a < b) {
            return a;
        } else {
            return b;
        }
    }

    function cancelAuction() public ownerOnly {
        auctionState = State.Canceled;
    }

    function placeBid() public payable notOwner afterStart beforeEnd {
        require(auctionState == State.Running);
        require(msg.value >= 100);
        uint256 currentBid = bids[msg.sender] + msg.value;
        require(
            currentBid > highestBindingBid,
            "highest bid must be higher than highestBindingBid"
        );

        bids[msg.sender] = currentBid;

        if (currentBid <= bids[highestBidder]) {
            highestBindingBid = min(
                currentBid + bidIncrement,
                bids[highestBidder]
            );
        } else {
            highestBidder = payable(msg.sender);
        }
    }

    function finalizeAuction() public {
        require(auctionState == State.Canceled || block.number > endBlock);
        require(msg.sender == owner || bids[msg.sender] > 0);

        address payable recipient;
        uint256 value;

        // auction was Canceled
        if (auctionState == State.Canceled) {
            recipient = payable(msg.sender);
            value = bids[msg.sender];
        } else {
            // auction not Canceled
            if (msg.sender == owner) {
                recipient = owner;
                value = highestBindingBid;
            } else {
                // this is a bidder
                if (msg.sender == highestBidder) {
                    recipient = highestBidder;
                    value = bids[highestBidder] - highestBindingBid;
                } else {
                    recipient = payable(msg.sender);
                    value = bids[msg.sender];
                }
            }
        }
        // send money to the recipient
        recipient.transfer(value);
    }
}
