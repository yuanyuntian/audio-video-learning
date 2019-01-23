//
//  ViewController.m
//  AUGraphPlayer
//
//  Created by yuan on 2019/1/17.
//  Copyright © 2019年 sunEEE. All rights reserved.
//

#import "ViewController.h"

#import "SEAudioUnitPlayer.h"

@interface ViewController ()
{
    SEAudioUnitPlayer * _unitPlayer;
    
    __weak IBOutlet UILabel *timeL;
    __weak IBOutlet UILabel *currenttime;
    __weak IBOutlet UISlider *slide;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSString* filePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"可惜没如果.wav"];

//    _player = [[AUGraphPlayer alloc] initWithFilePath:filePath];
    _unitPlayer = [[SEAudioUnitPlayer alloc] initWithFilePath:filePath delegete:self];
    
//    _testPlayer = [[AudioUnitPlayer alloc] init];
//    [_testPlayer open:filePath];
}

- (IBAction)seekAction:(id)sender {
    UISlider * s = (UISlider*)sender;
    [_unitPlayer seekPacketIndex:s.value];
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

-(void)didPlayingGetcurrentTime:(NSInteger)seconds{
    dispatch_async(dispatch_get_main_queue(), ^{
        self->currenttime.text = [NSString stringWithFormat:@"%ld", (long)seconds];
//        self->slide.value = seconds;
    });
}

-(void)didGetFileInfo:(NSDictionary *)info{
    NSString * timeStr = info[@"duration"];
    timeL.text = timeStr;
    slide.maximumValue = [timeStr integerValue];
    slide.minimumValue = 0;
}

@end
