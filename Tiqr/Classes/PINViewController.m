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

#import "PINViewController.h"
#import "ErrorController.h"
#import "NSString+Verhoeff.h"

@interface PINViewController ()

@property (nonatomic, strong) ErrorController *errorController;
@property (nonatomic, strong) IBOutlet UIButton *confirmButton;
@property (strong, nonatomic) IBOutlet UILabel *notesLabel;
@property (nonatomic, strong) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, strong) IBOutlet UILabel *descriptionLabel;

@property (nonatomic, strong) IBOutlet UIButton *okButton;
@property (weak, nonatomic) IBOutlet UITextField *pinTextField;
@property (weak, nonatomic) IBOutlet UIStackView *pinViewsStackView;

@end


@implementation PINViewController

- (instancetype)init {
    self = [super initWithNibName:@"PINView" bundle:nil];
    if (self != nil) {
        self.errorController = [[ErrorController alloc] init];
    }
    return self;
}

- (NSString *)subtitle {
    return self.subtitleLabel.text;
}

- (void)setSubtitle:(NSString *)subtitle {
    self.subtitleLabel.text = subtitle;
}

- (NSString *)pinDescription {
    return self.descriptionLabel.text;
}

- (void)setPinDescription:(NSString *)description {
    self.descriptionLabel.text = description;
}

- (NSString *)pinNotes {
    return self.descriptionLabel.text;
}

- (void)setPinNotes:(NSString *)notes {
    self.notesLabel.text = notes;
    self.notesLabel.hidden = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.confirmButton setTitle:NSLocalizedString(@"ok_button", @"OK Button") forState:UIControlStateNormal];

    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.errorController.view.hidden = YES;
    [self.errorController addToView:self.view];

    for (UIView *view in self.pinViewsStackView.arrangedSubviews) {
        view.layer.borderColor = UIColor.grayColor.CGColor;
        view.layer.borderWidth = 1.0f;
    }

    NSMutableDictionary *attrs = [self.pinTextField.defaultTextAttributes mutableCopy];
    [attrs addEntriesFromDictionary:@{
        NSKernAttributeName: @46,
        NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:28 weight:UIFontWeightMedium]
    }];
    self.pinTextField.defaultTextAttributes = attrs;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    [textField setUserInteractionEnabled:NO];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [textField setUserInteractionEnabled:YES];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *text = [self.pinTextField.text stringByReplacingCharactersInRange:range withString:string];
    if ([text length] > 4) {
        return NO;
    }

    self.okButton.enabled = [text length] == 4;
    return YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];    
 
    [self clear];
    [self.pinTextField becomeFirstResponder];
}

- (IBAction)ok {
    [self dismissViewControllerAnimated:YES completion:nil];
    NSString *pin = self.pinTextField.text;
    [self.delegate PINViewController:self didFinishWithPIN:pin];
}

- (void)showErrorWithTitle:(NSString *)title message:(NSString *)message {
    self.errorController.title = title;
    self.errorController.message = message;
    self.errorController.view.hidden = NO;
    [self.view endEditing:YES];
}

- (void)clear {
    self.pinTextField.text = @"";
    self.okButton.enabled = YES;
}

@end
