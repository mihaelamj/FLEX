//
//  FLEXTypeEncodingParser.h
//  FLEX
//
//  Created by Tanner Bennett on 8/22/19.
//  Copyright © 2019 Flipboard. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FLEXTypeEncodingParser : NSObject

/// @return The type encoding of an individual argument in a method's type encoding string.
/// Pass 0 to get the type of the return value. 1 and 2 are `self` and `_cmd` respectively.
+ (NSString *)type:(NSString *)typeEncoding forMethodArgumentAtIndex:(NSUInteger)idx;

/// @return The size of the typeof an individual argument in a method's type encoding string.
/// Pass 0 to get the size of the return value. 1 and 2 are `self` and `_cmd` respectively.
+ (ssize_t)size:(NSString *)typeEncoding forMethodArgumentAtIndex:(NSUInteger)idx;

/// Do not pass the result of method_getTypeEncoding
//+ (ssize_t)sizeForTypeEncoding:(NSString *)typeEncoding;

@end
