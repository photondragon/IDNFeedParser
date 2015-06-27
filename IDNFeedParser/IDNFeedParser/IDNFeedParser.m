//
//  IDNFeedParser.m
//  IDNFramework
//
//  Created by photondragon on 15/6/24.
//  Copyright (c) 2015年 iosdev.net.
//

#import "IDNFeedParser.h"
#import "NSString+HTML.h"
#import "NSDate+InternetDateTime.h"

// Debug Logging
#if 0 // Set to 1 to enable debug logging
#define MWLog(x, ...) NSLog(x, ## __VA_ARGS__);
#else
#define MWLog(x, ...)
#endif

// NSXMLParser Logging
#if 0 // Set to 1 to enable XML parsing logs
#define MWXMLLog(x, ...) NSLog(x, ## __VA_ARGS__);
#else
#define MWXMLLog(x, ...)
#endif

// Empty XHTML elements ( <!ELEMENT br EMPTY> in http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd )
#define ELEMENT_IS_EMPTY(e) ([e isEqualToString:@"br"] || [e isEqualToString:@"img"] || [e isEqualToString:@"input"] || \
[e isEqualToString:@"hr"] || [e isEqualToString:@"link"] || [e isEqualToString:@"base"] || \
[e isEqualToString:@"basefont"] || [e isEqualToString:@"frame"] || [e isEqualToString:@"meta"] || \
[e isEqualToString:@"area"] || [e isEqualToString:@"col"] || [e isEqualToString:@"param"])

#define MWErrorDomain @"MWFeedParser"
#define MWErrorCodeNotInitiated				1		/* MWFeedParser not initialised correctly */
#define MWErrorCodeConnectionFailed			2		/* Connection to the URL failed */
#define MWErrorCodeFeedParsingError			3		/* NSXMLParser encountered a parsing error */
#define MWErrorCodeFeedValidationError		4		/* NSXMLParser encountered a validation error */
#define MWErrorCodeGeneral					5		/* MWFeedParser general error */

typedef enum { ParseTypeFull, ParseTypeItemsOnly, ParseTypeInfoOnly } ParseType;
typedef enum { FeedTypeUnknown, FeedTypeRSS, FeedTypeRSS1, FeedTypeAtom } FeedType;

@interface IDNFeedParser()
<NSXMLParserDelegate>
@property(nonatomic,strong,readonly) NSString* standardUrl; //标准化URL
@property(nonatomic,strong) IDNFeedInfo* feedInfo;
@property(nonatomic,strong) NSArray* feedItems;
@property(nonatomic) ParseType feedParseType;
@end

@implementation IDNFeedParser
{
	NSString *asyncTextEncodingName;

	NSXMLParser *feedParser;
	FeedType feedType;
	NSDateFormatter *dateFormatterRFC822, *dateFormatterRFC3339;

	BOOL aborted; //是否中止。只有当feedParseType==ParseTypeInfoOnly时，才会中止
	NSError* error; //解析过程中产生的错误。如果非nil，则解析一定会中止

	BOOL hasEncounteredItems; // Whether the parser has started parsing items

	// Parsing of XML structure as content
	NSString *pathOfElementWithXHTMLType; // Hold the path of the element who's type="xhtml" so we can stop parsing when it's ended
	BOOL parseStructureAsContent; // For atom feeds when element type="xhtml"

	// Parsing Data
	NSString *currentPath;
	NSMutableString *currentText;
	NSDictionary *currentElementAttributes;
	IDNFeedInfo *info;
	IDNFeedItem *item;
	NSMutableArray* itemsContainer;
}

#pragma mark NSObject

