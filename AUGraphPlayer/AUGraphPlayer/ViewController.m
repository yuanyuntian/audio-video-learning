//
//  ViewController.m
//  AUGraphPlayer
//
//  Created by yuan on 2019/1/17.
//  Copyright © 2019年 sunEEE. All rights reserved.
//

#import "ViewController.h"
#import "AUGraphPlayer.h"
#import "SEAudioUnitPlayer.h"

#import "AudioUnitPlayer.h"
@interface ViewController ()
{
    AUGraphPlayer * _player;
    
    SEAudioUnitPlayer * _unitPlayer;
    
    AudioUnitPlayer * _testPlayer;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSString* filePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"test2.wav"];

//    _player = [[AUGraphPlayer alloc] initWithFilePath:filePath];
    _unitPlayer = [[SEAudioUnitPlayer alloc] initWithFilePath:filePath];
    
//    _testPlayer = [[AudioUnitPlayer alloc] init];
//    [_testPlayer open:filePath];
}

- (IBAction)startAction:(id)sender {
    [_unitPlayer play];
//    [_testPlayer play:YES];
}
- (IBAction)pauseAction:(id)sender {
    [_unitPlayer pause];
//    [_testPlayer stop];

}
- (IBAction)stopAction:(id)sender {
    [_unitPlayer stop];
}

@end
