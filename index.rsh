'reach 0.1';

/* eslint-disable */
const myFromMaybe = (m) => fromMaybe(m, (() => false), ((x) => x));

export const main = Reach.App(() => {

  setOptions({ connectors: [ ALGO ], untrustworthyMaps: true });

  const A = Participant('A', {
    // Token, Max Addresses, Number of tokens to distribute per address
    setParams: Fun([], Tuple(Token, UInt, UInt)),
    fundContract: Fun([], Null),
    seeAddToWhitelist: Fun([Address], Null),
    seeClaim: Fun([Address], Null),
  });
    
    
  const B = API('B', {
    // add address to whitelist, return true if successful
    addToWhitelist: Fun([], Bool), 
    claimTokens: Fun([], Bool),
  });

  const C = API('C', {
    endContract: Fun([], Bool),
  });

  const V = View({
    canClaimTokens: Fun([Address], Bool),
    getTokenInfo: Token,
  });
  
  init();
  A.only(() => {
    const [ ClaimToken, MaxAddresses, TokensPerAddress ] = declassify(interact.setParams());
    const TotalTokens = (MaxAddresses * TokensPerAddress);
  })
  A.publish(ClaimToken, MaxAddresses, TokensPerAddress, TotalTokens);
  commit();

  // const M1 = new Map(Bytes(128));
  // const M2 = new Map(Null);

  A.publish().pay([0, [TotalTokens, ClaimToken]]);
  commit;

  A.interact.fundContract();
  A.publish();

  // Map to track whitelisted addresses
  const whitelist = new Map(Bool);

  V.canClaimTokens.set((m) => myFromMaybe(whitelist[m]));
  V.getTokenInfo.set(ClaimToken);

  const [ done, distrubtedTokens, whitelistSize ] = parallelReduce([ false, 0, 0 ])
      .invariant(whitelistSize <= MaxAddresses)
      .while(!done)
      .api(
        B.addToWhitelist,
        () => {},
        () => 0,
        (returnFunc) => {
          const canAdd = (whitelistSize < MaxAddresses) ? true : false;
          returnFunc(canAdd);
          if (canAdd) {
            whitelist[this] = true;
            A.interact.seeAddToWhitelist(this);
          }
          const whitelistIncrement = (canAdd) ? 1 : 0;

          return [ done, distrubtedTokens, whitelistSize + whitelistIncrement ];
        }
      )
      .api(
        B.claimTokens,
        () => {
            assume(balance(ClaimToken) >= TokensPerAddress);
        },
        () => 0,
        (returnFunc) => {
          const canWithdraw = (myFromMaybe(whitelist[this]) == true && balance(ClaimToken) >= TokensPerAddress) ? true : false;
          returnFunc(canWithdraw);

          if (canWithdraw) {
              transfer([0, [TokensPerAddress, ClaimToken]]).to(this);
              whitelist[this] = false;
              A.interact.seeClaim(this);
          }
          const claimedTokens = (canWithdraw) ? TokensPerAddress : 0;

          return [ done, distrubtedTokens + claimedTokens, whitelistSize ];
        }
      )
      .api(
        C.endContract,
        () => {
          assume(this == A);
        },
        () => 0,
        (returnFunc) => {
          require(this == A);
          returnFunc(true);

          return [ true, distrubtedTokens, whitelistSize ];
        }
      );

      transfer(balance()).to(A);
      transfer([ 0, [ balance(ClaimToken), ClaimToken ] ]).to(A);
      commit();

  exit();
  
});
