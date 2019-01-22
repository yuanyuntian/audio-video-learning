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
#import "SEAVAudioSession.h"

@interface SEAudioUnitPlayer()
{
    SEAVAudioSession * _session;//音频硬件环境
    NSString * _path;//资源路径
    
    AudioUnit   _PlayerUnit;
    
    UInt64 _packetCount;//包个数
    
    UInt32 *_audioData;
    
    UInt32 _packetIndex;
    
    UInt32 _durating;
    
//    Float64 _sampleRate;//当前设备的采样率
    
    AudioConverterRef _converter;
    
    AudioStreamBasicDescription _sourceFormat;
    
    AudioStreamPacketDescription * _outPacketDescriptions;
}
@property(nonatomic,weak)id<SEAudioPlayerDelegate>delegate;
@end

@implementation SEAudioUnitPlayer


static AudioStreamBasicDescription PCMStreamDescription()
{
    //给AudioUnit设置参数
    AudioStreamBasicDescription pcmStreamDesc;
    UInt32 bytesPerSample = sizeof(SInt16);
    bzero(&pcmStreamDesc, sizeof(pcmStreamDesc));
    pcmStreamDesc.mFormatID          = kAudioFormatLinearPCM;//指定音频格式
    //mFormatFlagsa表示格式：FloatPacked表示格式是float
    //NonInterleaved表示音频存储的的AudioBufferList中的mBuffer[0]是左声道 mBuffer[1]是又声道 非交错存放
    //如果使用Interleaved 左右声道数据交错存放在mBuffer[0]中
    pcmStreamDesc.mFormatFlags       = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;//
    pcmStreamDesc.mFramesPerPacket   = 1;
    pcmStreamDesc.mChannelsPerFrame  = 2;// 通道为2 ->SInt16 ，     通道为1 ->UInt32               
    // 2 indicates stereo
    pcmStreamDesc.mBytesPerFrame     = bytesPerSample * pcmStreamDesc.mChannelsPerFrame ;
    //mBitsPerChannel和mBytesPerPacket的赋值 需要看mFormatFlags 如果是NonInterleaved 就赋值 bytesPerSample
    //如果是Interleaved 则需要bytesPerSample * Channels
    pcmStreamDesc.mBitsPerChannel    = 8 * bytesPerSample;//一个声道的音频数据用多少位来表示 SInt16
    pcmStreamDesc.mBytesPerPacket    = bytesPerSample * pcmStreamDesc.mChannelsPerFrame;
    pcmStreamDesc.mSampleRate        = 44100;
    return pcmStreamDesc;
}


OSStatus ConverterDataRenderCallback(AudioConverterRef inAudioConverter,UInt32 * ioNumberDataPackets,AudioBufferList *  ioData,AudioStreamPacketDescription * __nullable * __nullable outDataPacketDescription,void * __nullable inUserData)
{
    SEAudioUnitPlayer* self = (__bridge SEAudioUnitPlayer *)inUserData;
    if (self->_packetIndex >= self->_packetCount) {
        NSLog(@"No Data");
        return 'bxmo';
    }
    
    for (int i=0; i < ioData->mNumberBuffers; i++)
    {
        AudioBuffer buffer = ioData->mBuffers[i];
        UInt32 *frameBuffer = buffer.mData;
        for (int index = 0; index < *ioNumberDataPackets; index++)
        {
            frameBuffer[index] = [self getNextPacket];
        }
    }
//    static AudioStreamPacketDescription aspdesc;
//    aspdesc.mDataByteSize = (UInt32)packet.length;
//    aspdesc.mStartOffset = 0;
//    aspdesc.mVariableFramesInPacket = 1;
    *outDataPacketDescription = self->_outPacketDescriptions;
//    self->_readedPacketIndex++;
    return 0;
}


