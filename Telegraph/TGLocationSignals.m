#import "TGLocationSignals.h"

#import <CoreLocation/CoreLocation.h>
#import "thirdparty/AFNetworking/TAFHTTPClient.h"

#import "TGRemoteHttpLocationSignal.h"

#import "TGLocationVenue.h"
#import "TGLocationReverseGeocodeResult.h"

NSString *const TGLocationFoursquareSearchEndpointUrl = @"https://api.foursquare.com/v2/venues/search/";
NSString *const TGLocationFoursquareClientId = @"BN3GWQF1OLMLKKQTFL0OADWD1X1WCDNISPPOT1EMMUYZTQV1";
NSString *const TGLocationFoursquareClientSecret = @"WEEZHCKI040UVW2KWW5ZXFAZ0FMMHKQ4HQBWXVSX4WXWBWYN";
NSString *const TGLocationFoursquareVersion = @"20150326";
NSString *const TGLocationFoursquareVenuesCountLimit = @"25";
NSString *const TGLocationFoursquareLocale = @"en";

NSString *const TGLocationGooglePlacesSearchEndpointUrl = @"https://maps.googleapis.com/maps/api/place/nearbysearch/json";
NSString *const TGLocationGooglePlacesApiKey = @"AIzaSyBCTH4aAdvi0MgDGlGNmQAaFS8GTNBrfj4";
NSString *const TGLocationGooglePlacesRadius = @"150";
NSString *const TGLocationGooglePlacesLocale = @"en";

NSString *const TGLocationGoogleGeocodeLocale = @"en";

@implementation TGLocationSignals

+ (SSignal *)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
{
    NSURL *url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&sensor=true&language=%@", coordinate.latitude, coordinate.longitude, TGLocationGoogleGeocodeLocale]];
    
    return [[TGRemoteHttpLocationSignal jsonForHttpLocation:url.absoluteString] map:^id(id json)
    {
        if (![json respondsToSelector:@selector(objectForKey:)])
            return nil;
        
        NSArray *results = json[@"results"];
        if (![results respondsToSelector:@selector(objectAtIndex:)])
            return nil;
        
        if (![results.firstObject isKindOfClass:[NSDictionary class]])
            return nil;
        
        return [TGLocationReverseGeocodeResult reverseGeocodeResultWithDictionary:results.firstObject];
    }];
}

+ (SSignal *)searchNearbyPlacesWithQuery:(NSString *)query coordinate:(CLLocationCoordinate2D)coordinate service:(TGLocationPlacesService)service
{
    switch (service)
    {
        case TGLocationPlacesServiceGooglePlaces:
            return [self _searchGooglePlacesWithQuery:query coordinate:coordinate];
            
        default:
            return [self _searchFoursquareVenuesWithQuery:query coordinate:coordinate];
    }
}

+ (SSignal *)_searchFoursquareVenuesWithQuery:(NSString *)query coordinate:(CLLocationCoordinate2D)coordinate
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    parameters[@"limit"] = TGLocationFoursquareVenuesCountLimit;
    parameters[@"ll"] = [NSString stringWithFormat:@"%lf,%lf", coordinate.latitude, coordinate.longitude];
    if (query.length > 0)
        parameters[@"query"] = query;
    
    NSString *url = [self _urlForService:TGLocationPlacesServiceFoursquare parameters:parameters];
    return [[TGRemoteHttpLocationSignal jsonForHttpLocation:url] map:^id(id json)
    {
        if (![json respondsToSelector:@selector(objectForKey:)])
            return nil;

        NSArray *results = json[@"response"][@"venues"];
        if (![results respondsToSelector:@selector(objectAtIndex:)])
            return nil;

        NSMutableArray *venues = [[NSMutableArray alloc] init];
        for (NSDictionary *result in results)
        {
            TGLocationVenue *venue = [TGLocationVenue venueWithFoursquareDictionary:result];
            if (venue != nil)
                [venues addObject:venue];
        }
        
        return venues;
    }];
}

+ (SSignal *)_searchGooglePlacesWithQuery:(NSString *)query coordinate:(CLLocationCoordinate2D)coordinate
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    parameters[@"location"] = [NSString stringWithFormat:@"%lf,%lf", coordinate.latitude, coordinate.longitude];
    if (query.length > 0)
        parameters[@"name"] = query;
    
    NSString *url = [self _urlForService:TGLocationPlacesServiceGooglePlaces parameters:parameters];
    return [[TGRemoteHttpLocationSignal jsonForHttpLocation:url] map:^id(id json)
    {
        if (![json respondsToSelector:@selector(objectForKey:)])
            return nil;
        
        NSArray *results = json[@"results"];
        if (![results respondsToSelector:@selector(objectAtIndex:)])
            return nil;
        
        NSMutableArray *venues = [[NSMutableArray alloc] init];
        for (NSDictionary *result in results)
        {
            TGLocationVenue *venue = [TGLocationVenue venueWithGooglePlacesDictionary:result];
            if (venue != nil)
                [venues addObject:venue];
        }
        
        return venues;
    }];
}

+ (NSString *)_urlForService:(TGLocationPlacesService)service parameters:(NSDictionary *)parameters
{
    if (service == TGLocationPlacesServiceNone)
        return nil;
    
    NSMutableDictionary *finalParameters = [[self _defaultParametersForService:service] mutableCopy];
    [finalParameters addEntriesFromDictionary:parameters];
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", [self _endpointUrlForService:service], AFQueryStringFromParametersWithEncoding(finalParameters, NSUTF8StringEncoding)];
    
    return urlString;
}

+ (NSString *)_endpointUrlForService:(TGLocationPlacesService)service
{
    switch (service)
    {
        case TGLocationPlacesServiceGooglePlaces:
            return TGLocationGooglePlacesSearchEndpointUrl;
            
        case TGLocationPlacesServiceFoursquare:
            return TGLocationFoursquareSearchEndpointUrl;
            
        default:
            return nil;
    }
}

+ (NSDictionary *)_defaultParametersForService:(TGLocationPlacesService)service
{
    switch (service)
    {
        case TGLocationPlacesServiceGooglePlaces:
            return @{ @"key": TGLocationGooglePlacesApiKey,
                      @"language": TGLocationGooglePlacesLocale,
                      @"radius": TGLocationGooglePlacesRadius,
                      @"sensor": @"true" };
            
        case TGLocationPlacesServiceFoursquare:
            return @{ @"v": TGLocationFoursquareVersion,
                      @"locale": TGLocationFoursquareLocale,
                      @"client_id": TGLocationFoursquareClientId,
                      @"client_secret" :TGLocationFoursquareClientSecret };
            
        default:
            return nil;
    }
}

#pragma mark -

static CLLocation *lastKnownUserLocation;

+ (void)storeLastKnownUserLocation:(CLLocation *)location
{
    lastKnownUserLocation = location;
}

+ (CLLocation *)lastKnownUserLocation
{
    NSTimeInterval locationAge = -[lastKnownUserLocation.timestamp timeIntervalSinceNow];
    if (locationAge > 600)
        lastKnownUserLocation = nil;
    
    return lastKnownUserLocation;
}

@end
