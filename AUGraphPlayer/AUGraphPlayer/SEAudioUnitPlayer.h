//
//  SEAudioUnitPlayer.h
//  AUGraphPlayer
//
//  Created by yuan on 2019/1/17.
//  Copyright © 2019年 sunEEE. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//播放本地文件
@interface SEAudioUnitPlayer : NSObject

-(instancetype)init NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;

//资源路径
- (instancetype)initWithFilePath:(NSString *)path; 

//停止
-(void)stop;

//播放
-(void)play;

//暂停
-(void)pause;

@end

NS_ASSUME_NONNULL_END
