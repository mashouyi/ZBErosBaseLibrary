//
//  BMUploadImageUtils.m
//  WeexDemo
//
//  Created by XHY on 2017/2/10.
//  Copyright © 2017年 taobao. All rights reserved.
//

#import "BMUploadImageUtils.h"
#import "BMDefine.h"
#import "UIImage+Util.h"
#import "NSDictionary+Util.h"
#import <SVProgressHUD.h>

#import <MobileCoreServices/MobileCoreServices.h>

#import "BMUploadImageRequest.h"

#import <TZImagePickerController/TZImagePickerController.h>
#import <TZImagePickerController/TZImageManager.h>

#import <SDWebImage/SDImageCache.h>



@interface BMUploadImageUtils () <UIActionSheetDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate,UIAlertViewDelegate>

@property (nonatomic, weak) WXSDKInstance *weexInstance;
@property (nonatomic, copy) WXModuleCallback callback;
@property (nonatomic, strong) BMUploadImageModel *imageInfo;
@property (nonatomic, assign) BOOL isLocal; /**< 通过此参数判断是否返回本地的图片地址 */

@end

@implementation BMUploadImageUtils

#pragma mark - Setter / Getter

#pragma mark - Custom Views

#pragma mark - Api Request


/* 先将图片上传至图片服务器然后在将返回的图片id上传至后台服务器 */
-(void)uploadImage:(NSArray<UIImage *> *)images
{
    [SVProgressHUD showWithStatus:@"处理中.."];
    
    NSMutableArray *arr4Request = [NSMutableArray array];
    for (UIImage *image in images) {
        BMUploadImageRequest *api = [[BMUploadImageRequest alloc] initWithImage:image uploadImageModel:self.imageInfo];
        [arr4Request addObject:api];
    }
    
    YTKBatchRequest *batchRequest = [[YTKBatchRequest alloc] initWithRequestArray:arr4Request];
    
    [batchRequest startWithCompletionBlockWithSuccess:^(YTKBatchRequest * _Nonnull batchRequest) {
        
        [SVProgressHUD dismiss];
        
        NSMutableArray *arr4ImagesUrl = [NSMutableArray array];
        
        for (BMUploadImageRequest *request in batchRequest.requestArray) {
            id result = [request responseObject];
            [arr4ImagesUrl addObject:result ?: @""];
        }
        if (self.callback) {
            NSDictionary *backData = [NSDictionary configCallbackDataWithResCode:BMResCodeSuccess msg:nil data:arr4ImagesUrl];
            self.callback(backData);
        }
        
    } failure:^(YTKBatchRequest * _Nonnull batchRequest) {
        [SVProgressHUD dismiss];

        if (self.callback) {
            // 获取错误code
            NSNumber *errorCode = [NSNumber numberWithInteger:batchRequest.failedRequest.responseStatusCode ?: -1];
            NSString *msg = [NSString getStatusText:[errorCode integerValue]];
            NSDictionary *resData = @{
                                      @"status": errorCode,
                                      @"errorMsg": msg,
                                      @"data": @{}
                                      };
            self.callback(resData);
        }
        
    }];
}

#pragma mark - Private Method
- (void)selectImage
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:@"取消"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"拍照", @"去相册选择", nil];
    
    [sheet showInView:[UIApplication sharedApplication].keyWindow];
}

//相册
-(void)LocalPhoto{
    
    [self getFileList];
    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:self.imageInfo.maxCount delegate:nil];
    
    /* 设置图片自动裁剪尺寸 */
    
    if (self.imageInfo.imageWidth > 0) {
        imagePickerVc.photoWidth = self.imageInfo.imageWidth;
    }
    
    /* 设置不允许选择视频/gif/原图 */
    imagePickerVc.allowPickingVideo = NO;
    imagePickerVc.allowPickingGif = NO;
    imagePickerVc.allowPickingOriginalPhoto = NO;
    imagePickerVc.allowTakePicture = NO;
    imagePickerVc.allowCrop = NO;
    /* 判断是否是上传头像如果是则 允许裁剪图片 */
    if (self.imageInfo.allowCrop && self.imageInfo.maxCount == 1) {
        imagePickerVc.allowCrop = YES;
        imagePickerVc.cropRect = CGRectMake(0, ([UIScreen mainScreen].bounds.size.height - [UIScreen mainScreen].bounds.size.width) / 2.0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width);
    }
    
    __weak typeof(self)weakSelf = self;
    [imagePickerVc setDidFinishPickingPhotosHandle:^(NSArray<UIImage *> *photos, NSArray *assets, BOOL isSelectOriginalPhoto) {
        
        if (weakSelf.isLocal) {
            [weakSelf cacheImages:photos];
        } else {
            [weakSelf uploadImage:photos];
        }
    }];
    
    [self.weexInstance.viewController presentViewController:imagePickerVc animated:YES completion:nil];
    
}

