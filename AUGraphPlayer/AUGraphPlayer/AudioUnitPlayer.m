//
//  AudioUnitPlayer.m
//  AudioUnitPlayer
//
//  Created by Sajiv Nair on 02/07/15.
//  Copyright (c) 2015 intelliswift. All rights reserved.
//

#import "AudioUnitPlayer.h"
#import <AudioToolbox/AudioSession.h>
#import <AudioUnit/AUComponent.h>
#import <AudioUnit/AudioUnitProperties.h>
#import <AudioUnit/AudioOutputUnit.h>

@implementation AudioUnitPlayer

OSStatus playCallback(void                            *inRefCon,
                      AudioUnitRenderActionFlags      *ioActionFlags,
                      const AudioTimeStamp            *inTimeStamp,
                      UInt32                          inBusNumber,
                      UInt32                          inNumberFrames,
                      AudioBufferList                 *ioData){
    
    AudioUnitPlayer* this = (__bridge AudioUnitPlayer *)inRefCon;
    
    for (int i=0; i < ioData->mNumberBuffers; i++)
    {
        AudioBuffer buffer = ioData->mBuffers[i];
        UInt32 *frameBuffer = buffer.mData;
        for (int index = 0; index < inNumberFrames; index++)
        {
            frameBuffer[index] = [this->inMemoryAudioFile getNextPacket:this->loop];
        }
    }
    
//    UInt32 *frameBuffer = ioData->mBuffers[0].mData;
//    UInt32 count=inNumberFrames;
//    for (int j = 0; j < count; j++){
//        frameBuffer[j] = [this->inMemoryAudioFile getNextPacket:this->loop];
//    }
    
    return noErr;
}

static void CheckError(OSStatus error,const char *operaton){
    if (error==noErr) {
        return;
    }
    char errorString[20]={};
    *(UInt32 *)(errorString+1)=CFSwapInt32HostToBig(error);
    if (isprint(errorString[1])&&isprint(errorString[2])&&isprint(errorString[3])&&isprint(errorString[4])) {
        errorString[0]=errorString[5]='\'';
        errorString[6]='\0';
    }else{
        sprintf(errorString, "%d",(int)error);
    }
    fprintf(stderr, "Error:%s (%s)\n",operaton,errorString);
    exit(1);
}

void audioRouteChangeListener(  void                      *inClientData,
                                AudioSessionPropertyID    inID,
                                UInt32                    inDataSize,
                                const void                *inData) {
    printf("audioRouteChangeListener");
}

void audioInterruptionListener(void *inClientData,UInt32 inInterruptionState){
    switch (inInterruptionState) {
        case kAudioSessionBeginInterruption:
            break;
        case kAudioSessionEndInterruption:
            break;
        default:
            break;
    }
}

-(void)configAudio {
    //Upon launch, the application automatically gets a singleton audio session.
    //Initialize a session and registering an interruption callback
    CheckError(AudioSessionInitialize(NULL, kCFRunLoopDefaultMode, audioInterruptionListener, (__bridge void *)(self)), "couldn't initialize the audio session");
    
    //Add a AudioRouteChange listener
    CheckError(AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioRouteChangeListener, (__bridge void *)(self)),"couldn't add a route change listener");
    
    //Is there an audio input device available
    UInt32 inputAvailable;
    UInt32 propSize=sizeof(inputAvailable);
    CheckError(AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &propSize, &inputAvailable), "not available for the current input audio device");
    if (!inputAvailable) {
        return;
    }
    
    //Adjust audio hardware I/O buffer duration.If I/O latency is critical in your app, you can request a smaller duration.
    Float32 ioBufferDuration = .005;
    CheckError(AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(ioBufferDuration), &ioBufferDuration),"couldn't set the buffer duration on the audio session");
    
    //Set the audio category
    UInt32 audioCategory = kAudioSessionCategory_PlayAndRecord;
    CheckError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory), "couldn't set the category on the audio session");
    
    UInt32 override=true;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, sizeof(override), &override);
    
    //Get hardware sample rate and setting the audio format
    Float64 sampleRate;
    UInt32 sampleRateSize=sizeof(sampleRate);
    CheckError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &sampleRateSize, &sampleRate),                                      "Couldn't get hardware samplerate");
    mAudioFormat.mSampleRate         = sampleRate;
    mAudioFormat.mFormatID           = kAudioFormatLinearPCM; //kAudioFormatMPEG4AAC
    mAudioFormat.mFormatFlags        = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;  // kMPEG4Object_AAC_Main
    mAudioFormat.mFramesPerPacket    = 1;
    mAudioFormat.mChannelsPerFrame   = kChannels;
    mAudioFormat.mBitsPerChannel     = 16;
    mAudioFormat.mBytesPerFrame      = mAudioFormat.mBitsPerChannel*mAudioFormat.mChannelsPerFrame/8;
    mAudioFormat.mBytesPerPacket     = mAudioFormat.mBytesPerFrame*mAudioFormat.mFramesPerPacket;
    mAudioFormat.mReserved           = 0;
    
    //Obtain a RemoteIO unit instance
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_RemoteIO;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &acd);
    CheckError(AudioComponentInstanceNew(inputComponent, &mAudioUnit), "Couldn't new AudioComponent instance");
    
    //The Remote I/O unit, by default, has output enabled and input disabled
    //Enable input scope of input bus for recording.
    UInt32 enable = 1;
    UInt32 disable=0;
    CheckError(AudioUnitSetProperty(mAudioUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input,
                                    kInputBus,
                                    &enable,
                                    sizeof(enable)),
                                    "kAudioOutputUnitProperty_EnableIO::kAudioUnitScope_Input::kInputBus");
    
    //Applying format to input scope of output bus for playing
    CheckError(AudioUnitSetProperty(mAudioUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    kOutputBus,
                                    &mAudioFormat,
                                    sizeof(mAudioFormat)),
                                    "kAudioUnitProperty_StreamFormat::kAudioUnitScope_Input::kOutputBus");
    
    //AudioUnitInitialize
    CheckError(AudioUnitInitialize(mAudioUnit), "AudioUnitInitialize");
}


- (id)init
{
    [self configAudio];
    
    //Add a callback for playing
    AURenderCallbackStruct playStruct;
    playStruct.inputProc=playCallback;
    playStruct.inputProcRefCon=(__bridge void *)(self);
    CheckError(AudioUnitSetProperty(mAudioUnit,
                                    kAudioUnitProperty_SetRenderCallback,
                                    kAudioUnitScope_Input,
                                    kOutputBus,
                                    &playStruct,
                                    sizeof(playStruct)),
                                    "kAudioUnitProperty_SetRenderCallback::kAudioUnitScope_Input::kOutputBus");

    inMemoryAudioFile = [[InMemoryAudioFile alloc] init];
    return self;
}

-(void)open:(NSString *)filePath {
    [inMemoryAudioFile open:filePath];
}

-(void)play:(BOOL) isLooping {
    loop = isLooping;
    AudioOutputUnitStart(mAudioUnit);
    
}

-(void)stop {
    AudioOutputUnitStop(mAudioUnit);
}

@end


