// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract Auction {
    address public owner;
    uint256 public auctionEndTime;
    uint256 public auctionExtendedTime = 10 minutes;
    uint256 public highestBid;
    address public highestBidder;
    uint256 public minimumIncrement = 5;
    bool public ended;

    struct Offer {
        address bidder;
        uint256 amount;
    }

    Offer[] public offers;
    mapping(address => uint256) public bids;

    event NewBid(address indexed bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el owner puede ejecutar esta funcion");
        _;
    }

    modifier auctionActive() {
        require(block.timestamp < auctionEndTime && !ended, "La subasta no esta activa");
        _;
    }

    modifier auctionEnded() {
        require(block.timestamp >= auctionEndTime || ended, "La subasta sigue activa");
        _;
    }

    constructor(uint256 _durationMinutes) {
        owner = msg.sender;
        auctionEndTime = block.timestamp + (_durationMinutes * 1 minutes);
    }

    function bid() external payable auctionActive {
        require(msg.value > 0, "La oferta debe ser mayor a 0");
        uint256 minimumBid = highestBid + (highestBid * minimumIncrement / 100);
        require(msg.value >= minimumBid, "Oferta debe ser al menos 5% mayor que la oferta mas alta");

        // Registrar oferta
        bids[msg.sender] += msg.value;
        offers.push(Offer({bidder: msg.sender, amount: msg.value}));

        // Actualizar mejor oferta
        highestBid = msg.value;
        highestBidder = msg.sender;
        emit NewBid(msg.sender, msg.value);

        // Extender la subasta si estamos en los ultimos 10 minutos
        if (block.timestamp + auctionExtendedTime > auctionEndTime) {
            auctionEndTime += auctionExtendedTime;
        }
    }

    function endAuction() external onlyOwner auctionActive {
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    function withdraw() external auctionEnded {
        uint256 amount = bids[msg.sender];
        require(amount > 0, "No hay fondos para retirar");
        bids[msg.sender] = 0;

        // Si el ofertante no es el ganador, devolver el deposito menos una comision del 2%
        if (msg.sender != highestBidder) {
            uint256 fee = amount * 2 / 100;
            amount -= fee;
        }

        payable(msg.sender).transfer(amount);
    }

    function partialWithdraw(uint256 _amount) external auctionActive {
        uint256 availableAmount = bids[msg.sender] - highestBid;
        require(availableAmount > 0, "No hay fondos excedentes para retirar");
        require(_amount <= availableAmount, "Excede el monto disponible");

        bids[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    function getOffers() external view returns (Offer[] memory) {
        return offers;
    }

    function getWinner() external view auctionEnded returns (address, uint256) {
        return (highestBidder, highestBid);
    }
}