//拍照
-(void)takePhoto{
    
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied) {
        // 无相机权限 做一个友好的提示
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"无法使用相机" message:@"请在iPhone的""设置-隐私-相机""中允许访问相机" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
        [alert show];
        // 拍照之前还需要检查相册权限
    } else if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusDenied) { // 已被拒绝，没有相册权限，将无法保存拍的照片
        UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"无法访问相册" message:@"请在iPhone的""设置-隐私-相册""中允许访问相册" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
        alert.tag = 1;
        [alert show];
    } else { // 调用相机
        //资源类型为照相机
        UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
        //判断是否有相机
        if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]){
            UIImagePickerController *picker = [[UIImagePickerController alloc] init];
            picker.delegate = self;
            /* 判断是否是上传头像如果是则 允许裁剪图片 */
            if (self.imageInfo.allowCrop) picker.allowsEditing = YES;
            //资源类型为照相机
            picker.sourceType = sourceType;
            if (self.imageInfo.isFront){
                picker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
            }else {
                picker.cameraDevice = UIImagePickerControllerCameraDeviceRear;
            }
            [self.weexInstance.viewController presentViewController:picker animated:YES completion:nil];
            
        }else {
            WXLogInfo(@"该设备无摄像头");
        }
    }
}

- (void)saveImage:(UIImage *)image {
    
    if (!image) {
        return;
    }
    // 图片保存到系统相册
//    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized || [PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined) {
//        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
//            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
//        } completionHandler:nil];
//    }
    
    @weakify(self);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
     
        @strongify(self);
        CGSize asize = CGSizeMake(self.imageInfo.imageWidth, self.imageInfo.imageWidth * image.size.height / image.size.width);
        
        UIImage *smallImage = [image imageToSize:asize];

        if (!smallImage) {
            WXLogError(@"图片不存在");
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (self.isLocal) {
                //缓存图片到本地
                [self cacheImages:@[smallImage]];
            } else {
                //上传服务器
                [self uploadImage:@[smallImage]];
            }
            
        });
        
    });
}

//- (NSString *)convertStrToTime:(NSString *)timeStr withFormatter: (NSString *)formatterStr {
//    long long time=[timeStr longLongValue];
//    NSDate *d = [[NSDate alloc]initWithTimeIntervalSince1970:time/1000.0];
//    NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
//    [formatter setDateFormat:formatterStr];
//    NSString *timeString = [formatter stringFromDate:d];
//    return timeString;
//}
/** 将图片缓存到沙盒 */
//- (void) saveImg: (UIImage *) image {
//
//    NSString *str = [self convertStrToTime:[self getCurrentTimeString] withFormatter:@"yyyy-MM-dd HH:mm:ss"];
//
//    NSString * docsdir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//    NSString *dataFilePath = [docsdir stringByAppendingPathComponent:@"bangsale"]; // 在Document目录下创建 "archiver" 文件夹
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//    BOOL isDir = NO;
//    // fileExistsAtPath 判断一个文件或目录是否有效，isDirectory判断是否一个目录
//    BOOL existed = [fileManager fileExistsAtPath:dataFilePath isDirectory:&isDir];
//
//    if (!(isDir && existed)) {
//        // 在Document目录下创建一个archiver目录
//        [fileManager createDirectoryAtPath:dataFilePath withIntermediateDirectories:YES attributes:nil error:nil];
//    }
//    NSString *path = [dataFilePath stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@.png",str]];
//    NSData *data = UIImageJPEGRepresentation(image,0.8);
//    NSData *data= UIImagePNGRepresentation(image);
//    [data writeToFile:path atomically:YES];
//    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES)lastObject]stringByAppendingPathComponent:[NSString stringWithFormat:@"bangsale/%@.png",str]];
//    NSLog(@"%@",path);
//    //图片是png格式的转化
//    NSData *data = UIImageJPEGRepresentation(image,0.8);
//    //图片是png格式的转化
////    NSData *data= UIImagePNGRepresentation(image);
//    [data writeToFile:path atomically:YES];
//    NSArray *photoArr = [self getImageArrayWithName:@"bangsale"];
//    NSLog(@"%@",photoArr);
//}

