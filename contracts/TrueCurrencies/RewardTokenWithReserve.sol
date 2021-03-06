pragma solidity 0.5.13;

import { RewardToken } from "./RewardToken.sol";

/**
 * @title RewardTokenWithReserve
 * @dev Provides a reserve to swap rewardTokens for gas savings
 *
 * -- Overview --
 * The Reserve holds Tokens and RewardTokens
 * Because gas costs can be high for depositing/redeeming in financial
 * opportunities, we use this contract to keep a reserve of tokens
 * to provide swap opportunities
 *
 */
contract RewardTokenWithReserve is RewardToken {

    // Reserve is an address which nobody has the private key to
    // Reserves of TUSD and TrueRewardBackedToken are held at this addess
    address public constant RESERVE = 0xf000000000000000000000000000000000000000;

    event ReserveDeposit(address indexed account, uint256 depositAmount, uint256 rewardTokenReturned, address indexed finOp);
    event ReserveRedeem(address indexed account, uint256 rewardTokenRedeemed, uint256 tokenAmountReturned, address indexed finOp);

    /**
     * @dev get reserve token balance
     *
     * @return token balance of reserve
     */
    function reserveBalance() public view returns (uint256) {
        return super.balanceOf(RESERVE);
    }

    /**
     * @dev Get rewardToken reserve balance
     *
     * @param finOp address of financial opportunity
     * @return rewardToken balance of reserve for finOp
     */
    function reserveRewardBalance(address finOp) public view returns (uint) {
        return rewardTokenBalance(RESERVE, finOp);
    }

    /**
     * @dev Withdraw Token from reserve through transferAll
     *
     * @param to address to withdraw to
     * @param value amount to withdraw
     */
    function reserveWithdraw(address to, uint256 value) external onlyOwner {
        _transferAllArgs(RESERVE, to, value);
    }

    /**
     * @dev Allow this contract to rebalance currency reserves
     * This is called when there is too much money in an opportunity and we want
     * to get more TrueCurrency.
     * This allows us to reduct the cost of transfers 5-10x in/out of opportunities
     *
     * @param tokenAmount amount of rewardTokens to redeem
     * @param finOp financial opportunity to redeem from
     */
    function reserveRedeem(uint256 tokenAmount, address finOp) internal {
        redeemRewardToken(RESERVE, tokenAmount, finOp);
    }

    /**
     * @dev Allow this contract to rebalance currency reserves
     * This is called when there is not enough rewardToken for an
     * opportunity and we want to add rewardTokens to the reserve
     *
     * @param rewardAmount amount of Token to redeem for rewardToken
     * @param finOp financial opportunity to redeem for
     */
    function reserveMint(uint256 rewardAmount, address finOp) internal {
        mintRewardToken(RESERVE, rewardAmount, finOp);
    }

    /**
     * @dev Use reserve to swap Token for rewardToken between accounts
     *
     * @param account account to swap token for
     * @param tokenAmount deposit token amount to withdraw from reserve
     * @param rewardAmount reward token amount to deposit into reserve
     * @param finOp financial opportunity to swap tokens for
     */
    function swapRewardForToken(
        address account,
        uint256 tokenAmount,
        uint256 rewardAmount,
        address finOp
    ) internal validFinOp(finOp) {
        // put reward tokens into reserve
        _subRewardBalance(account, rewardAmount, finOp);
        _addRewardBalance(RESERVE, rewardAmount, finOp);

        // take deposit tokens from reserve
        _subBalance(RESERVE, tokenAmount);
        _addBalance(account, tokenAmount);

        emit Transfer(account, RESERVE, tokenAmount);
        emit Transfer(RESERVE, account, tokenAmount);
    }

    /**
     * @dev Use reserve to swap Token for rewardToken between accounts
     *
     * @param account account to swap token for
     * @param tokenAmount deposit token amount to deposit into reserve
     * @param rewardAmount reward token amount to withdraw from reserve
     * @param finOp financial opportunity to swap tokens for
     */
    function swapTokenForReward(
        address account,
        uint256 tokenAmount,
        uint256 rewardAmount,
        address finOp
    ) internal validFinOp(finOp) {
        // deposit tokens into reserve
        _subBalance(account, tokenAmount);
        _addBalance(RESERVE, tokenAmount);

        // withdraw reward tokens from reserve
        _subRewardBalance(RESERVE, rewardAmount, finOp);
        _addRewardBalance(account, rewardAmount, finOp);

        // emit transfer events
        emit Transfer(account, RESERVE, tokenAmount);
        emit Transfer(RESERVE, account, tokenAmount);
    }

    /**
     * @dev Redeem tokens from financial opportunity if reserve balance cannot cover it
     * swap with reserve otherwise
     *
     * @param account account which wants to redeem
     * @param rewardAmount reward token amount to redeem
     * @param finOp financial opportunity we interact with
     * @return amount of depositTokens returned to account
     */
    function redeemWithReserve(address account, uint256 rewardAmount, address finOp) internal returns (uint256) {
        // calculate deposit amount
        uint256 tokenAmount = _toToken(rewardAmount, finOp);

        return redeemWithReserve(account, tokenAmount, rewardAmount, finOp);
    }

    function redeemWithReserve(address account, uint256 tokenAmount, uint256 rewardAmount, address finOp) internal returns (uint256) {
        // if sufficient reserve balance, make swap and emit event
        if (reserveBalance() >= tokenAmount) {
            swapRewardForToken(account, tokenAmount, rewardAmount, finOp);
            emit ReserveRedeem(account, rewardAmount, tokenAmount, finOp);
            return tokenAmount;
        }
        // otherwise redeem through opportunity
        else {
            return redeemRewardToken(account, rewardAmount, finOp);
        }
    }

    /**
     * @dev Deposit tokens into financial opportunity and mint new debt backed tokens
     * if reserve reward token balance is lower than deposited amount
     * swap with reserve otherwise
     *
     * @param account account which wants to redeem
     * @param depositAmount token amount to exchange for reward tokens
     * @param finOp financial opportunity we interact with
     * @return amount of rewardTokens exchanged to account
     */
    function depositWithReserve(address account, uint256 depositAmount, address finOp) internal returns (uint256) {
        // calculate reward token amount for deposit
        uint256 rewardAmount = _toRewardToken(depositAmount, finOp);

        // if sufficient reserve reward token balance, make swap and emit event
        if (rewardTokenBalance(RESERVE, finOp) >= rewardAmount) {
            swapTokenForReward(account, depositAmount, rewardAmount, finOp);
            emit ReserveDeposit(account, depositAmount, rewardAmount, finOp);
            return rewardAmount;
        }
        // otherwise mint new rewardTokens by depositing into opportunity
        else {
            return mintRewardToken(account, depositAmount, finOp);
        }
    }
}
