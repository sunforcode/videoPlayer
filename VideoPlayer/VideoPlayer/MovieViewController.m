//
//  MovieViewController.m
//  VideoPlayer
//
//  Created by 汤 on 16/10/26.
//  Copyright © 2016年 com.syj.app. All rights reserved.
//

#import "MovieViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <Masonry.h>
@class textbook;
typedef NS_ENUM(NSInteger, PanDirection){
    PanDirectionHorizontalMoved, // 横向移动
    PanDirectionVerticalMoved    // 纵向移动
};
@interface MovieViewController ()<UIGestureRecognizerDelegate>
@property(nonatomic, strong)MPMoviePlayerController *videoPlayer;
@property(nonatomic, weak)MPVolumeView *volumeProgress;
@property(nonatomic, weak)UILabel *titlLabel;
@property(nonatomic, weak)UILabel *playTimeLabel;
@property(nonatomic, weak)UISlider *playProgressSlider;
@property(nonatomic, weak)UILabel *totalTimeLabel;
@property(nonatomic, weak)UIView *topBarView;
@property(nonatomic, weak)UIView *bottomBar;
@property(nonatomic, strong)UISlider *volumeSlider;
@property(nonatomic, strong)UIButton *volumeButton;
@property(nonatomic, weak)UIButton *playButton;
@property (nonatomic, assign) PanDirection           panDirection;
/** 用来保存快进的总时长 */
@property (nonatomic, assign) CGFloat                sumTime;


@property(nonatomic, weak)NSTimer *videoProgressTimer;
@property(nonatomic, weak)NSTimer *autoHideTopBottomBarTimer;

/** 是否在调节音量*/
@property (nonatomic, assign) BOOL                   isVolume;
@end

@implementation MovieViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor redColor];
    [self setUpUI];
    [self prepareToPlayWithText:nil];
    [self setUpGesture];
    [self setUpNotification];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startAutoHideTopBottomBarTimer];
}

- (void)didClickBackBarItem: (UIButton *)sender {
    [self endAutoHideTopBottomBarTimer];
    [self endVideoProgressTimer];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)didClickPlayListButton: (UIButton *)sender {
    
}

- (void)didClickLockButton: (UIButton *)sender {
    sender.selected = !sender.selected;
}

- (void)didClickPlayButton: (UIButton *)sender {
    sender.selected = !sender.selected;
    if (!sender.selected == YES) {
        [self.videoPlayer play];
    } else {
        [self.videoPlayer pause];
    }
}

- (void)didClickVolumeButton: (UIButton *)sender {
    sender.selected = !sender.selected;
    self.volumeSlider.value = sender.selected? 0 : 0.3;
}


- (BOOL)shouldAutorotate
{
    return YES;
}
- (void)didClickFullScreenButton: (UIButton *)sender {
    sender.selected = !sender.selected;


    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    UIInterfaceOrientation interfaceOrientation = (UIInterfaceOrientation)orientation;
    UIInterfaceOrientation orientationlast = UIInterfaceOrientationUnknown;
    if (interfaceOrientation == UIInterfaceOrientationPortrait || interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
         orientationlast = UIInterfaceOrientationLandscapeRight;
    }else {
        orientationlast = UIInterfaceOrientationPortrait;
    }
    
    if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
        SEL selector             = NSSelectorFromString(@"setOrientation:");
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
        [invocation setSelector:selector];
        [invocation setTarget:[UIDevice currentDevice]];
        int val                  = orientationlast;
        // 从2开始是因为0 1 两个参数已经被selector和target占用
        [invocation setArgument:&val atIndex:2];
        [invocation invoke];
    }
}

- (void)playProgressSliderValueChange: (UISlider *)sender {
    [self endVideoProgressTimer];
    [self endAutoHideTopBottomBarTimer];
    _playTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d", (int)(_playProgressSlider.value/ 60.0)%60, (int)(_playProgressSlider.value)%60];
}

