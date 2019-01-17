//
//  SEAudioUnitPlayer.m
//  AUGraphPlayer
//
//  Created by yuan on 2019/1/17.
//  Copyright © 2019年 sunEEE. All rights reserved.
//

#import "SEAudioUnitPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>


@interface SEAudioUnitPlayer()
{
    AVAudioSession * _session;//音频硬件环境
    NSString * _path;//资源路径
}
@end

@implementation SEAudioUnitPlayer


//资源路径
- (instancetype)initWithFilePath:(NSString *)path{
    self = [super init];
    if (self) {
        _path = path;
        [self setupAudioSession];
    }
    return self;
}

//配置音频硬件环境
-(void)setupAudioSession{
    _session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    if (![_session setCategory:AVAudioSessionCategoryPlayback
                   withOptions:AVAudioSessionCategoryOptionMixWithOthers
                         error:&error]) {
        NSLog(@" set category failed on audio session ! :%@",error.localizedDescription);
    }
    
    //设置参照采样率
    if (![_session setPreferredSampleRate:44100 error:&error]) {
        NSLog(@"error when setPreferredSampleRate on audio session :%@ ",error.localizedDescription);
    }
    
    //激活会话
    if (![_session setActive:YES error:&error]) {
        NSLog(@"error when setActive on audio session :%@ ",error.localizedDescription);
    }
    
    //监听RouteChange事件
    [[NSNotificationCenter defaultCenter] addObserver:self     
                                             selector:@selector(onNotificationAudioRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    
    //添加打断监听（电话）
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioInterrupted:) name:AVAudioSessionInterruptionNotification
                                               object:nil];
}

#pragma mark ——— notification observer
- (void)onNotificationAudioRouteChange:(NSNotification *)sender{
    NSDictionary * info = sender.userInfo;
    AVAudioSessionRouteChangeReason reason = [info[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    //旧音频设备断开
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        //获取上一线路描述信息并获取上一线路的输出设备类型
        AVAudioSessionRouteDescription *previousRoute = info[AVAudioSessionRouteChangePreviousRouteKey];
        AVAudioSessionPortDescription *previousOutput = previousRoute.outputs[0];
        NSString *portType = previousOutput.portType;
        if ([portType isEqualToString:AVAudioSessionPortHeadphones]) {
            //在这里暂停播放
        }
    }
}

//监听打电话，自动暂停或者播放
- (void)onNotificationAudioInterrupted:(NSNotification *)sender{
    AVAudioSessionInterruptionType interruptionType = [[[sender userInfo]
                                                        objectForKey:AVAudioSessionInterruptionTypeKey]
                                                       unsignedIntegerValue];
    switch (interruptionType) {
        case AVAudioSessionInterruptionTypeBegan:
            [self stop];
            break;
        case AVAudioSessionInterruptionTypeEnded:
            [self play];
        default:
            break;
    }
}


#pragma -mark 停止
-(void)stop{
    
}

#pragma -mark播放
-(void)play{
    
}

#pragma -mark暂停
-(void)pause{
    
}

@end
