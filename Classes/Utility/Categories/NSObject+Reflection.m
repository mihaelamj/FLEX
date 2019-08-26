//
//  NSObject+Reflection.m
//  MirrorKit
//
//  Created by Tanner on 6/30/15.
//  Copyright (c) 2015 Tanner Bennett. All rights reserved.
//

#import "NSObject+Reflection.h"
#import "FLEXMirror.h"
#import "FLEXProperty.h"
#import "FLEXMethod.h"
#import "FLEXIvar.h"
#import "FLEXPropertyAttributes.h"


NSString * MKTypeEncodingString(const char *returnType, NSUInteger count, ...) {
    if (returnType == NULL) return nil;
    
    NSMutableString *encoding = [NSMutableString string];
    [encoding appendFormat:@"%s%s%s", returnType, @encode(id), @encode(SEL)];
    
    va_list args;
    va_start(args, count);
    char *type = va_arg(args, char *);
    for (NSUInteger i = 0; i < count; i++, type = va_arg(args, char *)) {
        [encoding appendFormat:@"%s", type];
    }
    va_end(args);
    
    return encoding.copy;
}

#pragma mark - Reflection -

@implementation NSObject (Reflection)

+ (FLEXMirror *)reflection {
    return [FLEXMirror reflect:self];
}

- (FLEXMirror *)reflection {
    return [FLEXMirror reflect:self];
}

/** Code borrowed from MAObjCRuntime by Mike Ash. */
+ (NSArray *)allSubclasses {
    Class *buffer = NULL;
    
    int count, size;
    do {
        count  = objc_getClassList(NULL, 0);
        buffer = (Class *)realloc(buffer, count * sizeof(*buffer));
        size   = objc_getClassList(buffer, count);
    } while(size != count);
    
    NSMutableArray *array = [NSMutableArray array];
    for(int i = 0; i < count; i++) {
        Class candidate = buffer[i];
        Class superclass = candidate;
        while(superclass) {
            if(superclass == self) {
                [array addObject:candidate];
                break;
            }
            superclass = class_getSuperclass(superclass);
        }
    }
    
    free(buffer);
    [array removeObject:[self class]];
    return array;
}

- (Class)setClass:(Class)cls {
    return object_setClass(self, cls);
}

+ (Class)metaclass {
    return objc_getMetaClass(NSStringFromClass(self.class).UTF8String);
}

+ (size_t)instanceSize {
    return class_getInstanceSize(self.class);
}

