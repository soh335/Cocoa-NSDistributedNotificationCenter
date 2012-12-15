#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

// undefine Move macro, this is conflict to Mac OS X QuickDraw API.
#undef Move

#import <Foundation/Foundation.h>
#import <objc/objc-runtime.h>

#ifdef DEBUG
#  define LOG(...) NSLog(__VA_ARGS__)
#else
#  define LOG(...) ;
#endif

// steal from https://github.com/typester/Cocoa-BatteryInfo/blob/master/batteryinfo.m
static inline SV* nsnumber_to_sv(NSNumber* n) {
    SV* sv;

    switch (*[n objCType]) {
        case 'c':
            // char
            sv = newSViv([n charValue]);
            break;
        case 'i':
            // int
            sv = newSViv([n intValue]);
            break;
        case 's':
            // short
            sv = newSViv([n shortValue]);
            break;
        case 'l':
            // long
            sv = newSViv([n longValue]);
            break;
        case 'q':
            // long long
            sv = newSViv([n longLongValue]);
            break;
        case 'C':
            // unsigned char
            sv = newSVuv([n unsignedCharValue]);
            break;
        case 'I':
            // unsigned int
            sv = newSVuv([n unsignedIntValue]);
            break;
        case 'S':
            // unsigned short
            sv = newSVuv([n unsignedShortValue]);
            break;
        case 'L':
            // unsigned long
            sv = newSVuv([n unsignedLongValue]);
            break;
        case 'Q':
            // unsigned long long
            sv = newSVuv([n unsignedLongLongValue]);
            break;
        case 'f':
            // float
            sv = newSVnv([n floatValue]);
            break;
        case 'd':
            // double
            sv = newSVnv([n doubleValue]);
            break;
        case 'B':
            // bool
            sv = newSViv([n boolValue]);
            break;
        default:
            sv = NULL;
    }

    return sv;
}