- (instancetype)init
{
	if ((self = [super init])) {

		// Defaults
		_feedParseType = ParseTypeFull;

		// Date Formatters
		// Good info on internet dates here: http://developer.apple.com/iphone/library/qa/qa2010/qa1480.html
		NSLocale *en_US_POSIX = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
		dateFormatterRFC822 = [[NSDateFormatter alloc] init];
		dateFormatterRFC3339 = [[NSDateFormatter alloc] init];
		[dateFormatterRFC822 setLocale:en_US_POSIX];
		[dateFormatterRFC3339 setLocale:en_US_POSIX];
		[dateFormatterRFC822 setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
		[dateFormatterRFC3339 setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

	}
	return self;
}

#pragma mark Parsing

// Reset data variables before processing
// Exclude parse state variables as they are needed after parse
- (void)reset {
	feedType = FeedTypeUnknown;
	currentPath = @"/";
	currentText = [[NSMutableString alloc] init];
	item = nil;
	info = nil;
	currentElementAttributes = nil;
	parseStructureAsContent = NO;
	pathOfElementWithXHTMLType = nil;
	hasEncounteredItems = NO;
}

+ (NSData*)dataFromUrl:(NSString*)url
{
	NSURL* nsurl = [NSURL URLWithString:url];
	if(nsurl==nil)
		return nil;

	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:nsurl];
	request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
	request.timeoutInterval = 30.0;
	request.HTTPMethod = @"GET";
	NSError* netError = nil;
	NSHTTPURLResponse* response;
	NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&netError];
	if(data==nil)
	{
		return nil;
	}
	data = [IDNFeedParser utf8DataFromData:data textEncodingName:response.textEncodingName];
	return data;
}

+ (IDNFeedInfo*)feedInfoWithUrl:(NSString*)url
{
	NSData* data = [self dataFromUrl:url];
	return [self feedInfoWithData:data fromUrl:url];
}
+ (IDNFeedInfo*)feedInfoWithData:(NSData *)data fromUrl:(NSString*)url
{
	if(data==nil)
		return nil;

	IDNFeedParser* parser = [IDNFeedParser new];
	parser.feedParseType = ParseTypeInfoOnly;
	[parser parseData:data fromUrl:url];
	return parser.feedInfo;
}

+ (NSArray*)feedItemsWithUrl:(NSString*)url
{
	NSData* data = [self dataFromUrl:url];
	return [self feedItemsWithData:data fromUrl:url];
}
+ (NSArray*)feedItemsWithData:(NSData*)data fromUrl:(NSString*)url; // 返回IDNFeedItem对象的数组
{
	if(data==nil)
		return nil;

	IDNFeedParser* parser = [IDNFeedParser new];
	parser.feedParseType = ParseTypeItemsOnly;
	[parser parseData:data fromUrl:url];
	return parser.feedItems;
}

