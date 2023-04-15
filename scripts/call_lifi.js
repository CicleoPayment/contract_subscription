const axios = require("axios");
const ethers = require("ethers");

const endpoint = 'https://li.quest/v1/quote/contractCall';

const KLIMA_STAKING_CONTRACT = '0x5AE476d984eA2F1Afd844234d2eEa6f358300fF3';

// Full ABI on 
// https://polygonscan.com/address/0x4D70a031Fc76DA6a9bC0C922101A05FA95c3A227#code
const KLIMA_STAKING_ABI = ['function subscribeWithBridge(address user, uint256 subscriptionManagerId, uint8 subscriptionId) external'];
  
const generateKLIMATransaction = async () => {
    const stakeKlimaTx = await new ethers.Contract(
        KLIMA_STAKING_CONTRACT,
        KLIMA_STAKING_ABI
      ).populateTransaction.subscribeWithBridge("0xfa5FF1747Df46e146A8cD85D6Bd9c115abF819Cd", 6, 1);
    return stakeKlimaTx;
};

const getQuote = async () => {
    // We would like to stake this amount of KLIMA to get sKLIMA
    const stakeAmount = '1000000';

    const stakeKlimaTx = await generateKLIMATransaction(stakeAmount);

    const quoteRequest = {
        fromChain: 'POL',
        fromToken: "0xB7b31a6BC18e48888545CE79e83E06003bE70930",
        fromAddress: '0xe122593c21185B17111496e27744F4130b231a75',
        toChain: 'FTM',
        toToken: "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75",
        toAmount: stakeAmount,
        toContractAddress: stakeKlimaTx.to,
        toContractCallData: stakeKlimaTx.data,
        toContractGasLimit: '900000',
    };
    
    const response = await axios.post(endpoint, quoteRequest);
    return response.data;
};

getQuote().then(console.log);