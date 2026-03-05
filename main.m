#include <stdio.h>
#include <spawn.h>
#include <unistd.h>
#include <libgen.h>
#include <sys/stat.h>
#include <mach-o/dyld.h>
#include <Foundation/Foundation.h>

#include "incbin.h"

INCBIN(TROLLSTORE_TAR, "trollstore/TrollStore.tar");
INCBIN(TROLLSTORE_HELPER, "trollstore/trollstorehelper");

extern char **environ;

@interface _LSApplicationState : NSObject
- (BOOL)isValid;
@end

@interface LSBundleProxy : NSObject
-(BOOL)isContainerized;
- (NSURL *)bundleURL;
- (NSURL *)containerURL;
- (NSURL *)dataContainerURL;
- (NSString *)bundleExecutable;
- (NSString *)bundleIdentifier;
@end

@interface LSPlugInKitProxy : LSBundleProxy
@end

@interface LSApplicationProxy : LSBundleProxy
+ (id)applicationProxyForIdentifier:(id)arg1;
- (id)localizedNameForContext:(id)arg1;
- (_LSApplicationState *)appState;
- (NSString *)vendorName;
- (NSString *)teamID;
- (NSString *)applicationType;
- (NSSet *)claimedURLSchemes;
- (BOOL)isDeletable;
- (NSDictionary*)environmentVariables;
@property (nonatomic,readonly) NSDictionary *groupContainerURLs;
@property (nonatomic,readonly) NSArray<LSPlugInKitProxy *> *plugInKitPlugins;
@end

@interface LSApplicationWorkspace : NSObject
+ (LSApplicationWorkspace*)defaultWorkspace;
- (BOOL)_LSPrivateRebuildApplicationDatabasesForSystemApps:(BOOL)arg1
												  internal:(BOOL)arg2
													  user:(BOOL)arg3;
- (BOOL)registerApplicationDictionary:(NSDictionary *)applicationDictionary;
- (BOOL)registerBundleWithInfo:(NSDictionary *)bundleInfo
					   options:(NSDictionary *)options
						  type:(unsigned long long)arg3
					  progress:(id)arg4;
- (BOOL)registerApplication:(NSURL *)url;
- (BOOL)registerPlugin:(NSURL *)url;
- (BOOL)unregisterApplication:(NSURL *)url;
- (NSArray *)installedPlugins;
- (void)_LSPrivateSyncWithMobileInstallation;
- (NSArray<LSApplicationProxy *> *)allApplications;
@end