#ifdef __clang__
#pragma clang diagnostic push
#endif
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
+ (Class)setSuperclass:(Class)superclass {
    return class_setSuperclass(self, superclass);
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif

@end


#pragma mark - Methods -

@implementation NSObject (Methods)

+ (NSArray *)allMethods {
    unsigned int mcount;
    Method *objcmethods = class_copyMethodList([self class], &mcount);
    
    NSMutableArray *methods = [NSMutableArray array];
    for (int i = 0; i < mcount; i++) {
        FLEXMethod *m = [FLEXMethod method:objcmethods[i] isInstanceMethod:YES];
        if (m) {
            [methods addObject:m];
        }
    }
    
    free(objcmethods);
    objcmethods = NULL;
    mcount = 0;
    
    objcmethods = class_copyMethodList([self metaclass], &mcount);
    for (int i = 0; i < mcount; i++) {
        FLEXMethod *m = [FLEXMethod method:objcmethods[i] isInstanceMethod:NO];
        if (m) {
            [methods addObject:m];
        }
    }
    
    free(objcmethods);
    return methods;
}

+ (FLEXMethod *)methodNamed:(NSString *)name {
    Method m = class_getInstanceMethod([self class], NSSelectorFromString(name));
    if (m == NULL)
        return nil;
    return [FLEXMethod method:m isInstanceMethod:YES];
}

+ (FLEXMethod *)classMethodNamed:(NSString *)name {
    Method m = class_getClassMethod([self class], NSSelectorFromString(name));
    if (m == NULL)
        return nil;
    return [FLEXMethod method:m isInstanceMethod:NO];
}

+ (BOOL)addMethod:(SEL)selector typeEncoding:(NSString *)typeEncoding implementation:(IMP)implementaiton toInstances:(BOOL)instance {
    return class_addMethod(instance ? self.class : self.metaclass, selector, implementaiton, typeEncoding.UTF8String);
}

+ (IMP)replaceImplementationOfMethod:(FLEXMethodBase *)method with:(IMP)implementation useInstance:(BOOL)instance {
    return class_replaceMethod(instance ? self.class : self.metaclass, method.selector, implementation, method.typeEncoding.UTF8String);
}

+ (void)swizzle:(FLEXMethodBase *)original with:(FLEXMethodBase *)other onInstance:(BOOL)instance {
    [self swizzleBySelector:original.selector with:other.selector onInstance:instance];
}

+ (BOOL)swizzleByName:(NSString *)original with:(NSString *)other onInstance:(BOOL)instance {
    SEL originalMethod = NSSelectorFromString(original);
    SEL newMethod      = NSSelectorFromString(other);
    if (originalMethod == 0 || newMethod == 0)
        return NO;
    
    [self swizzleBySelector:originalMethod with:newMethod onInstance:instance];
    return YES;
}

+ (void)swizzleBySelector:(SEL)original with:(SEL)other onInstance:(BOOL)instance {
    Class cls = instance ? self.class : self.metaclass;
    Method originalMethod = class_getInstanceMethod(cls, original);
    Method newMethod = class_getInstanceMethod(cls, other);
    if (class_addMethod(cls, original, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(cls, other, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

@end


#pragma mark - Ivars -

@implementation NSObject (Ivars)

+ (NSArray *)allIvars {
    unsigned int ivcount;
    Ivar *objcivars = class_copyIvarList([self class], &ivcount);
    
    NSMutableArray *ivars = [NSMutableArray array];
    for (int i = 0; i < ivcount; i++)
        [ivars addObject:[FLEXIvar ivar:objcivars[i]]];
    
    free(objcivars);
    return ivars;
}

+ (FLEXIvar *)ivarNamed:(NSString *)name {
    Ivar i = class_getInstanceVariable([self class], name.UTF8String);
    if (i == NULL)
        return nil;
    return [FLEXIvar ivar:i];
}

#pragma mark Get address
- (void *)getIvarAddress:(FLEXIvar *)ivar {
    return (uint8_t *)(__bridge void *)self + ivar.offset;
}

- (void *)getObjcIvarAddress:(Ivar)ivar {
    return (uint8_t *)(__bridge void *)self + ivar_getOffset(ivar);
}

- (void *)getIvarAddressByName:(NSString *)name {
    Ivar ivar = class_getInstanceVariable(self.class, name.UTF8String);
    if (!ivar) return 0;
    
    return (uint8_t *)(__bridge void *)self + ivar_getOffset(ivar);
}

#pragma mark Set ivar object
- (void)setIvar:(FLEXIvar *)ivar object:(id)value {
    object_setIvar(self, ivar.objc_ivar, value);
}

- (BOOL)setIvarByName:(NSString *)name object:(id)value {
    Ivar ivar = class_getInstanceVariable(self.class, name.UTF8String);
    if (!ivar) return NO;
    
    object_setIvar(self, ivar, value);
    return YES;
}

- (void)setObjcIvar:(Ivar)ivar object:(id)value {
    object_setIvar(self, ivar, value);
}

#pragma mark Set ivar value
- (void)setIvar:(FLEXIvar *)ivar value:(void *)value size:(size_t)size {
    void *address = [self getIvarAddress:ivar];
    memcpy(address, value, size);
}

- (BOOL)setIvarByName:(NSString *)name value:(void *)value size:(size_t)size {
    Ivar ivar = class_getInstanceVariable(self.class, name.UTF8String);
    if (!ivar) return NO;
    
    [self setObjcIvar:ivar value:value size:size];
    return YES;
}

- (void)setObjcIvar:(Ivar)ivar value:(void *)value size:(size_t)size {
    void *address = [self getObjcIvarAddress:ivar];
    memcpy(address, value, size);
}

@end


#pragma mark - Properties -

@implementation NSObject (Properties)

+ (NSArray *)allProperties {
    unsigned int pcount;
    objc_property_t *objcproperties = class_copyPropertyList([self class], &pcount);
    
    NSMutableArray *properties = [NSMutableArray array];
    for (int i = 0; i < pcount; i++)
        [properties addObject:[FLEXProperty property:objcproperties[i]]];
    
    free(objcproperties);
    return properties;
}

+ (FLEXProperty *)propertyNamed:(NSString *)name {
    objc_property_t p = class_getProperty([self class], name.UTF8String);
    if (p == NULL)
        return nil;
    return [FLEXProperty property:p];
}

+ (void)replaceProperty:(FLEXProperty *)property {
    [self replaceProperty:property.name attributes:property.attributes];
}

+ (void)replaceProperty:(NSString *)name attributes:(FLEXPropertyAttributes *)attributes {
    unsigned int count;
    objc_property_attribute_t *objc_attributes = [attributes copyAttributesList:&count];
    class_replaceProperty([self class], name.UTF8String, objc_attributes, count);
    free(objc_attributes);
}

@end


