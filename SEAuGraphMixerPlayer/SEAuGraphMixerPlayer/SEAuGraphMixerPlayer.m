//
//  SEAUGraphPlayer.m
//  SEAUGraph
//
//  Created by yuan on 2019/1/30.
//  Copyright © 2019年 sunEEE. All rights reserved.
//

#import "SEAuGraphMixerPlayer.h"

const Float64 kGraphSampleRate = 44100.0; // 48000.0 optional tests
#define MAXBUFS  2
#define NUMFILES 2

typedef struct {
    AudioStreamBasicDescription asbd;
    Float32 *data;
    UInt32 numFrames;
    UInt32 sampleNum;
} SoundBuffer, *SoundBufferPtr;


@interface SEAuGraphMixerPlayer()
{
    AUGraph   _Graph;
    AudioUnit _Mixer;
    AudioUnit _Output;
    
    BOOL _isPlaying;
    
    CFURLRef _sourceURL[2];
    
    SoundBuffer mSoundBuffer[MAXBUFS];
    
    AVAudioFormat *mAudioFormat;
    
}
@end

@implementation SEAuGraphMixerPlayer

-(void)initAUGraph{
    printf("initialize\n");
    
    AUNode outputNode;
    AUNode mixerNode;
    
    // this is the format for the graph
    mAudioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                    sampleRate:kGraphSampleRate
                                                      channels:2
                                                   interleaved:NO];
    
    OSStatus result = noErr;
    
    // load up the audio data
    [self performSelectorInBackground:@selector(loadFiles) withObject:nil];
    
    // create a new AUGraph
    result = NewAUGraph(&_Graph);
    if (result) { printf("NewAUGraph result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    
    // create two AudioComponentDescriptions for the AUs we want in the graph
    
}

-(void)loadFiles{
    AVAudioFormat * clientFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:kGraphSampleRate channels:2 interleaved:YES];
    
    for (int i = 0; i < NUMFILES; i++) {
        printf("loadFiles, %d\n", i);
        ExtAudioFileRef fileID = 0;
        //open one of the two source files
        OSStatus result = ExtAudioFileOpenURL(_sourceURL[i], &fileID);
        if (result || !fileID) { printf("ExtAudioFileOpenURL result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); break; }
        
        // get the file data format, this represents the file's actual data format
        AudioStreamBasicDescription fileFormat;
        UInt32 propSize = sizeof(fileFormat);
        result = ExtAudioFileGetProperty(fileID, kExtAudioFileProperty_FileDataFormat, &propSize, &fileFormat);
        if (result) { printf("ExtAudioFileGetProperty kExtAudioFileProperty_FileDataFormat result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); break; }
        
        // set the client format - this is the format we want back from ExtAudioFile and corresponds to the format
        // we will be providing to the input callback of the mixer, therefore the data type must be the same
        
        // used to account for any sample rate conversion
        double rateRatio = kGraphSampleRate / fileFormat.mSampleRate;
        propSize = sizeof(AudioStreamBasicDescription);
        //设置这个属性，才能进行对非pcm格式的文件进行编解码，这个格式也是ExtAudioFileRead 和 ExtAudioFileWrite 时的格式
        result = ExtAudioFileSetProperty(fileID, kExtAudioFileProperty_ClientDataFormat, propSize, clientFormat.streamDescription);
        if (result) { printf("ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); break; }
        
        // get the file's length in sample frames
        UInt64 numFrames = 0;
        propSize = sizeof(numFrames);
        result = ExtAudioFileGetProperty(fileID, kExtAudioFileProperty_FileLengthFrames, &propSize, &numFrames);
        if (result) { printf("ExtAudioFileGetProperty kExtAudioFileProperty_FileLengthFrames result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); break; }
        printf("File %d, Number of Sample Frames: %u\n", i, (unsigned int)numFrames);
        
        // account for any sample rate conversion
        numFrames = (numFrames * rateRatio); 
        printf("File %d, Number of Sample Frames after rate conversion (if any): %u\n", i, (unsigned int)numFrames);
        
        // set up our buffer
        mSoundBuffer[i].numFrames = (UInt32)numFrames;
        mSoundBuffer[i].asbd = *(clientFormat.streamDescription);
        
        UInt32 samples = (UInt32)numFrames * mSoundBuffer[i].asbd.mChannelsPerFrame;
        mSoundBuffer[i].data = (Float32 *)calloc(samples, sizeof(Float32));
        mSoundBuffer[i].sampleNum = 0;
        
        // set up a AudioBufferList to read data into
        AudioBufferList bufList;
        bufList.mNumberBuffers = 1;
        bufList.mBuffers[0].mNumberChannels = 1;
        bufList.mBuffers[0].mData = mSoundBuffer[i].data;
        bufList.mBuffers[0].mDataByteSize = samples * sizeof(Float32);
        
        // perform a synchronous sequential read of the audio data out of the file into our allocated data buffer
        UInt32 numPackets = (UInt32)numFrames;
        result = ExtAudioFileRead(fileID, &numPackets, &bufList);
        if (result) {
            printf("ExtAudioFileRead result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result);
            free(mSoundBuffer[i].data);
            mSoundBuffer[i].data = 0;
        }
        // close the file and dispose the ExtAudioFileRef
        ExtAudioFileDispose(fileID);
    }
}

//播放
-(void)play{
    printf("PLAY\n");
    OSStatus result = AUGraphStart(_Graph);
    if (result) { printf("AUGraphStart result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    _isPlaying = true;
}


//停止
-(void)stop{
    printf("STOP\n");
    Boolean isRunning = false;
    OSStatus result =AUGraphIsRunning(_Graph, &isRunning);
    if (result) { printf("AUGraphIsRunning result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    //    kAudioOutputUnitProperty_IsRunning
    if (isRunning) {
        result = AUGraphStop(_Graph);
        if (result) { printf("AUGraphStop result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
        _isPlaying = false;
    }
}


// enable or disables a specific bus
- (void)enableInput:(UInt32)inputNum isOn:(BOOL)value{
    AudioUnitParameterValue isOn = value;
    printf("BUS %d isON %d\n", (unsigned int)inputNum, value);
    OSStatus result = AudioUnitSetParameter(_Mixer, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, inputNum, isOn, 0);
    if (result) {
        printf("AudioUnitSetParameter kMultiChannelMixerParam_Enable result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); 
        return;
        
    }
}

// sets the input volume for a specific bus
- (void)setInputVolume:(UInt32)inputNum value:(float)value{
    AudioUnitParameterValue v = value;
    OSStatus result = AudioUnitSetParameter(_Mixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, inputNum, v, 0);
    if (result) { 
        printf("AudioUnitSetParameter kMultiChannelMixerParam_Volume Input result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result);
        return; 
    }
}

- (void)setOutputVolume:(float)value{
    AudioUnitParameterValue v = value;
    OSStatus result = AudioUnitSetParameter(_Mixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, v, 0);
    if (result) { printf("AudioUnitSetParameter kMultiChannelMixerParam_Volume Output result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
}
@end
