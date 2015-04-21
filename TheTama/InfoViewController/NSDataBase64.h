//
//  NSDataBase64.h
//  OpenCode
//
//

#import <Foundation/Foundation.h>

@class NSString; 

@interface NSData (Base64)

// Base64にエンコードした文字列を生成する
- (NSString *)stringEncodedWithBase64;
// Base64文字列をデコードし、NSDataオブジェクトを生成する(NSStringより)
+ (NSData *)dataWithBase64String:(NSString *)pstrBase64;

@end