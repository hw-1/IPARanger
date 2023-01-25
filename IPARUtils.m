#import "IPARUtils.h"

@implementation IPARUtils
+ (NSString *)sha256ForFileAtPath:(NSString *)filePath {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    if (handle == nil) {
        NSLog(@"File %@ not found", filePath);
        return nil;
    }

    CC_SHA256_CTX sha256;
    CC_SHA256_Init(&sha256);

    BOOL done = NO;
    while (!done) {
        NSData *fileData = [handle readDataOfLength:256];
        CC_SHA256_Update(&sha256, [fileData bytes], (CC_LONG)[fileData length]);
        if ([fileData length] == 0) {
            done = YES;
        }
    }

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &sha256);

    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];

    for(int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];

    return output;
}

+ (void)presentErrorWithTitle:(NSString *)title 
                      message:(NSString *)message 
                      numberOfActions:(NSUInteger)numberOfActions 
                      buttonText:(NSString *)buttonText 
                      alertBlock:(AlertActionBlock)block 
                      presentOn:(id)viewController {

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:buttonText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (block != nil) {
            block();
        }
    }];
    [alert addAction:okAction];
    if (numberOfActions > 1) {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
    }

    [viewController presentViewController:alert animated:YES completion:nil];
}

+ (NSDictionary<NSString*,NSArray*> *)setupTaskAndPipesWithCommand:(NSString *)command {
    NSLog(@"omriku running command.. %@", command);
    NSTask *task = [[NSTask alloc] init];
    NSMutableArray *args = [NSMutableArray array];
    [args addObject:@"-c"];
    [args addObject:command];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:args];
    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    [task setStandardError:errorPipe];
    [task setStandardOutput:outputPipe];
    [task launch];

    NSData *outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
    NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

    NSData *errorData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
    NSString *errorOutput = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];

    NSLog(@"omriku ran command with args: %@ %@",task.launchPath, [task.arguments componentsJoinedByString:@" "]);
    NSArray *standardOutputArray = [outputString componentsSeparatedByCharactersInSet:
                                            [NSCharacterSet newlineCharacterSet]];

    NSArray *errorOutputArray = [errorOutput componentsSeparatedByCharactersInSet:
                                            [NSCharacterSet newlineCharacterSet]];

    return @{@"standardOutput": standardOutputArray, @"errorOutput": errorOutputArray};
}
@end
