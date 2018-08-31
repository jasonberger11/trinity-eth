pragma solidity ^0.4.18;

interface token {
    function transferFrom (address _from,address _to, uint256 _value) external returns (bool success);
    function approve (address _spender,uint256 _value) external;
    function transfer(address _to, uint256 _value) external;
}

contract TrinityEvent{

    event Deposit(bytes32 channleId, address partnerA, uint256 amountA,address partnerB, uint256 amountB);
    event UpdateDeposit(bytes32 channleId, address partnerA, uint256 amountA, address partnerB, uint256 amountB);    
    event QuickCloseChannel(bytes32 channleId, address closer, uint256 amount1, address partner, uint256 amount2);
    event CloseChannel(bytes32 channleId, address closer, address partner);
    event UpdateTransaction(bytes32 channleId, address partnerA, uint256 amountA, address partnerB, uint256 amountB);
    event Settle(bytes32 channleId, address partnerA, uint256 amountA, address partnerB, uint256 amountB);
    event Withdraw(bytes32 channleId, bytes32 hashLock);
    event WithdrawUpdate(bytes32 channleId, bytes32 hashLock, uint256 balance);
    event WithdrawSettle(bytes32 channleId, bytes32 hashLock, uint256 balance); 
    event SetSettleTimeout(uint256 timeoutBlock);
    event SetToken(address tokenValue);
}

contract Owner{
    address public owner;
    bool paused;
    
    constructor() public{
        owner = msg.sender;
        paused = false;
    }
    
    modifier onlyOwner(){
        require(owner == msg.sender);
        _;
    } 
    
    modifier whenNotPaused(){
        require(!paused);
        _;
    }

    modifier whenPaused(){
        require(paused);
        _;
    }

    //disable contract setting funciton
    function pause() external onlyOwner whenNotPaused {
        paused = true;
    }

    //enable contract setting funciton
    function unpause() public onlyOwner whenPaused {
        paused = false;
    }    
    
}

contract VerifySignature{
    
    function verifyTimelock(bytes32 channelId,
                            uint256 nonce,
                            address sender,
                            address receiver,
                            uint256 lockPeriod ,
                            uint256 lockAmount,
                            bytes32 lockHash,
                            bytes partnerAsignature,
                            bytes partnerBsignature) internal pure returns(bool)  {

        address recoverA = verifyLockSignature(channelId, nonce, sender, receiver, lockPeriod, lockAmount,lockHash, partnerAsignature);
        address recoverB = verifyLockSignature(channelId, nonce, sender, receiver, lockPeriod, lockAmount,lockHash, partnerBsignature);
        if ((recoverA == sender && recoverB == receiver) || (recoverA == receiver && recoverB == sender)){
            return true;
        }
        return false;
    }

    function verifyLockSignature(bytes32 channelId,
                                uint256 nonce,
                                address sender,
                                address receiver,
                                uint256 lockPeriod ,
                                uint256 lockAmount,
                                bytes32 lockHash,
                                bytes signature) internal pure returns(address)  {

        bytes32 data_hash;
        address recover_addr;
        data_hash=keccak256(channelId, nonce, sender, receiver, lockPeriod, lockAmount,lockHash);
        recover_addr=_recoverAddressFromSignature(signature,data_hash);
        return recover_addr;
    }

     /*
     * Funcion:   parse both signature for check whether the transaction is valid
     * Parameters:
     *    addressA: node address that deployed on same channel;
     *    addressB: node address that deployed on same channel;
     *    balanceA : nodaA assets amount;
     *    balanceB : nodaB assets assets amount;
     *    nonce: transaction nonce;
     *    signatureA: A signature for this transaction;
     *    signatureB: B signature for this transaction;
     * Return:
     *    result: if both signature is valid, return TRUE, or return False.
    */

    function verifyTransaction(
        bytes32 channelId,
        uint256 nonce,
        address addressA,
        uint256 balanceA,
        address addressB,
        uint256 balanceB,
        bytes signatureA,
        bytes signatureB) internal pure returns(bool result){

        address recoverA;
        address recoverB;

        recoverA = recoverAddressFromSignature(channelId, nonce, addressA, balanceA, addressB, balanceB, signatureA);
        recoverB = recoverAddressFromSignature(channelId, nonce, addressA, balanceA, addressB, balanceB, signatureB);
        if ((recoverA == addressA && recoverB == addressB) || (recoverA == addressB && recoverB == addressA)){
            return true;
        }
        return false;
    }

    function recoverAddressFromSignature(
        bytes32 channelId,
        uint256 nonce,
        address addressA,
        uint256 balanceA,
        address addressB,
        uint256 balanceB,
        bytes signature
        ) internal pure returns(address)  {

        bytes32 data_hash;
        address recover_addr;
        data_hash=keccak256(channelId, nonce, addressA, balanceA, addressB, balanceB);
        recover_addr=_recoverAddressFromSignature(signature,data_hash);
        return recover_addr;
    }


	function _recoverAddressFromSignature(bytes signature,bytes32 dataHash) internal pure returns (address)
    {
        bytes32 r;
        bytes32 s;
        uint8 v;

        (r,s,v)=signatureSplit(signature);

        return ecrecoverDecode(dataHash,v, r, s);
    }

    function signatureSplit(bytes signature)
        pure
        internal
        returns (bytes32 r, bytes32 s, uint8 v)
    {
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := and(mload(add(signature, 65)), 0xff)
        }
        v=v+27;
        require((v == 27 || v == 28), "check v value");
    }

    function ecrecoverDecode(bytes32 datahash,uint8 v,bytes32 r,bytes32 s) internal pure returns(address addr){

        addr=ecrecover(datahash,v,r,s);
        return addr;
    }
    
    function computeMerkleRoot(bytes lock, bytes merkle_proof)
        pure
        internal
        returns (bytes32)
    {
        require(merkle_proof.length % 32 == 0);

        uint i;
        bytes32 h;
        bytes32 el;

        h = keccak256(lock);
        for (i = 32; i <= merkle_proof.length; i += 32) {
            assembly {
                el := mload(add(merkle_proof, i))
            }

            if (h < el) {
                h = keccak256(h, el);
            } else {
                h = keccak256(el, h);
            }
        }

        return h;
    }    
}

