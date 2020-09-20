// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

//#import <SafariServices/SafariServices.h>
#import <WebKit/WebKit.h>

#import "FLTURLLauncherPlugin.h"

//API_AVAILABLE(ios(9.0))
//@interface FLTURLLaunchSession : NSObject <SFSafariViewControllerDelegate>
//
//@property(copy, nonatomic) FlutterResult flutterResult;
//@property(strong, nonatomic) NSURL *url;
//@property(strong, nonatomic) SFSafariViewController *safari;
//@property(nonatomic, copy) void (^didFinish)(void);
//
//@end
//
//@implementation FLTURLLaunchSession
//
//- (instancetype)initWithUrl:url withFlutterResult:result {
//  self = [super init];
//  if (self) {
//    self.url = url;
//    self.flutterResult = result;
//    if (@available(iOS 9.0, *)) {
//      self.safari = [[SFSafariViewController alloc] initWithURL:url];
//      self.safari.delegate = self;
//    }
//  }
//  return self;
//}
//
//- (void)safariViewController:(SFSafariViewController *)controller
//      didCompleteInitialLoad:(BOOL)didLoadSuccessfully API_AVAILABLE(ios(9.0)) {
//  if (didLoadSuccessfully) {
//    self.flutterResult(nil);
//  } else {
//    self.flutterResult([FlutterError
//        errorWithCode:@"Error"
//              message:[NSString stringWithFormat:@"Error while launching %@", self.url]
//              details:nil]);
//  }
//}
//
//- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller API_AVAILABLE(ios(9.0)) {
//  [controller dismissViewControllerAnimated:YES completion:nil];
//  self.didFinish();
//}
//
//- (void)close {
//  [self safariViewControllerDidFinish:self.safari];
//}
//
//@end

typedef NS_ENUM(NSInteger, InterceptionType) {
    InterceptionTypeStartsWith,
    InterceptionTypeContains,
};

#define UIColorFromRGB(rgbValue) \
[UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
                green:((float)((rgbValue & 0x00FF00) >>  8))/255.0 \
                 blue:((float)((rgbValue & 0x0000FF) >>  0))/255.0 \
                alpha:1.0]
#define APP_BAR_HEIGHT 40

API_AVAILABLE(ios(9.0))
@interface FLTURLLaunchSession : NSObject <WKNavigationDelegate, WKUIDelegate, UINavigationBarDelegate>

@property(copy, nonatomic) FlutterResult flutterResult;
@property(strong, nonatomic) NSURL *url;
@property(strong, nonatomic) NSString *interceptUrlPattern;
@property(strong, nonatomic) WKWebView *wkWebView;
@property InterceptionType interceptionType;
@property(strong, nonatomic) FlutterMethodChannel *channel;
@property(nonatomic, copy) void (^didFinish)(void);

@end

@implementation FLTURLLaunchSession

+ (CGFloat)getTopOffset API_AVAILABLE(ios(9.0)) {
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets insets = UIApplication.sharedApplication.keyWindow.safeAreaInsets;
        return insets.top;
    } else {
        NSLog(@"Defaulting to top offset 20");
        return 20;
    }
}

+ (CGFloat)getBottomOffset API_AVAILABLE(ios(9.0)) {
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets insets = UIApplication.sharedApplication.keyWindow.safeAreaInsets;
        return insets.bottom;
    } else {
        NSLog(@"Defaulting bottom top offset 0");
        return 0;
    }
}

