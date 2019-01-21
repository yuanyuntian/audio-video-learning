//
//  AudioUnitPlayer.h
//  AudioUnitPlayer
//
//  Created by Sajiv Nair on 02/07/15.
//  Copyright (c) 2015 intelliswift. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioFile.h>
#import <AudioUnit/AudioComponent.h>
#include <sys/time.h>

#import "InMemoryAudioFile.h"

#define kChannels   2
#define kOutputBus  0
#define kInputBus   1

@interface AudioUnitPlayer : NSObject {
    BOOL                        loop;
    AudioComponentInstance      mAudioUnit;
    InMemoryAudioFile           *inMemoryAudioFile;
    AudioStreamBasicDescription mAudioFormat;
}

-(id)init;

// Opens an audio file
-(void)open:(NSString *)filePath;

// Play the opened file
-(void)play:(BOOL) isLooping;

// Stop playback
-(void)stop;


@end