+ (NSData*)utf8DataFromData:(NSData*)data textEncodingName:(NSString*)textEncodingName
{
	if(textEncodingName==nil) //检测xml文件头中包含的字符编码。例如：<?xml version="1.0" encoding="gb2312"?>
	{
		NSData* dataHeader;
		if(data.length>1024)
			dataHeader = [data subdataWithRange:NSMakeRange(0, 1024)];
		else
			dataHeader = data;
		NSString* dataHeaderString = [[NSString alloc] initWithData:dataHeader encoding:NSMacOSRomanStringEncoding];
		if ([dataHeaderString hasPrefix:@"<?xml"]) {
			NSRange a = [dataHeaderString rangeOfString:@"?>"];
			if (a.location != NSNotFound) {
				NSString *xmlHeader = [dataHeaderString substringToIndex:a.location];
				NSRange b = [xmlHeader rangeOfString:@"encoding=\""];
				if (b.location != NSNotFound) {
					NSUInteger s = b.location+b.length;
					NSRange c = [xmlHeader rangeOfString:@"\"" options:0 range:NSMakeRange(s, [xmlHeader length] - s)];
					if (c.location != NSNotFound) {
						textEncodingName = [xmlHeader substringWithRange:NSMakeRange(b.location+b.length,c.location-b.location-b.length)];
					}
				}
			}
		}
	}
	// Check whether it's UTF-8
	if (![[textEncodingName lowercaseString] isEqualToString:@"utf-8"]) {

		// Not UTF-8 so convert
		MWLog(@"MWFeedParser: XML document was not UTF-8 so we're converting it");
		NSString *string = nil;

		// Attempt to detect encoding from response header
		NSStringEncoding nsEncoding = 0;

		if (textEncodingName) {
			if([textEncodingName rangeOfString:@"gb2312" options:NSCaseInsensitiveSearch].location!=NSNotFound)
			{
				nsEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
			}
			else if([textEncodingName rangeOfString:@"gb18030" options:NSCaseInsensitiveSearch].location!=NSNotFound)
			{
				nsEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
			}
			else if([textEncodingName rangeOfString:@"gbk" options:NSCaseInsensitiveSearch].location!=NSNotFound)
			{
				nsEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGBK_95);
			}
			else
			{
				CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)textEncodingName);
				if (cfEncoding != kCFStringEncodingInvalidId)
					nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
			}

			if (nsEncoding != 0)
				string = [[NSString alloc] initWithData:data encoding:nsEncoding];
		}

		// If that failed then make our own attempts
		if (!string) {
			// http://www.mikeash.com/pyblog/friday-qa-2010-02-19-character-encodings.html
			string			    = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			if (!string) string = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
			if (!string) string = [[NSString alloc] initWithData:data encoding:NSMacOSRomanStringEncoding];
		}

		// Nil data
		data = nil;

		// Parse
		if (string) {

			// Set XML encoding to UTF-8
			if ([string hasPrefix:@"<?xml"]) {
				NSRange a = [string rangeOfString:@"?>"];
				if (a.location != NSNotFound) {
					NSString *xmlDec = [string substringToIndex:a.location];
					if ([xmlDec rangeOfString:@"encoding=\"UTF-8\""
									  options:NSCaseInsensitiveSearch].location == NSNotFound) {
						NSRange b = [xmlDec rangeOfString:@"encoding=\""];
						if (b.location != NSNotFound) {
							NSUInteger s = b.location+b.length;
							NSRange c = [xmlDec rangeOfString:@"\"" options:0 range:NSMakeRange(s, [xmlDec length] - s)];
							if (c.location != NSNotFound) {
								NSString *temp = [string stringByReplacingCharactersInRange:NSMakeRange(b.location,c.location+c.length-b.location)
																				 withString:@"encoding=\"UTF-8\""];
								string = temp;
							}
						}
					}
				}
			}

			// Convert string to UTF-8 data
			if (string) {
				data = [string dataUsingEncoding:NSUTF8StringEncoding];
			}
		}
	}
	return data;
}

- (void)parseData:(NSData *)data fromUrl:(NSString*)url
{
	if(data.length==0 || url.length==0)
		return;
	if(feedParser)//正在解析
		return;

	[self reset];
	error = nil;
	aborted = NO;

	if(data==nil)
	{
		[self parsingFailedWithErrorCode:MWErrorCodeFeedParsingError andDescription:@"Error with feed encoding"];
		return;
	}

	feedParser = [[NSXMLParser alloc] initWithData:data];
	if(feedParser==nil)
	{
		[self parsingFailedWithErrorCode:MWErrorCodeFeedParsingError andDescription:@"Feed not a valid XML document"];
		return;
	}

	self.standardUrl = url;
	info = [[IDNFeedInfo alloc] init];
	info.url = self.standardUrl;

	itemsContainer = [NSMutableArray new];

	feedParser.delegate = self;
	[feedParser setShouldProcessNamespaces:YES];
	[feedParser parse];
	feedParser = nil; // Release after parse

	self.feedInfo = info;
	if(error)
		self.feedItems = nil;
	else
		self.feedItems = [itemsContainer copy];
	itemsContainer = nil;
}

// If an error occurs, create NSError and inform delegate
- (void)parsingFailedWithErrorCode:(int)code andDescription:(NSString *)description {
	if(error) //如果有错，则解析已经中止
		return;
	error = [NSError errorWithDomain:MWErrorDomain code:code
							userInfo:[NSDictionary dictionaryWithObject:description
																 forKey:NSLocalizedDescriptionKey]];
	MWLog(@"%@", error);

	if (feedParser)
		[feedParser abortParsing];

	[self reset];
}

