/*
 * Copyright (c) 2010-2011 SURFnet bv
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of SURFnet bv nor the names of its contributors 
 *    may be used to endorse or promote products derived from this 
 *    software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 * GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "Challenge-Protected.h"
#import "EnrollmentChallenge.h"
#import "Identity+Utils.h"
#import "IdentityProvider+Utils.h"

NSString *const TIQRECErrorDomain = @"org.tiqr.ec";

@interface EnrollmentChallenge ()

@property (nonatomic, assign) BOOL allowFiles;
@property (nonatomic, copy) NSString *identityProviderIdentifier;
@property (nonatomic, copy) NSString *identityProviderDisplayName;
@property (nonatomic, copy) NSString *identityProviderAuthenticationUrl;
@property (nonatomic, copy) NSString *identityProviderInfoUrl;
@property (nonatomic, copy) NSString *identityProviderOcraSuite;
@property (nonatomic, copy) NSData *identityProviderLogo;

@property (nonatomic, copy) NSString *identityIdentifier;
@property (nonatomic, copy) NSString *identityDisplayName;

@property (nonatomic, copy) NSString *enrollmentUrl;
@property (nonatomic, copy) NSString *returnUrl;

@end

@implementation EnrollmentChallenge

- (instancetype)initWithRawChallenge:(NSString *)challenge managedObjectContext:(NSManagedObjectContext *)context allowFiles:(BOOL)allowFiles {
    self = [super initWithRawChallenge:challenge managedObjectContext:context autoParse:NO];
    if (self != nil) {
        self.allowFiles = allowFiles;
		[self parseRawChallenge];
	}
	
	return self;
}

- (instancetype)initWithRawChallenge:(NSString *)challenge managedObjectContext:(NSManagedObjectContext *)context {
    return [self initWithRawChallenge:challenge managedObjectContext:context allowFiles:NO];
}

- (instancetype)initWithRawChallenge:(NSString *)challenge managedObjectContext:(NSManagedObjectContext *)context autoParse:(BOOL)autoParse {
    return [self initWithRawChallenge:challenge managedObjectContext:context allowFiles:NO];
}

- (BOOL)isValidMetadata:(NSDictionary *)metadata {
    // TODO: service => identityProvider 
	if ([metadata valueForKey:@"service"] == nil ||
		[metadata valueForKey:@"identity"] == nil) {
		return NO;
	}

	// TODO: improve validation
    
	return YES;
}

- (NSData *)downloadSynchronously:(NSURL *)url error:(NSError **)error {
	NSURLResponse *response = nil;
	NSURLRequest *request = [NSURLRequest requestWithURL:url];
	NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:error];
	return data;
}

- (BOOL)assignIdentityProviderMetadata:(NSDictionary *)metadata {
	self.identityProviderIdentifier = [metadata[@"identifier"] description];
	self.identityProvider = [IdentityProvider findIdentityProviderWithIdentifier:self.identityProviderIdentifier inManagedObjectContext:self.managedObjectContext];

	if (self.identityProvider != nil) {
		self.identityProviderDisplayName = self.identityProvider.displayName;
		self.identityProviderAuthenticationUrl = self.identityProvider.authenticationUrl;	
        self.identityProviderOcraSuite = self.identityProvider.ocraSuite;
		self.identityProviderLogo = self.identityProvider.logo;
	} else {
		NSURL *logoUrl = [NSURL URLWithString:[metadata[@"logoUrl"] description]];		
		NSError *error = nil;		
		NSData *logo = [self downloadSynchronously:logoUrl error:&error];
		if (error != nil) {
            NSString *errorTitle = NSLocalizedString(@"error_enroll_logo_error_title", @"No identity provider logo");
            NSString *errorMessage = NSLocalizedString(@"error_enroll_logo_error", @"No identity provider logo message");
            NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage, NSUnderlyingErrorKey: error};
            self.error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECIdentityProviderLogoError userInfo:details];        
			return NO;
		}
		
		self.identityProviderDisplayName =  [metadata[@"displayName"] description];
		self.identityProviderAuthenticationUrl = [metadata[@"authenticationUrl"] description];	
		self.identityProviderInfoUrl = [metadata[@"infoUrl"] description];        
        self.identityProviderOcraSuite = [metadata[@"ocraSuite"] description];
		self.identityProviderLogo = logo;
	}	
	
	return YES;
}

- (BOOL)assignIdentityMetadata:(NSDictionary *)metadata {
	self.identityIdentifier = [metadata[@"identifier"] description];
	self.identityDisplayName = [metadata[@"displayName"] description];
	self.identitySecret = nil;
	
	if (self.identityProvider != nil) {
		Identity *identity = [Identity findIdentityWithIdentifier:self.identityIdentifier forIdentityProvider:self.identityProvider inManagedObjectContext:self.managedObjectContext];
		if (identity != nil && [identity.blocked boolValue]) {
            self.identity = identity;
        } else if (identity != nil) {
            NSString *errorTitle = NSLocalizedString(@"error_enroll_already_enrolled_title", @"Account already activated");
            NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"error_enroll_already_enrolled", @"Account already activated message"), self.identityDisplayName, self.identityProviderDisplayName];
            NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
            self.error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECAccountAlreadyExistsError userInfo:details];        
			return NO;			
		}
	}
								 
	return YES;
}

- (void)parseRawChallenge {
    NSString *scheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQREnrollmentURLScheme"]; 
    NSURL *fullURL = [NSURL URLWithString:self.rawChallenge];
    if (fullURL == nil || ![fullURL.scheme isEqualToString:scheme]) {
        NSString *errorTitle = NSLocalizedString(@"error_enroll_invalid_qr_code", @"Invalid QR tag title");
        NSString *errorMessage = NSLocalizedString(@"error_enroll_invalid_response", @"Invalid QR tag message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        self.error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECInvalidQRTagError userInfo:details];        
		return;        
    }
    
	NSURL *url = [NSURL URLWithString:[self.rawChallenge substringFromIndex:13]];
    if (url == nil) {
        NSString *errorTitle = NSLocalizedString(@"error_enroll_invalid_qr_code", @"Invalid QR tag title");
        NSString *errorMessage = NSLocalizedString(@"error_enroll_invalid_response", @"Invalid QR tag message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        self.error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECInvalidQRTagError userInfo:details];        
		return;        
    }
    
	if (![url.scheme isEqualToString:@"http"] && ![url.scheme isEqualToString:@"https"] && ![url.scheme isEqualToString:@"file"]) {
        NSString *errorTitle = NSLocalizedString(@"error_enroll_invalid_qr_code", @"Invalid QR tag title");
        NSString *errorMessage = NSLocalizedString(@"error_enroll_invalid_response", @"Invalid QR tag message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        self.error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECInvalidQRTagError userInfo:details];        
		return;
	} else if ([url.scheme isEqualToString:@"file"] && !self.allowFiles) {
        NSString *errorTitle = NSLocalizedString(@"error_enroll_invalid_qr_code", @"Invalid QR tag title");
        NSString *errorMessage = NSLocalizedString(@"error_enroll_invalid_response", @"Invalid QR tag message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        self.error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECInvalidQRTagError userInfo:details];        
		return;
	}
    
    
	NSError *error = nil;
	NSData *data = [self downloadSynchronously:url error:&error];
	if (error != nil) {
        NSString *errorTitle = NSLocalizedString(@"no_connection", @"No connection title");
        NSString *errorMessage = NSLocalizedString(@"internet_connection_required", @"You need an Internet connection to activate your account. Please try again later.");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage, NSUnderlyingErrorKey: error};
        self.error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECConnectionError userInfo:details];        
		return;
	}

	NSDictionary *metadata = nil;
	
	@try {
        id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([object isKindOfClass:[NSDictionary class]]) {
            metadata = object;
        }
	} @catch (NSException *exception) {
        metadata = nil;
    } 

	if (metadata == nil || error != nil || ![self isValidMetadata:metadata]) {
        NSString *errorTitle = NSLocalizedString(@"error_enroll_invalid_response_title", @"Invalid response title");
        NSString *errorMessage = NSLocalizedString(@"error_enroll_invalid_response", @"Invalid response message");
        NSDictionary *details;
        if (error) {
            details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage, NSUnderlyingErrorKey: error};
        } else {
            details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        }
        self.error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECInvalidResponseError userInfo:details];
		return;        
	}
	
	NSMutableDictionary *identityProviderMetadata = [NSMutableDictionary dictionaryWithDictionary:metadata[@"service"]];
	if (![self assignIdentityProviderMetadata:identityProviderMetadata]) {
		return;
	}

	NSDictionary *identityMetadata = metadata[@"identity"];	
	if (![self assignIdentityMetadata:identityMetadata]) {
		return;
	}
    
    NSString *regex = @"^http(s)?://.*";
    NSPredicate *protocolPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    
    if (url.query != nil && [url.query length] > 0 && [protocolPredicate evaluateWithObject:url.query] == YES) {
        self.returnUrl = [self decodeURL:url.query];
    } else {
        self.returnUrl = nil;
    }
	
	self.returnUrl = nil; // TODO: support return URL url.query == nil || [url.query length] == 0 ? nil : url.query;	
	self.enrollmentUrl = [identityProviderMetadata[@"enrollmentUrl"] description];
}


@end