- (void)playProgressSliderTouchUpInside: (UISlider *)sender {
    [self startAutoHideTopBottomBarTimer];
    [self startVideoProgressTimer];
    self.videoPlayer.currentPlaybackTime = sender.value;
}

- (void)volumeSliderValueChange: (UISlider *)sender {
    self.volumeButton.selected = sender.value == 0;
}

#pragma mark - set/get


#pragma mark - 系统方法
#pragma mark 手势设置
- (void)setUpGesture {
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panGesture:)];
    panRecognizer.delegate = self;
    [panRecognizer setMaximumNumberOfTouches:1];
    [panRecognizer setDelaysTouchesBegan:YES];
    [panRecognizer setDelaysTouchesEnded:YES];
    [panRecognizer setCancelsTouchesInView:YES];
    [self.view addGestureRecognizer:panRecognizer];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapGesture:)];
    tapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapGesture];
    
}
#pragma mark 通知设置
- (void)setUpNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReciveFinishNotification:) name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
    // app退到后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReciveDidEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
    // app进入前台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReciveDidEnterPlayground:) name:UIApplicationDidBecomeActiveNotification object:nil];
    //拔插耳机
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeListenerCallback:) name:AVAudioSessionRouteChangeNotification object:nil];
}


-(BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - 私有方法
//为播放做准备
- (void)prepareToPlayWithText:(textbook *)textBook {
    
    NSString *path = [[NSBundle mainBundle]pathForResource:@"1456117847747a_x264.mp4" ofType:nil];
    
    NSURL *url = [NSURL fileURLWithPath:path];
    self.videoPlayer.contentURL = url;
    self.totalTimeLabel.text = [NSString stringWithFormat:@"%f", self.videoPlayer.duration];
    [self.videoPlayer play];
    AVURLAsset *avURLAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    NSInteger totalSecond = avURLAsset.duration.value / avURLAsset.duration.timescale;
    //    NSInteger initSeccond = [self lastPlayingTime];
    
    self.playProgressSlider.maximumValue = totalSecond;
    self.playProgressSlider.minimumValue = 0.0;
    NSString *duration = [NSString stringWithFormat:@"%02d:%02d", (int)(totalSecond/ 60.0)%60, (int)(totalSecond)%60];
    self.totalTimeLabel.text = duration;
    //    _playProgressSlider.value = initSeccond;
    //    _playTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d", (int)(initSeccond/ 60.0)%60, (int)(initSeccond)%60];
    [self.videoPlayer play];
    self.videoProgressTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(videoProgressTimer:) userInfo:nil repeats:YES];
}



- (void)videoProgressTimer:(NSTimer *)timer {
    self.playProgressSlider.value = self.videoPlayer.currentPlaybackTime;
    self.playTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d", (int)(self.videoPlayer.currentPlaybackTime/ 60.0)%60, (int)(self.videoPlayer.currentPlaybackTime)%60];
}
- (void)autoHideTopBottomBar :(NSTimer *)timer {
    
    [UIView animateWithDuration:0.5 animations:^{
        self.topBarView.alpha = 0.2;
        self.bottomBar.alpha = 0.2;
    } completion:^(BOOL finished) {
        self.topBarView.hidden = YES;
        self.bottomBar.hidden = YES;
        self.topBarView.alpha = 1;
        self.bottomBar.alpha = 1;
    }];
    [timer invalidate];
    self.autoHideTopBottomBarTimer = nil;
}

//timerStart/timerEnd
- (void)startVideoProgressTimer {
    self.videoProgressTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(videoProgressTimer:) userInfo:nil repeats:YES];
}

- (void)endVideoProgressTimer {
    [self.videoProgressTimer invalidate];
    self.videoProgressTimer = nil;
}