/** 将图片缓存到磁盘 */
- (void)cacheImages:(NSArray *)images
{
    @weakify(self);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @strongify(self);
        NSMutableArray *imagesPath = [[NSMutableArray alloc] init];
        for (UIImage *img in images) {
            NSString *path = [self saveImage2Disk:img];
            [imagesPath addObject:path];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.callback) {
                NSDictionary *backData = [NSDictionary configCallbackDataWithResCode:BMResCodeSuccess msg:nil data:imagesPath];
                self.callback(backData);
            }
        });
    });
}

#pragma mark - Custom Delegate & DataSource


#pragma mark - System Delegate & DataSource

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    if (buttonIndex == 1) {
        [self LocalPhoto];
    }
    else if (buttonIndex == 0) {
        [self takePhoto];
    }
    
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { // 去设置界面，开启相机访问权限
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    if ([[info objectForKey:UIImagePickerControllerMediaType] isEqualToString:(__bridge NSString *)kUTTypeImage]) {
        UIImage *img = [info objectForKey:UIImagePickerControllerEditedImage];
        if (!img) img = [info objectForKey:UIImagePickerControllerOriginalImage];
        
//        UIImage *waterImg = [self waterImageWithImage:img waterImage: [UIImage imageNamed:@"logo.png"] text:@"邦营销" textPoint:CGPointMake(900, 900) attributedString:@{NSFontAttributeName:[UIFont systemFontOfSize:120], NSForegroundColorAttributeName: [UIColor greenColor]} waterImageRect: CGRectMake(700, 870, 180, 180) timeText:[self getCurrentTimeString]];
//        [self saveImg:waterImg];
        [self saveImage:img];
    }
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void) getFileList{
    
    NSString *string = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];

    NSArray *fileList = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:string error:nil] pathsMatchingExtensions:@[@".png"]];
    
    NSLog(@"%@",fileList);
}
// 获取保存到文件下所有图片
- (NSMutableArray *)getImageArrayWithName:(NSString *)fileName{

    NSMutableArray * imageArray = [NSMutableArray array];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString * path = [paths[0]stringByAppendingPathComponent:fileName];

    if (![[NSFileManager defaultManager]fileExistsAtPath:path]){//判断createPath路径文件夹是否已存在，不存在直接返回
         return imageArray;
    }
    //此文件夹下所有图片名称
    NSArray *filesNameArray = [[NSFileManager defaultManager]
                                   subpathsOfDirectoryAtPath:path error:nil];
    if (filesNameArray && filesNameArray.count !=0 ) {
        
        for (int i =0 ; i < filesNameArray.count; i++) {
             UIImage * image = [UIImage imageWithContentsOfFile:[path stringByAppendingPathComponent:filesNameArray[i]]];
            [imageArray addObject:image];
        }
    }
    return imageArray;
}

// 给图片添加文字水印：
- (UIImage *)waterImageWithImage:(UIImage *)image waterImage:(UIImage *)waterImage text:(NSString *)text textPoint:(CGPoint)point attributedString:(NSDictionary * )attributed waterImageRect:(CGRect)rect timeText: (NSString *)timeText  {
    //1.开启上下文
    UIGraphicsBeginImageContextWithOptions(image.size, NO, 0);
    //2.绘制图片
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    //绘制水印图片到当前上下文
    [waterImage drawInRect:rect];
    //添加水印文字
    [text drawAtPoint:point withAttributes:attributed];
    [timeText drawInRect:CGRectMake(600, 1050, 1000, 140) withAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:80], NSForegroundColorAttributeName: [UIColor greenColor]}];
    //3.从上下文中获取新图片
    UIImage * newImage = UIGraphicsGetImageFromCurrentImageContext();
    //4.关闭图形上下文
    UIGraphicsEndImageContext();
    //返回图片
    return newImage;
}
//------------------------------------------------------------------------------------
#pragma mark - 将图片保存到本地
//------------------------------------------------------------------------------------
//获取当前时间字符串
- (NSString *)getCurrentTimeString
{
    return [NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970] * 1000];
}

