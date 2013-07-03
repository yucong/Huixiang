//
//  ViewController.m
//  Huixiang
//
//  Created by ltebean on 13-6-13.
//  Copyright (c) 2013年 ltebean. All rights reserved.
//

#import "ViewController.h"
#import "HTTP.h"
#import "PieceView.h"
#import "iCarousel.h"
#import "HMSideMenu.h"
#import "Settings.h"
#import "SVProgressHUD.h"
#import "WeiboHTTP.h"

#define NUMBER_OF_VISIBLE_ITEMS 1
#define ITEM_SPACING 260.0f
#define INCLUDE_PLACEHOLDERS YES

@interface ViewController ()<iCarouselDataSource, iCarouselDelegate,PieceViewDelegate>
@property (weak, nonatomic) IBOutlet iCarousel *carousel;
@property(nonatomic,strong) NSMutableArray* pieces;
@property (nonatomic, strong) HMSideMenu *sideMenu;
@property int currentIndex;
@property BOOL loaded;
@end

@implementation ViewController

-(id)initWithCoder:(NSCoder *)aDecoder
{
    self=[super initWithCoder:aDecoder];
    if(self){
        [super viewDidLoad];
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"看看" image:nil tag:0];
        [[self tabBarItem] setFinishedSelectedImage:[UIImage imageNamed:@"main.png"] withFinishedUnselectedImage:[UIImage imageNamed:@"main.png"]];
        [[self tabBarItem] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [UIColor colorWithRed:150.0f/255.0f green:150.0f/255.0f blue:150.0f/255.0f alpha:1.0f], UITextAttributeTextColor,
                                                   nil] forState:UIControlStateNormal];
        [self.tabBarController setSelectedIndex:0];
        self.tabBarController.tabBar.selectedImageTintColor = nil;
    }
    return self;
}

-(void)initSideView
{
    UIView *favItem = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    [favItem setMenuActionWithBlock:^{
        [self addToFav];
    }];
    UIImageView *favIcon = [[UIImageView alloc] initWithFrame:CGRectMake(6, 7, 28, 28)];
    [favIcon setImage:[UIImage imageNamed:@"fav"]];
    [favItem addSubview:favIcon];
    
    
    UIView *emailItem = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    [emailItem setMenuActionWithBlock:^{
        NSLog(@"tapped email item");
    }];
    UIImageView *emailIcon = [[UIImageView alloc] initWithFrame:CGRectMake(5, 5, 30 , 30)];
    [emailIcon setImage:[UIImage imageNamed:@"email"]];
    [emailItem addSubview:emailIcon];
    
    
    UIView *weiboItem = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    [weiboItem setMenuActionWithBlock:^{
        [self shareToWeibo];
    }];
    UIImageView *weiboIcon = [[UIImageView alloc] initWithFrame:CGRectMake(1, 1, 38, 38)];
    
    [weiboIcon setImage:[UIImage imageNamed:@"weibo"]];
    [weiboItem addSubview:weiboIcon];
    
    self.sideMenu = [[HMSideMenu alloc] initWithItems:@[favItem,weiboItem, emailItem]];
    self.sideMenu.menuPosition=HMSideMenuPositionTop;
    [self.sideMenu setItemSpacing:15.0f];
    [self.carousel addSubview:self.sideMenu];

}

- (void)viewDidLoad
{
   
    [self initSideView];

    self.carousel.dataSource=self;
    self.carousel.delegate=self;
    self.carousel.type = iCarouselTypeTimeMachine;
    
    self.currentIndex=0;
    self.loaded=NO;
	// Do any additional setup after loading the view, typically from a nib.
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    if(!self.loaded){
        [self refreshData];
    }
}


-(void)refreshData
{
    [SVProgressHUD showWithStatus:@"加载中"];

    [HTTP sendRequestToPath:@"pieces" method:@"GET" params:nil cookies:nil completionHandler:^(id data) {
        self.pieces=data;
        self.loaded=YES;
        [SVProgressHUD dismiss];
        [self.carousel reloadData];
    }];
}

-(void)addToFav
{
    NSDictionary* user=[Settings getUser];
    if(!user){
        [self performSegueWithIdentifier:@"auth" sender:nil];
        return;
    }
    
    [SVProgressHUD showWithStatus:@"收藏"];
    NSDictionary* piece=self.pieces[self.carousel.currentItemIndex];
    [HTTP sendRequestToPath:@"/fav" method:@"POST" params:@{@"pieceid":piece[@"id"]} cookies:@{@"cu":user[@"client_hash"]} completionHandler:^(id data) {
        if([data[@"code"] isEqualToNumber:@200]){
            [SVProgressHUD showSuccessWithStatus:@"成功"];
        }else{
            [SVProgressHUD showErrorWithStatus:@"失败"];
        }
    }];
}

-(void)shareToWeibo
{
    NSDictionary* user=[Settings getUser];
    if(!user){
        [self performSegueWithIdentifier:@"auth" sender:nil];
        return;
    }
    NSDictionary* piece=self.pieces[self.carousel.currentItemIndex];

    [SVProgressHUD showWithStatus:@"分享"];
    NSString* content=piece[@"content"];
        [WeiboHTTP sendRequestToPath:@"/statuses/update.json" method:@"POST" params:@{@"access_token":user[@"weibo_access_token"],@"status":content} completionHandler:^(id data) {
            [SVProgressHUD showSuccessWithStatus:@"成功"];
        }];
}

-(void)didSelectPiece:(NSDictionary*)peice
{
    if (!self.sideMenu.isOpen){
        [self.sideMenu open];
    }
}

#pragma mark -
#pragma mark iCarousel methods

- (NSUInteger)numberOfItemsInCarousel:(iCarousel *)carousel
{
    return self.pieces.count;
}

- (NSUInteger)numberOfVisibleItemsInCarousel:(iCarousel *)carousel
{
    //limit the number of items views loaded concurrently (for performance reasons)
    //this also affects the appearance of circular-type carousels
    return NUMBER_OF_VISIBLE_ITEMS;
}

- (UIView *)carousel:(iCarousel *)carousel viewForItemAtIndex:(NSUInteger)index reusingView:(UIView *)view
{
	//create new view if no view is available for recycling
	if (view == nil)
	{
        NSArray* nibViews = [[NSBundle mainBundle] loadNibNamed:@"PieceView"
                                                          owner:self
                                                        options:nil];
        view=[nibViews lastObject];
        ((PieceView*)view).delegate=self;
        
    }
    ((PieceView*)view).piece=self.pieces[index];
  	return view;
    
}

- (void)carouselWillBeginDragging:(iCarousel *)carousel;
{
    if(self.sideMenu.isOpen){
        [self.sideMenu close];
    }
}

- (CGFloat)carouselItemWidth:(iCarousel *)carousel
{
    //usually this should be slightly wider than the item views
    return ITEM_SPACING;
}

- (CGFloat)carousel:(iCarousel *)carousel itemAlphaForOffset:(CGFloat)offset
{
	//set opacity based on distance from camera
    return 1.0f - fminf(fmaxf(offset, 0.0f), 1.0f);
}

- (CATransform3D)carousel:(iCarousel *)_carousel itemTransformForOffset:(CGFloat)offset baseTransform:(CATransform3D)transform
{
    //implement 'flip3D' style carousel
    transform = CATransform3DRotate(transform, M_PI / 8.0f, 0.0f, 1.0f, 0.0f);
    return CATransform3DTranslate(transform, 0.0f, 0.0f, offset * self.carousel.itemWidth);
}


- (BOOL)carouselShouldWrap:(iCarousel *)carousel
{
    return YES;
}



-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:YES];
}



@end
