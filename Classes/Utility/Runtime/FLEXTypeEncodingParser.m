//
//  FLEXTypeEncodingParser.m
//  FLEX
//
//  Created by Tanner Bennett on 8/22/19.
//  Copyright © 2019 Flipboard. All rights reserved.
//

#import "FLEXTypeEncodingParser.h"
#import "FLEXRuntimeUtility.h"

#define S(ch) [NSString stringWithFormat:@"%c" , ch]

@interface FLEXTypeEncodingParser ()
@property (nonatomic, readonly) NSScanner *scan;
@end

@implementation FLEXTypeEncodingParser

#pragma mark Initialization

- (id)initWithObjCTypes:(NSString *)typeEncoding {
    self = [super init];
    if (self) {
        _scan = [NSScanner scannerWithString:typeEncoding];
    }

    return self;
}

#pragma mark Public

+ (NSString *)type:(NSString *)typeEncoding forMethodArgumentAtIndex:(NSUInteger)idx {
    FLEXTypeEncodingParser *parser = [[self alloc] initWithObjCTypes:typeEncoding];

    // Scan up to the argument we want
    for (NSUInteger i = 0; i < idx; i++) {
        if (![parser scanPastArg]) {
            [NSException raise:NSRangeException
                        format:@"Index %lu out of bounds for type encoding '%@'", idx, typeEncoding];
        }
    }

    return [parser scanArg];
}

+ (ssize_t)size:(NSString *)typeEncoding forMethodArgumentAtIndex:(NSUInteger)idx {
    return [self sizeForTypeEncoding:[self type:typeEncoding forMethodArgumentAtIndex:idx]];
}

//+ (ssize_t)sizeForTypeEncoding:(NSString *)typeEncoding {
//    // TODO
//    return 0;
//}

#pragma mark Private

- (BOOL)scanString:(NSString *)str {
    return [self.scan scanString:str intoString:nil];
}

- (BOOL)canScanString:(NSString *)str {
    if ([self.scan scanString:str intoString:nil]) {
        self.scan.scanLocation -= str.length;
        return YES;
    }

    return NO;
}

- (BOOL)canScanChar:(char)c {
    return [self canScanString:S(c)];
}

- (BOOL)scanChar:(char)c {
    return [self canScanString:S(c)];
}

- (BOOL)scanNumber {
    return [self.scan scanInt:nil];
}

- (NSString *)scanPair:(char)c1 close:(char)c2 {
    if (![self canScanChar:c1]) {
        return nil;
    }

    // Starting position and string variables
    NSUInteger start = self.scan.scanLocation;
    NSString *s1 = S(c1);

    // Character set for scanning up to either symbol
    NSCharacterSet *bothChars = ({
        NSString *bothCharsStr = [NSString stringWithFormat:@"%c%c" , c1, c2];
        [NSCharacterSet characterSetWithCharactersInString:bothCharsStr];
    });

    // Stack for finding pairs, starting with the opening symbol
    NSMutableArray *stack = [NSMutableArray arrayWithObject:s1];

    // Algorithm for scanning to the closing end of a pair of opening/closing symbols
    while ([self.scan scanUpToCharactersFromSet:bothChars intoString:nil]) {
        // Opening symbol found
        if ([self canScanChar:c1]) {
            // Begin pair
            [stack addObject:s1];
        }
        // Closing symbol found
        if ([self canScanChar:c2]) {
            if (!stack.count) {
                // Abort, no matching opening symbol
                self.scan.scanLocation = start;
                return nil;
            }

            // Pair found, pop opening symbol
            [stack removeLastObject];
        }
    }

    if (stack.count) {
        // Abort, no matching closing symbol
        self.scan.scanLocation = start;
        return nil;
    }

    // Slice out the string we just scanned
    return [self.scan.string
        substringWithRange:NSMakeRange(start, self.scan.scanLocation - start)
    ];
}

- (BOOL)scanPastArg {
    NSUInteger start = self.scan.scanLocation;

    // Check for void first
    if ([self scanChar:FLEXTypeEncodingVoid]) {
        return YES;
    }

    // Scan optional const
    [self scanChar:FLEXTypeEncodingConst];

    // Check for pointer, then scan next
    if ([self scanChar:FLEXTypeEncodingPointer]) {
        // Recurse to scan something else
        if (![self scanPastArg]) {
            self.scan.scanLocation = start;
            return NO;
        }
    }

    // Check for struct/union/array, scan past it
    if ([self scanPair:FLEXTypeEncodingStructBegin close:FLEXTypeEncodingStructEnd] ||
      [self scanPair:FLEXTypeEncodingUnionBegin close:FLEXTypeEncodingUnionEnd] ||
      [self scanPair:FLEXTypeEncodingArrayBegin close:FLEXTypeEncodingArrayEnd]) {
        return YES;
    }

    // Scan single thing and possible size and return
    if ([self scanChar:FLEXTypeEncodingUnknown] ||
      [self scanChar:FLEXTypeEncodingChar] ||
      [self scanChar:FLEXTypeEncodingInt] ||
      [self scanChar:FLEXTypeEncodingShort] ||
      [self scanChar:FLEXTypeEncodingLong] ||
      [self scanChar:FLEXTypeEncodingLongLong] ||
      [self scanChar:FLEXTypeEncodingUnsignedChar] ||
      [self scanChar:FLEXTypeEncodingUnsignedInt] ||
      [self scanChar:FLEXTypeEncodingUnsignedShort] ||
      [self scanChar:FLEXTypeEncodingUnsignedLong] ||
      [self scanChar:FLEXTypeEncodingUnsignedLongLong] ||
      [self scanChar:FLEXTypeEncodingFloat] ||
      [self scanChar:FLEXTypeEncodingDouble] ||
      [self scanChar:FLEXTypeEncodingLongDouble] ||
      [self scanChar:FLEXTypeEncodingCBool] ||
      [self scanChar:FLEXTypeEncodingCString] ||
      [self scanChar:FLEXTypeEncodingSelector] ||
      [self scanChar:FLEXTypeEncodingBitField]) {
        // Size is optional
        [self scanNumber];
        return YES;
    }

    // These might have numbers OR quotes after them
    if ([self scanChar:FLEXTypeEncodingObjcObject] || [self scanChar:FLEXTypeEncodingObjcClass]) {
        [self scanNumber] || [self scanPair:FLEXTypeEncodingQuote close:FLEXTypeEncodingQuote];
        return YES;
    }

    self.scan.scanLocation = start;
    return NO;
}

- (NSString *)scanArg {
    NSUInteger start = self.scan.scanLocation;
    if (![self scanPastArg]) {
        return nil;
    }

    return [self.scan.string
        substringWithRange:NSMakeRange(start, self.scan.scanLocation - start)
    ];
}

@end
