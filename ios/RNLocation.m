#import <CoreLocation/CoreLocation.h>

#import "RCTBridge.h"
#import "RCTConvert.h"
#import "RCTEventDispatcher.h"

#import "RNLocation.h"

@interface RNLocation() <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *lastLocation;
@property (nonatomic, assign) BOOL deferringUpdates;

@end

@implementation RNLocation

RCT_EXPORT_MODULE()

@synthesize bridge = _bridge;

#pragma mark Initialization

- (instancetype)init
{
    if (self = [super init]) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.lastLocation    = [[CLLocation alloc] init];

        self.locationManager.delegate = self;
        self.locationManager.distanceFilter = 35;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
        self.locationManager.activityType = CLActivityTypeFitness;
        self.locationManager.pausesLocationUpdatesAutomatically = NO;
        self.locationManager.allowsBackgroundLocationUpdates = YES;
    }

    self.deferringUpdates = NO;

    return self;
}

#pragma mark

RCT_EXPORT_METHOD(requestAlwaysAuthorization)
{
    NSLog(@"react-native-location: requestAlwaysAuthorization");
    [self.locationManager requestAlwaysAuthorization];
}

RCT_EXPORT_METHOD(requestWhenInUseAuthorization)
{
    NSLog(@"react-native-location: requestWhenInUseAuthorization");
    [self.locationManager requestWhenInUseAuthorization];
}

RCT_EXPORT_METHOD(getAuthorizationStatus:(RCTResponseSenderBlock)callback)
{
    callback(@[[self nameForAuthorizationStatus:[CLLocationManager authorizationStatus]]]);
}

RCT_EXPORT_METHOD(setDesiredAccuracy:(double) accuracy)
{
    self.locationManager.desiredAccuracy = accuracy;
}

RCT_EXPORT_METHOD(setDistanceFilter:(double) distance)
{
    self.locationManager.distanceFilter = distance;
}

RCT_EXPORT_METHOD(setAllowsBackgroundLocationUpdates:(BOOL) enabled)
{
    self.locationManager.allowsBackgroundLocationUpdates = enabled;
}

RCT_EXPORT_METHOD(startMonitoringSignificantLocationChanges)
{
    NSLog(@"react-native-location: startMonitoringSignificantLocationChanges");
    [self.locationManager startMonitoringSignificantLocationChanges];
}

RCT_EXPORT_METHOD(startUpdatingLocation)
{
    [self.locationManager startUpdatingLocation];
}

RCT_EXPORT_METHOD(startUpdatingHeading)
{
    [self.locationManager startUpdatingHeading];
}

RCT_EXPORT_METHOD(stopMonitoringSignificantLocationChanges)
{
    [self.locationManager stopMonitoringSignificantLocationChanges];
}

RCT_EXPORT_METHOD(stopUpdatingLocation)
{
    [self.locationManager stopUpdatingLocation];
}

RCT_EXPORT_METHOD(stopUpdatingHeading)
{
    [self.locationManager stopUpdatingHeading];
}

-(NSString *)nameForAuthorizationStatus:(CLAuthorizationStatus)authorizationStatus
{
    switch (authorizationStatus) {
        case kCLAuthorizationStatusAuthorizedAlways:
            NSLog(@"Authorization Status: authorizedAlways");
            return @"authorizedAlways";

        case kCLAuthorizationStatusAuthorizedWhenInUse:
            NSLog(@"Authorization Status: authorizedWhenInUse");
            return @"authorizedWhenInUse";

        case kCLAuthorizationStatusDenied:
            NSLog(@"Authorization Status: denied");
            return @"denied";

        case kCLAuthorizationStatusNotDetermined:
            NSLog(@"Authorization Status: notDetermined");
            return @"notDetermined";

        case kCLAuthorizationStatusRestricted:
            NSLog(@"Authorization Status: restricted");
            return @"restricted";
    }
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    NSString *statusName = [self nameForAuthorizationStatus:status];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"authorizationStatusDidChange" body:statusName];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"Location manager failed: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
  if (newHeading.headingAccuracy < 0)
    return;

  // Use the true heading if it is valid.
  CLLocationDirection heading = ((newHeading.trueHeading > 0) ?
    newHeading.trueHeading : newHeading.magneticHeading);

  NSDictionary *headingEvent = @{
    @"heading": @(heading)
  };

  NSLog(@"heading: %f", heading);
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"headingUpdated" body:headingEvent];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *location = [locations lastObject];
    self.lastLocation = location;

    if (!self.deferringUpdates) {
        self.deferringUpdates = YES;
        [self.locationManager allowDeferredLocationUpdatesUntilTraveled:25 timeout:25];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFinishDeferredUpdatesWithError:(NSError *)error {
    self.deferringUpdates = NO;

    NSDictionary *locationEvent = @{
        @"coords": @{
            @"latitude": @(self.lastLocation.coordinate.latitude),
            @"longitude": @(self.lastLocation.coordinate.longitude),
            @"altitude": @(self.lastLocation.altitude),
            @"accuracy": @(self.lastLocation.horizontalAccuracy),
            @"altitudeAccuracy": @(self.lastLocation.verticalAccuracy),
            @"course": @(self.lastLocation.course),
            @"speed": @(self.lastLocation.speed),
        },
        @"timestamp": @([self.lastLocation.timestamp timeIntervalSince1970] * 1000) // in ms
    };

    NSLog(@"%@: lat: %f, long: %f, altitude: %f", self.lastLocation.timestamp, self.lastLocation.coordinate.latitude, self.lastLocation.coordinate.longitude, self.lastLocation.altitude);
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"locationUpdated" body:locationEvent];
}

@end
