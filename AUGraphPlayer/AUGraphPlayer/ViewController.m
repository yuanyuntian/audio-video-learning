//
//  ViewController.m
//  AUGraphPlayer
//
//  Created by yuan on 2019/1/17.
//  Copyright © 2019年 sunEEE. All rights reserved.
//

#import "ViewController.h"
#import "AUGraphPlayer.h"
@interface ViewController ()
{
    AUGraphPlayer * _player;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSString* filePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"遇见.mp3"];

    _player = [[AUGraphPlayer alloc] initWithFilePath:filePath];
}

- (IBAction)startAction:(id)sender {
    [_player play];
}
- (IBAction)pauseAction:(id)sender {
    [_player pause];
}
- (IBAction)stopAction:(id)sender {
    [_player stop];
}

@end
