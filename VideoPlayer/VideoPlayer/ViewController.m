//
//  ViewController.m
//  VideoPlayer
//
//  Created by 汤 on 16/10/26.
//  Copyright © 2016年 com.syj.app. All rights reserved.
//

#import "ViewController.h"
#import "MovieViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
@interface ViewController ()
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) MPVolumeView *mpVolumeView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor lightGrayColor];
    
}

- (IBAction)didClickVideoPlayer:(UIButton *)sender {
    MovieViewController *movie = [[MovieViewController alloc]init];
    [self.navigationController pushViewController:movie animated:YES];
}
/*
- (void)valueChange:(UISlider *)sender {
    NSLog(@"%f", sender.value);
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    UISlider *slider = [[UISlider alloc]init];
    MPVolumeView *volumeProgress = [[MPVolumeView alloc]initWithFrame:CGRectMake(50, 440, self.view.frame.size.width - 100, 40)];
    [volumeProgress setMinimumVolumeSliderImage:[UIImage imageNamed:@"slider_min_track"] forState:UIControlStateNormal];
    [volumeProgress setMaximumVolumeSliderImage:[UIImage imageNamed:@"slider_thum"] forState:UIControlStateNormal];
//    [volumeProgress setVolumeThumbImage:[UIImage imageNamed:@"slider_min_track"] forState:UIControlStateNormal];
    volumeProgress.showsRouteButton = NO;
    [self.view addSubview:volumeProgress];
    
    for (UIView *view in volumeProgress.subviews) {
        NSLog(@"%@",view);
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]) {
            slider = (UISlider *)view;
             [slider setThumbImage:[UIImage imageNamed:@"slider_thum.png"] forState:UIControlStateNormal];
            [slider addTarget:self action:@selector(valueChange:) forControlEvents:UIControlEventValueChanged];
            NSLog(@"%f", slider.value);
        }
    }
}


*/
@end
