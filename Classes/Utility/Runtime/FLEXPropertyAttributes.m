//
//  MKPropertyAttributes.m
//  MirrorKit
//
//  Created by Tanner on 7/5/15.
//  Copyright (c) 2015 Tanner Bennett. All rights reserved.
//

#import "FLEXPropertyAttributes.h"
#import "FLEXRuntimeUtility.h"
#import "NSString+ObjcRuntime.h"
#import "NSDictionary+ObjcRuntime.h"


#pragma mark - MKPropertyAttributes -

@interface FLEXPropertyAttributes ()

@property (nonatomic) NSString *backingIvar;
@property (nonatomic) NSString *typeEncoding;
@property (nonatomic) NSString *oldTypeEncoding;
@property (nonatomic) SEL customGetter;
@property (nonatomic) SEL customSetter;
@property (nonatomic) BOOL isReadOnly;
@property (nonatomic) BOOL isCopy;
@property (nonatomic) BOOL isRetained;
@property (nonatomic) BOOL isNonatomic;
@property (nonatomic) BOOL isDynamic;
@property (nonatomic) BOOL isWeak;
@property (nonatomic) BOOL isGarbageCollectable;

@end

@implementation FLEXPropertyAttributes

#pragma mark Initializers

+ (instancetype)attributesFromDictionary:(NSDictionary *)attributes {
    NSString *attrs = attributes.propertyAttributesString;
    if (!attrs) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Invalid property attributes dictionary: %@", attributes];
    }
    return [self attributesFromString:attrs];
}

+ (instancetype)attributesFromString:(NSString *)attributes {
    return [[self alloc] initWithAttributesString:attributes];
}

- (id)initWithAttributesString:(NSString *)attributesString {
    NSParameterAssert(attributesString);
    
    self = [super init];
    if (self) {
        _attributesString = attributesString;
        
        NSDictionary *attributes = attributesString.propertyAttributes;
        if (!attributes) {
            [NSException raise:NSInternalInconsistencyException
                        format:@"Invalid property attributes string: %@", attributesString];
        }
        
        _count                = attributes.allKeys.count;
        _typeEncoding         = attributes[kFLEXPropertyAttributeKeyTypeEncoding];
        _backingIvar          = attributes[kFLEXPropertyAttributeKeyBackingIvarName];
        _oldTypeEncoding      = attributes[kFLEXPropertyAttributeKeyOldStyleTypeEncoding];
        _customGetter         = NSSelectorFromString(attributes[kFLEXPropertyAttributeKeyCustomGetter]);
        _customSetter         = NSSelectorFromString(attributes[kFLEXPropertyAttributeKeyCustomSetter]);
        _isReadOnly           = [attributes[kFLEXPropertyAttributeKeyReadOnly] boolValue];
        _isCopy               = [attributes[kFLEXPropertyAttributeKeyCopy] boolValue];
        _isRetained           = [attributes[kFLEXPropertyAttributeKeyRetain] boolValue];
        _isNonatomic          = [attributes[kFLEXPropertyAttributeKeyNonAtomic] boolValue];
        _isWeak               = [attributes[kFLEXPropertyAttributeKeyWeak] boolValue];
        _isGarbageCollectable = [attributes[kFLEXPropertyAttributeKeyGarbageCollectable] boolValue];
    }
    
    return self;
}

#pragma mark Misc

- (NSString *)description {
    return [NSString
        stringWithFormat:@"<%@ ivar=%@, readonly=%d, nonatomic=%d, getter=%@, setter=%@>",
        NSStringFromClass(self.class),
        self.backingIvar ?: @"none",
        self.isReadOnly,
        self.isNonatomic,
        NSStringFromSelector(self.customGetter) ?: @" ",
        NSStringFromSelector(self.customSetter) ?: @" "
    ];
}