- (instancetype)initSession {
    NSLog(@"FLTURLLaunchSession-initSession");
  self = [super init];
  return self;
}
+ (WKWebView *)createWkWebView API_AVAILABLE(ios(9.0)) {
    CGFloat top = [FLTURLLaunchSession getTopOffset];
    CGFloat bottom = [FLTURLLaunchSession getBottomOffset];
    CGRect screenRect = [UIScreen mainScreen].bounds;
    CGRect position = (CGRect){
        .origin.x = 0,
        .origin.y = APP_BAR_HEIGHT + top,
        .size.width = screenRect.size.width,
        .size.height = screenRect.size.height - APP_BAR_HEIGHT - top - bottom
    };
    WKWebView *webView = [[WKWebView alloc] initWithFrame:position];
    return webView;
}
+ (NSString *)getTypeName:(InterceptionType)interceptionType {
    switch(interceptionType) {
        case InterceptionTypeContains:
            return @"InterceptionTypeContains";
        case InterceptionTypeStartsWith:
            return @"InterceptionTypeStartsWith";
    }
}
- (void)setWkWebView:(WKWebView *)wkWebView API_AVAILABLE(ios(9.0)) {
    _wkWebView = wkWebView;
    _wkWebView.navigationDelegate = self;
    _wkWebView.UIDelegate= self;
}

- (void)loadUrl API_AVAILABLE(ios(9.0)) {
    if (self.wkWebView != nil) {
        NSURLRequest *nsrequest=[NSURLRequest requestWithURL:self.url];
        [self.wkWebView loadRequest:nsrequest];
    }
    else {
        NSLog(@"Error loading request, wkWebView is null!");
    }
}