OSStatus renderCallback(void                            *inRefCon,
                      AudioUnitRenderActionFlags      *ioActionFlags,
                      const AudioTimeStamp            *inTimeStamp,
                      UInt32                          inBusNumber,
                      UInt32                          inNumberFrames,
                      AudioBufferList                 *ioData){
//    printf("play::%u,",(unsigned int)inNumberFrames);
////    printf("play::%p,",ioData);
//    printf("play::%u,",(unsigned int)ioData->mNumberBuffers);
//    printf("inBusNumber::%u,",(unsigned int)inBusNumber);
    
    SEAudioUnitPlayer* self = (__bridge SEAudioUnitPlayer *)inRefCon;

    @synchronized (self) {
        if (self->_packetIndex < self->_packetCount) {
            
            UInt32 packetSize = inNumberFrames;
//            OSStatus status = AudioConverterFillComplexBuffer(self->_converter, ConverterDataRenderCallback, (__bridge void *)self, &packetSize, ioData, NULL);
            
            
            /*
            AudioBuffer buffer = ioData->mBuffers[0];
            UInt32 *frameBuffer = buffer.mData;
            for (int index = 0; index < inNumberFrames; index++){

                frameBuffer[index] = [self getNextPacket];
            }
             */
            
            for (int i=0; i < ioData->mNumberBuffers; i++)
            {
                AudioBuffer buffer = ioData->mBuffers[i];
                UInt32 *frameBuffer = buffer.mData;
                for (int index = 0; index < inNumberFrames; index++)
                {
                    frameBuffer[index] = [self getNextPacket];
                }
            }
            NSInteger n = (self->_packetIndex/(float)(self->_packetCount)) * self->_durating;
            if (self.delegate) {
                [self.delegate didPlayingGetcurrentTime:n];
            }
        }else{
            [self stop];
            return  -1;
        }
    }

    /*
     UInt32 sizeIn = sizeof(AudioStreamBasicDescription);
     AudioStreamBasicDescription audioFormatIn;
     AudioUnitGetProperty(this -> _audioUnit,
     kAudioUnitProperty_StreamFormat,
     kAudioUnitScope_Input,
     0,
     &audioFormatIn,
     &sizeIn);
     UInt32 sizeOut = sizeof(AudioStreamBasicDescription);
     AudioStreamBasicDescription audioFormatOut;
     AudioUnitGetProperty(this -> _audioUnit,
     kAudioUnitProperty_StreamFormat,
     kAudioUnitScope_Output,
     0,
     &audioFormatOut,
     &sizeOut);
     */
    
    return noErr;
}

-(void)seekPacketIndex:(UInt32)index{
    _packetIndex = index;
}

//资源路径
- (instancetype)initWithFilePath:(NSString *)path delegete:(id)delegate{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        _path = path;
        _packetIndex = 0;
        [self setupAudioSession];
        [self readPacketsOffile:path];
        [self setupAudioUnitInfo];
    }
    return self;
}

-(void)readPacketsOffile:(NSString *)path{
    
    [self getfileInfo:path];
    AudioFileID fileID = nil;

    CFURLRef audioFileUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    
    OSStatus result = AudioFileOpenURL(audioFileUrl, kAudioFileReadPermission, 0, &fileID);
    SECheckStatus(result, @"open audio file failed ...", YES);
    
    UInt32 datasize = sizeof(UInt64);
    result = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataPacketCount, &datasize, &_packetCount);
    SECheckStatus(result, @"获取音频镇失败 ...", YES);
    
    AudioStreamBasicDescription format;
    UInt32 formatDatasize = sizeof(AudioStreamBasicDescription);
    result = AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &formatDatasize, &format);
    SECheckStatus(result, @"获取音频镇失败 ...", YES);
    _sourceFormat = format;
//    UInt32 time = sizeof(UInt32);
//    result = AudioFileGetPropertyInfo(fileID, kAudioFilePropertyEstimatedDuration, &time, &_durating);
//    SECheckStatus(result, @"获取时间失败 ...", YES);
    

    NSDictionary*piDict =nil;
    UInt32 piDataSize   =sizeof(piDict );
    result= AudioFileGetProperty(fileID,kAudioFilePropertyInfoDictionary,&piDataSize,&piDict);
    if(result !=noErr ){
        NSLog(@"AudioFileGetProperty failed for property info dictionary");
    }
    
    CFDataRef AlbumPic=nil;
    UInt32 picDataSize =sizeof(picDataSize);
    result=AudioFileGetProperty(fileID,  kAudioFilePropertyAlbumArtwork,&picDataSize,&AlbumPic);
    if(result !=noErr ){
        NSLog(@"Get picture failed");
    }

    if (_packetCount > 0) {
         UInt32 packetRead = (UInt32)_packetCount;
         _audioData=(UInt32 *)malloc(sizeof(UInt32)*packetRead);
         UInt32 numBytesRead=-1;
        
        UInt32 descSize = sizeof(AudioStreamPacketDescription) * packetRead;
        AudioStreamPacketDescription * outPacketDescriptions = (AudioStreamPacketDescription *)malloc(descSize);
        
        result =AudioFileReadPacketData(fileID, false, &numBytesRead, outPacketDescriptions, 0, &packetRead, _audioData);
//         result = AudioFileReadPackets(fileID, false, &numBytesRead, NULL, 0, &packetRead, _audioData);
        SECheckStatus(result, @"ReadPacketData faile...", YES);
        _outPacketDescriptions = outPacketDescriptions;
        //print out general info about  the file
        NSLog(@"Packets read from file: %u\n", (unsigned int)packetRead);
        NSLog(@"Bytes read from file: %u\n", (unsigned int)numBytesRead);
        //for a stereo 32 bit per sample file this is ok
        NSLog(@"Sample count: %u\n", numBytesRead / 2);
        //for a 32bit per stereo sample at 44100khz this is correct
        NSLog(@"Time in Seconds: %f.4\n", ((float)numBytesRead / 4.0) / 44100.0);

    }
    
}