#pragma mark ---------图片管理-----------
//获取图片完整路径
- (NSString *)getImagePath{
    
    NSString *path = NSHomeDirectory();
    path = [path stringByAppendingPathComponent:@"Library/Caches/images"];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:path]) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *filePath = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg",[self getCurrentTimeString]]];
    return filePath;
}

//图片保存本地
- (NSString *)saveImage2Disk:(UIImage *)tempImage
{
    NSData *imageData=UIImageJPEGRepresentation(tempImage, 1);
    NSString *path=[self getImagePath];
    if ([imageData writeToFile:path atomically:YES]) {
        return path;
    }
    return @"";
}

#pragma mark - Public Method

- (void)uploadImageWithInfo:(BMUploadImageModel *)info weexInstance:(WXSDKInstance *)weexInstance callback:(WXModuleCallback)callback
{
    self.isLocal = NO;
    self.imageInfo = info;
    self.weexInstance = weexInstance;
    self.callback = callback;
    [self selectImage];
}

- (void)uploadImage:(NSArray *)images uploadImageModel:(BMUploadImageModel *)info callback:(WXModuleCallback)callback
{
    self.isLocal = NO;
    self.callback = callback;
    self.imageInfo = info;
    
    @weakify(self);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @strongify(self);
        NSMutableArray *imgs = [[NSMutableArray alloc] initWithCapacity:images.count];
        for (id item in images) {
            if ([item isKindOfClass:[UIImage class]]) {
                [imgs addObject:item];
            }
            else if ([item isKindOfClass:[NSString class]])
            {
                NSString *imgPath = (NSString *)item;
                if ([imgPath hasPrefix:BM_LOCAL])
                {
                    // 拦截器
                    if (BM_InterceptorOn()) {
                        NSURL *imgUrl = [NSURL URLWithString:imgPath];
                        // 从jsbundle读取图片
                        NSString *imgPath = [NSString stringWithFormat:@"%@/%@%@",K_JS_PAGES_PATH,imgUrl.host,imgUrl.path];
                        UIImage *img = [UIImage imageWithContentsOfFile:imgPath];
                        
                        if (img) {
                            [imgs addObject:img];
                        } else {
                            WXLogError(@"加载jsbundle中图片失败:%@",imgPath);
                        }
                        
                    } else {
                        WXLogError(@"拦截器关闭状态下不支持上传jsbundle中的图片");
                    }
                }
                else if (![imgPath hasPrefix:@"http"])
                {
                    NSFileManager *fm = [NSFileManager defaultManager];
                    if ([fm fileExistsAtPath:imgPath]) {
                        UIImage *img = [UIImage imageWithContentsOfFile:imgPath];
                        if (img) {
                            [imgs addObject:img];
                        } else {
                            WXLogError(@"加载本地图片失败：%@",imgPath);
                        }
                    } else {
                        WXLogError(@"本地图片不存在：%@",imgPath);
                    }
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self uploadImage:imgs];
        });
    });
}

- (void)camera:(BMUploadImageModel *)info weexInstance:(WXSDKInstance *)weexInstance callback:(WXModuleCallback)callback
{
    self.isLocal = YES;
    self.imageInfo = info;
    self.callback = callback;
    self.weexInstance = weexInstance;
    [self takePhoto];
}

- (void)pick:(BMUploadImageModel *)info weexInstance:(WXSDKInstance *)weexInstance callback:(WXModuleCallback)callback
{
    self.isLocal = YES;
    self.imageInfo = info;
    self.callback = callback;
    self.weexInstance = weexInstance;
    [self LocalPhoto];
}

@end
