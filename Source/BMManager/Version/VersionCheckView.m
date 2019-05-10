//
//  VersionCheckView.m
//  BangSale
//
//  Created by 马守印 on 2018/8/31.
//  Copyright © 2018年 bang. All rights reserved.
//

#import "VersionCheckView.h"
#import "Masonry.h"

@implementation VersionCheckView

- (instancetype)initWithFrame:(CGRect)frame{
    
    if (self == [super initWithFrame:frame]) {
        
        self.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.5f];
        
        _dataArrs = [[NSArray alloc]init];

        UIImageView *bgImg = [[UIImageView alloc] init];
        bgImg.image = [UIImage imageNamed:@"version_bg"];
        
        [self addSubview:bgImg];
        [self addSubview:self.versionLab];
        [self addSubview:self.updateBtn];
        [self addSubview:self.tableView];
    
        [bgImg mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.mas_equalTo(self);
            make.size.mas_equalTo(CGSizeMake(280, 350));
        }];
        
        [self.versionLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(bgImg.mas_top).offset(30);
            make.centerX.mas_equalTo(self);
        }];
        
        [self.updateBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.size.mas_equalTo(CGSizeMake(100, 30));
            make.centerX.mas_equalTo(self);
            make.bottom.equalTo(bgImg.mas_bottom).offset(-15);
        }];
        
        [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.mas_equalTo(self);
            make.height.mas_equalTo(80);
            make.bottom.equalTo(self.updateBtn.mas_top).offset(-15);
            make.width.mas_equalTo(280);
        }];
    }

    return self;
}

#pragma mark----注释
- (void) updateBtnClick{
    NSLog(@"立即更新");
    [_delegate updateBtnIsClick];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _dataArrs.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"versionCell"];
    if (cell == nil){
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"versionCell"];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    [cell.textLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(cell.mas_left).offset(50);
        make.right.mas_equalTo(cell.mas_right).offset(-50);
    }];
    cell.textLabel.text = _dataArrs[indexPath.row];
    
    return cell;
}
#pragma mark----懒加载

- (UILabel *)versionLab{
    
    if(!_versionLab){
        
        _versionLab = [[UILabel alloc]init];
        _versionLab.text = @"版本更新";
        _versionLab.textColor = [UIColor whiteColor];
        if (@available(iOS 8.2, *)) {
            _versionLab.font = [UIFont systemFontOfSize:18 weight: UIFontWeightBold];
        } else {
            // Fallback on earlier versions
        }
    }
    return _versionLab;
}

- (UITableView *) tableView{
    
    if(!_tableView){
        _tableView = [[UITableView alloc] init];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.scrollEnabled = NO;
        [_tableView registerClass: [UITableViewCell class] forCellReuseIdentifier:@"versionCell"];
        _tableView.rowHeight = 20;
    }
    return _tableView;
}

- (UIButton *)updateBtn{
    
    if(!_updateBtn){
        _updateBtn = [[UIButton alloc]init];
//        [_updateBtn setTitle:@"立即更新" forState:UIControlStateNormal];
        [_updateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _updateBtn.backgroundColor = [UIColor colorWithRed:0.0f green:170.0f blue:238.0f alpha:1.0f];
        _updateBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        _updateBtn.layer.cornerRadius = 15;
        _updateBtn.layer.masksToBounds = YES;
        [_updateBtn addTarget:self action:@selector(updateBtnClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _updateBtn;
}
- (void)setDataArrs:(NSArray *)dataArrs{
    _dataArrs = dataArrs;
    NSLog(@"%@",dataArrs);
    [_tableView reloadData];
}

- (void)setBtnTitle:(NSString *)btnTitle{
    _btnTitle = btnTitle;
    [_updateBtn setTitle:btnTitle forState:UIControlStateNormal];
}

@end