#pragma mark XML Parsing

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
	MWXMLLog(@"NSXMLParser: didStartElement: %@", qualifiedName);
	@autoreleasepool {

		// Adjust path
		currentPath = [currentPath stringByAppendingPathComponent:qualifiedName];
		currentElementAttributes = attributeDict;

		// Parse content as structure (Atom feeds with element type="xhtml")
		// - Use elementName not qualifiedName to ignore XML namespaces for XHTML entities
		if (parseStructureAsContent) {

			// Open XHTML tag
			[currentText appendFormat:@"<%@", elementName];

			// Add attributes
			for (NSString *key in attributeDict) {
				[currentText appendFormat:@" %@=\"%@\"", key,
				 [[attributeDict objectForKey:key] stringByEncodingHTMLEntities]];
			}

			// End tag or close
			if (ELEMENT_IS_EMPTY(elementName)) {
				[currentText appendString:@" />"];
			} else {
				[currentText appendString:@">"];
			}

			// Dont continue
			return;

		}

		// Reset
		[currentText setString:@""];

		// Determine feed type
		if (feedType == FeedTypeUnknown) {
			if ([qualifiedName isEqualToString:@"rss"]) feedType = FeedTypeRSS;
			else if ([qualifiedName isEqualToString:@"rdf:RDF"]) feedType = FeedTypeRSS1;
			else if ([qualifiedName isEqualToString:@"feed"]) feedType = FeedTypeAtom;
			else {

				// Invalid format so fail
				[self parsingFailedWithErrorCode:MWErrorCodeFeedParsingError
								  andDescription:@"XML document is not a valid web feed document."];

			}
			return;
		}

		// Entering new feed element
		if (_feedParseType != ParseTypeItemsOnly) {
			if ((feedType == FeedTypeRSS  && [currentPath isEqualToString:@"/rss/channel"]) ||
				(feedType == FeedTypeRSS1 && [currentPath isEqualToString:@"/rdf:RDF/channel"]) ||
				(feedType == FeedTypeAtom && [currentPath isEqualToString:@"/feed"])) {
				return;
			}
		}

		// Entering new item element
		if ((feedType == FeedTypeRSS  && [currentPath isEqualToString:@"/rss/channel/item"]) ||
			(feedType == FeedTypeRSS1 && [currentPath isEqualToString:@"/rdf:RDF/item"]) ||
			(feedType == FeedTypeAtom && [currentPath isEqualToString:@"/feed/entry"])) {

			// Send off feed info to delegate
			if (!hasEncounteredItems) {
				hasEncounteredItems = YES;
				if (_feedParseType != ParseTypeItemsOnly) { // Check whether to ignore feed info

					// Dispatch feed info to delegate
					[self dispatchFeedInfoToDelegate];

					// Stop parsing if only requiring meta data
					if (_feedParseType == ParseTypeInfoOnly) {

						// Debug log
						MWLog(@"MWFeedParser: Parse type is ParseTypeInfoOnly so finishing here");

						// Finish
						aborted = YES;
						[parser abortParsing];
						return;

					}

				} else {

					// Ignoring feed info so debug log
					MWLog(@"MWFeedParser: Parse type is ParseTypeItemsOnly so ignoring feed info");

				}
			}

			// New item
			item = [[IDNFeedItem alloc] init];

			// Return
			return;
		}

		// Check if entering into an Atom content tag with type "xhtml"
		// If type is "xhtml" then it can contain child elements and structure needs
		// to be parsed as content
		// See: http://www.atomenabled.org/developers/syndication/atom-format-spec.php#rfc.section.3.1.1
		if (feedType == FeedTypeAtom) {

			// Check type attribute
			NSString *typeAttribute = [attributeDict objectForKey:@"type"];
			if (typeAttribute && [typeAttribute isEqualToString:@"xhtml"]) {

				// Start parsing structure as content
				parseStructureAsContent = YES;

				// Remember path so we can stop parsing structure when element ends
				pathOfElementWithXHTMLType = currentPath;

			}

		}

	}

}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	MWXMLLog(@"NSXMLParser: didEndElement: %@", qName);
	@autoreleasepool {

		// Parse content as structure (Atom feeds with element type="xhtml")
		// - Use elementName not qualifiedName to ignore XML namespaces for XHTML entities
		if (parseStructureAsContent) {

			// Check for finishing parsing structure as content
			if (currentPath.length > pathOfElementWithXHTMLType.length) {

				// Close XHTML tag unless it is an empty element
				if (!ELEMENT_IS_EMPTY(elementName)) [currentText appendFormat:@"</%@>", elementName];

				// Adjust path & don't continue
				currentPath = [currentPath stringByDeletingLastPathComponent];

				// Return
				return;

			}

			// Finish
			parseStructureAsContent = NO;
			pathOfElementWithXHTMLType = nil;

			// Continue...

		}

		// Store data
		BOOL processed = NO;
		if (currentText) {

			// Remove newlines and whitespace from currentText
			NSString *processedText = [currentText stringByRemovingNewLinesAndWhitespace];

			// Process
			switch (feedType) {
				case FeedTypeRSS: {

					// Specifications
					// http://cyber.law.harvard.edu/rss/index.html
					// http://web.resource.org/rss/1.0/modules/dc/ Dublin core also seems to be used for RSS 2 as well

					// Item
					if (!processed) {
						if ([currentPath isEqualToString:@"/rss/channel/item/title"]) { if (processedText.length > 0) item.title = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rss/channel/item/link"]) { if (processedText.length > 0) item.link = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rss/channel/item/author"]) { if (processedText.length > 0) item.author = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rss/channel/item/dc:creator"]) { if (processedText.length > 0) item.author = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rss/channel/item/guid"]) { if (processedText.length > 0) item.identifier = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rss/channel/item/description"]) { if (processedText.length > 0) item.summary = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rss/channel/item/content:encoded"]) { if (processedText.length > 0) item.content = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rss/channel/item/pubDate"]) { if (processedText.length > 0) item.date = [NSDate dateFromInternetDateTimeString:processedText formatHint:DateFormatHintRFC822]; processed = YES; }
						else if ([currentPath isEqualToString:@"/rss/channel/item/enclosure"]) { [self createEnclosureFromAttributes:currentElementAttributes andAddToItem:item]; processed = YES; }
						else if ([currentPath isEqualToString:@"/rss/channel/item/dc:date"]) { if (processedText.length > 0) item.date = [NSDate dateFromInternetDateTimeString:processedText formatHint:DateFormatHintRFC3339]; processed = YES; }
					}

					// Info
					if (!processed && _feedParseType != ParseTypeItemsOnly) {
						if ([currentPath isEqualToString:@"/rss/channel/title"]) { if (processedText.length > 0) info.title = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rss/channel/description"]) { if (processedText.length > 0) info.summary = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rss/channel/link"]) { if (processedText.length > 0) info.link = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rss/channel/image/url"]) { if (processedText.length > 0) info.image = processedText; processed = YES; }
					}

					break;
				}
				case FeedTypeRSS1: {

					// Specifications
					// http://web.resource.org/rss/1.0/spec
					// http://web.resource.org/rss/1.0/modules/dc/

					// Item
					if (!processed) {
						if ([currentPath isEqualToString:@"/rdf:RDF/item/title"]) { if (processedText.length > 0) item.title = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rdf:RDF/item/link"]) { if (processedText.length > 0) item.link = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rdf:RDF/item/description"]) { if (processedText.length > 0) item.summary = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rdf:RDF/item/content:encoded"]) { if (processedText.length > 0) item.content = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rdf:RDF/item/dc:identifier"]) { if (processedText.length > 0) item.identifier = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rdf:RDF/item/dc:creator"]) { if (processedText.length > 0) item.author = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rdf:RDF/item/dc:date"]) { if (processedText.length > 0) item.date = [NSDate dateFromInternetDateTimeString:processedText formatHint:DateFormatHintRFC3339]; processed = YES; }
						else if ([currentPath isEqualToString:@"/rdf:RDF/item/enc:enclosure"]) { [self createEnclosureFromAttributes:currentElementAttributes andAddToItem:item]; processed = YES; }
					}

					// Info
					if (!processed && _feedParseType != ParseTypeItemsOnly) {
						if ([currentPath isEqualToString:@"/rdf:RDF/channel/title"]) { if (processedText.length > 0) info.title = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rdf:RDF/channel/description"]) { if (processedText.length > 0) info.summary = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/rdf:RDF/channel/link"]) { if (processedText.length > 0) info.link = processedText; processed = YES; }
					}

					break;
				}
				case FeedTypeAtom: {

					// Specifications
					// http://www.ietf.org/rfc/rfc4287.txt
					// http://www.intertwingly.net/wiki/pie/DublinCore

					// Item
					if (!processed) {
						if ([currentPath isEqualToString:@"/feed/entry/title"]) { if (processedText.length > 0) item.title = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/feed/entry/link"]) { [self processAtomLink:currentElementAttributes andAddToMWObject:item]; processed = YES; }
						else if ([currentPath isEqualToString:@"/feed/entry/id"]) { if (processedText.length > 0) item.identifier = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/feed/entry/summary"]) { if (processedText.length > 0) item.summary = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/feed/entry/content"]) { if (processedText.length > 0) item.content = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/feed/entry/author/name"]) { if (processedText.length > 0) item.author = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/feed/entry/dc:creator"]) { if (processedText.length > 0) item.author = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/feed/entry/published"]) { if (processedText.length > 0) item.date = [NSDate dateFromInternetDateTimeString:processedText formatHint:DateFormatHintRFC3339]; processed = YES; }
						else if ([currentPath isEqualToString:@"/feed/entry/updated"]) { if (processedText.length > 0) item.updated = [NSDate dateFromInternetDateTimeString:processedText formatHint:DateFormatHintRFC3339]; processed = YES; }
					}

					// Info
					if (!processed && _feedParseType != ParseTypeItemsOnly) {
						if ([currentPath isEqualToString:@"/feed/title"]) { if (processedText.length > 0) info.title = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/feed/description"]) { if (processedText.length > 0) info.summary = processedText; processed = YES; }
						else if ([currentPath isEqualToString:@"/feed/link"]) { [self processAtomLink:currentElementAttributes andAddToMWObject:info]; processed = YES;}
					}

					break;
				}
				default: break;
			}
		}

		// Adjust path
		currentPath = [currentPath stringByDeletingLastPathComponent];

		// If end of an item then tell delegate
		if (!processed) {
			if (((feedType == FeedTypeRSS || feedType == FeedTypeRSS1) && [qName isEqualToString:@"item"]) ||
				(feedType == FeedTypeAtom && [qName isEqualToString:@"entry"])) {

				// Dispatch item to delegate
				[self dispatchFeedItem];

			}
		}

		// Check if the document has finished parsing and send off info if needed (i.e. there were no items)
		if (!processed) {
			if ((feedType == FeedTypeRSS && [qName isEqualToString:@"rss"]) ||
				(feedType == FeedTypeRSS1 && [qName isEqualToString:@"rdf:RDF"]) ||
				(feedType == FeedTypeAtom && [qName isEqualToString:@"feed"])) {

				// Document ending so if we havent sent off feed info yet, do so
				if (info && _feedParseType != ParseTypeItemsOnly)
					[self dispatchFeedInfoToDelegate];
			}
		}
	}
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock {
	MWXMLLog(@"NSXMLParser: foundCDATA (%d bytes)", CDATABlock.length);

	// Remember characters
	NSString *string = nil;
	@try {

		// Try decoding with NSUTF8StringEncoding & NSISOLatin1StringEncoding
		string = [[NSString alloc] initWithData:CDATABlock encoding:NSUTF8StringEncoding];
		if (!string) string = [[NSString alloc] initWithData:CDATABlock encoding:NSISOLatin1StringEncoding];

		// Add - No need to encode as CDATA should not be encoded as it's ignored by the parser
		if (string) [currentText appendString:string];

	} @catch (NSException * e) {
	} @finally {
		string = nil;
	}

}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	MWXMLLog(@"NSXMLParser: foundCharacters: %@", string);
	// Remember characters
	if (!parseStructureAsContent) {
		// Add characters normally
		[currentText appendString:string];
	} else {
		// If parsing structure as content then we should encode characters
		[currentText appendString:[string stringByEncodingHTMLEntities]];
	}

}

