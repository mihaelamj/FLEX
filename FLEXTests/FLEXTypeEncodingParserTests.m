//
//  FLEXTypeEncodingParserTests.m
//  FLEXTests
//
//  Created by Tanner Bennett on 8/25/19.
//  Copyright © 2019 Flipboard. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "FLEXTypeEncodingParser.h"

#define Type(t) @(@encode(t))
#define TypeSizePair(t) Type(t): @(sizeof(t))

@interface FLEXTypeEncodingParserTests : XCTestCase
@property (nonatomic, readonly) NSDictionary<NSString *, NSNumber *> *typesToSizes;
@end

@implementation FLEXTypeEncodingParserTests

- (void)setUp {
    _typesToSizes = @{
        TypeSizePair(NSDecimal),
        TypeSizePair(char),
        TypeSizePair(short),
        TypeSizePair(int),
        TypeSizePair(long),
        TypeSizePair(long long),
        TypeSizePair(float),
        TypeSizePair(double),
        TypeSizePair(long double),
        TypeSizePair(Class),
        TypeSizePair(id),
        TypeSizePair(CGPoint),
        TypeSizePair(CGRect),
        TypeSizePair(char *),
        TypeSizePair(long *),
        TypeSizePair(Class *),
        TypeSizePair(CGRect *)
    };
}

- (void)testTypeEncodingParser {
    [self.typesToSizes enumerateKeysAndObjectsUsingBlock:^(NSString *typeString, NSNumber *size, BOOL *stop) {
        ssize_t s = [FLEXTypeEncodingParser sizeForTypeEncoding:typeString];
        XCTAssertEqual(s, size.longValue);
    }];
}

- (void)testExpectedStructureSizes {
    typedef struct _FooBytes {
        uint8_t x: 3;
        struct {
            uint8_t a: 1;
            uint8_t b: 2;
        } y;
        uint8_t z: 5;
    } FooBytes;

    typedef struct _FooInts {
        unsigned int x: 3;
        struct {
            unsigned int a: 1;
            unsigned int b: 2;
        } y;
        unsigned int z: 5;
    } FooInts;

    typedef struct _Bar {
        unsigned int x: 3;
        unsigned int z: 5;
        struct {
            unsigned int a: 1;
            unsigned int b: 2;
        } y;
    } Bar;

    typedef struct _ArrayInMiddle {
        unsigned int x: 3;
        unsigned char c[2];
        unsigned int z: 5;
    } ArrayInMiddle;
    typedef struct _ArrayAtEnd {
        unsigned int x: 3;
        unsigned int z: 5;
        unsigned char c[2];
    } ArrayAtEnd;

    typedef struct _OneBit {
        uint8_t x: 1;
    } OneBit;
    typedef struct _OneByte {
        uint8_t x;
    } OneByte;
    typedef struct _TwoBytes {
        uint8_t x, y;
    } TwoBytes;
    typedef struct _TwoJoinedBytesAndOneByte {
        uint16_t x;
        uint8_t y;
    } TwoJoinedBytesAndOneByte;

    // Structs have the alignment of the size of their smallest member, recursively.
    // That is, a struct has the alignment of the greater of the size of its
    // largest direct member or the largest alignment of it's nested structs.
    XCTAssertEqual(__alignof__(FooBytes), 1);
    XCTAssertEqual(__alignof__(FooInts), 4);
    XCTAssertEqual(__alignof__(ArrayInMiddle), 4);
    XCTAssertEqual(__alignof__(ArrayAtEnd), 4);
    XCTAssertEqual(__alignof__(OneBit), 1);
    XCTAssertEqual(__alignof__(OneByte), 1);
    XCTAssertEqual(__alignof__(TwoBytes), 1);
    XCTAssertEqual(__alignof__(TwoJoinedBytesAndOneByte), 2);

    // Nested structs are aligned before and after, if between bitfields
    XCTAssertEqual(sizeof(FooBytes), 3);
    XCTAssertEqual(sizeof(FooInts), 12);
    // Bitfields are not aligned at all and they will pack if adjacent to one another
    XCTAssertEqual(sizeof(Bar), 8);
    // Structs are resized to match their alignment
    XCTAssertEqual(sizeof(OneBit), 1);
    XCTAssertEqual(sizeof(OneByte), 1);
    XCTAssertEqual(sizeof(TwoJoinedBytesAndOneByte), 4);
    // Arrays do not affect alignment like nested structs do
    XCTAssertEqual(sizeof(ArrayInMiddle), 4);
    XCTAssertEqual(sizeof(ArrayAtEnd), 4);

    // Test my method of converting calculated sizes to actual sizes
    // for FLEXTypeEncodingParser
    #define RoundUpToMultipleOf4(num) ((num + 3) & ~0x03)
    XCTAssertEqual(RoundUpToMultipleOf4(1), 4);
    XCTAssertEqual(RoundUpToMultipleOf4(2), 4);
    XCTAssertEqual(RoundUpToMultipleOf4(3), 4);
    XCTAssertEqual(RoundUpToMultipleOf4(4), 4);
    XCTAssertEqual(RoundUpToMultipleOf4(5), 8);
    XCTAssertEqual(RoundUpToMultipleOf4(6), 8);
    XCTAssertEqual(RoundUpToMultipleOf4(7), 8);
    XCTAssertEqual(RoundUpToMultipleOf4(8), 8);
    XCTAssertEqual(RoundUpToMultipleOf4(9), 12);
    XCTAssertEqual(RoundUpToMultipleOf4(10), 12);
    XCTAssertEqual(RoundUpToMultipleOf4(11), 12);
    XCTAssertEqual(RoundUpToMultipleOf4(12), 12);
    XCTAssertEqual(RoundUpToMultipleOf4(13), 16);

    // Test expected type encodings
    char *fooBytes = @encode(FooBytes);
    char *fooInts = @encode(FooInts);
    char *bar = nil;
}

@end