- (objc_property_attribute_t *)copyAttributesList:(unsigned int *)attributesCount {
    NSDictionary *attributes = self.attributesString.propertyAttributes;
    *attributesCount = (unsigned int)attributes.allKeys.count;
    objc_property_attribute_t *propertyAttributes = malloc(attributes.allKeys.count*sizeof(objc_property_attribute_t));
    
    NSUInteger i = 0;
    for (NSString *key in attributes.allKeys) {
        FLEXPropertyAttribute c = (FLEXPropertyAttribute)[key characterAtIndex:0];
        switch (c) {
            case FLEXPropertyAttributeTypeEncoding: {
                objc_property_attribute_t pa = {
                    kFLEXPropertyAttributeKeyTypeEncoding.UTF8String,
                    self.typeEncoding.UTF8String
                };
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeBackingIvarName: {
                objc_property_attribute_t pa = {
                    kFLEXPropertyAttributeKeyBackingIvarName.UTF8String,
                    self.backingIvar.UTF8String
                };
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeCopy: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyCopy.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeCustomGetter: {
                objc_property_attribute_t pa = {
                    kFLEXPropertyAttributeKeyCustomGetter.UTF8String,
                    NSStringFromSelector(self.customGetter).UTF8String ?: ""
                };
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeCustomSetter: {
                objc_property_attribute_t pa = {
                    kFLEXPropertyAttributeKeyCustomSetter.UTF8String,
                    NSStringFromSelector(self.customSetter).UTF8String ?: ""
                };
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeDynamic: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyDynamic.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeGarbageCollectible: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyGarbageCollectable.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeNonAtomic: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyNonAtomic.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeOldTypeEncoding: {
                objc_property_attribute_t pa = {
                    kFLEXPropertyAttributeKeyOldStyleTypeEncoding.UTF8String,
                    self.oldTypeEncoding.UTF8String ?: ""
                };
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeReadOnly: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyReadOnly.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeRetain: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyRetain.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeWeak: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyWeak.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
        }
        i++;
    }
    
    return propertyAttributes;
}

#pragma mark Copying

- (id)copyWithZone:(NSZone *)zone {
    return [[FLEXPropertyAttributes class] attributesFromString:self.attributesString];
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    return [[MKMutablePropertyAttributes class] attributesFromString:self.attributesString];
}

@end



#pragma mark - MKMutablePropertyAttributes -

@implementation MKMutablePropertyAttributes

@dynamic backingIvar;
@dynamic typeEncoding;
@dynamic oldTypeEncoding;
@dynamic customGetter;
@dynamic customSetter;
@dynamic isReadOnly;
@dynamic isCopy;
@dynamic isRetained;
@dynamic isNonatomic;
@dynamic isDynamic;
@dynamic isWeak;
@dynamic isGarbageCollectable;

+ (instancetype)attributes {
    return [self new];
}

- (void)setTypeEncodingChar:(char)type {
    self.typeEncoding = [NSString stringWithFormat:@"%c", type];
}

- (NSString *)attributesString {
    NSMutableDictionary *attrs = [NSMutableDictionary new];
    if (self.typeEncoding)
        attrs[kFLEXPropertyAttributeKeyTypeEncoding]         = self.typeEncoding;
    if (self.backingIvar)
        attrs[kFLEXPropertyAttributeKeyBackingIvarName]      = self.backingIvar;
    if (self.oldTypeEncoding)
        attrs[kFLEXPropertyAttributeKeyOldStyleTypeEncoding] = self.oldTypeEncoding;
    if (self.customGetter)
        attrs[kFLEXPropertyAttributeKeyCustomGetter]         = NSStringFromSelector(self.customGetter);
    if (self.customSetter)
        attrs[kFLEXPropertyAttributeKeyCustomSetter]         = NSStringFromSelector(self.customSetter);
    
    attrs[kFLEXPropertyAttributeKeyReadOnly]           = @(self.isReadOnly);
    attrs[kFLEXPropertyAttributeKeyCopy]               = @(self.isCopy);
    attrs[kFLEXPropertyAttributeKeyRetain]             = @(self.isRetained);
    attrs[kFLEXPropertyAttributeKeyNonAtomic]          = @(self.isNonatomic);
    attrs[kFLEXPropertyAttributeKeyDynamic]            = @(self.isDynamic);
    attrs[kFLEXPropertyAttributeKeyWeak]               = @(self.isWeak);
    attrs[kFLEXPropertyAttributeKeyGarbageCollectable] = @(self.isGarbageCollectable);
    
    return attrs.propertyAttributesString;
}

@end