// Call if parsing error occured or parse was aborted
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
	MWXMLLog(@"NSXMLParser: parseErrorOccurred: %@", parseError);
	// Fail with error
	if (aborted==NO)
	{
		// This method is called when legimitaly aboring the parser so ignore if this is the case
		[self parsingFailedWithErrorCode:MWErrorCodeFeedParsingError andDescription:[parseError localizedDescription]];
	}

}

- (void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validError {
	MWXMLLog(@"NSXMLParser: validationErrorOccurred: %@", validError);

	// Fail with error
	[self parsingFailedWithErrorCode:MWErrorCodeFeedValidationError andDescription:[validError localizedDescription]];

}

#pragma mark -
#pragma mark Send Items to Delegate

- (void)dispatchFeedInfoToDelegate {
	if (info) {
		// Debug log
		MWLog(@"MWFeedParser: Feed info for \"%@\" successfully parsed", info.title);
	}
}

- (void)dispatchFeedItem {
	if (item)
	{
		// Process before hand
		if (!item.summary) { item.summary = item.content; item.content = nil; }
		if (!item.date && item.updated) { item.date = item.updated; }

		// Debug log
		MWLog(@"MWFeedParser: Feed item \"%@\" successfully parsed", item.title);

		// Finish
		[itemsContainer addObject:item];
		item = nil;
	}
}

#pragma mark -
#pragma mark Helpers & Properties

// Set URL to parse and removing feed: uri scheme info
// http://en.wikipedia.org/wiki/Feed:_URI_scheme
- (void)setStandardUrl:(NSString *)standardUrl
{
	NSURL* url = [NSURL URLWithString:(NSString *)standardUrl].standardizedURL;
	if ([url.scheme isEqualToString:@"feed"])
	{
		// Remove feed URL scheme
		url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",
									([url.resourceSpecifier hasPrefix:@"//"] ? @"http:" : @""),
									url.resourceSpecifier]];
	}
	_standardUrl = url.absoluteString;
}

