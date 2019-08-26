//
//  MKMirror.m
//  MirrorKit
//
//  Created by Tanner on 6/29/15.
//  Copyright (c) 2015 Tanner Bennett. All rights reserved.
//

#import "FLEXMirror.h"
#import "FLEXProperty.h"
#import "FLEXMethod.h"
#import "FLEXIvar.h"
#import "FLEXProtocol.h"
#import "FLEXUtility.h"
//#import "MirrorKit.h"
//#import "NSObject+Reflection.h"


#pragma mark - MKMirror -

@implementation FLEXMirror

- (id)init { [NSException raise:NSInternalInconsistencyException format:@"Class instance should not be created with -init"]; return nil; }

#pragma mark Initialization
+ (instancetype)reflect:(id)objectOrClass {
    return [[self alloc] initWithValue:objectOrClass];
}

- (id)initWithValue:(id)value {
    NSParameterAssert(value);
    
    self = [super init];
    if (self) {
        _value = value;
        [self examine];
    }
    
    return self;
}

- (NSString *)description {
    NSString *type = self.isClass ? @"metaclass" : @"class";
    return [NSString stringWithFormat:@"<%@ %@=%@, %lu properties, %lu ivars, %lu methods, %lu protocols>",
            NSStringFromClass(self.class), type, self.className, (unsigned long)self.properties.count, (unsigned long)self.instanceVariables.count, (unsigned long)self.methods.count, (unsigned long)self.protocols.count];
}

- (void)examine {
    // cls is a metaclass if self.value is a class
    Class cls = object_getClass(self.value);
    
    unsigned int pcount, mcount, ivcount, pccount;
    objc_property_t *objcproperties     = class_copyPropertyList(cls, &pcount);
    Protocol*__unsafe_unretained *procs = class_copyProtocolList(cls, &pccount);
    Method *objcmethods                 = class_copyMethodList(cls, &mcount);
    Ivar *objcivars                     = class_copyIvarList(cls, &ivcount);
    
    _className = NSStringFromClass(cls);
    _isClass   = class_isMetaClass(cls); // or object_isClass(self.value)
    
    NSMutableArray *properties = [NSMutableArray array];
    for (int i = 0; i < pcount; i++)
        [properties addObject:[FLEXProperty property:objcproperties[i]]];
    _properties = properties;
    
    NSMutableArray *methods = [NSMutableArray array];
    for (int i = 0; i < mcount; i++)
        [methods addObject:[FLEXMethod method:objcmethods[i]]];
    _methods = methods;
    
    NSMutableArray *ivars = [NSMutableArray array];
    for (int i = 0; i < ivcount; i++)
        [ivars addObject:[FLEXIvar ivar:objcivars[i]]];
    _instanceVariables = ivars;
    
    NSMutableArray *protocols = [NSMutableArray array];
    for (int i = 0; i < pccount; i++)
        [protocols addObject:[FLEXProtocol protocol:procs[i]]];
    _protocols = protocols;
    
    // Cleanup
    free(objcproperties);
    free(objcmethods);
    free(objcivars);
    free(procs);
    procs = NULL;
}

#pragma mark Misc

- (FLEXMirror *)superMirror {
    return [FLEXMirror reflect:[self.value superclass]];
}

@end


#pragma mark - ExtendedMirror -

@implementation FLEXMirror (ExtendedMirror)

- (FLEXMethod *)methodNamed:(NSString *)name {
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"%K = %@", @"selectorString", name];
    return [self.methods filteredArrayUsingPredicate:filter].firstObject;
}

- (FLEXProperty *)propertyNamed:(NSString *)name {
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"%K = %@", @"name", name];
    return [self.properties filteredArrayUsingPredicate:filter].firstObject;
}

- (FLEXIvar *)ivarNamed:(NSString *)name {
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"%K = %@", @"name", name];
    return [self.instanceVariables filteredArrayUsingPredicate:filter].firstObject;
}

- (FLEXProtocol *)protocolNamed:(NSString *)name {
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"%K = %@", @"name", name];
    return [self.protocols filteredArrayUsingPredicate:filter].firstObject;
}

@end