void InstallTrollStore()
{
	NSString* tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
	[[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:nil];
	NSLog(@"tmpDir: %@", tmpDir);

	NSData* trollstoreTarData = [NSData dataWithBytes:gTROLLSTORE_TARData length:gTROLLSTORE_TARSize];
	NSString* trollstoreTarPath = [tmpDir stringByAppendingPathComponent:@"TrollStore.tar"];
	[trollstoreTarData writeToFile:trollstoreTarPath atomically:YES];

	NSData* trollstoreHelperData = [NSData dataWithBytes:gTROLLSTORE_HELPERData length:gTROLLSTORE_HELPERSize];
	NSString* trollstoreHelperPath = [tmpDir stringByAppendingPathComponent:@"trollstorehelper"];
	[trollstoreHelperData writeToFile:trollstoreHelperPath atomically:YES];

	chmod(trollstoreHelperPath.fileSystemRepresentation, 0755);

	const char* argv[]  = {trollstoreHelperPath.fileSystemRepresentation, "install-trollstore", trollstoreTarPath.fileSystemRepresentation, NULL};
	
	pid_t pid = -1;
	int ret = posix_spawn(&pid, argv[0], NULL, NULL, (char*const*)argv, environ);
	NSLog(@"posix_spawn returned %d, pid=%d", ret, pid);

	waitpid(pid, NULL, 0);

	[NSFileManager.defaultManager removeItemAtPath:tmpDir error:nil];
}

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

int main(int argc, char *argv[], char *envp[])
{
	NSLog(@"jbinit uid=%d,gid=%d,pid=%d,ppid=%d argv=%p envp=%p\n", getuid(), getgid(), getpid(), getppid(), argv, envp);

	if(fork() > 0) {
		// exit parent process so that launchd will respawn the real daemon
		return 0;
	}

	char path[PATH_MAX]={0};
	uint32_t pathSize = sizeof(path);
	_NSGetExecutablePath(path, &pathSize);

	if(getuid() != 0)
	{
		posix_spawnattr_t attr;
		posix_spawnattr_init(&attr);
		
		posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
		posix_spawnattr_set_persona_uid_np(&attr, 0);
		posix_spawnattr_set_persona_gid_np(&attr, 0);

		pid_t pid=0;
		int ret = posix_spawn(&pid, path, NULL, &attr, argv, envp);
		NSLog(@"posix_spawn returned %d, pid=%d", ret, pid);
		return ret;
	}

	//remove all jbinit files
	NSString* dirpath = @(dirname(path));
	for(NSString* item in [NSFileManager.defaultManager contentsOfDirectoryAtPath:dirpath error:nil]) {
		if([item hasPrefix:@".jbinit-"]) {
			NSError* error = nil;
			NSLog(@"Removing jbinit file: %@", item);
			[NSFileManager.defaultManager removeItemAtPath:[dirpath stringByAppendingPathComponent:item] error:&error];
			if(error) {
				NSLog(@"Error removing jbinit file: %@", error);
			}
		}
	}

	BOOL TrollStoreInstalled = NO;
	NSString* trollStorePath = nil;
	for(LSApplicationProxy* app in LSApplicationWorkspace.defaultWorkspace.allApplications)
	{
		if([app.bundleIdentifier hasPrefix:@"com.opa334.TrollStore"])
		{
			NSLog(@"Found TrollStore at %@", app.bundleURL);
			trollStorePath = app.bundleURL.path;
			TrollStoreInstalled = YES;
			// break;
		}

		if([app.bundleURL.path hasPrefix:@"/private/preboot/"]) {
			[LSApplicationWorkspace.defaultWorkspace unregisterApplication:app.bundleURL];
		}

	}

	NSString* message = @"\nPalera1n(roothide) boot successful.\n\n";
	NSString* buttonText = nil;
	if(TrollStoreInstalled) {
		message = [message stringByAppendingString:@"Please install and run the jailbreak app in TrollStore to continue."];
	} else {
		buttonText = @"Continue";
		message = [message stringByAppendingString:@"Press [Continue] to install TrollStore ..."];
	}

	//this is a sync call
	CFUserNotificationDisplayAlert(0, kCFUserNotificationCautionAlertLevel, NULL, NULL, NULL, CFSTR("Palera1n(roothide)"), (__bridge CFStringRef)message, (__bridge CFStringRef)buttonText, NULL, NULL, NULL);

	if(!TrollStoreInstalled)
	{
		NSMutableDictionary *alert = [[NSMutableDictionary alloc] init];
		CFOptionFlags flags = kCFUserNotificationCautionAlertLevel | kCFUserNotificationNoDefaultButtonFlag;

		alert[(__bridge NSString *)kCFUserNotificationAlertHeaderKey] = @"Palera1n(roothide)";
		alert[(__bridge NSString *)kCFUserNotificationAlertMessageKey] = @"\nInstalling TrollStore...\n";
		
		CFUserNotificationRef notif = CFUserNotificationCreate(kCFAllocatorDefault, 0, flags, NULL, (__bridge CFMutableDictionaryRef)alert);

		sleep(1);
		InstallTrollStore();
		sleep(1);

		CFUserNotificationCancel(notif);
		CFRelease(notif);

		buttonText = nil;
		message = @"\nTrollStore installed successful.\n\nPlease install and run the jailbreak app in TrollStore to continue.";
		CFUserNotificationDisplayAlert(0, kCFUserNotificationCautionAlertLevel, NULL, NULL, NULL, CFSTR("Palera1n(roothide)"), (__bridge CFStringRef)message, (__bridge CFStringRef)buttonText, NULL, NULL, NULL);
	}
	else
	{
		NSString* trollstoreHelperPath = [trollStorePath stringByAppendingPathComponent:@"trollstorehelper"];

		const char* argv[]  = {trollstoreHelperPath.fileSystemRepresentation, "refresh", NULL};

		pid_t pid = -1;
		int ret = posix_spawn(&pid, argv[0], NULL, NULL, (char*const*)argv, environ);
		NSLog(@"posix_spawn returned %d, pid=%d", ret, pid);

		waitpid(pid, NULL, 0);
	}

	// while(true) {
	// 	NSLog(@"jbinit...uid=%d,gid=%d,pid=%d,ppid=%d argv=%p envp=%p\n", getuid(), getgid(), getpid(), getppid(), argv, envp);
	// 	FILE* f = fopen("/var/jbinit.txt", "w+");
	// 	if(f) {
	// 		fprintf(f, "[%lu] jbinit...uid=%d,gid=%d,pid=%d,ppid=%d argv=%p envp=%p\n", time(NULL), getuid(), getgid(), getpid(), getppid(), argv, envp);
	// 		fclose(f);
	// 	}
	// 	sleep(1);
	// };
	
	return 0;
}