#pragma mark -
#pragma mark Misc

// Create an enclosure NSDictionary from enclosure (or link) attributes
- (BOOL)createEnclosureFromAttributes:(NSDictionary *)attributes andAddToItem:(IDNFeedItem *)currentItem {

	// Create enclosure
	NSDictionary *enclosure = nil;
	NSString *encURL = nil, *encType = nil;
	NSNumber *encLength = nil;
	if (attributes) {
		switch (feedType) {
			case FeedTypeRSS: { // http://cyber.law.harvard.edu/rss/rss.html#ltenclosuregtSubelementOfLtitemgt
				// <enclosure>
				encURL = [attributes objectForKey:@"url"];
				encType = [attributes objectForKey:@"type"];
				encLength = [NSNumber numberWithLongLong:[((NSString *)[attributes objectForKey:@"length"]) longLongValue]];
				break;
			}
			case FeedTypeRSS1: { // http://www.xs4all.nl/~foz/mod_enclosure.html
				// <enc:enclosure>
				encURL = [attributes objectForKey:@"rdf:resource"];
				encType = [attributes objectForKey:@"enc:type"];
				encLength = [NSNumber numberWithLongLong:[((NSString *)[attributes objectForKey:@"enc:length"]) longLongValue]];
				break;
			}
			case FeedTypeAtom: { // http://www.atomenabled.org/developers/syndication/atom-format-spec.php#rel_attribute
				// <link rel="enclosure" href=...
				if ([[attributes objectForKey:@"rel"] isEqualToString:@"enclosure"]) {
					encURL = [attributes objectForKey:@"href"];
					encType = [attributes objectForKey:@"type"];
					encLength = [NSNumber numberWithLongLong:[((NSString *)[attributes objectForKey:@"length"]) longLongValue]];
				}
				break;
			}
			default: break;
		}
	}
	if (encURL) {
		NSMutableDictionary *e = [[NSMutableDictionary alloc] initWithCapacity:3];
		[e setObject:encURL forKey:@"url"];
		if (encType) [e setObject:encType forKey:@"type"];
		if (encLength) [e setObject:encLength forKey:@"length"];
		enclosure = [NSDictionary dictionaryWithDictionary:e];
	}

	// Add to item
	if (enclosure) {
		if (currentItem.enclosures) {
			currentItem.enclosures = [currentItem.enclosures arrayByAddingObject:enclosure];
		} else {
			currentItem.enclosures = [NSArray arrayWithObject:enclosure];
		}
		return YES;
	} else {
		return NO;
	}

}

