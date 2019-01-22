//
//  SEAudioUnitPlayer.h
//  AUGraphPlayer
//
//  Created by yuan on 2019/1/17.
//  Copyright © 2019年 sunEEE. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SEAudioUnitPlayer;

@protocol SEAudioPlayerDelegate<NSObject>

@optional
-(void)didFinishedPlayer:(SEAudioUnitPlayer*)player;
-(void)didPlayFailed:(SEAudioUnitPlayer*)player;
-(void)didPlayingGetcurrentTime:(NSInteger)seconds;
-(void)didGetFileInfo:(NSDictionary *)info;
@end

NS_ASSUME_NONNULL_BEGIN

//播放本地文件
@interface SEAudioUnitPlayer : NSObject

-(instancetype)init NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;

//资源路径
- (instancetype)initWithFilePath:(NSString *)path delegete:(id)delegate; 

//停止
-(void)stop;

//播放
-(void)play;

//暂停
-(void)pause;

-(void)seekPacketIndex:(UInt32)index;

@end

NS_ASSUME_NONNULL_END
