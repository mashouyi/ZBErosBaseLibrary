//
//  VersionCheckView.h
//  BangSale
//
//  Created by 马守印 on 2018/8/31.
//  Copyright © 2018年 bang. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol VersionCheckViewDelegate <NSObject>

- (void) updateBtnIsClick;

@end

@interface VersionCheckView : UIView<UITableViewDelegate,UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *updateBtn;
@property (nonatomic, strong) UILabel *versionLab;
@property (nonatomic, strong) NSArray *dataArrs;
@property (nonatomic, strong) NSString *btnTitle;
// 代理
@property (nonatomic, assign)id<VersionCheckViewDelegate>delegate;

@end