- (void)startAutoHideTopBottomBarTimer {
    self.autoHideTopBottomBarTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(autoHideTopBottomBar:) userInfo:nil repeats:NO];
}
- (void)endAutoHideTopBottomBarTimer {
    [self.autoHideTopBottomBarTimer invalidate];
    self.autoHideTopBottomBarTimer = nil;
}

#pragma mark 通知
- (void)didReciveFinishNotification:(NSNotification *)notification {
    [self.videoPlayer stop];
    self.videoPlayer.currentPlaybackTime = 0.0;
    self.playProgressSlider.value = 0;
    self.playButton.selected = YES;
    [self endVideoProgressTimer];
    self.playTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d", (int)(self.videoPlayer.currentPlaybackTime/ 60.0)%60, (int)(self.videoPlayer.currentPlaybackTime)%60];
}

- (void)didReciveDidEnterBackground:(NSNotification *)notification {
    self.playButton.selected = NO;
}

- (void)didReciveDidEnterPlayground:(NSNotification *)notification {
    self.playButton.selected = YES;
    [self.videoPlayer play];
}


- (void)audioRouteChangeListenerCallback: (NSNotification *)notification {
    NSDictionary *interuptionDict = notification.userInfo;
    
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    switch (routeChangeReason) {
            
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            // 耳机插入
            break;
            
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        {
            // 耳机拔掉
            // 拔掉耳机继续播放
            [self.videoPlayer play];
        }
            break;
            
        case AVAudioSessionRouteChangeReasonCategoryChange:
            // called at start - also when other audio wants to play
            NSLog(@"AVAudioSessionRouteChangeReasonCategoryChange");
            break;
    }
}




#pragma mark手势
- (void)panGesture:(UIPanGestureRecognizer *)pan {
    //根据在view上Pan的位置，确定是调音量还是亮度
    CGPoint locationPoint = [pan locationInView:self.view];
    // 根据上次和本次移动的位置，算出一个速率的point
    CGPoint veloctyPoint = [pan velocityInView:self.view];
    // 判断是垂直移动还是水平移动
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:{ // 开始移动
            // 使用绝对值来判断移动的方向
            self.topBarView.hidden = NO;
            self.bottomBar.hidden = NO;
            [self endVideoProgressTimer];
            [self endAutoHideTopBottomBarTimer];
            CGFloat x = fabs(veloctyPoint.x);
            CGFloat y = fabs(veloctyPoint.y);
            if (x > y) { // 水平移动
                // 取消隐藏
                self.panDirection = PanDirectionHorizontalMoved;
            }
            else if (x < y){ // 垂直移动
                self.panDirection = PanDirectionVerticalMoved;
                // 开始滑动的时候,状态改为正在控制音量
                if (locationPoint.x > self.view.bounds.size.width / 2) {
                    self.isVolume = YES;
                    //改变音量
                }else { // 状态改为显示亮度调节
                    self.isVolume = NO;
                    //亮度调节
                }
            }
            break;
        }
        case UIGestureRecognizerStateChanged:{ // 正在移动
            switch (self.panDirection) {
                case PanDirectionHorizontalMoved:{
                    [self horizontalMoved:veloctyPoint.x]; // 水平移动的方法只要x方向的值
                    break;
                }
                case PanDirectionVerticalMoved:{
                    [self verticalMoved:veloctyPoint.y]; // 垂直移动方法只要y方向的值
                    break;
                }
            }
            break;
        }
        case UIGestureRecognizerStateEnded:{ // 移动停止
            [self startAutoHideTopBottomBarTimer];
            [self startVideoProgressTimer];
            // 移动结束也需要判断垂直或者平移
            // 比如水平移动结束时，要快进到指定位置，如果这里没有判断，当我们调节音量完之后，会出现屏幕跳动的bug
            switch (self.panDirection) {
                case PanDirectionHorizontalMoved:{
                    self.videoPlayer.currentPlaybackTime = self.playProgressSlider.value;
                    break;
                }
                case PanDirectionVerticalMoved:{
                    break;
                }
            }
            break;
        }
        default:
            break;
    }
}

