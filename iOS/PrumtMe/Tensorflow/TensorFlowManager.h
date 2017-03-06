//
//  TensorFlowManager.h
//  PrumtMe
//
//  Created by fauquette fred on 1/03/17.
//  Copyright © 2017 fauquette fred. All rights reserved.
//

#import <CoreImage/CoreImage.h>
#import <Foundation/Foundation.h>

@interface TensorFlowManager : NSObject

+ (instancetype _Nullable)sharedManager;

@property (readonly) BOOL modelIsLoaded;
- (void)initializeCNNWithCompletion:(void(^ _Nonnull)(NSError  * _Nullable error))completion;

- (void)runCNNOnFrame:(CVPixelBufferRef _Nonnull)pixelBuffer
           completion:(void(^ _Nonnull)(NSDictionary * _Nullable predictions, NSError * _Nullable error))completion;

@end
