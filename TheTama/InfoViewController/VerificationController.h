//
//	Important note about In-App Purchase Receipt Validation on iOS
//
//	If your app uses In-App Purchase on iOS 5.1 and earlier, you should review new documentation about 
//	In-App Purchase Receipt Validation on iOS. This will help ensure that your app is not vulnerable to
//	potential fraudulent In-App Purchases.
//
#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>


#define IS_IOS6_AWARE (__IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1)

#define ITMS_PROD_VERIFY_RECEIPT_URL        @"https://buy.itunes.apple.com/verifyReceipt"
#define ITMS_SANDBOX_VERIFY_RECEIPT_URL     @"https://sandbox.itunes.apple.com/verifyReceipt";

#define KNOWN_TRANSACTIONS_KEY              @"knownIAPTransactions"

//#define ITC_CONTENT_PROVIDER_SHARED_SECRET  @"062e76976c5a468a82bda70683326208"	//Condition

//char* base64_encode(const void* buf, size_t size);
void * base64_decode(const char* s, size_t * data_len);
BOOL checkReceiptSecurity(NSString *purchase_info_string, NSString *signature_string, CFDateRef purchaseDate);


@interface VerificationController : NSObject 
{
@private
	id										mDelegate;
    NSMutableDictionary		*transactionsReceiptStorageDictionary;
}

+ (VerificationController *) sharedInstance;

// Checking the results of this is not enough.
// The final verification happens in the connection:didReceiveData: callback within
// this class.  So ensure IAP feaures are unlocked from there.
- (BOOL)verifyPurchase:(SKPaymentTransaction *)transaction
					sharedSecret:(NSString*)sharedSecret
							target:(id)target;

@end

@protocol VerificationControllerDelegate <NSObject>
#pragma mark - <VerificationControllerDelegate>
- (void)verificationResult:(BOOL)result;
@end