- (void)verticalMoved:(CGFloat)value {
    self.isVolume ? (self.volumeSlider.value -= value / 10000) : ([UIScreen mainScreen].brightness -= value / 10000);
}

- (void)horizontalMoved:(CGFloat)value {
    self.playProgressSlider.value += value/1000;
    self.playTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d", (int)(self.playProgressSlider.value/ 60.0)%60, (int)(self.playProgressSlider.value)%60];
}

- (void)tapGesture:(UITapGestureRecognizer *)tapGesture {
    self.topBarView.hidden = !self.topBarView.hidden;
    self.bottomBar.hidden = !self.bottomBar.hidden;
    
    if (self.autoHideTopBottomBarTimer != nil) {
        [self endAutoHideTopBottomBarTimer];
    }
    if (self.topBarView.hidden == NO) {
        [self startAutoHideTopBottomBarTimer];
    }
}
#pragma mark -代理

-(BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    CGFloat top = CGRectGetMaxY(self.topBarView.frame);
    CGFloat bottom = CGRectGetMinY(self.bottomBar.frame);
    CGRect okRect = CGRectMake(0, top, self.view.bounds.size.width, bottom - top);
    if (CGRectContainsPoint(okRect, [gestureRecognizer locationInView:self.view])) {
        return YES;
    }
    return NO;
}

