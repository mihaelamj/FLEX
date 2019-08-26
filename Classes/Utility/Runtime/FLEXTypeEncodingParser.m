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

+ (ssize_t)sizeForTypeEncoding:(NSString *)typeEncoding {
    return [[[self alloc] initWithObjCTypes:typeEncoding] scanAndGetSizeAndAlignForNextType:nil] / 8;
}

#pragma mark Private

/// Size in BYTES
- (ssize_t)sizeForType:(FLEXTypeEncoding)type {
    switch (type) {
        case FLEXTypeEncodingChar: return sizeof(char);
        case FLEXTypeEncodingInt: return sizeof(int);
        case FLEXTypeEncodingShort: return sizeof(short);
        case FLEXTypeEncodingLong: return sizeof(long);
        case FLEXTypeEncodingLongLong: return sizeof(long long);
        case FLEXTypeEncodingUnsignedChar: return sizeof(unsigned char);
        case FLEXTypeEncodingUnsignedInt: return sizeof(unsigned int);
        case FLEXTypeEncodingUnsignedShort: return sizeof(unsigned short);
        case FLEXTypeEncodingUnsignedLong: return sizeof(unsigned long);
        case FLEXTypeEncodingUnsignedLongLong: return sizeof(unsigned long long);
        case FLEXTypeEncodingFloat: return sizeof(float);
        case FLEXTypeEncodingDouble: return sizeof(double);
        case FLEXTypeEncodingLongDouble: return sizeof(long double);
        case FLEXTypeEncodingCBool: return sizeof(_Bool);
        case FLEXTypeEncodingVoid: return 0;
        case FLEXTypeEncodingCString: return sizeof(char *);
        case FLEXTypeEncodingObjcObject:  return sizeof(id);
        case FLEXTypeEncodingObjcClass:  return sizeof(Class);
        case FLEXTypeEncodingSelector: return sizeof(SEL);
        case FLEXTypeEncodingPointer: return sizeof(uintptr_t);

        default: return -1;
    }
}