static inline SV* ns_to_sv(id value) {

    SV *res;
    SV** unused;

    if ([value isKindOfClass:[NSDictionary class]]) {
        LOG(@"dict");
        HV* hv = (HV *)sv_2mortal((SV *)newHV());

        NSArray *keys = [(NSDictionary *)value allKeys];
        for (NSString* key in keys) {
            id _value = [(NSDictionary*)value objectForKey:key];
            SV* _sv_value;
            _sv_value = ns_to_sv(_value);
            unused = hv_store(hv, [key UTF8String], [key lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                    SvREFCNT_inc(_sv_value), 0);
        }
        res = sv_2mortal(newRV_inc((SV *)hv));
        return res;
    }
    else if ([value isKindOfClass:[NSArray class]]) {
        LOG(@"array");
        AV* av = (AV *)sv_2mortal((SV *)newAV());
        for (id _value in (NSArray *)value) {
            SV *__value = ns_to_sv(_value);
            av_push(av, SvREFCNT_inc(__value));
        }
        res = sv_2mortal(newRV_inc((SV *)av));
        return res;
    }
    else if ([value isKindOfClass:[NSString class]]) {
        LOG(@"string");
        res = sv_2mortal(newSV(0));
        sv_setpv(res, [value UTF8String]);
        return res;
    }
    else if([value isKindOfClass:[NSNumber class]]) {
        LOG(@"number");
        res = nsnumber_to_sv((NSNumber *)value);
        return res;
    }
    else if([value isKindOfClass:[NSNull class]]) {
        LOG(@"null");
        res = NULL;
        return res;
    }
    else if([value isKindOfClass:[NSDate class]]) {
        LOG(@"time");
        NSTimeInterval timestamp = [(NSDate *)value timeIntervalSince1970];
        res = newSVnv(timestamp);
        return res;
    }
    else if([value isKindOfClass:[NSData class]]) {
        LOG(@"data");
        NSString *str = [[NSString alloc] initWithData:(NSData *)value encoding:NSUTF8StringEncoding];
        res = sv_2mortal(newSV(0));
        sv_setpv(res, [str UTF8String]);
        return res;
    }
    else {
        Perl_croak(aTHX_ "unsupport class\n");
    }
}

@interface NotificationObserver :NSObject {
@public
    SV* perl_obj;
}
- (void)fire:(NSNotification *)aNotification;
@end

@implementation NotificationObserver

- (void)fire:(NSNotification *)aNotification {

    HV* hv;
    SV* sv_hoge;
    STRLEN len;
    char* ptr;
    NSString* hoge;

    SV* sv_no_name;

    dSP;

    LOG(@"ovserver fire");

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    LOG(@"%@", [aNotification name]);
    LOG(@"%@", [[aNotification userInfo] description]);

    NSString     *no_name = [aNotification name];
    sv_no_name = sv_2mortal(newSV(0));
    sv_setpv(sv_no_name, [no_name UTF8String]);

    NSDictionary *dict = [aNotification userInfo];
    SV* ns_sv = ns_to_sv(dict);

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(self->perl_obj);
    XPUSHs(sv_no_name);
    XPUSHs(ns_sv);
    PUTBACK;

    call_method("_fire", G_DISCARD);

    SPAGAIN;
    PUTBACK;
    FREETMPS;
    LEAVE;

    [pool drain];
}
-(void) dealloc {
    [super dealloc];
}

@end

XS(XS_Cocoa__NSDistributedNotificationCenter_set_up) {
    dXSARGS;
    SV* sv_obj;

    if ( items < 1 ) {
        Perl_croak(aTHX_ "invalid arguments\n");
    }

    sv_obj = ST(0);

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    NotificationObserver* no = [[NotificationObserver alloc] init];

    no->perl_obj = SvREFCNT_inc(sv_obj);

    sv_magic(SvRV(sv_obj), NULL, PERL_MAGIC_ext, NULL, 0);
    mg_find(SvRV(sv_obj), PERL_MAGIC_ext)->mg_obj = (SV*)no;

    [pool drain];

    XSRETURN(0);
}

XS(XS_Cocoa__NSDistributedNotificationCenter_add_listener) {
    dXSARGS;
    SV* sv_obj;
    SV* sv_name;
    STRLEN len;
    NSString* name;
    char* ptr;

    if ( items < 2 ) {
        Perl_croak(aTHX_ "invalid arguments\n");
    }

    sv_obj = ST(0);
    sv_name = ST(1);

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    NotificationObserver* no = (NotificationObserver *)mg_find(SvRV(sv_obj), PERL_MAGIC_ext)->mg_obj;

    ptr = SvPV(sv_name, len);
    name = [NSString stringWithUTF8String:ptr];

    LOG(@"listen %@", name);

    [[NSDistributedNotificationCenter defaultCenter] addObserver:no selector:@selector(fire:) name:name object:nil];

    [pool drain];

    XSRETURN(0);
}

XS(XS_Cocoa__NSDistributedNotificationCenter_destroy) {
    dXSARGS;
    SV* sv_obj;
    SV* perl_obj;

    if ( items < 1 ) {
        Perl_croak(aTHX_ "invalid arguments\n");
    }

    LOG(@"destroy");

    sv_obj = ST(0);

    NotificationObserver* no = (NotificationObserver *)mg_find(SvRV(sv_obj), PERL_MAGIC_ext)->mg_obj;
    perl_obj = no->perl_obj;
    SvREFCNT_dec(perl_obj);
    [no release];
    sv_unmagic( SvRV(sv_obj), PERL_MAGIC_ext );
}

XS(boot_Cocoa__NSDistributedNotificationCenter) {
    newXS("Cocoa::NSDistributedNotificationCenter::_set_up", XS_Cocoa__NSDistributedNotificationCenter_set_up, __FILE__);
    newXS("Cocoa::NSDistributedNotificationCenter::_add_listener", XS_Cocoa__NSDistributedNotificationCenter_add_listener, __FILE__);
    newXS("Cocoa::NSDistributedNotificationCenter::_destroy", XS_Cocoa__NSDistributedNotificationCenter_destroy, __FILE__);
}
