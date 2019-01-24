//
//  SEAVAudioSession.m
//  AUGraphPlayer
//
//  Created by yuan on 2019/1/22.
//  Copyright © 2019年 sunEEE. All rights reserved.
//

#import "SEAVAudioSession.h"
#import <AVFoundation/AVFoundation.h>

@interface SEAVAudioSession(){
    AVAudioSession * _session;
}
@end

@implementation SEAVAudioSession

-(instancetype)init{
    if (self = [super init]) {
        _session = [AVAudioSession sharedInstance];
    }
    return self;
}

-(void)configAudioSession{
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
    
    //设置延迟
    Float32 ioBufferDuration = .005;
    if (![_session setPreferredIOBufferDuration:ioBufferDuration error:&error]) {
        NSLog(@"error when setPreferredSampleRate on audio session :%@ ",error.localizedDescription);
    }
}

-(void)setActive:(BOOL)active{
    NSError *error = nil;
    //激活会话
    if (![_session setActive:YES error:&error]) {
        NSLog(@"error when setActive on audio session :%@ ",error.localizedDescription);
    }
}

-(void)dealloc{
    
}

@end
