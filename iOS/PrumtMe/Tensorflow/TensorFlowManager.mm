//
//  TensorFlowManager.m
//  PrumtMe
//
//  Created by fauquette fred on 1/03/17.
//  Copyright © 2017 fauquette fred. All rights reserved.
//

#import "TensorFlowManager.h"

#include <memory>
#include "tensorflow/core/public/session.h"
#include "tensorflow/core/util/memmapped_file_system.h"

#include <sys/time.h>
#include "tensorflow_utils.h"

// If you have your own model, modify this to the file name, and make sure
// you've added the file to your app resources too.
static NSString* model_file_name = @"mmapped_graph";
static NSString* model_file_type = @"pb";
// This controls whether we'll be loading a plain GraphDef proto, or a
// file created by the convert_graphdef_memmapped_format utility that wraps a
// GraphDef and parameter file that can be mapped into memory from file to
// reduce overall memory usage.
const bool model_uses_memory_mapping = true;
// If you have your own model, point this to the labels file.
static NSString* labels_file_name = @"output_labels";
static NSString* labels_file_type = @"txt";
// These dimensions need to match those the model was trained with.
const int wanted_input_width = 299;
const int wanted_input_height = 299;
const int wanted_input_channels = 3;
const float input_mean = 128.0f;
const float input_std = 128.0f;
const std::string input_layer_name = "Mul";
const std::string output_layer_name = "final_result";

@interface TensorFlowManager () {
    std::unique_ptr<tensorflow::Session> tf_session;
    std::unique_ptr<tensorflow::MemmappedEnv> tf_memmapped_env;
    std::vector<std::string> labels;
}
@property BOOL modelIsLoaded;
@end


@implementation TensorFlowManager

#pragma mark Singleton Methods

+ (instancetype)sharedManager {
    static TensorFlowManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (id)init {
    if (self = [super init]) {
        self.modelIsLoaded = NO;
    }
    return self;
}

- (void)initializeCNNWithCompletion:(void(^)(NSError  * _Nullable error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        tensorflow::Status load_status;
        if (model_uses_memory_mapping) {
            load_status = LoadMemoryMappedModel(
                                                model_file_name,
                                                model_file_type,
                                                &tf_session,
                                                &tf_memmapped_env);
        } else {
            load_status = LoadModel(model_file_name,
                                    model_file_type,
                                    &tf_session);
        }
        tensorflow::Status labels_status = LoadLabels(labels_file_name, labels_file_type, &labels);
        if (!load_status.ok()) {
            completion([NSError errorWithDomain:@"Tensorflow"
                                           code:500
                                       userInfo:@{
                                                  NSLocalizedDescriptionKey: NSLocalizedString(@"Could not load model", nil)
                                                  }
                        ]);
        } else if (!labels_status.ok()) {
            completion([NSError errorWithDomain:@"Tensorflow"
                                           code:500
                                       userInfo:@{
                                                  NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't load labels", nil)
                                                  }
                        ]);
        } else {
            self.modelIsLoaded = YES;
            completion(nil);
        }
    });
    
}

- (void)runCNNOnFrame:(CVPixelBufferRef _Nonnull)pixelBuffer
           completion:(void(^ _Nonnull)(NSDictionary * _Nullable predictions, NSError * _Nullable error))completion {
    const int sourceRowBytes = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
    const int image_width = (int)CVPixelBufferGetWidth(pixelBuffer);
    const int fullHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    unsigned char *sourceBaseAddr =
    (unsigned char *)(CVPixelBufferGetBaseAddress(pixelBuffer));
    int image_height;
    unsigned char *sourceStartAddr;
    if (fullHeight <= image_width) {
        image_height = fullHeight;
        sourceStartAddr = sourceBaseAddr;
    } else {
        image_height = image_width;
        const int marginY = ((fullHeight - image_width) / 2);
        sourceStartAddr = (sourceBaseAddr + (marginY * sourceRowBytes));
    }
    const int image_channels = 4;
    
    assert(image_channels >= wanted_input_channels);
    tensorflow::Tensor image_tensor(
                                    tensorflow::DT_FLOAT,
                                    tensorflow::TensorShape(
                                                            {1, wanted_input_height, wanted_input_width, wanted_input_channels}));
    auto image_tensor_mapped = image_tensor.tensor<float, 4>();
    tensorflow::uint8 *in = sourceStartAddr;
    float *out = image_tensor_mapped.data();
    for (int y = 0; y < wanted_input_height; ++y) {
        float *out_row = out + (y * wanted_input_width * wanted_input_channels);
        for (int x = 0; x < wanted_input_width; ++x) {
            const int in_x = (y * image_width) / wanted_input_width;
            const int in_y = (x * image_height) / wanted_input_height;
            tensorflow::uint8 *in_pixel =
            in + (in_y * image_width * image_channels) + (in_x * image_channels);
            float *out_pixel = out_row + (x * wanted_input_channels);
            for (int c = 0; c < wanted_input_channels; ++c) {
                out_pixel[c] = (in_pixel[c] - input_mean) / input_std;
            }
        }
    }
    
    if (tf_session.get()) {
        std::vector<tensorflow::Tensor> outputs;
        tensorflow::Status run_status = tf_session->Run(
                                                        {{input_layer_name, image_tensor}}, {output_layer_name}, {}, &outputs);
        if (!run_status.ok()) {
            completion(nil, [NSError errorWithDomain:@"Tensorflow"
                                           code:500
                                       userInfo:@{
                                                  NSLocalizedDescriptionKey: NSLocalizedString(@"Running model failed", nil)
                                                  }
                        ]);
        } else {
            tensorflow::Tensor *output = &outputs[0];
            auto predictions = output->flat<float>();
            
            NSMutableDictionary *newValues = [NSMutableDictionary dictionary];
            for (int index = 0; index < predictions.size(); index += 1) {
                const float predictionValue = predictions(index);
                if (predictionValue > 0.05f) {
                    std::string label = labels[index % predictions.size()];
                    NSString *labelObject = [NSString stringWithCString:label.c_str() encoding:NSUTF8StringEncoding];
                    NSNumber *valueObject = [NSNumber numberWithFloat:predictionValue];
                    [newValues setObject:valueObject forKey:labelObject];
                }
            }
            completion(newValues, nil);
        }
    }
}

@end
