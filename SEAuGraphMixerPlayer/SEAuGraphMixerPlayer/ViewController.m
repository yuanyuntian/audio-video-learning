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
#import "SEAuGraphMixerPlayer.h"

@interface ViewController ()
{
    SEAuGraphMixerPlayer * _player;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _player = [[SEAuGraphMixerPlayer alloc] init];
}
- (IBAction)playAction:(id)sender {
    if (_player.isPlaying) {
        [_player stop];
    }else{
        [_player play];
    }
}

- (IBAction)enableInput:(id)sender {
    UISwitch * v = (UISwitch *)sender;
    UInt32 inputNum = (UInt32)[v tag];
    [_player enableInput:inputNum isOn:v.isOn];
}

- (IBAction)setInputVolume:(id)sender {
    UISlider * v = (UISlider *)sender;
    UInt32 inputNum = (UInt32)[v tag];
    [_player setInputVolume:v.value value:inputNum];
}
- (IBAction)setOutputVolume:(id)sender {
    UISlider * v = (UISlider *)sender;
    [_player setOutputVolume:v.value];
}

@end