-(void)getfileInfo:(NSString *)fileUrl{
    AVURLAsset* audioAsset =[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:fileUrl] options:nil];
    //时间
    CMTime duration= audioAsset.duration;
    int seconds =(int)CMTimeGetSeconds(duration);//总时间
    self->_durating =  seconds;
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didGetFileInfo:@{@"duration":[NSString stringWithFormat:@"%d", seconds]}];
        });
    }
}

//配置音频硬件环境
-(void)setupAudioSession{
    _session = [SEAVAudioSession new];
    [_session setActive:YES];

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
    memset(&outputUinitDesc, 0, sizeof(AudioComponentDescription));

//    bzero(&outputUinitDesc, sizeof(AudioComponentDescription));
    outputUinitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputUinitDesc.componentType = kAudioUnitType_Output;
    outputUinitDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    outputUinitDesc.componentFlags = 0;
    outputUinitDesc.componentFlagsMask = 0;
    AudioComponent outComponent = AudioComponentFindNext(NULL, &outputUinitDesc); 
    OSStatus status = AudioComponentInstanceNew(outComponent, &_PlayerUnit);  
    SECheckStatus(status, @"set Player Unit faile...", YES);
    
    //给AudioUnit设置参数
    AudioStreamBasicDescription pcmStreamDesc = PCMStreamDescription();
    status = AudioConverterNew(&self->_sourceFormat, &pcmStreamDesc, &self->_converter);
    SECheckStatus(status, @"create converter failed...", YES);

    status = AudioUnitSetProperty(_PlayerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &pcmStreamDesc, sizeof(pcmStreamDesc));  
    SECheckStatus(status, @"set Player Unit StreamFormat faile...", YES);

    //Add a callback for playing
    AURenderCallbackStruct renderStruct;
    renderStruct.inputProc = renderCallback;
    renderStruct.inputProcRefCon = (void *)CFBridgingRetain(self);
    
    AudioUnitSetProperty(_PlayerUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderStruct, sizeof(renderStruct));
    AudioUnitInitialize(_PlayerUnit);
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

#pragma mark ======== 获取下一个packet API ========

-(UInt32)getNextPacket
{
    UInt32 returnValue = 0;
    if (_packetIndex >= _packetCount)
    {
        _packetIndex = 0;
    }
    returnValue = _audioData[_packetIndex++];
//    NSLog(@"...%llu", self->_packetIndex/self->_packetCount );
//    if (self.delegate) {
////        [self.delegate didPlayingGetcurrentTime:self->_packetIndex/self->_packetIndex * self->_durating];
//    }
    return returnValue;
}



#pragma -mark 停止
-(void)stop{
    OSStatus status = AudioOutputUnitStop(_PlayerUnit);
    assert(status == noErr);
}

#pragma -mark播放
-(void)play{
    NSLog(@"******%d", _packetIndex);
    OSStatus status = AudioOutputUnitStart(_PlayerUnit);
    assert(status == noErr);
}

#pragma -mark暂停
-(void)pause{
    OSStatus status = AudioOutputUnitStop(_PlayerUnit);
    assert(status == noErr);
    NSLog(@"&&&&%d", _packetIndex);
    _packetIndex = 10000000;
}

void SECheckStatus(OSStatus status, NSString * message, BOOL fatal){
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

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
