//
//  AUGraphPlayer.m
//  AUGraphPlayer
//
//  Created by yuan on 2019/1/17.
//  Copyright © 2019年 sunEEE. All rights reserved.
//

#import "AUGraphPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>


@interface AUGraphPlayer()
{
    AUGraph  _playerGraph;
    AUNode      _PlayerNode;
    AudioUnit   _PlayerUnit;

    AVAudioSession * _session;//音频硬件环境
    
    NSString * _path;//资源路径
}
@end

@implementation AUGraphPlayer

- (instancetype)initWithFilePath:(NSString *)path{
    self = [super init];
    if (self) {
        _path = path;
        [self setupAudioSession];
        [self initComponent];
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

#pragma -mark 初始化音频组件
-(void)initComponent{
    OSStatus status = noErr;
    //1:构造AUGraph
    status = NewAUGraph(&_playerGraph);
    checkStatus(status, @"Could not create a new AUGraph", YES);
    //添加IONode
    AudioComponentDescription ioDescription;
    bzero(&ioDescription, sizeof(ioDescription));
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioDescription.componentType = kAudioUnitType_Output;
    ioDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    
    status = AUGraphAddNode(_playerGraph, &ioDescription, &_PlayerNode);
    
    
    //打开Graph, 只有真正的打开了Graph才会实例化每一个Node
    status = AUGraphOpen(_playerGraph);
    checkStatus(status, @"Could not open AUGraph", YES);
    //获取出PlayerNode的AudioUnit
    status = AUGraphNodeInfo(_playerGraph, _PlayerNode, NULL, &_PlayerUnit);
    
    //给AudioUnit设置参数
    AudioStreamBasicDescription stereoStreamFormat;
    UInt32 bytesPerSample = sizeof(Float32);
    bzero(&stereoStreamFormat, sizeof(stereoStreamFormat));
    stereoStreamFormat.mFormatID          = kAudioFormatLinearPCM;//指定音频格式
    //mFormatFlagsa表示格式：FloatPacked表示格式是float
    //NonInterleaved表示音频存储的的AudioBufferList中的mBuffer[0]是左声道 mBuffer[1]是又声道 非交错存放
    //如果使用Interleaved 左右声道数据交错存放在mBuffer[0]中
    stereoStreamFormat.mFormatFlags       = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;//
    stereoStreamFormat.mFramesPerPacket   = 1;
    stereoStreamFormat.mBytesPerFrame     = bytesPerSample;
    stereoStreamFormat.mChannelsPerFrame  = 2;                    // 2 indicates stereo
    //mBitsPerChannel和mBytesPerPacket的赋值 需要看mFormatFlags 如果是NonInterleaved 就赋值 bytesPerSample
    //如果是Interleaved 则需要bytesPerSample * Channels
    stereoStreamFormat.mBitsPerChannel    = 8 * bytesPerSample;//一个声道的音频数据用多少位来表示 float类型
    stereoStreamFormat.mBytesPerPacket    = bytesPerSample;
    stereoStreamFormat.mSampleRate        = 44100;
    status = AudioUnitSetProperty(_PlayerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  &stereoStreamFormat,
                                  sizeof (stereoStreamFormat)
                                  );
    [self prepareFileload];
}

-(void)prepareFileload{
    OSStatus status = noErr;
    AudioFileID musicFile;
    CFURLRef songURL = (__bridge  CFURLRef) [NSURL fileURLWithPath:_path];
    // open the input audio file
    status = AudioFileOpenURL(songURL, kAudioFileReadPermission, 0, &musicFile);
    checkStatus(status, @"Open AudioFile... ", YES);
    
    
    // tell the file player unit to load the file we want to play
    status = AudioUnitSetProperty(_PlayerUnit, kAudioUnitProperty_ScheduledFileIDs,
                                  kAudioUnitScope_Global, 0, &musicFile, sizeof(musicFile));
    checkStatus(status, @"Tell AudioFile Player Unit Load Which File... ", YES);
    
    
    
    AudioStreamBasicDescription fileASBD;
    // get the audio data format from the file
    UInt32 propSize = sizeof(fileASBD);
    status = AudioFileGetProperty(musicFile, kAudioFilePropertyDataFormat,
                                  &propSize, &fileASBD);
    checkStatus(status, @"get the audio data format from the file... ", YES);
    UInt64 nPackets;
    UInt32 propsize = sizeof(nPackets);
    AudioFileGetProperty(musicFile, kAudioFilePropertyAudioDataPacketCount,
                         &propsize, &nPackets);
    // tell the file player AU to play the entire file
    ScheduledAudioFileRegion rgn;
    memset (&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    rgn.mTimeStamp.mSampleTime = 0;
    rgn.mCompletionProc = NULL;
    rgn.mCompletionProcUserData = NULL;
    rgn.mAudioFile = musicFile;
    rgn.mLoopCount = 0;
    rgn.mStartFrame = 0;
    rgn.mFramesToPlay = (UInt32)nPackets * fileASBD.mFramesPerPacket;
    status = AudioUnitSetProperty(_PlayerUnit, kAudioUnitProperty_ScheduledFileRegion,
                                  kAudioUnitScope_Global, 0,&rgn, sizeof(rgn));
    checkStatus(status, @"Set Region... ", YES);
    
    
    // prime the file player AU with default values
    UInt32 defaultVal = 0;
    status = AudioUnitSetProperty(_PlayerUnit, kAudioUnitProperty_ScheduledFilePrime,
                                  kAudioUnitScope_Global, 0, &defaultVal, sizeof(defaultVal));
    checkStatus(status, @"Prime Player Unit With Default Value... ", YES);
    
    
    // tell the file player AU when to start playing (-1 sample time means next render cycle)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    status = AudioUnitSetProperty(_PlayerUnit, kAudioUnitProperty_ScheduleStartTimeStamp,
                                  kAudioUnitScope_Global, 0, &startTime, sizeof(startTime));
    checkStatus(status, @"set Player Unit Start Time... ", YES);
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



//停止
-(void)stop{
    Boolean isRunning = false;
    OSStatus status = AUGraphIsRunning(_playerGraph, &isRunning);
    if (isRunning) {
        status = AUGraphStop(_playerGraph);
        checkStatus(status, @"Could not stop AUGraph", YES);
    }
}

//播放
-(void)play{
    OSStatus status = AUGraphStart(_playerGraph);
    checkStatus(status, @"Could not start AUGraph", YES);
}

//暂停
-(void)pause{
    
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