// Process ATOM link and determine whether to ignore it, add it as the link element or add as enclosure
// Links can be added to MWObject (info or item)
- (BOOL)processAtomLink:(NSDictionary *)attributes andAddToMWObject:(id)MWObject {
	if (attributes && [attributes objectForKey:@"rel"]) {

		// Use as link if rel == alternate
		if ([[attributes objectForKey:@"rel"] isEqualToString:@"alternate"]) {
			[MWObject setLink:[attributes objectForKey:@"href"]]; // Can be added to MWFeedItem or MWFeedInfo
			return YES;
		}

		// Use as enclosure if rel == enclosure
		if ([[attributes objectForKey:@"rel"] isEqualToString:@"enclosure"]) {
			if ([MWObject isMemberOfClass:[IDNFeedItem class]]) { // Enclosures can only be added to MWFeedItem
				[self createEnclosureFromAttributes:attributes andAddToItem:(IDNFeedItem *)MWObject];
				return YES;
			}
		}

	}
	return NO;
}

@end

@implementation IDNFeedInfo

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super init];
	if(self)
	{
		_title = [aDecoder decodeObjectForKey:@"title"];
		_link = [aDecoder decodeObjectForKey:@"link"];
		_summary = [aDecoder decodeObjectForKey:@"summary"];
		_url = [aDecoder decodeObjectForKey:@"url"];
		_image = [aDecoder decodeObjectForKey:@"image"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:_title forKey:@"title"];
	[aCoder encodeObject:_link forKey:@"link"];
	[aCoder encodeObject:_summary forKey:@"summary"];
	[aCoder encodeObject:_url forKey:@"url"];
	[aCoder encodeObject:_image forKey:@"image"];
}

@end

@implementation IDNFeedItem

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super init];
	if(self)
	{
		_identifier = [aDecoder decodeObjectForKey:@"identifier"];
		_title = [aDecoder decodeObjectForKey:@"title"];
		_link = [aDecoder decodeObjectForKey:@"link"];
		_date = [aDecoder decodeObjectForKey:@"date"];
		_updated = [aDecoder decodeObjectForKey:@"updated"];
		_summary = [aDecoder decodeObjectForKey:@"summary"];
		_content = [aDecoder decodeObjectForKey:@"content"];
		_author = [aDecoder decodeObjectForKey:@"author"];
		_enclosures = [aDecoder decodeObjectForKey:@"enclosures"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:_identifier forKey:@"identifier"];
	[aCoder encodeObject:_title forKey:@"title"];
	[aCoder encodeObject:_link forKey:@"link"];
	[aCoder encodeObject:_date forKey:@"date"];
	[aCoder encodeObject:_updated forKey:@"updated"];
	[aCoder encodeObject:_summary forKey:@"summary"];
	[aCoder encodeObject:_content forKey:@"content"];
	[aCoder encodeObject:_author forKey:@"author"];
	[aCoder encodeObject:_enclosures forKey:@"enclosures"];
}

@end