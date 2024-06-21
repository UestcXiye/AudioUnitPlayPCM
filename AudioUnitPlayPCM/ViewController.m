//
//  ViewController.m
//  AudioUnitPlayPCM
//
//  Created by 刘文晨 on 2024/6/21.
//

#import "ViewController.h"
#import "AUPlayer.h"

@interface ViewController () <AUPlayerDelegate>

@end

@implementation ViewController
{
    AUPlayer* player;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.view setBackgroundColor:UIColor.whiteColor];
    
    self.label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
    self.label.textColor = [UIColor blackColor];
    self.label.text = @"使用 Audio Unit 播放 PCM";
    self.label.translatesAutoresizingMaskIntoConstraints = NO;
        
    self.currentTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
    self.currentTimeLabel.textColor = [UIColor grayColor];
        
    self.playButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    [self.playButton setTitle:@"play" forState:UIControlStateNormal];
    [self.playButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    self.playButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.playButton addTarget:self action:@selector(onDecodeStart) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.label];
    [self.view addSubview:self.currentTimeLabel];
    [self.view addSubview:self.playButton];
    
    /* 添加约束 */
    [NSLayoutConstraint activateConstraints:@[
        [self.label.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:95],
        [self.label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.playButton.topAnchor constraintEqualToAnchor:self.label.bottomAnchor constant:300],
        [self.playButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
}

- (void)onDecodeStart
{
    self.playButton.hidden = YES;
    player = [[AUPlayer alloc] init];
    player.delegate = self;
    [player play];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - AUPlayer Delegate Method

- (void)onPlayToEnd:(AUPlayer *)player
{
    [self playButton];
    player = nil;
    self.playButton.hidden = NO;
}

@end
