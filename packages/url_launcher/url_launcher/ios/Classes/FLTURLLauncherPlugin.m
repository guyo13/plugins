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

API_AVAILABLE(ios(9.0))
@interface FLTURLLaunchSession : NSObject <WKNavigationDelegate, WKUIDelegate>

@property(copy, nonatomic) FlutterResult flutterResult;
@property(strong, nonatomic) NSURL *url;
@property(strong, nonatomic) NSString *interceptUrlPattern;
//@property(strong, nonatomic) SFSafariViewController *safari;
@property(strong, nonatomic) WKWebView *wkWebView;
@property(strong, nonatomic) FlutterMethodChannel *channel;
@property(nonatomic, copy) void (^didFinish)(void);

@end

@implementation FLTURLLaunchSession

- (instancetype)initWithUrl:url withFlutterResult:result interceptUrl: pattern methodChannel: channel{
    NSLog(@"FLTURLLaunchSession-initWithUrl");
  self = [super init];
  if (self) {
      self.url = url;
      self.flutterResult = result;
      self.interceptUrlPattern = pattern;
      self.channel = channel;
    if (@available(iOS 9.0, *)) {
        CGRect screenRect = [UIScreen mainScreen].bounds;
        self.wkWebView = [[WKWebView alloc] initWithFrame:screenRect];
        self.wkWebView.navigationDelegate = self;
        self.wkWebView.UIDelegate= self;
        NSURLRequest *nsrequest=[NSURLRequest requestWithURL:self.url];
        [self.wkWebView loadRequest:nsrequest];
    }
  }
  return self;
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler API_AVAILABLE(ios(9.0)) {
    NSLog(@"FLTURLLaunchSession-decidePolicyForNavigationAction");
    if (self.interceptUrlPattern != nil &&
        self.interceptUrlPattern.length > 0) {
        if (navigationAction.request.URL != nil &&
            [navigationAction.request.URL.absoluteString containsString:self.interceptUrlPattern]) {
            NSLog(@"FLTURLLaunchSession-decidePolicyForNavigationAction - Intercepting %@ ", self.interceptUrlPattern);
            decisionHandler(WKNavigationActionPolicyCancel);
            //TODO - call method channel
            if(self.channel != nil) {
                NSLog(@"FLTURLLaunchSession-decidePolicyForNavigationAction - calling method channel");
                [self.channel invokeMethod:@"interceptUrl" arguments:navigationAction.request.URL.absoluteString];
                [self close];
            }
        }
        else {
            NSLog(@"FLTURLLaunchSession-decidePolicyForNavigationAction - Allowing %@ ", self.interceptUrlPattern);
            decisionHandler(WKNavigationActionPolicyAllow);
        }
    }
    else {
        //TODO - allow
        NSLog(@"FLTURLLaunchSession-decidePolicyForNavigationAction - no intercept URL found. Allowing %@ ", self.interceptUrlPattern);
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation API_AVAILABLE(ios(9.0)) {
    //This is begin called every time there is navigation!
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
    self.didFinish();
}

@end







API_AVAILABLE(ios(9.0))
@interface FLTURLLauncherPlugin ()

@property(strong, nonatomic) FLTURLLaunchSession *currentSession;
@property(strong, nonatomic) FlutterMethodChannel *channel;

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
  if ([@"canLaunch" isEqualToString:call.method]) {
    result(@([self canLaunchURL:url]));
  } else if ([@"launch" isEqualToString:call.method]) {
    NSNumber *useSafariVC = call.arguments[@"useSafariVC"];
    if (useSafariVC.boolValue) {
      if (@available(iOS 9.0, *)) {
          [self launchURLInVC:url result:result interceptUrl:interceptUrl];
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

- (void)launchURLInVC:(NSString *)urlString result:(FlutterResult)result interceptUrl:(NSString *)interceptUrl API_AVAILABLE(ios(9.0)) {
    NSLog(@"FLTURLLauncherPlugin-launchURLInVC");
  NSURL *url = [NSURL URLWithString:urlString];
    self.currentSession = [[FLTURLLaunchSession alloc] initWithUrl:url
                                                 withFlutterResult:result
                                                interceptUrl:interceptUrl
                                                     methodChannel:self.channel
                           ];
  __weak typeof(self) weakSelf = self;
  self.currentSession.didFinish = ^(void) {
    weakSelf.currentSession = nil;
    weakSelf.channel = nil;
  };
    [self.topViewController.view addSubview:self.currentSession.wkWebView];
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