- (BOOL)needsInterception:(NSString *)url API_AVAILABLE(ios(9.0)) {
    if (self.interceptUrlPattern != nil && self.interceptUrlPattern.length > 0) {
        switch(self.interceptionType) {
            case InterceptionTypeContains:
                return [url containsString:self.interceptUrlPattern];
                break;
            case InterceptionTypeStartsWith:
                return [url hasPrefix:self.interceptUrlPattern];
                break;
        }
    } else { return false;}
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler API_AVAILABLE(ios(9.0)) {
    NSLog(@"FLTURLLaunchSession-decidePolicyForNavigationAction");
    NSString *requestUrl = navigationAction.request.URL.absoluteString;
    if ([self needsInterception:requestUrl]) {
        NSLog(@"FLTURLLaunchSession-decidePolicyForNavigationAction - Intercepting URL '%@' with Pattern '%@' and %@", navigationAction.request.URL.absoluteString, self.interceptUrlPattern, [FLTURLLaunchSession getTypeName:self.interceptionType]);
        decisionHandler(WKNavigationActionPolicyCancel);
       if(self.channel != nil) {
           NSLog(@"FLTURLLaunchSession-decidePolicyForNavigationAction - calling method channel");
           [self.channel invokeMethod:@"interceptUrl" arguments:navigationAction.request.URL.absoluteString];
       }
       [self close];
    } else {
        NSLog(@"FLTURLLaunchSession-decidePolicyForNavigationAction - Allowing %@ ", navigationAction.request.URL.absoluteString);
        decisionHandler(WKNavigationActionPolicyAllow);
    }
    
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation API_AVAILABLE(ios(9.0)) {
    //This is called every time there is navigation!
    //FIXME - minor - call only the first time!
    NSLog(@"FLTURLLaunchSession-didFinishNavigation");
    if (navigation != nil) {
    self.flutterResult(nil);
  } else {
    self.flutterResult([FlutterError
        errorWithCode:@"Error"
              message:[NSString stringWithFormat:@"Error while launching %@", self.url]
              details:nil]);
  }
}
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error API_AVAILABLE(ios(9.0)) {
    NSLog(@"FLTURLLaunchSession-didFailNavigation");
    self.flutterResult([FlutterError
    errorWithCode:@"Error"
          message:[NSString stringWithFormat:@"Error while launching %@", self.url]
          details:nil]);
}

- (void)webViewDidClose:(WKWebView *)webView API_AVAILABLE(ios(9.0)) {
    NSLog(@"FLTURLLaunchSession-webViewDidClose");
    [self close];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView API_AVAILABLE(ios(9.0)) {
    NSLog(@"FLTURLLaunchSession-webViewWebContentProcessDidTerminate");
    [self close];
}

- (void)close {
    NSLog(@"FLTURLLaunchSession-close");
    self.channel = nil;
    self.flutterResult = nil;
    self.url = nil;
    self.interceptUrlPattern = nil;
    self.didFinish();
}

- (UIBarPosition)positionForBar:(id<UIBarPositioning>)bar {
    return UIBarPositionBottom;
}

@end


API_AVAILABLE(ios(9.0))
@interface FLTURLLauncherPlugin ()

@property(strong, nonatomic) FLTURLLaunchSession *currentSession;
@property(strong, nonatomic) FlutterMethodChannel *channel;
@property(strong, nonatomic) WKWebView *webView;
@property(strong, nonatomic) UINavigationBar *myNav;

@end

@implementation FLTURLLauncherPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    NSLog(@"FLTURLLauncherPlugin-registerWithRegistrar");
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/url_launcher"
                                  binaryMessenger:registrar.messenger];
  FLTURLLauncherPlugin *plugin = [[FLTURLLauncherPlugin alloc] init];
    plugin.channel = channel;
  [registrar addMethodCallDelegate:plugin channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSLog(@"FLTURLLauncherPlugin-handleMethodCall");
  NSString *url = call.arguments[@"url"];
  NSString *interceptUrl = call.arguments[@"webUrlInterceptionPattern"];
    NSNumber *interceptStartsWith = call.arguments[@"interceptStartsWith"];
    NSNumber *interceptContains = call.arguments[@"interceptContains"];
    InterceptionType interceptionType = InterceptionTypeStartsWith;
    NSNumber *toolbarColor = call.arguments[@"toolbarColor"];
    NSNumber *toolbarTitleColor = call.arguments[@"toolbarTitleColor"];
    NSNumber *toolbarBackButtonColor = call.arguments[@"toolbarBackButtonColor"];
    NSString *toolbarTitle = call.arguments[@"toolbarTitle"];
    if (interceptContains.boolValue && interceptStartsWith.boolValue) {
        NSLog(@"Both interceptContains and interceptStartsWith specified. Defaulting to interceptStartsWith");
    } else if (interceptContains.boolValue) {
        interceptionType = InterceptionTypeContains;
    }
  if ([@"canLaunch" isEqualToString:call.method]) {
    result(@([self canLaunchURL:url]));
  } else if ([@"launch" isEqualToString:call.method]) {
    NSNumber *useSafariVC = call.arguments[@"useSafariVC"];
    if (useSafariVC.boolValue) {
      if (@available(iOS 9.0, *)) {
          [self launchURLInVC:url
                       result:result
                       interceptUrl:interceptUrl
                       interceptionType:interceptionType
                       toolbarColor:toolbarColor
                       toolbarTitleColor:toolbarTitleColor
                       toolbarBackButtonColor:toolbarBackButtonColor
                       toolbarTitle:toolbarTitle
           ];
      } else {
        [self launchURL:url call:call result:result];
      }
    } else {
      [self launchURL:url call:call result:result];
    }
  } else if ([@"closeWebView" isEqualToString:call.method]) {
    if (@available(iOS 9.0, *)) {
      [self closeWebViewWithResult:result];
    } else {
      result([FlutterError
          errorWithCode:@"API_NOT_AVAILABLE"
                message:@"SafariViewController related api is not availabe for version <= IOS9"
                details:nil]);
    }
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (BOOL)canLaunchURL:(NSString *)urlString {
    NSLog(@"FLTURLLauncherPlugin-canLaunchURL");
  NSURL *url = [NSURL URLWithString:urlString];
  UIApplication *application = [UIApplication sharedApplication];
  return [application canOpenURL:url];
}

- (void)launchURL:(NSString *)urlString
             call:(FlutterMethodCall *)call
           result:(FlutterResult)result {
    NSLog(@"FLTURLLauncherPlugin-launchURL");
  NSURL *url = [NSURL URLWithString:urlString];
  UIApplication *application = [UIApplication sharedApplication];

  if (@available(iOS 10.0, *)) {
    NSNumber *universalLinksOnly = call.arguments[@"universalLinksOnly"] ?: @0;
    NSDictionary *options = @{UIApplicationOpenURLOptionUniversalLinksOnly : universalLinksOnly};
    [application openURL:url
                  options:options
        completionHandler:^(BOOL success) {
          result(@(success));
        }];
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    BOOL success = [application openURL:url];
#pragma clang diagnostic pop
    result(@(success));
  }
}

- (void)launchURLInVC:(NSString *)urlString result:(FlutterResult)result
         interceptUrl:(NSString *)interceptUrl
         interceptionType:(InterceptionType)interceptionType
         toolbarColor:(NSNumber *)toolbarColor
         toolbarTitleColor:(NSNumber *)toolbarTitleColor
         toolbarBackButtonColor:(NSNumber *)toolbarBackButtonColor
         toolbarTitle:(NSString *)toolbarTitle API_AVAILABLE(ios(9.0)) {
    NSLog(@"FLTURLLauncherPlugin-launchURLInVC");
  NSURL *url = [NSURL URLWithString:urlString];
    self.currentSession = [[FLTURLLaunchSession alloc] initSession];
    self.currentSession.url = url;
    self.currentSession.interceptUrlPattern = interceptUrl;
    self.currentSession.interceptionType = interceptionType;
    self.currentSession.flutterResult = result;
    self.currentSession.channel = self.channel;
    //Reuse webview object
    if (self.webView == nil) {
        NSLog(@"FLTURLLauncherPlugin - creating new WebView!");
        self.webView = [FLTURLLaunchSession createWkWebView];
    }
    [self.currentSession setWkWebView:self.webView];
    
  __weak typeof(self) weakSelf = self;
  self.currentSession.didFinish = ^(void) {
     [weakSelf.webView removeFromSuperview];
      weakSelf.currentSession.wkWebView = nil;
    weakSelf.currentSession = nil;
  };

    CGFloat topOffset = [FLTURLLaunchSession getTopOffset];
    NSLog(@"Top offset %f", topOffset);
    //Height isn't taken into account here just width
    self.myNav = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, topOffset, [UIScreen mainScreen].bounds.size.width, 0)];
    [UINavigationBar appearance].barTintColor = UIColorFromRGB(toolbarColor.intValue);
    self.myNav.delegate = self.currentSession;
    self.myNav.titleTextAttributes = @{
        NSForegroundColorAttributeName : UIColorFromRGB(toolbarTitleColor.intValue)
    };
    UINavigationItem *navigItem = [[UINavigationItem alloc] initWithTitle:toolbarTitle];
    navigItem.backBarButtonItem.tintColor = UIColorFromRGB(toolbarBackButtonColor.intValue);
    navigItem.hidesBackButton = false;
    self.myNav.items = [NSArray arrayWithObjects: navigItem,nil];
    
    [self.currentSession loadUrl];
    [self.topViewController.view addSubview:self.webView];
    [self.topViewController.view addSubview:self.myNav];
}

- (void)closeWebViewWithResult:(FlutterResult)result API_AVAILABLE(ios(9.0)) {
    NSLog(@"FLTURLLauncherPlugin-closeWebViewWithResult");
  if (self.currentSession != nil) {
    [self.currentSession close];
  }
  result(nil);
}

- (UIViewController *)topViewController {
    NSLog(@"FLTURLLauncherPlugin-topViewController");
  return [self topViewControllerFromViewController:[UIApplication sharedApplication]
                                                       .keyWindow.rootViewController];
}

/**
 * This method recursively iterate through the view hierarchy
 * to return the top most view controller.
 *
 * It supports the following scenarios:
 *
 * - The view controller is presenting another view.
 * - The view controller is a UINavigationController.
 * - The view controller is a UITabBarController.
 *
 * @return The top most view controller.
 */
- (UIViewController *)topViewControllerFromViewController:(UIViewController *)viewController {
  if ([viewController isKindOfClass:[UINavigationController class]]) {
    UINavigationController *navigationController = (UINavigationController *)viewController;
    return [self
        topViewControllerFromViewController:[navigationController.viewControllers lastObject]];
  }
  if ([viewController isKindOfClass:[UITabBarController class]]) {
    UITabBarController *tabController = (UITabBarController *)viewController;
    return [self topViewControllerFromViewController:tabController.selectedViewController];
  }
  if (viewController.presentedViewController) {
    return [self topViewControllerFromViewController:viewController.presentedViewController];
  }
  return viewController;
}
@end
