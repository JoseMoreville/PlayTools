//
//  PlayLoader.m
//  PlayTools
//
#import "PlayLoader.h"
#import <PlayTools/PlayTools-Swift.h>
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#import <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#import <sys/utsname.h>
#include <unistd.h>
#import "NSObject+Swizzle.h"
#include "sandbox.h"
@import Darwin.POSIX.ioctl;

#define SYSTEM_INFO_PATH "/System/Library/CoreServices/SystemVersion.plist"
#define IOS_SYSTEM_INFO_PATH "/System/Library/CoreServices/iOSSystemVersion.plist"

#define CS_OPS_STATUS 0            /* return status */
#define CS_OPS_ENTITLEMENTS_BLOB 7 /* get entitlements blob */
#define CS_OPS_IDENTITY 11         /* get codesign identity */

int dyld_get_active_platform();

int my_dyld_get_active_platform() { return 2; }

extern void *dyld_get_base_platform(void *platform);

void *my_dyld_get_base_platform(void *platform) { return 2; }

#define DEVICE_MODEL ("iPad13,8")
// #define DEVICE_MODEL ("iPad8,6")

// find Mac by using sysctl of HW_TARGET
#define OEM_ID ("J522AP")
//#define OEM_ID ("J320xAP")

static int my_uname(struct utsname *uts) {
  int result = 0;
  NSString *nickname = @"ipad";
//   NSString *productType = @"iPad13,8";
  NSString *productType = @"iPad8,6";
  if (nickname.length == 0)
    result = uname(uts);
  else {
    strncpy(uts->nodename, [nickname UTF8String], nickname.length + 1);
    strncpy(uts->machine, [productType UTF8String], productType.length + 1);
  }
  return result;
}

static int my_sysctl(int *name, u_int types, void *buf, size_t *size, void *arg0, size_t arg1) {
  if (name[0] == CTL_HW && (name[1] == HW_MACHINE || name[0] == HW_PRODUCT)) {
    if (NULL == buf) {
      *size = strlen(DEVICE_MODEL) + 1;
    } else {
      if (*size > strlen(DEVICE_MODEL)) {
        strcpy(buf, DEVICE_MODEL);
      } else {
        return ENOMEM;
      }
    }
    return 0;
  } else if (name[0] == CTL_HW && (name[1] == HW_TARGET)) {
    if (NULL == buf) {
      *size = strlen(OEM_ID) + 1;
    } else {
      if (*size > strlen(OEM_ID)) {
        strcpy(buf, OEM_ID);
      } else {
        return ENOMEM;
      }
    }
    return 0;
  }

  return sysctl(name, types, buf, size, arg0, arg1);
}

static int my_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp,
                           size_t newlen) {
  if ((strcmp(name, "hw.machine") == 0) || (strcmp(name, "hw.product") == 0) ||
      (strcmp(name, "hw.model") == 0)) {
    if (oldp != NULL) {
      int ret = sysctlbyname(name, oldp, oldlenp, newp, newlen);
      const char *mechine = DEVICE_MODEL;
      strncpy((char *)oldp, mechine, strlen(mechine));
      return ret;
    } else {
      int ret = sysctlbyname(name, oldp, oldlenp, newp, newlen);
      return ret;
    }
  } else if ((strcmp(name, "hw.target") == 0)) {
    if (oldp != NULL) {
      int ret = sysctlbyname(name, oldp, oldlenp, newp, newlen);
      const char *mechine = OEM_ID;
      strncpy((char *)oldp, mechine, strlen(mechine));
      return ret;
    } else {
      int ret = sysctlbyname(name, oldp, oldlenp, newp, newlen);
      return ret;
    }
  } else {
    return sysctlbyname(name, oldp, oldlenp, newp, newlen);
  }
}

// Useful for debugging:
 static int my_open(const char *path, int flags, mode_t mode) {
   mode = 0644;
   int value = open(path, flags, mode);
   if (value == -1) {
     printf("[Lucas] open (%s): %s\n", strerror(errno), path);
   }

   return value;
 }

 static int my_create(const char *path, mode_t mode) {
   int value = creat(path, mode);
   if (value == -1) {
     printf("[Lucas] create (%s): %s\n", strerror(errno), path);
   }
   return value;
 }

 static int my_mkdir(const char *path, mode_t mode) {
   int value = mkdir(path, mode);
   if (value == -1) {
     printf("[Lucas] mkdir (%s): %s\n", strerror(errno), path);
   }
   return value;
 }

 static int my_lstat(const char *restrict path, void *restrict buf) {
   int value = lstat(path, buf);
   if (value == -1) {
     printf("[Lucas] lstat (%s): %s\n", strerror(errno), path);
   }
   return value;
 }

// get and printf window size
 static int my_ioctl(int fd, unsigned long request, void *arg) {
   int value = ioctl(fd, request, arg);
   printf("[Lucas] ioctl (%s): %d\n", strerror(errno), value);
   if (value == -1) {
    // declare path
    char path[1024];
    printf("[Lucas] ioctl (%s): %s\n", strerror(errno), path);
  }
  return value;
}


static bool isGenshin = false;

extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);

int my_csops(pid_t pid, uint32_t ops, user_addr_t useraddr, user_size_t usersize) {
  if (isGenshin) {
    if (ops == CS_OPS_STATUS || ops == CS_OPS_IDENTITY) {
      printf("Hooked CSOPS %d \n", ops);
        printf("Hooked tests");
      return 0;
    }
  }

  return csops(pid, ops, useraddr, usersize);
}

DYLD_INTERPOSE(my_csops, csops)
DYLD_INTERPOSE(my_ioctl, ioctl)
DYLD_INTERPOSE(my_dyld_get_active_platform, dyld_get_active_platform)
DYLD_INTERPOSE(my_dyld_get_base_platform, dyld_get_base_platform)
DYLD_INTERPOSE(my_uname, uname)
DYLD_INTERPOSE(my_sysctlbyname, sysctlbyname)
DYLD_INTERPOSE(my_sysctl, sysctl)
 DYLD_INTERPOSE(my_open, open)
 DYLD_INTERPOSE(my_mkdir, mkdir)
 DYLD_INTERPOSE(my_create, creat)
 DYLD_INTERPOSE(my_lstat, lstat)

@implementation PlayLoader

static void __attribute__((constructor)) initialize(void) {
  NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    printf("sas");
  /*
      printf("init values");
    // print hook_frame value
    printf("%f %f %f %f", [self hook_frame].origin.x, [self hook_frame].origin.y, [self hook_frame].size.width, [self hook_frame].size.height);
    //print hook_bounds value
    printf("%f %f %f %f", [self hook_bounds].origin.x, [self hook_bounds].origin.y, [self hook_bounds].size.width, [self hook_bounds].size.height);
    //print hook_size value
    printf("%f %f", [self hook_size].width, [self hook_size].height);
  */
  isGenshin =
      [bundleId isEqual:@"com.miHoYo.GenshinImpact"] || [bundleId isEqual:@"com.miHoYo.Yuanshen"];
  [PlayCover launch];
}

@end
