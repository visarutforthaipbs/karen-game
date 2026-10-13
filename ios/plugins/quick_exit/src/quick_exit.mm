// QuickExit — Godot iOS plugin for Under Two Skies.
//
// Problem (crash logs 2026-10-13, 0x8BADF00D "Failed to terminate gracefully after
// 5.0s"): on -applicationWillTerminate: Godot 4.7.2 runs the full Main::cleanup(),
// which frees every node; freeing a ShaderMaterial waits for its in-flight Metal
// pipeline compile (MTLCompilerScheduler). That can exceed iOS's 5 s budget and
// the watchdog kills the app, which TestFlight/App Store Connect record as a crash.
//
// Fix: replace -[GDTApplicationDelegate applicationWillTerminate:] with an
// immediate _exit(0). Safe for this game: the campaign is saved synchronously when
// a burn ends (SaveGame.save in VillageHearth), settings are written on change and
// on focus-out/pause (MainController), and nothing persists state in teardown.
// iOS always resigns active before terminating, so the focus-out flush has run.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <unistd.h>

static BOOL qe_patch(NSString *class_name) {
	Class cls = NSClassFromString(class_name);
	if (cls == nil) {
		return NO;
	}
	SEL sel = @selector(applicationWillTerminate:);
	Method m = class_getInstanceMethod(cls, sel);
	if (m == NULL) {
		return NO;
	}
	IMP fast = imp_implementationWithBlock(^(id self_, UIApplication *app) {
		NSLog(@"[QuickExit] applicationWillTerminate: exiting immediately (state already persisted)");
		_exit(0);
	});
	method_setImplementation(m, fast);
	return YES;
}

// Called by Godot at engine start (name set in quick_exit.gdip). Godot declares
// it from Objective-C++ with C++ linkage, so no extern "C" here.
void quick_exit_init() {
	BOOL a = qe_patch(@"GDTApplicationDelegate");
	BOOL b = qe_patch(@"GDTAppDelegateService");
	NSLog(@"[QuickExit] installed: GDTApplicationDelegate=%d GDTAppDelegateService=%d", a, b);
}

void quick_exit_deinit() {
}
