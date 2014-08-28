//
//  DDImageUploader.m
//  Duoduo
//
//  Created by 独嘉 on 14-3-30.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDImageUploader.h"
#import "AFHTTPClient.h"
#import "AIImageAdditions.h"
#import "AFHTTPRequestOperation.h"
#import "NSImage+Addition.h"

static int max_try_upload_times = 5;

@implementation DDImageUploader
{
}
+ (instancetype)instance
{
    static DDImageUploader* g_imageUploader;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_imageUploader = [[DDImageUploader alloc] init];
    });
    max_try_upload_times = 5;
    return g_imageUploader;
}

- (void)uploadImage:(NSImage*)image success:(void(^)(NSString* imageURL))success failure:(void(^)(id error))failure
{
    NSURL *url = [NSURL URLWithString:@"http://upload.mogujie.com"];
    
    AFHTTPClient *httpClient = [[AFHTTPClient alloc] initWithBaseURL:url];
//    NSData *imageData = [image bestRepresentationByType];
    NSData *imageData = [image imageDataCompressionFactor:1.0];
    NSDictionary *params =[NSDictionary dictionaryWithObjectsAndKeys:@"im_image",@"type", nil];
    NSMutableURLRequest *request = [httpClient multipartFormRequestWithMethod:@"POST" path:@"/upload/addpic/" parameters:params constructingBodyWithBlock: ^(id <AFMultipartFormData>formData) {
        [formData appendPartWithFileData:imageData name:@"image" fileName:@"icon.png" mimeType:@"image/jpeg"];
    }];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [operation setRedirectResponseBlock:^NSURLRequest *(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *redirectResponse) {
        if (redirectResponse &&  [redirectResponse class]==[NSHTTPURLResponse class]) {
            NSInteger statusCode = [(NSHTTPURLResponse *)redirectResponse statusCode];
            if (statusCode >= 300 && statusCode <=307) {
                NSDictionary *allHeaderFields = [(NSHTTPURLResponse *)redirectResponse allHeaderFields];
                NSString *location = [allHeaderFields  objectForKey:@"Location"];
                NSString *imageURL = [DDImageUploader imageUrl:location];
                NSMutableString *url = [NSMutableString stringWithFormat:@"%@",@"&$#@~^@[{:"];
                if (!imageURL)
                {
                    max_try_upload_times --;
                    if (max_try_upload_times > 0)
                    {
                        [self uploadImage:image success:^(NSString *imageURL) {
                            success(imageURL);
                        } failure:^(id error) {
                            failure(error);
                        }];
                    }
                    else
                    {
                        failure(nil);
                    }
                    return nil;
                }
                [url appendString:imageURL];
                [url appendString:@":}]&$~@#@"];
                success(url);
                return nil;
            }
            else
            {
                failure(nil);
            }
        }
        return request;
    }];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        failure(@"异常");
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSDictionary* userInfo = error.userInfo;
        NSHTTPURLResponse* response = userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
        NSInteger stateCode = response.statusCode;
        if (!(stateCode >= 300 && stateCode <=307))
        {
            failure(@"断网");
        }
    }];
    [operation start];
}

+ (NSString *)imageUrl:(NSString *)content{
    //NSRange *range = [*content rangeOfString:@"path="];
    NSRange range = [content rangeOfString:@"path="];
    NSString* url = nil;
    //    url = [content substringFromIndex:range.location+range.length];
    
    if ([content length] > range.location + range.length)
    {
        url = [content substringFromIndex:range.location+range.length];
    }
    url = [(NSString *)url stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    url = [url stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return url;
}

@end
