//
//  SceneDelegate.h
//  PlayTools
//
//  Created by José Elias Moreno villegas on 17/10/22.
//

#import <UIKit/UIKit.h>

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (strong, nonatomic) UIWindow * window;

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
    
#if TARGET_OS_MACCATALYST
    // Code specific to Mac.
    
    [(UIWindowScene *)scene titlebar].titleVisibility = UITitlebarTitleVisibilityHidden;
    
    [(UIWindowScene *)scene titlebar].toolbar = nil;
    
#else
    // Code to exclude from Mac.
#endif

}

@end


