//SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

contract Consumer{
    function getBalance() public view returns (uint){
        return address(this).balance;
    }
    function deposit() public payable{}
}

contract SmartContractWallet{

    address public owner;
    address public nextWalletOwner;

    uint8 public guardianVoteCount;
    uint8 public constant guardianVotesNeededForOwnerChange = 3;

    mapping(address => bool) public allowedToSend;
    mapping(address => uint) public addressAllowance;

    mapping(address => mapping(address => bool)) public guardianVotes;
    mapping(address => bool) public guardians;


    constructor(){
        owner = payable(msg.sender);
    }

    /**
    *@dev Wallet Owner sets the Allowance for an Address 
    *@param _for Address to set the allowance for
    *@param _allowance Allowance that is set for the _for address
    */
    function setAllowanceForAddress(address _for, uint _allowance) public {
        require(msg.sender == owner, "You are not the smart contract owner");
        require(_allowance >= 0, "Allowance cannot be less than 0 Wei");
        addressAllowance[_for] = _allowance;
        allowedToSend[_for] = true;
    }

    /// @dev Wallet Owner sets the Guardian Address
    /// @param _guardian The address to add to guardians
    function setGuardian(address _guardian) public {
        require(msg.sender == owner, "You must be the owner to set a guardian");
        guardians[_guardian] = true;
    }

    function getAddressAllowance(address _for)public view returns(uint){
        return addressAllowance[_for];
    }

    function getWalletBalance()public view returns(uint){
        return address(this).balance;
    }

    /*
    *@dev Guardians can set a new Wallet Owner address, at least 3 unique Guardian addresses need to vote for the new owner in a row
    *@param _newWalletOwner The address which the guardian is voting for
    *@notice Wallet Guardian calls the function with an address that he approves to be the next walletOwner
    */
    function proposeNewOwner(address payable _newWalletOwner) public {
        require(guardians[msg.sender], "You are not a guardian for the wallet");
        require(guardianVotes[_newWalletOwner][msg.sender] == false, "You have already Voted");

        if(nextWalletOwner != _newWalletOwner){
            nextWalletOwner = _newWalletOwner;
            guardianVoteCount = 0;
        }

        guardianVotes[_newWalletOwner][msg.sender] = true;
        guardianVoteCount ++;

        if(guardianVoteCount >= guardianVotesNeededForOwnerChange){
            owner = _newWalletOwner;
            nextWalletOwner = payable(address(0));
        }
    }


    ///@dev Simple Transfer function that allows to transfer fund to a certain address based on address allowance, Owner can withdraw the whole smart contract balance
    /// @param _to The address to which the funds would be transfered
    /// @param _amount The amount of funds to be transfered
    /// @param _payload Payload parameter
    function transfer(address payable _to, uint _amount, bytes memory _payload) public returns (bytes memory){
        if(msg.sender != owner){
            require(allowedToSend[_to], "You are not allowed to send funds");
            require(address(this).balance >= _amount, "Insufficient wallet balance");
            require(addressAllowance[_to] >= _amount, "Over the withdraw limit");

            addressAllowance[_to] -= _amount;
        }

        // Owner can withhdraw all funds with no allowance
        (bool success, bytes memory returnData) = _to.call{value: _amount}(_payload);
        require(success, "Aborting, call was not successful");
        return returnData;

    }

    receive() external payable{}

}