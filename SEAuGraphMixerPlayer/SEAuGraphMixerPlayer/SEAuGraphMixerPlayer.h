//
//  SEAuGraphMixerPlayer.h
//  SEAuGraphMixerPlayer
//
//  Created by yuan on 2019/1/30.
//  Copyright © 2019年 sunEEE. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>


NS_ASSUME_NONNULL_BEGIN

@interface SEAuGraphMixerPlayer : NSObject


@property(nonatomic, assign)BOOL isPlaying;
//播放
-(void)play;
//停止
-(void)stop;

//设置bus总线开关
- (void)enableInput:(UInt32)inputNum isOn:(BOOL)value;

//设置混合通道的音量
- (void)setInputVolume:(UInt32)inputNum value:(float)value;

//设置输出通道的音量
- (void)setOutputVolume:(float)value;


@end

NS_ASSUME_NONNULL_END
