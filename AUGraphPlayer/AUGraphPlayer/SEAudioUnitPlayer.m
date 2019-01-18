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
    
    AudioUnit   _PlayerUnit;
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

-(void)setupAudioUnitInfo{
    
    AudioComponentDescription outputUinitDesc;
    bzero(&outputUinitDesc, sizeof(outputUinitDesc));
    outputUinitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputUinitDesc.componentType = kAudioUnitType_Output;
    outputUinitDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    outputUinitDesc.componentFlags = 0;
    outputUinitDesc.componentFlagsMask = 0;
    AudioComponent outComponent = AudioComponentFindNext(NULL, &outputUinitDesc); 
    OSStatus status = AudioComponentInstanceNew(outComponent, &_PlayerUnit);  
    checkStatus(status, @"set Player Unit faile...", YES);
    
    //给AudioUnit设置参数
    AudioStreamBasicDescription pcmStreamDesc;
    UInt32 bytesPerSample = sizeof(Float32);
    bzero(&pcmStreamDesc, sizeof(pcmStreamDesc));
    pcmStreamDesc.mFormatID          = kAudioFormatLinearPCM;//指定音频格式
    //mFormatFlagsa表示格式：FloatPacked表示格式是float
    //NonInterleaved表示音频存储的的AudioBufferList中的mBuffer[0]是左声道 mBuffer[1]是又声道 非交错存放
    //如果使用Interleaved 左右声道数据交错存放在mBuffer[0]中
    pcmStreamDesc.mFormatFlags       = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;//
    pcmStreamDesc.mFramesPerPacket   = 1;
    pcmStreamDesc.mBytesPerFrame     = bytesPerSample;
    pcmStreamDesc.mChannelsPerFrame  = 2;                    // 2 indicates stereo
    //mBitsPerChannel和mBytesPerPacket的赋值 需要看mFormatFlags 如果是NonInterleaved 就赋值 bytesPerSample
    //如果是Interleaved 则需要bytesPerSample * Channels
    pcmStreamDesc.mBitsPerChannel    = 8 * bytesPerSample;//一个声道的音频数据用多少位来表示 float类型
    pcmStreamDesc.mBytesPerPacket    = bytesPerSample;
    pcmStreamDesc.mSampleRate        = 44100;
    status = AudioUnitSetProperty(_PlayerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &pcmStreamDesc, sizeof(pcmStreamDesc));  
    checkStatus(status, @"set Player Unit StreamFormat faile...", YES);

    
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

void checkStatus(OSStatus status, NSString * message, BOOL fatal){
    if (status != noErr) {
        char fourC[16];
        *(UInt32*)fourC = CFSwapInt32HostToBig(status);
        fourC[4] = '\0';
        
        if(isprint(fourC[0]) && isprint(fourC[1]) && isprint(fourC[2]) && isprint(fourC[3])){
            NSLog(@"%@: %s", message, fourC);
        }else{
            NSLog(@"%@: %d", message, (int)status);
        }
        if(fatal)exit(-1);
    }
}

@end
