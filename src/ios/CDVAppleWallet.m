/**
 * Created 8/8/2018
 * @author Hatem
 * @implementation {AppleWallet} file CDVAppleWallet
 * Copyright (c) Enigma Advanced Labs 2019
 */

#import "CDVAppleWallet.h"
#import <Cordova/CDV.h>
#import <PassKit/PassKit.h>
#import <WatchConnectivity/WatchConnectivity.h>
#import "AppDelegate.h"

typedef void (^completedPaymentProcessHandler)(PKAddPaymentPassRequest *request);

@interface AppleWallet()<PKAddPaymentPassViewControllerDelegate>


  @property (nonatomic, assign) BOOL isRequestIssued;
  @property (nonatomic, assign) BOOL isRequestIssuedSuccess;

  @property (nonatomic, strong) completedPaymentProcessHandler completionHandler;
  @property (nonatomic, strong) NSString* stringFromData;

  @property (nonatomic, copy) NSString* transactionCallbackId;
  @property (nonatomic, copy) NSString* completionCallbackId;
  
  @property (nonatomic, retain) UIViewController* addPaymentPassModal;

@end


@implementation AppleWallet


+ (BOOL) canAddPaymentPass
{
    return [PKAddPaymentPassViewController canAddPaymentPass];
}

// Plugin Method - check Device Eligibility
- (void) isAvailable:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[AppleWallet canAddPaymentPass]];
    [commandResult setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

// Plugin Method - check Card Eligibility
- (void) checkCardEligibility:(CDVInvokedUrlCommand*)command
{
    NSString * cardIdentifier = [command.arguments objectAtIndex:0];
    Boolean cardEligible = true;
    Boolean cardAddedtoPasses = false;
    Boolean cardAddedtoRemotePasses = false;
    
    NSLog(@"AppleWallet::checkCardEligibility: entry! {cardIdentifier='%@'}", cardIdentifier);
  
    PKPassLibrary *passLibrary = [[PKPassLibrary alloc] init];
//     NSArray<PKPass *> *paymentPasses = [passLibrary passesOfType:PKPassTypePayment];
    NSArray *paymentPasses = [[NSArray alloc] init];
    if (@available(iOS 13.5, *))
    { // PKPassTypePayment is deprecated in iOS13.5
        NSLog(@"AppleWallet::checkCardEligibility: looking for paymentPass... (iOS 13.5 or higher)");
        
        paymentPasses = [passLibrary passesOfType: PKPassTypeSecureElement];
        for (PKPass *pass in paymentPasses)
        {
            PKSecureElementPass *paymentPass = [pass secureElementPass];
            
            NSString* primaryAccountIdentifier = [paymentPass primaryAccountIdentifier];
            NSLog(@"AppleWallet::checkCardEligibility: cardIdentifier check. {identifier='%@'}", primaryAccountIdentifier);
            
            if ([primaryAccountIdentifier isEqualToString:cardIdentifier])
            {
                cardAddedtoPasses = true;
                
                break;
            }
        }
    }
    else
    {
        NSLog(@"AppleWallet::checkCardEligibility: looking for paymentPass... (iOS lower then 13.5)");
        
        paymentPasses = [passLibrary passesOfType: PKPassTypePayment];
        for (PKPass *pass in paymentPasses)
        {
            PKPaymentPass *paymentPass = [pass paymentPass];
            
            NSString* primaryAccountIdentifier = [paymentPass primaryAccountIdentifier];
            NSLog(@"AppleWallet::checkCardEligibility: cardIdentifier check. {identifier='%@'}", primaryAccountIdentifier);
            
            if([primaryAccountIdentifier isEqualToString:cardIdentifier])
            {
                cardAddedtoPasses = true;
                
                break;
            }
        }
    }
    
    NSLog(@"AppleWallet::checkCardEligibility: cardIdentfier check completed. {cardAddedtoPasses=%d}", cardAddedtoPasses);
  
    if (WCSession.isSupported)
    {
        // check if the device support to handle an Apple Watch
        
        WCSession *session = [WCSession defaultSession];
        [session setDelegate:self.appDelegate];
        [session activateSession];
        
        NSLog(@"AppleWallet::checkCardEligibility: WCSession is supported.");
      
        if ([session isPaired])
        {
            // Check if the iPhone is paired with the Apple Watch
            if (@available(iOS 13.5, *))
            {
                NSLog(@"AppleWallet::checkCardEligibility: looking for remote paymentPass... (iOS 13.5 or higher)");
                
                paymentPasses = [passLibrary remoteSecureElementPasses]; // remotePaymentPasses is deprecated in iOS13.5
                for (PKSecureElementPass *pass in paymentPasses)
                {
                    NSString* primaryAccountIdentifier = [pass primaryAccountIdentifier];
                    NSLog(@"AppleWallet::checkCardEligibility: cardIdentifier check (remote). {identifier='%@'}", primaryAccountIdentifier);
                    
                    if ([primaryAccountIdentifier isEqualToString:cardIdentifier])
                    {
                        cardAddedtoPasses = true;
                        
                        break;
                    }
                }
            }
            else
            {
                NSLog(@"AppleWallet::checkCardEligibility: looking for remote paymentPass... (iOS lower than 13.5)");
                
                paymentPasses = [passLibrary remotePaymentPasses];
                for (PKPass *pass in paymentPasses)
                {
                    PKPaymentPass * paymentPass = [pass paymentPass];
                    
                    NSString* primaryAccountIdentifier = [paymentPass primaryAccountIdentifier];
                    NSLog(@"AppleWallet::checkCardEligibility: cardIdentifier check (remote). {identifier='%@'}", primaryAccountIdentifier);
                    
                    if([primaryAccountIdentifier isEqualToString:cardIdentifier])
                    {
                        cardAddedtoRemotePasses = true;
                        
                        break;
                    }
                }
            }
        }
        else
        {
            NSLog(@"AppleWallet::checkCardEligibility: session is not paired!");
            
            cardAddedtoRemotePasses = true;
        }
    }
    else
    {
        NSLog(@"AppleWallet::checkCardEligibility: WCSession NOT supported!");

        cardAddedtoRemotePasses = true;
    }

    cardEligible = !cardAddedtoPasses || !cardAddedtoRemotePasses;

    NSLog(@"AppleWallet::checkCardEligibility: check completed. {cardAddedtoPasses=%d cardAddedtoRemotePasses=%d cardEligible=%d}", cardEligible,cardAddedtoPasses,cardAddedtoRemotePasses);
  
  
    CDVPluginResult *pluginResult;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:cardEligible];
    //pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[passLibrary canAddPaymentPassWithPrimaryAccountIdentifier:cardIdentifier]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Plugin Method - check Card Eligibility By Suffix
- (void) checkCardEligibilityBySuffix:(CDVInvokedUrlCommand*)command
{
	NSLog(@"AppleWallet::checkCardEligibilityBySuffix: entry!");
    
	NSString * cardSuffix = [command.arguments objectAtIndex:0];
    Boolean cardEligible = true;
    Boolean cardAddedtoPasses = false;
    Boolean cardAddedtoRemotePasses = false;
	
	NSLog(@"AppleWallet::checkCardEligibilityBySuffix: {cardSuffix='%@'}!",cardSuffix);
	
 
    PKPassLibrary *passLibrary = [[PKPassLibrary alloc] init];
//     NSArray<PKPass *> *paymentPasses = [passLibrary passesOfType:PKPassTypePayment];
    NSArray *paymentPasses = [[NSArray alloc] init];
    if (@available(iOS 13.5, *)) { // PKPassTypePayment is deprecated in iOS 13.5
      paymentPasses = [passLibrary passesOfType: PKPassTypeSecureElement];
        for (PKPass *pass in paymentPasses) {
            PKSecureElementPass *paymentPass = [pass secureElementPass];
            NSLog(@"AppleWallet::checkCardEligibilityBySuffix: iOS 13.5+ {primaryAccountNumberSuffix='%@'}!",[paymentPass primaryAccountNumberSuffix]);
            if ([[paymentPass primaryAccountNumberSuffix] isEqualToString:cardSuffix]) {
                cardAddedtoPasses = true;
				NSLog(@"AppleWallet::checkCardEligibilityBySuffix: paymentPasses iOS 13.5+ cardAdded true!");
            }
        }
    } else {
      paymentPasses = [passLibrary passesOfType: PKPassTypePayment];
        for (PKPass *pass in paymentPasses) {
          PKPaymentPass * paymentPass = [pass paymentPass];
          NSLog(@"AppleWallet::checkCardEligibilityBySuffix: 13.5- {primaryAccountNumberSuffix='%@'}!",[paymentPass primaryAccountNumberSuffix]);
          if([[paymentPass primaryAccountNumberSuffix] isEqualToString:cardSuffix]) {
            cardAddedtoPasses = true;
			NSLog(@"AppleWallet::checkCardEligibilityBySuffix: paymentPasses iOS 13.5- cardAdded true!");
		  }
        }
    }
   
    if (WCSession.isSupported) { // check if the device support to handle an Apple Watch
        WCSession *session = [WCSession defaultSession];
        [session setDelegate:self.appDelegate];
        [session activateSession];
        
        if ([session isPaired]) { // Check if the iPhone is paired with the Apple Watch
          if (@available(iOS 13.5, *)) { // remotePaymentPasses is deprecated in iOS 13.5
            paymentPasses = [passLibrary remoteSecureElementPasses];
            for (PKSecureElementPass *pass in paymentPasses) {
              NSLog(@"AppleWallet::checkCardEligibilityBySuffix: remote cards iOS 13.5+ {primaryAccountNumberSuffix='%@'}!",[pass primaryAccountNumberSuffix]);
              if ([[pass primaryAccountNumberSuffix] isEqualToString:cardSuffix]) {
                cardAddedtoRemotePasses = true;
				NSLog(@"AppleWallet::checkCardEligibilityBySuffix: paymentPasses remote cards iOS 13.5+ cardAdded true!");
              }
            }
          } else {
            paymentPasses = [passLibrary remotePaymentPasses];
            for (PKPass *pass in paymentPasses) {
              PKPaymentPass * paymentPass = [pass paymentPass];
                    NSLog(@"AppleWallet::checkCardEligibilityBySuffix: remote cards iOS 13.5- {primaryAccountNumberSuffix='%@'}!",[paymentPass primaryAccountNumberSuffix]);
					if([[paymentPass primaryAccountNumberSuffix] isEqualToString:cardSuffix]){
						cardAddedtoRemotePasses = true;
						NSLog(@"AppleWallet::checkCardEligibilityBySuffix: paymentPasses remote cards iOS 13.5- cardAdded true!");
					}
					
                }
            }

        }
        else {
            cardAddedtoRemotePasses = true;
			NSLog(@"AppleWallet::checkCardEligibilityBySuffix: Session is not Paired!");
		}
    }
    else {
        cardAddedtoRemotePasses = true;
		NSLog(@"AppleWallet::checkCardEligibilityBySuffix: WCSession is not Supported!");
	}
    
    cardEligible = !cardAddedtoPasses || !cardAddedtoRemotePasses;	   
    CDVPluginResult *pluginResult;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:cardEligible];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Plugin Method - check paired devices
- (void) checkPairedDevices:(CDVInvokedUrlCommand *)command 
{
    NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] init];
    if (WCSession.isSupported) { // check if the device support to handle an Apple Watch
        WCSession *session = [WCSession defaultSession];
        [session setDelegate:self.appDelegate];
        [session activateSession];
        if (session.isPaired) { // Check if the iPhone is paired with the Apple Watch
            [dictionary setObject:@"True" forKey:@"isWatchPaired"];
        } else {
            [dictionary setObject:@"False" forKey:@"isWatchPaired"];
        }
    } else {
        [dictionary setObject:@"False" forKey:@"isWatchPaired"];
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
    [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Plugin Method - check paired devices By Suffix
- (void) checkPairedDevicesBySuffix:(CDVInvokedUrlCommand *)command 
{
    NSString * suffix = [command.arguments objectAtIndex:0];
    NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] init];
    [dictionary setObject:@"False" forKey:@"isInWallet"];
    [dictionary setObject:@"False" forKey:@"isInWatch"];
    [dictionary setObject:@"" forKey:@"FPANID"];
    PKPassLibrary *passLib = [[PKPassLibrary alloc] init];

    // find if credit/debit card is exist in any pass container e.g. iPad
    for (PKPaymentPass *pass in [passLib passesOfType:PKPassTypePayment]){
        if ([pass.primaryAccountNumberSuffix isEqualToString:suffix]) {
            [dictionary setObject:@"True" forKey:@"isInWallet"];
            [dictionary setObject:pass.primaryAccountIdentifier forKey:@"FPANID"];
            break;
        }
    }
    
    // find if credit/debit card is exist in any remote pass container e.g. iWatch
    for (PKPaymentPass *remotePass in [passLib remotePaymentPasses]){
        if([remotePass.primaryAccountNumberSuffix isEqualToString:suffix]){
            [dictionary setObject:@"True" forKey:@"isInWatch"];
            [dictionary setObject:remotePass.primaryAccountIdentifier forKey:@"FPANID"];
            break;
        }
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
    [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString *) getCardFPAN:(NSString *) cardSuffix{
    
    PKPassLibrary *passLibrary = [[PKPassLibrary alloc] init];
    NSArray<PKPass *> *paymentPasses = [passLibrary passesOfType:PKPassTypePayment];
    for (PKPass *pass in paymentPasses) {
        PKPaymentPass * paymentPass = [pass paymentPass];
        if([[paymentPass primaryAccountNumberSuffix] isEqualToString:cardSuffix])
            return [paymentPass primaryAccountIdentifier];
    }
    
    if (WCSession.isSupported) { // check if the device support to handle an Apple Watch
        WCSession *session = [WCSession defaultSession];
        [session setDelegate:self.appDelegate];
        [session activateSession];
        
        if ([session isPaired]) { // Check if the iPhone is paired with the Apple Watch
            paymentPasses = [passLibrary remotePaymentPasses];
            for (PKPass *pass in paymentPasses) {
                PKPaymentPass * paymentPass = [pass paymentPass];
                if([[paymentPass primaryAccountNumberSuffix] isEqualToString:cardSuffix])
                    return [paymentPass primaryAccountIdentifier];
            }
        }
    }
    
    return nil;
}


- (void) startAddPaymentPass:(CDVInvokedUrlCommand *)command
{
    NSLog(@"AppleWallet::startAddPaymentPass: entry!");
    
    self.isRequestIssued = false;
    
    CDVPluginResult* pluginResult;
    NSArray* arguments = command.arguments;
    
    self.transactionCallbackId = nil;
    self.completionCallbackId = nil;
    
    NSUInteger numberOfArguments = [arguments count];
    
    if (numberOfArguments == 0)
    {
        NSLog(@"AppleWallet::startAddPaymentPass: argument check failure!");
        
        pluginResult =[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"incorrect number of arguments"];
        [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
        NSLog(@"AppleWallet::startAddPaymentPass: error returned!");
        
        return;
    }
    
   
    // Options
    NSDictionary* options = [arguments objectAtIndex:0];
    
    // encryption scheme to be used (RSA_V2 or ECC_V2)
    NSString* scheme = [options objectForKey:@"encryptionScheme"];
    PKEncryptionScheme encryptionScheme = PKEncryptionSchemeRSA_V2;
  
    
    if (scheme == nil)
    {
        NSLog(@"AppleWallet::startAddPaymentPass: scheme not defined!");
    }
    else
    {
        if([[scheme uppercaseString] isEqualToString:@"RSA_V2"])
        {
            NSLog(@"AppleWallet::startAddPaymentPass: RSA V2 scheme identified.");
            
            encryptionScheme = PKEncryptionSchemeRSA_V2;
        }
        else if([[scheme uppercaseString] isEqualToString:@"ECC_V2"])
        {
            NSLog(@"AppleWallet::startAddPaymentPass: ECC V2 scheme identified.");
            
            encryptionScheme = PKEncryptionSchemeECC_V2;
        }
        else
        {
            NSLog(@"AppleWallet::startAddPaymentPass: unknown scheme!");
        }
    }
  
    PKAddPaymentPassRequestConfiguration* configuration = [[PKAddPaymentPassRequestConfiguration alloc] initWithEncryptionScheme:encryptionScheme];
  
    // The name of the person the card is issued to
    configuration.cardholderName = [options objectForKey:@"cardholderName"];
    NSLog(@"AppleWallet::startAddPaymentPass: cardholderName check. {cardholderName='%@'}", configuration.cardholderName);
    
    // Last 4/5 digits of PAN. The last four or five digits of the PAN. Presented to the user with dots prepended to indicate that it is a suffix.
    configuration.primaryAccountSuffix = [options objectForKey:@"primaryAccountSuffix"];
    NSLog(@"AppleWallet::startAddPaymentPass: primaryAccountSuffix check. {primaryAccountSuffix='%@'}", configuration.primaryAccountSuffix);
    
    // A short description of the card.
    configuration.localizedDescription = [options objectForKey:@"localizedDescription"];
    NSLog(@"AppleWallet::startAddPaymentPass: localizedDescription check. {localizedDescription='%@'}", configuration.localizedDescription);
    
    // Filters the device and attached devices that already have this card provisioned. No filter is applied if the parameter is omitted
    configuration.primaryAccountIdentifier = [self getCardFPAN:configuration.primaryAccountSuffix]; //@"V-3018253329239943005544";//@"";
    NSLog(@"AppleWallet::startAddPaymentPass: primaryAccountIdentifier check. {primaryAccountIdentifier='%@'}", configuration.primaryAccountIdentifier);
    
    
    // Filters the networks shown in the introduction view to this single network.
    NSString* paymentNetwork = [options objectForKey:@"paymentNetwork"];
    
    if([[paymentNetwork uppercaseString] isEqualToString:@"VISA"])
    {
        configuration.paymentNetwork = PKPaymentNetworkVisa;
        
        NSLog(@"AppleWallet::startAddPaymentPass: VISA payment network selected.");
    }
    else if([[paymentNetwork uppercaseString] isEqualToString:@"MASTERCARD"])
    {
        configuration.paymentNetwork = PKPaymentNetworkMasterCard;
        
        NSLog(@"AppleWallet::startAddPaymentPass: MASTERCARD payment network selected.");
    }
    else
    {
        NSLog(@"AppleWallet::startAddPaymentPass: unknown payment network! {paymentNetwork='%@'}", paymentNetwork);
    }
    

    // Present view controller
    self.addPaymentPassModal = [[PKAddPaymentPassViewController alloc] initWithRequestConfiguration:configuration delegate:self];
    
    if(!self.addPaymentPassModal)
    {
        NSLog(@"AppleWallet::startAddPaymentPass: PKAddPaymentPassViewController creation failure!");
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Can not init PKAddPaymentPassViewController"];
        [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
        NSLog(@"AppleWallet::startAddPaymentPass: error returned!");
        
        return;
    }
    
    
    NSLog(@"AppleWallet::startAddPaymentPass: opening PKAddPaymentPassViewController...");
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
    self.transactionCallbackId = command.callbackId;
    [self.viewController presentViewController:self.addPaymentPassModal animated:YES completion:^{
        [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
        self.completionCallbackId = command.callbackId;
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.transactionCallbackId];
        
        NSLog(@"AppleWallet::startAddPaymentPass: PKAddPaymentPassViewController completion checkpoint.");
        
    }];
    
    
    NSLog(@"AppleWallet::startAddPaymentPass: exit!");
}
							   

- (void) addPaymentPassViewController:(PKAddPaymentPassViewController *)controller
          didFinishAddingPaymentPass:(PKPaymentPass *)pass
                               error:(NSError *)error
{
    NSLog(@"AppleWallet::addPaymentPassViewController::: entry!");
    
    [controller dismissViewControllerAnimated:YES completion:nil];
    
    NSLog(@"AppleWallet::addPaymentPassViewController::: PKAddPaymentPassViewController dismissed.");
    
    if (error != nil)
    {
        NSLog(@"AppleWallet::addPaymentPassViewController::: error!");
		NSLog(@"AppleWallet::%@",[error localizedDescription]);
        
        self.isRequestIssuedSuccess = NO;
        [self completeAddPaymentPass:nil];
    }
    else
    {
        NSLog(@"AppleWallet::addPaymentPassViewController::: success!");
        
        self.isRequestIssuedSuccess = YES;
        [self completeAddPaymentPass:nil];
    }
}

- (void) addPaymentPassViewController:(PKAddPaymentPassViewController *)controller
 generateRequestWithCertificateChain:(NSArray<NSData *> *)certificates
                               nonce:(NSData *)nonce
                      nonceSignature:(NSData *)nonceSignature
                   completionHandler:(void (^)(PKAddPaymentPassRequest *request))handler
{
    NSLog(@"AppleWallet::addPaymentPassViewController::::: entry!");
    
    // save completion handler
    self.completionHandler = handler;
    
    // the leaf certificate will be the first element of that array and the sub-CA certificate will follow.
    NSString *certificateOfIndexZeroString = [certificates[0] base64EncodedStringWithOptions:0];
    NSString *certificateOfIndexOneString = [certificates[1] base64EncodedStringWithOptions:0];
    NSString *nonceString = [nonce base64EncodedStringWithOptions:0];
    NSString *nonceSignatureString = [nonceSignature base64EncodedStringWithOptions:0];
    
    NSDictionary* dictionary = @{ @"data" :
                                      @{
                                          @"certificateLeaf" : certificateOfIndexZeroString,
                                          @"certificateSubCA" : certificateOfIndexOneString,
                                          @"nonce" : nonceString,
                                          @"nonceSignature" : nonceSignatureString,
                                          }
                                  };
    
    // Upcall with the data
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
    [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.completionCallbackId];
    
    NSLog(@"AppleWallet::addPaymentPassViewController::::: exit!");
}


- (void) completeAddPaymentPass:(CDVInvokedUrlCommand *)command
{
    NSLog(@"AppleWallet::completeAddPaymentPass: entry!");
    
    CDVPluginResult *commandResult;
    
    NSLog(@"AppleWallet::completeAddPaymentPass: commandResult object created");
    
    // Here to return a reasonable message after completeAddPaymentPass callback
    if (self.isRequestIssued == true)
    {
        NSLog(@"AppleWallet::completeAddPaymentPass: request was issued.");
        
        if (self.isRequestIssuedSuccess == false)
        {
            // Upcall with the data error
            commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"error"];
            
            NSLog(@"AppleWallet::completeAddPaymentPass: request issue failure!");
        }
        else
        {
            // Upcall with the data success
            commandResult= [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"success"];
            
            NSLog(@"AppleWallet::completeAddPaymentPass: request issue success!");
        }
        
        [commandResult setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:commandResult callbackId:self.completionCallbackId];
        
        return;
    }
    
    NSLog(@"AppleWallet::completeAddPaymentPass: request not issued.");
    
    // CDVPluginResult* pluginResult;
    NSArray* arguments = command.arguments;
    NSUInteger numberOfArguments = [arguments count];
    if (numberOfArguments == 0)
    {
        // pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"incorrect number of arguments"];
        // [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
        NSLog(@"AppleWallet::startAddPaymentPass: exit due to an incorrect number of arguments!");
        
        return;
    }
    
    
    PKAddPaymentPassRequest* request = [[PKAddPaymentPassRequest alloc] init];
    NSDictionary* options = [arguments objectAtIndex:0];
    
    NSString* activationData = [options objectForKey:@"activationData"];
    NSString* encryptedPassData = [options objectForKey:@"encryptedPassData"];
    NSString* wrappedKey = [options objectForKey:@"wrappedKey"];
    NSString* ephemeralPublicKey = [options objectForKey:@"ephemeralPublicKey"];
    
	request.activationData = [[NSData alloc] initWithBase64EncodedString:activationData options:0];
	NSLog(@"AppleWallet::completeAddPaymentPass:activationData=%@", activationData);
	
    request.encryptedPassData = [[NSData alloc] initWithBase64EncodedString:encryptedPassData options:0];
	NSLog(@"AppleWallet::completeAddPaymentPass:encryptedPassData=%@", encryptedPassData);
	
    if (wrappedKey)
    {
        request.wrappedKey = [[NSData alloc] initWithBase64EncodedString:wrappedKey options:0];
		NSLog(@"AppleWallet::completeAddPaymentPass:wrappedKey=%@", wrappedKey);
    }
    if (ephemeralPublicKey)
    {
        request.ephemeralPublicKey = [[NSData alloc] initWithBase64EncodedString:ephemeralPublicKey options:0];
		NSLog(@"AppleWallet::completeAddPaymentPass:ephemeralPublicKey=%@", ephemeralPublicKey);
    }
    
	if (self.completionHandler)
	{
		NSLog(@"AppleWallet::completeAddPaymentPass: calling completion handler...{callbackId='%@'}", command.callbackId);
    
		// Issue request
		self.completionHandler(request);
		self.completionCallbackId = command.callbackId;
		self.isRequestIssued = true;
	}
    NSLog(@"AppleWallet::completeAddPaymentPass: exit.");
}


- (NSData *)HexToNSData:(NSString *)hexString
{
    hexString = [hexString stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData *commandToSend= [[NSMutableData alloc] init];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    int i;
    for (i=0; i < [hexString length]/2; i++) {
        byte_chars[0] = [hexString characterAtIndex:i*2];
        byte_chars[1] = [hexString characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [commandToSend appendBytes:&whole_byte length:1];
    }
    NSLog(@"%@", commandToSend);
    return commandToSend;
}

@end

// in this case, it is handling if it found 2 watches (more than 1 remote device) 
// means if the credit/debit card is exist on more than 1 remote devices, iPad, iWatch etc

// -(void)eligibilityAddingToWallet2:(CDVInvokedUrlCommand*)command{
//     NSArray* arguments = command.arguments;
//     NSDictionary* options = [arguments objectAtIndex:0];
//     NSString* suffix = [options objectForKey:@"primaryAccountSuffix"];
//     NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] init];
//     [dictionary setObject:@"False" forKey:@"Wallet"];
//     [dictionary setObject:@"False" forKey:@"Watch"];
    
//     PKPaymentPass *currentPass;
    
//     PKPassLibrary *passLib = [[PKPassLibrary alloc] init];
//     for (PKPaymentPass *pass in [passLib passesOfType:PKPassTypePayment]){
//         if ([pass.primaryAccountNumberSuffix isEqualToString:suffix]) {
//             currentPass = pass;
//             break;
//         }
//     }
    
//     for (PKPaymentPass *remotePass in [passLib remotePaymentPasses]){
//         if([remotePass.primaryAccountNumberSuffix isEqualToString:suffix]){
//             currentPass = remotePass;
//             break;
//         }
//     }
    
//     if (currentPass != nil){
//         [passLib canAddPaymentPassWithPrimaryAccountIdentifier:currentPass.primaryAccountIdentifier];
//     }
    
//     CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
//     [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
//     [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
// }
