//
//  ViewController.m
//  SEAUGraph
//
//  Created by yuan on 2019/1/24.
//  Copyright © 2019年 sunEEE. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>


@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)enableInput:(id)sender {
    UISwitch * v = (UISwitch *)sender;
    UInt32 inputNum = (UInt32)[v tag];
    AudioUnitParameterValue value = v.isOn;
}

- (IBAction)setInputVolume:(id)sender {
}
- (IBAction)setOutputVolume:(id)sender {
}

@end
