// SPDX-License-Identifier: AGPL-3.0
// Feel free to change the license, but this is what we use

// Feel free to change this version of Solidity. We support >=0.6.0 <0.7.0;
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// These are the core Yearn libraries
import {
    BaseStrategy,
    StrategyParams
} from "@yearnvaults/contracts/BaseStrategy.sol";
import {
    SafeERC20,
    SafeMath,
    IERC20,
    Address
} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

// Import interfaces for many popular DeFi projects, or add your own!
//import "../interfaces/<protocol>/<Interface>.sol";
import "../interfaces/Compound/CErc20I.sol";
import "../interfaces/Compound/ComptrollerI.sol";

contract Strategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    event CurrentState(uint256 _amount);

    // Comptroller address for compound.finance
    ComptrollerI public constant compound = ComptrollerI(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    CErc20I public constant cDai = CErc20I(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);

    constructor(address _vault) public BaseStrategy(_vault) {
        // You can set these parameters on deployment to whatever you want
        // maxReportDelay = 6300;
        // profitFactor = 100;
        // debtThreshold = 0;
        want.approve(address(cDai), uint256(-1));
        

    }

    // ******** OVERRIDE THESE METHODS FROM BASE CONTRACT ************

    function name() external view override returns (string memory) {
        // Add your own name here, suggestion e.g. "StrategyCreamYFI"
        return "StrategyCompoundDaiTest1";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        // TODO: Build a more accurate estimate using the value of all positions in terms of `want`
        uint256 exchangeRate = cDai.exchangeRateStored();
        uint256 amount_of_cDai = cDai.balanceOf(address(this));
        return(want.balanceOf(address(this)).add(amount_of_cDai.mul(exchangeRate).div(uint256(10**18))));
    }

    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        // TODO: Do stuff here to free up any returns back into `want`
        // NOTE: Return `_profit` which is value generated by all positions, priced in `want`
        // NOTE: Should try to free up at least `_debtOutstanding` of underlying position
        uint256 exchangeRate = cDai.exchangeRateStored();
        uint256 amount_of_cDai = cDai.balanceOf(address(this));
        uint256 amount_of_Dai = want.balanceOf(address(this));
        uint256 depositedDai_in_cDai = amount_of_cDai.mul(exchangeRate).div(uint256(10**18));

        emit CurrentState(depositedDai_in_cDai);
        if(_debtOutstanding < amount_of_Dai){
            //return debt
            _debtPayment = _debtOutstanding;
            _profit = depositedDai_in_cDai.add(amount_of_Dai).sub(_debtOutstanding);
        }
        else{
            if (_debtOutstanding.sub(amount_of_Dai) < depositedDai_in_cDai){
                //affordable
                cDai.redeem(_debtOutstanding.sub(amount_of_Dai).mul(exchangeRate).div(uint256(10**(18 + 18 - 8))));
                _debtPayment = _debtOutstanding;
                _profit = depositedDai_in_cDai.add(amount_of_Dai).sub(_debtOutstanding);
            }
            else{
                //loss
                cDai.redeem(amount_of_cDai);
                _debtPayment = amount_of_Dai.add(depositedDai_in_cDai);
                _loss = _debtOutstanding.sub(_debtPayment);
            }
            
        }
        
        
    }

    function adjustPosition(uint256 _debtOutstanding) internal override {
        // TODO: Do something to invest excess `want` tokens (from the Vault) into your positions
        // NOTE: Try to adjust positions so that `_debtOutstanding` can be freed up on *next* harvest (not immediately)
        uint256 exchangeRate = cDai.exchangeRateStored();
        uint256 amount_of_cDai = cDai.balanceOf(address(this));
        uint256 amount_of_Dai = want.balanceOf(address(this));
        uint256 depositedDai_in_cDai = amount_of_cDai.mul(exchangeRate).div(uint256(10**18));
        //if over collateral mint;    
        cDai.mint(amount_of_Dai);
        //else redeem some;
        
        
        
    }

    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        // TODO: Do stuff here to free up to `_amountNeeded` from all positions back into `want`
        // NOTE: Maintain invariant `want.balanceOf(this) >= _liquidatedAmount`
        // NOTE: Maintain invariant `_liquidatedAmount + _loss <= _amountNeeded`

        
        uint256 exchangeRate = cDai.exchangeRateStored();
        uint256 amount_of_cDai = cDai.balanceOf(address(this));
        uint256 amount_of_Dai = want.balanceOf(address(this));
        uint256 depositedDai_in_cDai = amount_of_cDai.mul(exchangeRate).div(uint256(10**18));
        
        uint256 totalAssets = amount_of_Dai.add(depositedDai_in_cDai);
        if (_amountNeeded > totalAssets) {
            cDai.redeem(amount_of_cDai);
            _liquidatedAmount = totalAssets;
            _loss = _amountNeeded.sub(totalAssets);
        } else {
            cDai.redeem(_amountNeeded.div(exchangeRate.div(uint256(10**(18+18-8)))));
            _liquidatedAmount = _amountNeeded;
        }
    }

    function liquidateAllPositions() internal override returns (uint256) {
        // TODO: Liquidate all positions and return the amount freed.
        cDai.redeem(cDai.balanceOf(address(this)));
        uint256 exchangeRate = cDai.exchangeRateStored();
        uint256 amount_of_cDai = cDai.balanceOf(address(this));
        return(want.balanceOf(address(this)).add(amount_of_cDai.mul(exchangeRate).div(uint256(10**18))));
    }

    // NOTE: Can override `tendTrigger` and `harvestTrigger` if necessary

    function prepareMigration(address _newStrategy) internal override {
        // TODO: Transfer any non-`want` tokens to the new strategy
        // NOTE: `migrate` will automatically forward all `want` in this strategy to the new one
    }

    // Override this to add all tokens/tokenized positions this contract manages
    // on a *persistent* basis (e.g. not just for swapping back to want ephemerally)
    // NOTE: Do *not* include `want`, already included in `sweep` below
    //
    // Example:
    //
    //    function protectedTokens() internal override view returns (address[] memory) {
    //      address[] memory protected = new address[](3);
    //      protected[0] = tokenA;
    //      protected[1] = tokenB;
    //      protected[2] = tokenC;
    //      return protected;
    //    }
    function protectedTokens()
        internal
        view
        override
        returns (address[] memory)
    {}

    /**
     * @notice
     *  Provide an accurate conversion from `_amtInWei` (denominated in wei)
     *  to `want` (using the native decimal characteristics of `want`).
     * @dev
     *  Care must be taken when working with decimals to assure that the conversion
     *  is compatible. As an example:
     *
     *      given 1e17 wei (0.1 ETH) as input, and want is USDC (6 decimals),
     *      with USDC/ETH = 1800, this should give back 1800000000 (180 USDC)
     *
     * @param _amtInWei The amount (in wei/1e-18 ETH) to convert to `want`
     * @return The amount in `want` of `_amtInEth` converted to `want`
     **/
    function ethToWant(uint256 _amtInWei)
        public
        view
        virtual
        override
        returns (uint256)
    {
        // TODO create an accurate price oracle
        return _amtInWei;
    }
}
