#import "IPARLoginScreenViewController.h"
#import "IPARRootViewController.h"
#import "IPARUtils.h"

#define sha256verification @"22b9b697f865d25a702561e47a4748ade2675de6e26ad3a9ca2a607e66b0144b"

@interface IPARLoginScreenViewController ()
@property (nonatomic) IBOutlet UITextField *emailTextField;
@property (nonatomic) IBOutlet UITextField *passwordTextField;
@property (nonatomic) UIButton *loginButton;
@property (nonatomic, strong) NSMutableArray *linesStandardOutput;
@property (nonatomic, strong) NSMutableArray *linesErrorOutput;
@end

@implementation IPARLoginScreenViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _linesStandardOutput = [NSMutableArray array];
    _linesErrorOutput = [NSMutableArray array];
    [self setLoginButtons];
    [self basicSanityChecks];
    [self.view addSubview:_emailTextField];
    [self.view addSubview:_passwordTextField];
    [self.view addSubview:_loginButton];
}

- (void)setLoginButtons {
    // Create email text field
    self.emailTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, 280, 40)];
    self.emailTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.emailTextField.placeholder = @"Email";
    self.emailTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.emailTextField.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailTextField.returnKeyType = UIReturnKeyDone;
    self.emailTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.emailTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;

    // Create password text field
    self.passwordTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 150, 280, 40)];
    self.passwordTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.passwordTextField.placeholder = @"Password";
    self.passwordTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.passwordTextField.keyboardType = UIKeyboardTypeDefault;
    self.passwordTextField.returnKeyType = UIReturnKeyDone;
    self.passwordTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.passwordTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.passwordTextField.secureTextEntry = YES;

    // Create login button
    self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.loginButton setTitle:@"Login" forState:UIControlStateNormal];
    self.loginButton.frame = CGRectMake(20, 200, 280, 40);
    [self.loginButton addTarget:self action:@selector(handleLoginEmailPass) forControlEvents:UIControlEventTouchUpInside];
}

- (void)basicSanityChecks {
    NSString *s = [IPARUtils sha256ForFileAtPath:IPATOOL_SCRIPT_PATH];
    AlertActionBlock alertBlock = ^(void) {
        exit(0);
    };
    if (s == nil) {
        [IPARUtils presentErrorWithTitle:@"Critical Error" message:@"ipatool file was not found inside resources directory!" numberOfActions:1 buttonText:@"Exit IPARanger" alertBlock:alertBlock presentOn:self];
    } else if (![s isEqualToString:sha256verification]) {
        [IPARUtils presentErrorWithTitle:@"Critical Error" message:@"Could not verify the integrity of files" numberOfActions:1 buttonText:@"Exit IPARanger" alertBlock:alertBlock presentOn:self];
    }
    NSLog(@"omriku ipatool binary was found. all good!");
}

- (void)handleLoginEmailPass {
    NSString *commandToExecute = [NSString stringWithFormat:@"%@ auth login -e %@ -p %@", IPATOOL_SCRIPT_PATH, self.emailTextField.text, self.passwordTextField.text];
    NSDictionary *standardAndErrorOutputs = [IPARUtils setupTaskAndPipesWithCommand:commandToExecute];
    self.linesStandardOutput = standardAndErrorOutputs[@"standardOutput"];
    self.linesErrorOutput = standardAndErrorOutputs[@"errorOutput"];

    if ([self checkIfUserPassedAuthentication] == NO) {
        for (id obj in self.linesErrorOutput) {
            NSLog(@"omriku line error :%@", obj);
            if ([obj containsString:@"2FA"]) {
                [self handle2FADialog];
            } else {
                if ([obj containsString:@"Missing value for"]) {
                    [IPARUtils presentErrorWithTitle:@"Critical Error" message:@"Please fill both your Apple ID Email and Password" numberOfActions:1 buttonText:@"OK" alertBlock:nil presentOn:self];
                }
                //do we actually can get error here? dont think so.. need to check.
                //handle errors.. we are expecting to see only 2fa errors here. if not, present them!
            }
        }
    }
}

- (void)handle2FADialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Continue with 2FA" message:@"Please enter 2FA you got from Apple" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // Retrieve the text entered in the text field
        UITextField *textField = alert.textFields.firstObject;
        NSString *twoFAResponse = textField.text;
        [self handle2FALogic:twoFAResponse];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Enter your 2FA you got from Apple here";
    }];

    [alert addAction:okAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)handle2FALogic:(NSString *)twoFARes {
    NSString *commandToExecute = [NSString stringWithFormat:@"%@ auth login -e %@ -p %@%@", IPATOOL_SCRIPT_PATH, self.emailTextField.text, self.passwordTextField.text, twoFARes];
    NSDictionary *standardAndErrorOutputs = [IPARUtils setupTaskAndPipesWithCommand:commandToExecute];
    self.linesStandardOutput = standardAndErrorOutputs[@"standardOutput"];
    self.linesErrorOutput = standardAndErrorOutputs[@"errorOutput"];

    if ([self checkIfUserPassedAuthentication] == NO) {
        for (id obj in self.linesErrorOutput) {
            NSLog(@"omriku line error :%@", obj);
            if ([obj containsString:@"An unknown error has occurred"]) {
                [IPARUtils presentErrorWithTitle:@"Critical Error" message:@"Couldn't log you in, Something is wrong with your credentials.\nPlease try again" numberOfActions:1 buttonText:@"Try Again" alertBlock:nil presentOn:self];
            }
        }
    }
}

- (BOOL)checkIfUserPassedAuthentication {
    for (id obj in self.linesStandardOutput) {
        NSLog(@"omriku line output :%@", obj);
        if ([obj containsString:@"Authenticated as"]) {
            [self writeAuthToFile];
            return YES;
        }
    }
    return NO;
}

- (void)writeAuthToFile {
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    settings[@"Authenticated"] = @YES;
    settings[@"AccountEmail"] = self.emailTextField.text;
    settings[@"lastLoginDate"] = [NSDate date];
    [settings writeToFile:IPARANGER_SETTINGS_DICT atomically:YES];
    IPARRootViewController *mainVC = [[IPARRootViewController alloc] init];
    [self.navigationController pushViewController:mainVC animated:YES];
}
@end