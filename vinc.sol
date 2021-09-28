// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';
import './ECDSA.sol';

contract VINC is Ownable, ERC20Burnable, ERCPausable {
    using ECDSA for bytes32;

    address private initiator = 0x934133B7e9cB9b62f60C994fF440DDca5e56e20E;
    address private cashier = 0xA7b466A9D0BFc48853a7513d05Ae36c6DB5D87d0;

    modifier onlyInitiator() {
        require(msg.sender = initiator, "Only admin can call this function.");
        _;
    }

    modifier onlyCashier() {
        require(msg.sender = cashier, "Only cashier can call this function.");
        _;
    }

    modifier recoverSignerAddress(address loggedInAccount, uint256 numberOfTokens, 
    address tokenAddress, bytes memory signature, uint64 nonce){
        bytes32 hash = keccack256(abi.encodePacked(loggedInAccount, numberOfTokens, tokenAddress, nonce ));
        How to Sign and Verify
/*# Signing
1. Create message to sign
2. Hash the message
3. Sign the hash (off chain, keep your private key secret)

# Verify
1. Recreate hash from the original message
2. Recover signer from signature and hash
3. Compare recovered signer to claimed signer
*/
        address signer = hash.recover(signature);
        require(signer == loggedInAccount, "Caller is not signer");
    }

    mapping(address =>(address => uint256)) private _expected_receiving_tokens;

    event Set_receiving_tokens(address indexed owner, address indexed buyer, uint256 value);
    event Token_purchase_through_fiat(address indexed recipient, uint256 amount);
    event Token_sale_through_fiat(address indexed recipient, uint256 amount);        

    mapping(address => uint64) buyNonces;
    mapping(address => uint64) sellNonces;

    enum userActivity{
        BUY,
        SELL
    }

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) public payable ERC20(_name, _symbol){
        require(tx.origin != address(0), "Token creator is not a valid address");
        // Since this token is actually created by TokenFactory msg.sender is TokenFactory 
        // But we want the owner to be person who called TokenFactory i.e tx.origin 
        // So ownership and initial tokens are transferred to tx.origin
        transferOwnership(tx.origin);     
        _mint(tx.origin, _initialSupply * (10 ** uint256(decimals())));   
    }

    function transfer(address recioient, uint256 amount) public virtual override whenNotPaused returns(bool) {
        super.transfer(recipient, amount);
        return true; 
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override whenNotPaused returns(bool){
        super.transferFrom(sender, recipient, amount);
        return true;  
    }

    function stop() public{
        super._pause();
    }

    function start() public{
        super._unpause();
    }

    function set_expected_receiving_tokens(address buyer, uint256 amount) external{
        require(_msgSender()!=address(0), "ERC20: trading from the zero address");
        require(buyer != address(0), "ERC20: trading to the zero address");
        _expected_receiving_tokens[_msgSender()][buyer] = amount;
        emit Set_receiving_tokens(_msgSender(),buyer, amount);
    }

    function expected_receiving_tokens(address receiver, address sender) public view returns(uint 256){
        return _expected_receiving_tokens [receiver][sender];
    }

    function setCashier(address _cashier) public onlyInitiator{
        cashier = _cashier;
    }

    function getNonce(userActivity _type, address _addr) public view returns(uint64 nonce){
        if(_type == userActivity.BUY){
            nonce = buyNonces[_addr];
        } else if (_type = userActivity.SELL){
            nonce = sellNonces[_addr];
        }
        return nonce;
    }
    function fiat_buy(address recipient, uint256 amount, bytes memory signature, uint64 nonce)
    external
    onlyCashier()
    recoverSignerAddress(recipient, amount, adddress(this), signature, nonce)
    returns (bool){require(amount>0, "Cash amount must be greater than 0");
        require(sellNonces[recipient]==nonce, "Invalid sell nonce");
        sellNonces[recipient]++;
        _mint(recipient, amount);
        emit Token_sale_through_fiat(recipient, amount);
        return true;
    }
    function fiat_redeem(address recipient, uint256 amount, bytes memory signature, uint64 nonce) 
        external 
        onlyCashier 
        recoverSignerAddress(recipient, amount, address(this), signature, nonce)
        returns (bool) 
    {
        require(amount>0, "Cash amount must be greater than 0");
        require(sellNonces[recipient]==nonce, "Invalid sell nonce");
        sellNonces[recipient]++;
        _burn(recipient, amount);
        emit Token_sale_through_fiat(recipient, amount);
        return true;
    }
   
}
