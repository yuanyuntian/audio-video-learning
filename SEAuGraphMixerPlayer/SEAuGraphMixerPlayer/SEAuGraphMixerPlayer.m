//
//  SEAUGraphPlayer.m
//  SEAUGraph
//
//  Created by yuan on 2019/1/30.
//  Copyright © 2019年 sunEEE. All rights reserved.
//

#import "SEAuGraphMixerPlayer.h"
#import "SEAVAudioSession.h"

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
    
    
    
    CFURLRef _sourceURL[2];
    
    SoundBuffer mSoundBuffer[MAXBUFS];
    
    AVAudioFormat *mAudioFormat;
    
    SEAVAudioSession * _session;//音频硬件环境
}
@end

@implementation SEAuGraphMixerPlayer

static OSStatus renderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
    SoundBufferPtr sndbuf = (SoundBufferPtr)inRefCon;
    
    UInt32 sample = sndbuf[inBusNumber].sampleNum;// frame number to start from
    UInt32 bufSamples = sndbuf[inBusNumber].numFrames;// total number of frames in the sound buffer
    Float32 * in = sndbuf[inBusNumber].data;    //audio data buffer
    
    Float32 * outA = (Float32 *)ioData->mBuffers[0].mData;// output audio buffer for L channel
    Float32 *outB = (Float32 *)ioData->mBuffers[1].mData; // output audio buffer for R channel
    
    // for demonstration purposes we've configured 2 stereo input busses for the mixer unit
    // but only provide a single channel of data from each input bus when asked and silence for the other channel
    // alternating as appropriate when asked to render bus 0 or bus 1's input
    
    for (UInt32 i = 0; i < inBusNumber; ++i) {
        if (inBusNumber == 1) {
            outA[i] = 0;
            outB[i] = in[sample++];
        }else{
            outA[i] = in[sample++];
            outB[i] = 0;
        }
        
        if (sample > bufSamples) {
            // start over from the beginning of the data, our audio simply loops
            printf("looping data for bus %d after %ld source frames rendered\n", (unsigned int)inBusNumber, (long)sample-1);
            sample = 0;
        }
    }
    sndbuf[inBusNumber].sampleNum = sample; // keep track of where we are in the source data buffer
    return noErr;
}

-(instancetype)init{
    if (self = [super init]) {
        
        _session = [SEAVAudioSession new];
        [_session setActive:YES];
        
        
        _isPlaying = false;
        
        // clear the mSoundBuffer struct
        memset(&mSoundBuffer, 0, sizeof(mSoundBuffer));
        
        // create the URLs we'll use for source A and B
        NSString *sourceA = [[NSBundle mainBundle] pathForResource:@"遇见" ofType:@"mp3"];
        NSString *sourceB = [[NSBundle mainBundle] pathForResource:@"可惜没如果" ofType:@"wav"];
        _sourceURL[0] = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)sourceA, kCFURLPOSIXPathStyle, false);
        _sourceURL[1] = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)sourceB, kCFURLPOSIXPathStyle, false);
        
        [self initAUGraph];
    }
    return self;
}

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
    //output unit
    AudioComponentDescription output_desc;
    bzero(&output_desc, sizeof(output_desc));
    output_desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    output_desc.componentType = kAudioUnitType_Output;
    output_desc.componentSubType = kAudioUnitSubType_RemoteIO;
    output_desc.componentFlags = 0;
    output_desc.componentFlagsMask = 0;
    
    // multichannel mixer unit
    AudioComponentDescription mixer_desc;
    bzero(&mixer_desc, sizeof(mixer_desc));
    mixer_desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixer_desc.componentType = kAudioUnitType_Mixer;
    mixer_desc.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixer_desc.componentFlags = 0;
    mixer_desc.componentFlagsMask = 0;
    
    printf("new nodes\n");
    // create a node in the graph that is an AudioUnit, using the supplied AudioComponentDescription to find and open that unit
    result = AUGraphAddNode(_Graph, &output_desc, &outputNode);
    if (result) { printf("AUGraphNewNode 1 result %ld %4.4s\n", (long)result, (char*)&result); return; }
    
    result = AUGraphAddNode(_Graph, &mixer_desc, &mixerNode );
    if (result) { printf("AUGraphNewNode 2 result %ld %4.4s\n", (long)result, (char*)&result); return; }
    
    // connect a node's output to a node's input
    result = AUGraphConnectNodeInput(_Graph, mixerNode, 0, outputNode, 0);
    if (result) { printf("AUGraphConnectNodeInput result %ld %4.4s\n", (long)result, (char*)&result); return; }
    
    // open the graph AudioUnits are open but not initialized (no resource allocation occurs here)
    result = AUGraphOpen(_Graph);
    if (result) { printf("AUGraphOpen result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    
    result = AUGraphNodeInfo(_Graph, mixerNode, NULL, &_Mixer);
    if (result) { printf("AUGraphNodeInfo result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    
    result = AUGraphNodeInfo(_Graph, outputNode, NULL, &_Output);
    if (result) { printf("AUGraphNodeInfo result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    
    // set bus count
    UInt32 numbuses = 2;
    
    printf("set input bus count %u\n", (unsigned int)numbuses);
    result = AudioUnitSetProperty(_Mixer, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses));
    if (result) { printf("AudioUnitSetProperty result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    
    
    for (int  i = 0; i < numbuses; i++) {
        // setup render callback struct
        AURenderCallbackStruct rcbs;
        rcbs.inputProc = &renderInput;
        rcbs.inputProcRefCon = mSoundBuffer;
        printf("set kAudioUnitProperty_SetRenderCallback for mixer input bus %d\n", i);
        // Set a callback for the specified node's specified input
        result = AUGraphSetNodeInputCallback(_Graph, mixerNode, i, &rcbs);
        if (result) { printf("AUGraphSetNodeInputCallback result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
        
        // set input stream format to what we want
        printf("set mixer input kAudioUnitProperty_StreamFormat for bus %d\n", i);
        
        result = AudioUnitSetProperty(_Mixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, mAudioFormat.streamDescription, sizeof(AudioStreamBasicDescription));
        if (result) { 
            printf("AudioUnitSetProperty result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); 
            return; 
        }
    }
    // set output stream format to what we want
    printf("set output kAudioUnitProperty_StreamFormat\n");
    
    result = AudioUnitSetProperty(_Mixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, mAudioFormat.streamDescription, sizeof(AudioStreamBasicDescription));
    if (result) { printf("AudioUnitSetProperty result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    
    result = AudioUnitSetProperty(_Output, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, mAudioFormat.streamDescription, sizeof(AudioStreamBasicDescription));
    if (result) { printf("AudioUnitSetProperty result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    
    printf("AUGraphInitialize\n");
    
    // now that we've set everything up we can initialize the graph, this will also validate the connections
    result = AUGraphInitialize(_Graph);
    if (result) { printf("AUGraphInitialize result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    
    CAShow(_Graph);
    
}

-(void)loadFiles{
    AVAudioFormat * clientFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:kGraphSampleRate channels:1 interleaved:YES];
    
    for (int i = 0; i < NUMFILES && i < MAXBUFS; i++) {
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


- (void)dealloc
{    
    [_session setActive:NO];

    printf("MultichannelMixerController dealloc\n");
    
    DisposeAUGraph(_Graph);
    
    free(mSoundBuffer[0].data);
    free(mSoundBuffer[1].data);
    
    CFRelease(_sourceURL[0]);
    CFRelease(_sourceURL[1]);
}

@end