library SafeMath{
    
    function add256(uint256 addend, uint256 augend) internal pure returns(uint256 result){
        uint256 sum = addend + augend;
        assert(sum >= addend);
        return sum;
    }

    function sub256(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }
}

contract TrinityContract is Owner, VerifySignature, TrinityEvent{
    /*
     *  Define public data interface
     *  Mytoken: ERC20 standard token contract address
     *  trinityData: story channel status and balance, support multiple channel;
    */
    using SafeMath for uint256;
    
    enum status {None, Opening, Closing, Locking}

    struct ChannelData{
        //data storage for RSMC transaction
        address channelCloser;    /* closer address that closed channel first */
        address channelSettler;
        address partner1;
        address partner2;
        uint256 channelTotalBalance; /*total balance that both participators deposit together*/
        uint256 closingNonce;             /* transaction nonce that channel closer */
        uint256 expectedSettleBlock;      /* the closing time for final settlement for RSMC */
        uint256 closerSettleBalance;      /* the balance that closer want to withdraw */
        uint256 partnerSettleBalance;     /* the balance that closer provided for partner can withdraw */
        status channelStatus;             /* channel current status  */
        bool channelExist;
        
        // data storage for HTLC transaction
        uint256 withdrawNonce;
        mapping(bytes32 => address) timeLockVerifier;
        mapping(bytes32 => address) timeLockWithdrawer;
        mapping(bytes32 => uint256) lockAmount;
        mapping(bytes32 => uint256) lockTime;
        mapping(bytes32 => bool) withdrawn_locks;
    }

    struct Data {
        mapping(bytes32 => ChannelData)channelInfo;
        uint8 channelNumber;
        uint256 settleTimeout;
    }

    token public Mytoken;
    Data public trinityData;
    
    // constructor function
    function TrinityContract(address token_address, uint256 Timeout) payable public {
        Mytoken=token(token_address);
        trinityData.settleTimeout = Timeout;
        trinityData.channelNumber = 0;
    }

    function getChannelCount() external view returns (uint256){
        return trinityData.channelNumber;
    }
    
    function getChannelBalance(bytes32 channelId) external view returns (uint256){
        ChannelData memory channelInfo = trinityData.channelInfo[channelId];
        return channelInfo.channelTotalBalance;
    }    

    function getChannelById(bytes32 channelId)
             external
             view
             returns(address channelCloser,
                     address channelSettler,
                     address partner1,
                     address partner2,
                     uint256 channelTotalBalance,
                     uint256 closingNonce,
                     uint256 expectedSettleBlock,
                     uint256 closerSettleBalance,
                     uint256 partnerSettleBalance,
                     status channelStatus){

        ChannelData memory channelInfo = trinityData.channelInfo[channelId];

        channelCloser = channelInfo.channelCloser;
        channelSettler =  channelInfo.channelSettler;
        partner1 = channelInfo.partner1;
        partner2 = channelInfo.partner2;
        channelTotalBalance = channelInfo.channelTotalBalance;
        closingNonce = channelInfo.closingNonce;
        expectedSettleBlock = channelInfo.expectedSettleBlock;
        closerSettleBalance = channelInfo.closerSettleBalance;
        partnerSettleBalance  = channelInfo.partnerSettleBalance;
        channelStatus = channelInfo.channelStatus;
    }

    /*
     * Function: Set settle timeout value by contract owner only
    */
    function setSettleTimeout(uint256 blockNumber) public onlyOwner{
        trinityData.settleTimeout = blockNumber;
        
        emit SetSettleTimeout(blockNumber);
    }
    
    /*
     * Function: Set asset token address by contract owner only
    */
    function setToken(address tokenAddress) external onlyOwner{
        Mytoken=token(tokenAddress);
        
        emit SetToken(tokenAddress);
    }

    function createChannel(bytes32 channelId) internal {
        
        trinityData.channelInfo[channelId] = ChannelData(address(0),
                                                         address(0),
                                                         address(0),
                                                         address(0),
                                                         0,
                                                         0,
                                                         0,
                                                         0,
                                                         0,
                                                         status.Opening,
                                                         true,
                                                         0);
	    trinityData.channelNumber += 1;        
    }

    /*
      * Function: 1. Lock both participants assets to the contract
      *           2. setup channel.
      *           Before lock assets,both participants must approve contract can spend special amout assets.
      * Parameters:
      *    partnerA: partner that deployed on same channel;
      *    partnerB: partner that deployed on same channel;
      *    amountA : partnerA will lock assets amount;
      *    amountB : partnerB will lock assets amount;
      *    signedStringA: partnerA signature for this transaction;
      *    signedStringB: partnerB signature for this transaction;
      * Return:
      *    Null;
    */
    function deposit(bytes32 channelId,
                     uint256 nonce,
                     address funderAddress,
                     uint256 funderAmount,
                     address partnerAddress,
                     uint256 partnerAmount,
                     bytes funderSignature,
                     bytes partnerSignature) payable external whenNotPaused{

        //verify both signature to check the behavious is valid.
        require(verifyTransaction(channelId, nonce, funderAddress, funderAmount, partnerAddress, partnerAmount, funderSignature, partnerSignature) == true, "verify signature");
        
        //if channel have existed, can not create it again
        require(trinityData.channelInfo[channelId].channelExist == false, "check whether channel exist");

        //transfer both special assets to this contract.
        require(Mytoken.transferFrom(funderAddress,this,funderAmount) == true, "deposit from funder");
        require(Mytoken.transferFrom(partnerAddress,this,partnerAmount) == true, "deposit from partner");

        createChannel(channelId);
	    
        emit Deposit(channelId, funderAddress, funderAmount, partnerAddress, partnerAmount);
    }

    function updateDeposit(bytes32 channelId,
                           uint256 nonce,
                           address funderAddress,
                           uint256 funderAmount,
                           address partnerAddress,
                           uint256 partnerAmount,
                           bytes funderSignature,
                           bytes partnerSignature) payable external whenNotPaused{

        //verify both signature to check the behavious is valid.
        require(verifyTransaction(channelId, nonce, funderAddress, funderAmount, partnerAddress, partnerAmount, funderSignature, partnerSignature) == true, "verify signature");

        ChannelData storage channelInfo = trinityData.channelInfo[channelId];

        require(channelInfo.channelStatus == status.Opening, "check channel status");

        //transfer both special assets to this contract.
        require(Mytoken.transferFrom(funderAddress,this,funderAmount) == true, "deposit from funder");
        require(Mytoken.transferFrom(partnerAddress,this,partnerAmount) == true, "deposit from partner");
        
        uint256 detlaBalance = funderAmount.add256(partnerAmount);
        channelInfo.channelTotalBalance = channelInfo.channelTotalBalance.add256(detlaBalance);
        
        emit UpdateDeposit(channelId, funderAddress, funderAmount, partnerAddress, partnerAmount);
    }

    function quickCloseChannel(bytes32 channelId,
                               uint256 nonce,
                               address closer,
                               uint256 closerBalance,
                               address partner,
                               uint256 partnerBalance,
                               bytes closerSignature,
                               bytes partnerSignature) payable external whenNotPaused{

        uint256 closeTotalBalance = 0;

        //verify both signatures to check the behavious is valid
        require(verifyTransaction(channelId, nonce, closer, closerBalance, partner, partnerBalance, closerSignature, partnerSignature) == true, "verify signature");

        require(nonce == 0, "check nonce");

        require((msg.sender == closer || msg.sender == partner), "verify caller");
        
        ChannelData storage channelInfo = trinityData.channelInfo[channelId];

        //channel should be opening
        require(channelInfo.channelStatus == status.Opening, "check channel status");
        
        //sum of both balance should not larger than total deposited assets
        closeTotalBalance = closerBalance.add256(partnerBalance);
        require(closeTotalBalance == channelInfo.channelTotalBalance);
        
        Mytoken.transfer(closer, closerBalance);
        Mytoken.transfer(partner, partnerBalance);

	    trinityData.channelNumber -= 1;
        delete trinityData.channelInfo[channelId];
        
        emit QuickCloseChannel(channelId, closer, closerBalance, partner, partnerBalance);
    }

    /*
     * Funcion:   1. set channel status as closing
                  2. withdraw assets for partner against closer
                  3. freeze closer settle assets untill setelement timeout or partner confirmed the transaction;
     * Parameters:
     *    partnerA: partner that deployed on same channel;
     *    partnerB: partner that deployed on same channel;
     *    settleBalanceA : partnerA will withdraw assets amount;
     *    settleBalanceB : partnerB will withdraw assets amount;
     *    signedStringA: partnerA signature for this transaction;
     *    signedStringB: partnerB signature for this transaction;
     *    settleNonce: closer provided nonce for settlement;
     * Return:
     *    Null;
     */

    function closeChannel(bytes32 channelId,
                          uint256 nonce,
                          address closer,
                          uint256 closeBalance,      
                          address partner,
                          uint256 partnerBalance,
                          bytes closerSignature,
                          bytes partnerSignature) external whenNotPaused{

        uint256 closeTotalBalance = 0;

        //verify both signatures to check the behavious is valid
        require(verifyTransaction(channelId, nonce, closer, closeBalance, partner, partnerBalance, closerSignature, partnerSignature) == true, "verify signature");

        require(nonce != 0, "check nonce");

        ChannelData storage channelInfo = trinityData.channelInfo[channelId];

        //channel should be opening
        require(channelInfo.channelStatus == status.Opening, "check channel status");

        //sum of both balance should not larger than total deposited assets
        closeTotalBalance = closeBalance.add256(partnerBalance);
        require(closeTotalBalance == channelInfo.channelTotalBalance, "check total balance");
        
        require((msg.sender == closer || msg.sender == partner), "check caller");

        channelInfo.channelStatus = status.Closing;
        channelInfo.channelCloser = msg.sender;
        channelInfo.closingNonce = nonce;
        if (msg.sender == closer){
            //sender want close channel actively, withdraw partner balance firstly
            channelInfo.closerSettleBalance = closeBalance;
            channelInfo.partnerSettleBalance = partnerBalance;
            channelInfo.channelSettler = partner;
        }
        else if(msg.sender == partner)
        {
            channelInfo.closerSettleBalance = partnerBalance;
            channelInfo.partnerSettleBalance = closeBalance;
            channelInfo.channelSettler = closer;
        }
        channelInfo.expectedSettleBlock = block.number + trinityData.settleTimeout;
        
        emit CloseChannel(channelId, closer, partner);
    }


    /*
     * Funcion: After closer apply closed channle, partner update owner final transaction to check whether closer submitted invalid information
     *      1. if bothe nonce is same, the submitted settlement is valid, withdraw closer assets
            2. if partner nonce is larger than closer, then jugement closer have submitted invalid data, withdraw closer assets to partner;
            3. if partner nonce is less than closer, then jugement closer submitted data is valid, withdraw close assets.
     * Parameters:
     *    partnerA: partner that deployed on same channel;
     *    partnerB: partner that deployed on same channel;
     *    updateBalanceA : partnerA will withdraw assets amount;
     *    updateBalanceB : partnerB will withdraw assets amount;
     *    signedStringA: partnerA signature for this transaction;
     *    signedStringB: partnerB signature for this transaction;
     *    settleNonce: closer provided nonce for settlement;
     * Return:
     *    Null;
    */

    function updateTransaction(bytes32 channelId,
                               uint256 nonce,
                               address partnerA,
                               uint256 updateBalanceA,       
                               address partnerB,
                               uint256 updateBalanceB,
                               bytes signedStringA,
                               bytes signedStringB) payable external whenNotPaused{

        uint256 updateTotalBalance = 0;

        require(verifyTransaction(channelId, nonce, partnerA, updateBalanceA, partnerB, updateBalanceB, signedStringA, signedStringB) == true, "verify signature");

        require(nonce != 0, "check nonce");

        ChannelData storage channelInfo = trinityData.channelInfo[channelId];

        // only when channel status is closing, node can call it
        require(channelInfo.channelStatus == status.Closing, "check channel status");

        require((msg.sender == partnerA || msg.sender == partnerB), "check caller");

        // channel closer can not call it
        require(msg.sender == channelInfo.channelSettler, "check settler");

        //sum of both balance should not larger than total deposited assets
        updateTotalBalance = updateBalanceA.add256(updateBalanceB);
        require(updateTotalBalance == channelInfo.channelTotalBalance, "check total balance");

        channelInfo.channelStatus = status.None;

        // if updated nonce is less than (or equal to) closer provided nonce, folow closer provided balance allocation
        if (nonce <= channelInfo.closingNonce){
            Mytoken.transfer(channelInfo.channelCloser, channelInfo.closerSettleBalance);
            Mytoken.transfer(channelInfo.channelSettler, channelInfo.partnerSettleBalance);
            emit UpdateTransaction(channelId,
                                    channelInfo.channelCloser,
                                    channelInfo.closerSettleBalance,
                                    channelInfo.channelSettler,
                                    channelInfo.partnerSettleBalance);
        }

        // if updated nonce is equal to nonce+1 that closer provided nonce, folow partner provided balance allocation
        else if (nonce == (channelInfo.closingNonce + 1)){
            Mytoken.transfer(partnerA, updateBalanceA);
            Mytoken.transfer(partnerB, updateBalanceB);
            emit UpdateTransaction(channelId, partnerA, updateBalanceA, partnerB, updateBalanceB);
        }

        // if updated nonce is larger than nonce+1 that closer provided nonce, determine closer provided invalid transaction, partner will also get closer assets
        else if (nonce > (channelInfo.closingNonce + 1)){
            Mytoken.transfer(channelInfo.channelSettler, channelInfo.channelTotalBalance);
            emit UpdateTransaction(channelId, channelInfo.channelSettler, channelInfo.channelTotalBalance, channelInfo.channelCloser, 0);
        }
 
        delete trinityData.channelInfo[channelId];
        trinityData.channelNumber -= 1;
    }

    /*
     * Function: after apply close channnel, closer can withdraw assets until special settle window period time over
     * Parameters:
     *   partner: partner address that setup in same channel with sender;
     * Return:
         Null
    */

    function settleTransaction(bytes32 channelId) payable external whenNotPaused{
    
        ChannelData storage channelInfo = trinityData.channelInfo[channelId];
     
        // only chanel closer can call the function and channel status must be closing
        require(msg.sender == channelInfo.channelCloser, "check closer");
        
        require(channelInfo.channelStatus == status.Closing, "check channel status");
        
        uint256 currentBlockHight = block.number;
        require(channelInfo.expectedSettleBlock < currentBlockHight, "check settle time");

        channelInfo.channelStatus = status.None;

        // settle period have over and partner didn't provide final transaction information, contract will withdraw closer assets
        Mytoken.transfer(channelInfo.channelCloser, channelInfo.closerSettleBalance);
        Mytoken.transfer(channelInfo.channelSettler, channelInfo.partnerSettleBalance);

        // delete channel
	    trinityData.channelNumber -= 1;
        delete trinityData.channelInfo[channelId];
        
        emit Settle(channelId, 
                    channelInfo.channelCloser, 
                    channelInfo.closerSettleBalance, 
                    channelInfo.channelSettler,
                    channelInfo.partnerSettleBalance);
    }

    function withdraw(bytes32 channelId,
                      uint256 nonce,
                      address sender,
                      address receiver,
                      uint256 lockTime ,
                      uint256 lockAmount,
                      bytes32 lockHash,
                      bytes partnerAsignature,
                      bytes partnerBsignature,                      
                      bytes32 secret) external{

        require(verifyTimelock(channelId, nonce, sender, receiver, lockTime,lockAmount,lockHash,partnerAsignature,partnerBsignature) == true, "verify signature");
        
        require(nonce != 0, "check nonce");
        
        require(lockTime > block.number, "check lock time");        

        require(lockHash == keccak256(secret), "verify hash");
        
        require((msg.sender == receiver), "check caller");
        
        ChannelData storage channelInfo = trinityData.channelInfo[channelId];

        require(channelInfo.withdrawn_locks[lockHash] == false, "check withdraw status");
        
        require(nonce >= channelInfo.withdrawNonce);
        
        channelInfo.withdrawNonce = nonce;
        channelInfo.lockTime[lockHash] = lockTime;
        channelInfo.lockAmount[lockHash] = lockAmount;
        
        channelInfo.timeLockVerifier[lockHash] = sender;
        channelInfo.timeLockWithdrawer[lockHash] = receiver;
  
        channelInfo.withdrawn_locks[lockHash] = true;
        
        emit Withdraw(channelId, lockHash);
    }

    function withdrawUpdate(bytes32 channelId,
                      uint256 nonce,
                      address sender,
                      address receiver,
                      uint256 lockTime ,
                      uint256 lockAmount,
                      bytes32 lockHash,
                      bytes partnerAsignature,
                      bytes partnerBsignature) external payable whenNotPaused{

        require(verifyTimelock(channelId, nonce, sender, receiver, lockTime,lockAmount,lockHash,partnerAsignature,partnerBsignature) == true, "verify signature");

        require(nonce != 0, "check nonce");

        require(lockTime > block.number, "check lock time");  

        ChannelData storage channelInfo = trinityData.channelInfo[channelId];
        
        require(channelInfo.withdrawn_locks[lockHash] == true, "check withdraw status");
        
        require(msg.sender == channelInfo.timeLockVerifier[lockHash], "check verifier");
        
        if (nonce <= channelInfo.withdrawNonce){
            channelInfo.channelTotalBalance = channelInfo.channelTotalBalance.sub256(lockAmount);
            Mytoken.transfer(receiver, lockAmount);

            channelInfo.timeLockVerifier[lockHash] = address(0);
            channelInfo.timeLockWithdrawer[lockHash] = address(0);
            channelInfo.lockAmount[lockHash] = 0;
            channelInfo.lockTime[lockHash] = 0;            
            
            emit WithdrawUpdate(channelId, lockHash, channelInfo.channelTotalBalance);
        }
        else if(nonce > channelInfo.withdrawNonce){
            Mytoken.transfer(msg.sender, channelInfo.channelTotalBalance);
            // delete channel

            delete trinityData.channelInfo[channelId];   
	        trinityData.channelNumber -= 1;
	        
            emit WithdrawUpdate(channelId, lockHash, 0);
        }
    }
    
    function withdrawSettle(bytes32 channelId,
                            bytes32 lockHash,
                            bytes32 secret) external payable whenNotPaused{
        
        address withdrawer;
        uint256 lockAmount;
        
        require(lockHash == keccak256(secret), "verify hash");

        ChannelData storage channelInfo = trinityData.channelInfo[channelId];
        
        require(channelInfo.withdrawn_locks[lockHash] == true, "check withdraw status");
        
        require(channelInfo.lockTime[lockHash] < block.number, "check time lock");        
        
        withdrawer = channelInfo.timeLockWithdrawer[lockHash];
        require(withdrawer == msg.sender, "check withdrawer"); 

        lockAmount = channelInfo.lockAmount[lockHash];
        channelInfo.channelTotalBalance = channelInfo.channelTotalBalance.sub256(lockAmount);
        Mytoken.transfer(withdrawer, lockAmount);
        
        channelInfo.timeLockVerifier[lockHash] = address(0);
        channelInfo.timeLockWithdrawer[lockHash] = address(0);
        channelInfo.lockAmount[lockHash] = 0;
        channelInfo.lockTime[lockHash] = 0;
 
        emit WithdrawSettle(channelId, lockHash, channelInfo.channelTotalBalance);
    }
    
    function () public { revert(); }
}