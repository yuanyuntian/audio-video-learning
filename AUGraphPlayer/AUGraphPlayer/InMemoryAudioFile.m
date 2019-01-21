//
//  InMemoryAudioFile.m
//  AudioUnitExample
//
//  Created by Sajiv Nair on 30/06/15.
//  Copyright (c) 2015 intelliswift. All rights reserved.
//
//
//  InMemoryAudioFile.m
//  HelloWorld
//
//  Created by Aran Mulholland on 22/02/09.
//  Copyright 2009 Aran Mulholland. All rights reserved.
//

#import "InMemoryAudioFile.h"

@implementation InMemoryAudioFile

//overide init method
- (id)init
{
    self=[super init];
    if (self!=nil) {
        packetIndex = 0;
    }
    return self;
}

- (void)dealloc {
    //release the AudioBuffer
    free(audioData);
    //[super dealloc];
}

//open and read a wav file
-(OSStatus)open:(NSString *)filePath{
    
    //get a ref to the audio file, need one to open it
//    CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation (NULL, (const UInt8 *)[filePath cStringUsingEncoding:[NSString defaultCStringEncoding]] , strlen([filePath cStringUsingEncoding:[NSString defaultCStringEncoding]]), false);
    
    CFURLRef audioFileURL = (__bridge CFURLRef)[NSURL fileURLWithPath:filePath];

    //open the audio file
    OSStatus result = AudioFileOpenURL (audioFileURL, kAudioFileReadPermission, 0, &mAudioFile);
    //were there any errors reading? if so deal with them first
    if (result != noErr) {
        NSLog(@"Could not open file: %@", filePath);
        packetCount = -1;
    }
    //otherwise
    else{
        //get the file info
        [self getFileInfo];
        //how many packets read? (packets are the number of stereo samples in this case)
        NSLog(@"File Opened, packet Count: %lld", packetCount);
        
        UInt32 packetsRead = packetCount;
        OSStatus result = -1;
        
        //free the audioBuffer just in case it contains some data
        free(audioData);
        UInt32 numBytesRead = -1;
        //if we didn't get any packets dop nothing, nothing to read
        if (packetCount <= 0) { }
        //otherwise fill our in memory audio buffer with the whole file (i wouldnt use this with very large files btw)
        else{
            //allocate the buffer
            audioData = (UInt32 *)malloc(sizeof(UInt32) * packetCount);
            //read the packets
//            result = AudioFileReadPackets (mAudioFile, false, &numBytesRead, NULL, 0, &packetsRead,  audioData);
            result =AudioFileReadPacketData(mAudioFile, false, &numBytesRead, NULL, 0, &packetsRead, audioData);

        }
        if (result==noErr){
            //print out general info about  the file
            NSLog(@"Packets read from file: %ld\n", packetsRead);
            NSLog(@"Bytes read from file: %ld\n", numBytesRead);
            //for a stereo 32 bit per sample file this is ok
            NSLog(@"Sample count: %ld\n", numBytesRead / 2);
            //for a 32bit per stereo sample at 44100khz this is correct
            NSLog(@"Time in Seconds: %f.4\n", ((float)numBytesRead / 4.0) / 44100.0);
        }
    }
    
    CFRelease (audioFileURL);
    
    return result;
}


- (OSStatus) getFileInfo {
    
    OSStatus    result = -1;
    //double duration;
    
    if (mAudioFile != nil){
        UInt32 dataSize = sizeof packetCount;
        result = AudioFileGetProperty(mAudioFile, kAudioFilePropertyAudioDataPacketCount, &dataSize, &packetCount);
        if (result==noErr) {
            //duration = ((double)packetCount * 2) / 44100;
        }
        else{
            packetCount = -1;
        }
    }
    return result;
}


//gets the next packet from the buffer, if we have reached the end of the buffer return 0
-(UInt32)getNextPacket : (BOOL)loop{
    
    UInt32 returnValue = 0;
    
    if(loop) {
        
        //if the packetCount has gone to the end of the file, reset it. Audio will loop.
        if (packetIndex >= packetCount){
            packetIndex = 0;
            NSLog(@"Reset player to beginning of file.");
        }
        
        returnValue = audioData[packetIndex++];
    }
    else {
        
        //i always like to set a variable and then return it during development so i can
        //see the value while debugging
        if(packetIndex < packetCount)
            returnValue = audioData[packetIndex++];
    }
    //}
    
    return returnValue;
}

//gets the current index (where we are up to in the buffer)
-(SInt64)getIndex{
    return packetIndex;
}

-(void)reset{
    packetIndex = 0;
}

-(BOOL)eof{
    if (packetIndex >= packetCount){
        return YES;
    }
    return NO;
}

@end
