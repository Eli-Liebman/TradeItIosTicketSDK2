//
//  TradeItGetPositionsRequest.h
//  TradeItIosEmsApi
//
//  Created by Antonio Reyes on 2/3/16.
//  Copyright © 2016 TradeIt. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TradeItRequest.h"

@interface TradeItGetPositionsRequest : TradeItRequest

// Init with account number, preferred as accountNumber is required
-(id _Nonnull) initWithAccountNumber:(NSString * _Nonnull) accountNumber;


// Set the account number, required
@property (copy) NSString * _Nullable accountNumber;

// Set the page, if there are multiple pages
@property (copy) NSNumber<Optional> * _Nullable page;



// Session Token - Will be set by the session associated with the request
// Setting this here will be overriden
@property (copy) NSString * _Nullable token;

@end
