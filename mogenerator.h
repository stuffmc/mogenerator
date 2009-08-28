/*******************************************************************************
	mogenerator.h
		Copyright (c) 2006-2008 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "MiscMergeTemplate.h"
#import "MiscMergeCommandBlock.h"
#import "MiscMergeEngine.h"
#import "FoundationAdditions.h"
#import "nsenumerate.h"
#import "NSString+MiscAdditions.h"
#import "DDCommandLineInterface.h"
//@class ActiveSupportInflector;

@interface NSEntityDescription (customBaseClass)
//- (NSString*)pluralize;
- (BOOL)hasCustomSuperentity;
- (NSString*)customSuperentity;
- (void)_processPredicate:(NSPredicate*)predicate_ bindings:(NSMutableArray*)bindings_;
- (NSArray*)prettyFetchRequests;
@end

@interface NSAttributeDescription (scalarAttributeType)
//- (NSString*)pluralize;
- (BOOL)isTimeStamp;
- (BOOL)hasScalarAttributeType;
- (NSString*)scalarAttributeType;
- (NSString*)railsAttributeType;
- (NSString*)railsHTMLFormType;
- (BOOL)hasDefinedAttributeType;
- (NSString*)objectAttributeType;
@end

@interface NSString (camelCaseString)
- (NSString*)camelCaseString;
@end

@interface MOGeneratorApp : NSObject <DDCliApplicationDelegate> {
	NSString				*tempMOMPath;
	NSManagedObjectModel	*model;
	NSString				*baseClass;
	NSString				*includem;
	NSString				*templatePath;
	NSString				*railsDir;
	NSString				*outputDir;
	NSString				*machineDir;
	NSString				*humanDir;
	NSString				*templateGroup;
	BOOL					_help;
	BOOL					_version;
	int						machineFilesGenerated;
//	ActiveSupportInflector	*inflector;
}

- (NSString*)appSupportFileNamed:(NSString*)fileName_;
- (NSError*)outputError:(NSError*)error;
- (BOOL)processEntity:(NSEntityDescription *)entity forMachine:(MiscMergeEngine*)machine withFileName:(NSString *)fileName;

@end