/// Size in BITS
- (ssize_t)scanAndGetSizeAndAlignForNextType:(ssize_t *)alignment {
    NSUInteger start = self.scan.scanLocation;

    // Check for void first
    if ([self scanChar:FLEXTypeEncodingVoid]) {
        return 0;
    }

    // Scan optional const
    [self scanChar:FLEXTypeEncodingConst];

    // Check for pointer, then scan next
    if ([self scanChar:FLEXTypeEncodingPointer]) {
        // Recurse to scan something else
        if ([self scanPastArg]) {
            return sizeof(uintptr_t) * 8;
        } else {
            // Scan failed, abort
            self.scan.scanLocation = start;
            return -1;
        }
    }

    // Check for struct/union/array
    if ([self canScanChar:FLEXTypeEncodingStructBegin] ||
      [self canScanChar:FLEXTypeEncodingUnionBegin] ||
      [self canScanChar:FLEXTypeEncodingArrayBegin]) {
        NSUInteger backup = self.scan.scanLocation;

        // Ensure we have a closing tag
        if (![self scanPair:FLEXTypeEncodingStructBegin close:FLEXTypeEncodingStructEnd] &&
          ![self scanPair:FLEXTypeEncodingUnionBegin close:FLEXTypeEncodingUnionEnd] &&
          ![self scanPair:FLEXTypeEncodingArrayBegin close:FLEXTypeEncodingArrayEnd]) {
            // Scan failed, abort
            self.scan.scanLocation = start;
            return -1;
        }

        // Scan the next thing until we scan the closing tag
        self.scan.scanLocation = backup;
        FLEXTypeEncoding closing;
        if ([self scanChar:FLEXTypeEncodingStructBegin]) {
            closing = FLEXTypeEncodingStructEnd;
        } else if ([self scanChar:FLEXTypeEncodingUnionBegin]) {
            closing = FLEXTypeEncodingUnionEnd;
        } else {
            closing = FLEXTypeEncodingArrayEnd;
        }

        // Sum sizes of members together:
        // Scan for bitfields before checking for other members
        //
        // Arrays will only have one "member," but
        // this logic still works for them
        ssize_t sizeSoFar = 0;
        ssize_t maxAlign = 0;

        while (![self scanChar:closing]) {
            // Check for bitfields; sum their bits together
            // as long as they are consecutive
            ssize_t bits = 0;
            while ([self scanChar:FLEXTypeEncodingBitField]) {
                ssize_t currentBits = [self scanSize];
                if (!currentBits) {
                    // Bitfield did not have size after
                    self.scan.scanLocation = start;
                    return -1;
                }
            }
            ssize_t align = 0;
            ssize_t size = [self scanAndGetSizeAndAlignForNextType:&align];
            if (size == -1) {
                self.scan.scanLocation = start;
                return -1;
            }
            sizeSoFar += size;
            maxAlign = MAX(maxAlign, align);
        }

#warning Calculate alignment to get proper size?
        return sizeSoFar; // Bits
    }

    // If we encounter the ?= portion of something like {?=b8b4b1b1b18[8S]}
    // then we skip over it, since it means nothing to us in this context
    if ([self scanChar:FLEXTypeEncodingUnknown]) {
        if (![self scanString:@"="]) {
            // No size information available for strings like {?}
            self.scan.scanLocation = start;
            return -1;
        }
    }

    // Scan single thing and possible size and return
    FLEXTypeEncoding t;
    if ([self scanChar:FLEXTypeEncodingUnknown into:&t] ||
      [self scanChar:FLEXTypeEncodingChar into:&t] ||
      [self scanChar:FLEXTypeEncodingInt into:&t] ||
      [self scanChar:FLEXTypeEncodingShort into:&t] ||
      [self scanChar:FLEXTypeEncodingLong into:&t] ||
      [self scanChar:FLEXTypeEncodingLongLong into:&t] ||
      [self scanChar:FLEXTypeEncodingUnsignedChar into:&t] ||
      [self scanChar:FLEXTypeEncodingUnsignedInt into:&t] ||
      [self scanChar:FLEXTypeEncodingUnsignedShort into:&t] ||
      [self scanChar:FLEXTypeEncodingUnsignedLong into:&t] ||
      [self scanChar:FLEXTypeEncodingUnsignedLongLong into:&t] ||
      [self scanChar:FLEXTypeEncodingFloat into:&t] ||
      [self scanChar:FLEXTypeEncodingDouble into:&t] ||
      [self scanChar:FLEXTypeEncodingLongDouble into:&t] ||
      [self scanChar:FLEXTypeEncodingCBool into:&t] ||
      [self scanChar:FLEXTypeEncodingCString into:&t] ||
      [self scanChar:FLEXTypeEncodingSelector into:&t] ||
      [self scanChar:FLEXTypeEncodingBitField into:&t]) {
        // Size is optional
        ssize_t size = [self scanSize];
        if (t == FLEXTypeEncodingBitField) {
            if (size) {
                return size; // Bits
            } else {
                [NSException raise:NSInternalInconsistencyException
                            format:@"Invalid type encoding: bitfield without size"];
            }
        } else if (size) {
            return size * 8; // Bytes, so * 8
        } else {
            return [self sizeForType:t] * 8; // Bytes, so * 8
        }
    }

    // These might have numbers OR quotes after them
    if ([self scanChar:FLEXTypeEncodingObjcObject] || [self scanChar:FLEXTypeEncodingObjcClass]) {
        ssize_t size = [self scanSize];
        [self scanPair:FLEXTypeEncodingQuote close:FLEXTypeEncodingQuote];
        if (size) {
            return size * 8; // Bytes, so * 8
        } else {
            return sizeof(id) * 8;
        }
    }

    self.scan.scanLocation = start;
    return -1;
}

- (BOOL)scanString:(NSString *)str {
    return [self.scan scanString:str intoString:nil];
}

- (BOOL)canScanString:(NSString *)str {
    if ([self scanString:str]) {
        self.scan.scanLocation -= str.length;
        return YES;
    }

    return NO;
}

- (BOOL)canScanChar:(char)c {
    return [self canScanString:S(c)];
}

- (BOOL)scanChar:(char)c {
    return [self scanString:S(c)];
}

- (BOOL)scanChar:(char)c into:(char *)ref {
    if ([self scanString:S(c)]) {
        *ref = c;
        return YES;
    }

    return NO;
}

- (ssize_t)scanSize {
    NSInteger size = 0;
    if ([self.scan scanInteger:&size]) {
        return size;
    }

    return 0;
}

- (NSString *)scanPair:(char)c1 close:(char)c2 {
    // Starting position and string variables
    NSUInteger start = self.scan.scanLocation;
    NSString *s1 = S(c1);

    // Scan opening tag
    if (![self scanChar:c1]) {
        self.scan.scanLocation = start;
        return nil;
    }

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
        if ([self scanChar:c1]) {
            // Begin pair
            [stack addObject:s1];
        }
        // Closing symbol found
        if ([self scanChar:c2]) {
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
        if ([self scanPastArg]) {
            return YES;
        } else {
            // Scan failed, abort
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
        [self scanSize];
        return YES;
    }

    // These might have numbers OR quotes after them
    if ([self scanChar:FLEXTypeEncodingObjcObject] || [self scanChar:FLEXTypeEncodingObjcClass]) {
        [self scanSize] || [self scanPair:FLEXTypeEncodingQuote close:FLEXTypeEncodingQuote];
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
