//
//  AUPlayer.m
//  AudioUnitPlayPCM
//
//  Created by 刘文晨 on 2024/6/21.
//

#import "AUPlayer.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <assert.h>

const uint32_t CONST_BUFFER_SIZE = 0x10000;

#define INPUT_BUS 1
#define OUTPUT_BUS 0

@implementation AUPlayer
{
    AudioUnit audioUnit;
    AudioBufferList *audioBufferList;
    NSInputStream *inputSteam;
}

- (void)play
{
    [self initPlayer];
    AudioOutputUnitStart(audioUnit);
}

- (Float64)getCurrentTime
{
    Float64 timeInterval = 0;
    if (inputSteam)
    {
        
    }
    return timeInterval;
}

- (void)initPlayer
{
    // open file
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *url = [bundle URLForResource:@"music" withExtension:@"pcm"];
    inputSteam = [NSInputStream inputStreamWithURL:url];
    if (!inputSteam)
    {
        NSLog(@"failed to open file: %@", url);
        return;
    }
    
    [inputSteam open];
    
    self.sampleRate = 44100.0;
    NSError *audioSessionError = nil;
    OSStatus status = noErr;
    
    // set audio session
    // 获取 audio session 单例对象
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&audioSessionError];
    [audioSession setActive: YES error: &audioSessionError];
    self.sampleRate = [audioSession currentHardwareSampleRate];
    NSLog(@"Current Hardware sample rate: %f", self.sampleRate);
    
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &audioUnit);
    
    // buffer
    audioBufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    audioBufferList->mNumberBuffers = 1;
    audioBufferList->mBuffers[0].mNumberChannels = 1;
    audioBufferList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    audioBufferList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
    
    // audio property
    UInt32 flag = 1;
    if (flag)
    {
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      OUTPUT_BUS,
                                      &flag,
                                      sizeof(flag));
    }
    if (status)
    {
        NSLog(@"Audio Unit set property error with status: %d", status);
    }
    
    // output format
    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = self.sampleRate; // 采样率
    outputFormat.mFormatID = kAudioFormatLinearPCM; // PCM 格式
    outputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger; // 整形
    outputFormat.mFramesPerPacket = 1; // 每帧只有 1 个 packet
    outputFormat.mChannelsPerFrame = 1; // 声道数
    outputFormat.mBytesPerFrame = 2; // 每帧只有 2 个 byte，声道*位深*Packet
    outputFormat.mBytesPerPacket = 2; // 每个 Packet 只有 2 个 byte
    outputFormat.mBitsPerChannel = 16; // 位深
    [self printAudioStreamBasicDescription:outputFormat];

    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status)
    {
        NSLog(@"Audio Unit set property eror with status: %d", status);
    }
    
    // callback
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));
    
    OSStatus result = AudioUnitInitialize(audioUnit);
    NSLog(@"result: %d", result);
}

static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData)
{
    AUPlayer *player = (__bridge AUPlayer *)inRefCon;
    
    ioData->mBuffers[0].mDataByteSize =
        (UInt32)[player->inputSteam read:ioData->mBuffers[0].mData
                               maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];
    NSLog(@"output buffer size: %d", ioData->mBuffers[0].mDataByteSize);
    
    if (ioData->mBuffers[0].mDataByteSize <= 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [player stop];
        });
    }
    return noErr;
}


- (void)stop
{
    AudioOutputUnitStop(audioUnit);
    if (audioBufferList != nil)
    {
        if (audioBufferList->mBuffers[0].mData)
        {
            free(audioBufferList->mBuffers[0].mData);
            audioBufferList->mBuffers[0].mData = nil;
        }
        free(audioBufferList);
        audioBufferList = nil;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(onPlayToEnd:)])
    {
        __strong typeof(AUPlayer) *player = self;
        [self.delegate onPlayToEnd:player];
    }
    [inputSteam close];
}

- (void)dealloc
{
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    
    if (audioBufferList != nil)
    {
        free(audioBufferList);
        audioBufferList = nil;
    }
}

- (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd
{
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy(&formatID, formatIDString, 4);
    formatIDString[4] = '\0';

    NSLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"  Format ID:           %10s",    formatIDString);
    NSLog (@"  Format Flags:        %10X",    asbd.mFormatFlags);
    NSLog (@"  Bytes per Packet:    %10d",    asbd.mBytesPerPacket);
    NSLog (@"  Frames per Packet:   %10d",    asbd.mFramesPerPacket);
    NSLog (@"  Bytes per Frame:     %10d",    asbd.mBytesPerFrame);
    NSLog (@"  Channels per Frame:  %10d",    asbd.mChannelsPerFrame);
    NSLog (@"  Bits per Channel:    %10d",    asbd.mBitsPerChannel);
    
    printf("\n");
}

@end
