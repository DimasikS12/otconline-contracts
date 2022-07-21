// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "./IERC20.sol";

struct Deal {
    address payable seller;
    address payable buyer;
    uint price;
    uint fee;
    uint date;
}

// final version works with BUSD token
contract SafeDeal {   
    IERC20 private _token; 
    address private _owner;
    address[] private _moderators;
    mapping(uint => Deal) private _deals; // active deals
    uint[] private _ids; // will help to organize mapping loop

    modifier onlyOwner() {
        require(msg.sender == _owner, "this function can be called by owner only");
        _;
    }

    modifier onlyModerator() {
        bool exists = false;

        for (uint i = 0; i < _moderators.length; i++) {
            if (msg.sender == _moderators[i]) {
                exists = true;
                break;
            }
        }

        require(exists, "this function can be called by moderator only");
        _;
    }

    event Started(uint id, Deal deal);
    event Completed(uint id, Deal deal);
    event Cancelled(uint id, Deal deal);
    event ModeratorAdded(address[] moderators);
    event ModeratorRemoved(address[] moderators);
    event Balance(uint value);
    event BalanceAfterWithdraw(uint value);

    constructor() {
        _token = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); // token contract addr 
        _owner = msg.sender;      
    }
    
    function start(uint id, address payable seller, address payable buyer, uint price, uint fee) public payable {
        require(msg.sender == buyer, "this function can be called by buyer only");
        Deal memory deal = Deal({
            seller: seller,
            buyer: buyer,
            price: price,
            fee: fee,
            date: block.timestamp
        });
        _deals[id] = deal;
        _ids.push(id);
        bool sent = _token.transferFrom(buyer, address(this), price + fee); // approve is not needed, it was done by external transaction
        require(sent, "payment to contract failed");
        emit Started(id, deal);    
    }  
    
    function completeByBuyer(uint id) public payable {
        Deal memory deal = _deals[id];
        require(deal.buyer == msg.sender, "this function can be called by buyer only");
        bool approved = _token.approve(address(this), deal.price);
        require(approved, "approve failed");
        bool sent = _token.transferFrom(address(this), deal.seller, deal.price);
        require(sent, "payment to seller failed");        
        deleteDeal(id); // remove deal after completing
        emit Completed(id, deal);        
    }

    function completeByModerator(uint id) public onlyModerator payable {
        Deal memory deal = _deals[id];
        bool approved = _token.approve(address(this), deal.price);
        require(approved, "approve failed");
        bool sent = _token.transferFrom(address(this), deal.seller, deal.price);
        require(sent, "payment to seller failed");        
        deleteDeal(id); // remove deal after completing
        emit Completed(id, deal);
    }

    function cancelByModerator(uint id) public onlyModerator payable {
        Deal memory deal = _deals[id];
        bool approved = _token.approve(address(this), deal.price + deal.fee);
        require(approved, "approve failed");
        bool sent = _token.transferFrom(address(this), deal.buyer, deal.price + deal.fee);
        require(sent, "payment to buyer failed");        
        deleteDeal(id); // remove deal after completing  
        emit Cancelled(id, deal);
    }

    function addModerator(address moderator) onlyOwner public {
        bool exists = false;

        for (uint i = 0; i < _moderators.length; i++) {
            if (moderator == _moderators[i]) {
                exists = true;
                break;
            }
        }

        require(!exists, "moderator already exists");
        _moderators.push(moderator);
        emit ModeratorAdded(_moderators);
    }

    function removeModerator(address moderator) onlyOwner public {
        uint index;
        bool exists = false;

        for (uint i = 0; i < _moderators.length; i++) {
            if (moderator == _moderators[i]) {
                index = i;
                exists = true;
                break;
            }
        }

        require(exists, "moderator not found");
        _moderators[index] = _moderators[_moderators.length - 1];
        _moderators.pop();
        emit ModeratorRemoved(_moderators);
    }

    function getBalance() onlyOwner public returns(uint) {
        uint reserved = 0;

        for (uint i = 0; i < _ids.length; i++) {
            reserved += (_deals[_ids[i]].price + _deals[_ids[i]].fee);
        }

        uint balance = _token.balanceOf(address(this)) - reserved;
        emit Balance(balance);
        return balance;
    }

    function withdraw(address payable wallet, uint value) onlyOwner public payable {
        uint balance = getBalance();
        require(balance >= value, "insufficient tokens");
        bool approved = _token.approve(address(this), value);
        require(approved, "approve failed");
        bool sent = _token.transferFrom(address(this), wallet, value);
        require(sent, "payment failed");
        emit BalanceAfterWithdraw(balance - value);
    }

    // utils

    function deleteDeal(uint id) private {
        // delete deal
        delete _deals[id];

        // delete deal id
        uint index;
        bool exists = false;

        for (uint i = 0; i < _ids.length; i++) {
            if (id == _ids[i]) {
                index = i;
                exists = true;
                break;
            }
        }

        require(exists, "cant delete deal id, not found");
        _ids[index] = _ids[_ids.length - 1];
        _ids.pop();
    }   
}