#pragma mark - setUpUI
- (void)setUpUI {
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.navigationController.navigationBar.hidden = YES;
    MPMoviePlayerController *moviewController = [[MPMoviePlayerController alloc]init];
    moviewController.controlStyle = MPMovieControlStyleNone;
    [self.view addSubview:moviewController.view];
    self.videoPlayer =  moviewController;
    
    UIView *topBarView = [[UIView alloc]init];
    topBarView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:.0 alpha:0.4];
    self.topBarView = topBarView;
    [self.view addSubview:topBarView];
    
    UIButton *backBarItem = [[UIButton alloc]init];
    [backBarItem setImage:[UIImage imageNamed:@"kernel_back_bookshelf"] forState:UIControlStateNormal];
    [backBarItem addTarget:self action:@selector(didClickBackBarItem:) forControlEvents:UIControlEventTouchUpInside];
    [backBarItem sizeToFit];
    [topBarView addSubview:backBarItem];
    
    UILabel *titlLabel = [[UILabel alloc]init];
    titlLabel.textColor = [UIColor whiteColor];
    titlLabel.textAlignment = NSTextAlignmentCenter;
    titlLabel.text = @"测试标题";
    self.titlLabel = titlLabel;
    [topBarView addSubview:titlLabel];
    
    UIButton *playListButton = [[UIButton alloc]init];
    [playListButton setImage:[UIImage imageNamed:@"audio_playlist"] forState:UIControlStateNormal];
    [playListButton addTarget:self action:@selector(didClickPlayListButton:) forControlEvents:UIControlEventTouchUpInside];
    [playListButton sizeToFit];
    [topBarView addSubview:playListButton];
    
    UIButton *lockButton = [[UIButton alloc]init];
    [lockButton setImage:[UIImage imageNamed:@"video_unlock_screen"] forState:UIControlStateNormal];
    [lockButton setImage:[UIImage imageNamed:@"video_lock_screen"] forState:UIControlStateSelected];
    [lockButton addTarget:self action:@selector(didClickLockButton:) forControlEvents:UIControlEventTouchUpInside];
    [lockButton sizeToFit];
    [topBarView addSubview:lockButton];
    
    UIView *lineView1 = [[UIView alloc]init];
    lineView1.backgroundColor = [UIColor whiteColor];
    [topBarView addSubview:lineView1];
    
    UIView *bottomBar = [[UIView alloc]init];
    bottomBar.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:.0 alpha:0.4];
    self.bottomBar = bottomBar;
    [self.view addSubview:bottomBar];
    
    UIButton *playButton = [[UIButton alloc]init];
    [playButton setImage:[UIImage imageNamed:@"video_pause.png"] forState:UIControlStateNormal];
    [playButton setImage:[UIImage imageNamed:@"video_play.png"] forState:UIControlStateSelected];
    [playButton addTarget:self action:@selector(didClickPlayButton:) forControlEvents:UIControlEventTouchUpInside];
    [playButton sizeToFit];
    self.playButton = playButton;
    [bottomBar addSubview:playButton];
    
    UILabel *playTimeLabel = [[UILabel alloc]init];
    playTimeLabel.textColor = [UIColor whiteColor];
    playTimeLabel.textAlignment = NSTextAlignmentCenter;
    playTimeLabel.text = @"00:00";
    [playTimeLabel sizeToFit];
    self.playTimeLabel = playTimeLabel;
    [bottomBar addSubview:playTimeLabel];
    
    UISlider *playProgressSlider =[[UISlider alloc]init];
    [playProgressSlider setMinimumTrackImage:[UIImage imageNamed:@"slider_min_track.png"] forState:UIControlStateNormal];
    [playProgressSlider setMaximumTrackImage:[UIImage imageNamed:@"slider_max_track.png"] forState:UIControlStateNormal];
    [playProgressSlider setThumbImage:[UIImage imageNamed:@"slider_thum.png"] forState:UIControlStateNormal];
    [playProgressSlider setThumbImage:[UIImage imageNamed:@"slider_thum.png"] forState:UIControlStateHighlighted];
    [playProgressSlider addTarget:self action:@selector(playProgressSliderValueChange:) forControlEvents:UIControlEventValueChanged];
    [playProgressSlider addTarget:self action:@selector(playProgressSliderTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
    self.playProgressSlider = playProgressSlider;
    [bottomBar addSubview:playProgressSlider];
    
    UILabel *totalTimeLabel = [[UILabel alloc]init];
    totalTimeLabel.textColor = [UIColor whiteColor];
    totalTimeLabel.textAlignment = NSTextAlignmentCenter;
    totalTimeLabel.text = @"00:00";
    [totalTimeLabel sizeToFit];
    self.totalTimeLabel = totalTimeLabel;
    [bottomBar addSubview:totalTimeLabel];
    
    UIButton *volumeButton = [[UIButton alloc]init];
    [volumeButton setImage:[UIImage imageNamed:@"mute_y"] forState:UIControlStateSelected];
    [volumeButton setBackgroundImage:[UIImage imageNamed:@"mute_n"] forState:UIControlStateNormal];
    [volumeButton addTarget:self action:@selector(didClickVolumeButton:) forControlEvents:UIControlEventTouchUpInside];
    [volumeButton sizeToFit];
    self.volumeButton = volumeButton;
    [bottomBar addSubview:volumeButton];
    
    UISlider *slider = [[UISlider alloc]init];
    
    MPVolumeView *volumeProgress = [[MPVolumeView alloc]init];
    volumeProgress.showsRouteButton = NO;
    [volumeProgress setMinimumVolumeSliderImage:[UIImage imageNamed:@"slider_min_track.png"] forState:UIControlStateNormal];
    [volumeProgress setMaximumVolumeSliderImage:[UIImage imageNamed:@"slider_max_track.png"] forState:UIControlStateNormal];
    for (UIView *view in volumeProgress.subviews) {
        NSLog(@"%@",view);
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]) {
            slider = (UISlider *)view;
            [slider setThumbImage:[UIImage imageNamed:@"slider_thum.png"] forState:UIControlStateNormal];
            [slider addTarget:self action:@selector(volumeSliderValueChange:) forControlEvents:UIControlEventValueChanged];
            self.volumeSlider = slider;
        }
    }
    
    [bottomBar addSubview:volumeProgress];
    self.volumeProgress = volumeProgress;
    
    UIButton *fullScreenButton = [[UIButton alloc]init];
    [fullScreenButton setImage:[UIImage imageNamed:@"video_full_screen"] forState:UIControlStateNormal];
    [fullScreenButton setImage:[UIImage imageNamed:@"video_exif_full_screen"] forState:UIControlStateSelected];
    [fullScreenButton addTarget:self action:@selector(didClickFullScreenButton:) forControlEvents:UIControlEventTouchUpInside];
    [fullScreenButton sizeToFit];
    [bottomBar addSubview:fullScreenButton];
    
    UIView *lineView2 = [[UIView alloc]init];
    lineView2.backgroundColor = [UIColor whiteColor];
    [bottomBar addSubview:lineView2];
    
    
    topBarView.translatesAutoresizingMaskIntoConstraints = NO;
    bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    for (UIView *view in topBarView.subviews) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
    }
    for (UIView *view in bottomBar.subviews) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
    }
    
    [self.videoPlayer.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [topBarView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view.mas_left);
        make.top.equalTo(self.view.mas_top);
        make.right.equalTo(self.view.mas_right);
        make.height.mas_equalTo(64);
    }];
    [backBarItem mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(topBarView.mas_left).mas_offset(8);
        make.bottom.equalTo(topBarView.mas_bottom).mas_offset(-8);
    }];
    
    [titlLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(topBarView.mas_bottom).mas_offset(-8);
        make.centerX.equalTo(topBarView.mas_centerX);
    }];
    
    [playListButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(topBarView.mas_right).mas_offset(-8);
        make.bottom.equalTo(topBarView.mas_bottom).mas_offset(-8);
    }];
    
    [lockButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(playListButton.mas_left).mas_offset(-8);
        make.bottom.equalTo(topBarView.mas_bottom).mas_offset(-8);
    }];
    
    [lineView1 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view.mas_left);
        make.right.equalTo(self.view.mas_right);
        make.top.equalTo(topBarView.mas_bottom);
        make.height.mas_equalTo(1);
    }];
    
    [bottomBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view.mas_left);
        make.right.equalTo(self.view.mas_right);
        make.bottom.equalTo(self.view.mas_bottom);
        make.height.mas_equalTo(64);
    }];
    
    [playButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(bottomBar.mas_left).mas_offset(8);
        make.centerY.equalTo(bottomBar.mas_centerY);
        make.height.mas_equalTo(32);
        make.width.mas_equalTo(32);
    }];
    
    [playTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(playButton.mas_right).mas_offset(8);
        make.centerY.equalTo(bottomBar.mas_centerY);
        make.width.mas_equalTo(80);
    }];
    
    [playProgressSlider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(playTimeLabel.mas_right).mas_offset(8);
        make.centerY.equalTo(bottomBar.mas_centerY);
        make.right.equalTo(totalTimeLabel.mas_left).mas_offset(-8);
    }];
    
    [totalTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(bottomBar.mas_centerY);
        make.right.equalTo(volumeButton.mas_left).mas_equalTo(-8);
        make.width.mas_equalTo(80);
    }];
    
    [volumeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(bottomBar.mas_centerY);
        make.right.equalTo(volumeProgress.mas_left).mas_offset(-8);
    }];
    
    [volumeProgress mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(playProgressSlider.mas_top);
        make.right.equalTo(fullScreenButton.mas_left).offset(-8);
        make.height.mas_equalTo(44);
        make.width.mas_equalTo(60);
    }];
    
    [fullScreenButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(bottomBar.mas_centerY);
        make.right.equalTo(bottomBar.mas_right).mas_offset(-8);
    }];
    
    [lineView2 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(bottomBar.mas_left);
        make.right.equalTo(bottomBar.mas_right);
        make.bottom.equalTo(bottomBar.mas_top);
        make.height.mas_equalTo(1);
    }];
}

@end
