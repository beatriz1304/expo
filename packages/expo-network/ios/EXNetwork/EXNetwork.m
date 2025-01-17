// Copyright 2018-present 650 Industries. All rights reserved.

#import <EXNetwork/EXNetwork.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import <ifaddrs.h>
#import <errno.h>
#import <arpa/inet.h>

@interface EXNetwork ()

@property (nonatomic, weak) UMModuleRegistry *moduleRegistry;
@property (nonatomic) SCNetworkReachabilityRef reachabilityRef;
@property (nonatomic) SCNetworkReachabilityFlags lastFlags;
@property (nonatomic) NSString *type;

@end

@implementation EXNetwork

// Creates a new "blank" state
- (instancetype)init
{
  self = [super init];
  if (self) {
    _type = EXNetworkTypeUnknown;
  }
  return self;
}

UM_EXPORT_MODULE(ExpoNetwork);

- (void)setModuleRegistry:(UMModuleRegistry *)moduleRegistry
{
  _moduleRegistry = moduleRegistry;
}


UM_EXPORT_METHOD_AS(getMacAddressAsync,
                    resolver:(UMPromiseResolveBlock)resolve
                    rejecter:(UMPromiseRejectBlock)reject)
{
  //some iOS privacy issues
  NSString *address = @"02:00:00:00:00:00";
  resolve(address);
}

UM_EXPORT_METHOD_AS(getIpAddressAsync,
                    getIpAddressAsyncWithResolver:(UMPromiseResolveBlock)resolve rejecter:(UMPromiseRejectBlock)reject)
{
  NSString *address = @"0.0.0.0";
  struct ifaddrs *interfaces = NULL;
  struct ifaddrs *temp_addr = NULL;
  int error = 0;
  // retrieve the current interfaces - On success, returns 0; on error, -1 is returned, and errno is set appropriately.
  error = getifaddrs(&interfaces);
  
  if (error == 0) {
    // Loop through linked list of interfaces
    temp_addr = interfaces;
    while(temp_addr != NULL) {
      if(temp_addr->ifa_addr->sa_family == AF_INET) {
        // Check if interface is en0 which is the wifi connection on the iPhone
        if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
          // Get NSString from C String
          address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
        }
      }
      temp_addr = temp_addr->ifa_next;
    }
    resolve(address);
  } else {
    NSString *errorMessage = [NSString stringWithFormat:@"%@/%d/%s",  @"No network interfaces could be retrieved. getifaddrs() failed with error number: ", errno, strerror(errno)];

    reject(@"ERR_NETWORK_IP_ADDRESS", errorMessage, nil);
  }
  
  // Free memory
  freeifaddrs(interfaces);
}

UM_EXPORT_METHOD_AS(getNetworkStateAsync,
                    getNetworkStateAsyncWithResolver:(UMPromiseResolveBlock)resolve
                    rejecter:(UMPromiseRejectBlock)reject)
{
  _reachabilityRef =  [self createReachabilityRef];
  SCNetworkReachabilityFlags flags = [self lastFlags];
    
  if ((flags & kSCNetworkReachabilityFlagsReachable) == 0 ||
      (flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0) {
    _type = EXNetworkTypeNone;
  }
  
#if !TARGET_OS_TV
  else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
    _type = EXNetworkTypeCellular;
  }
#endif
  else {
    _type = EXNetworkTypeWifi;
  }
  
  resolve([self type]);
}


- (SCNetworkReachabilityRef)createReachabilityRef
{
  struct sockaddr_in zeroAddress;
  bzero(&zeroAddress, sizeof(zeroAddress));
  zeroAddress.sin_len = sizeof(zeroAddress);
  zeroAddress.sin_family = AF_INET;
  
  SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *) &zeroAddress);
  
  // Set the state the first time
  SCNetworkReachabilityFlags flags;
  SCNetworkReachabilityGetFlags(reachability, &flags);
  _lastFlags = flags;
  
  return reachability;
}

@end
