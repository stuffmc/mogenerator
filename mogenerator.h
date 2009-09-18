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


@interface NSManagedObjectModel (userInfo)
- (NSArray*)entitiesSorted;
- (NSEntityDescription *)entityForMenuOrder:(NSUInteger)menuOrder;
@end

@interface NSEntityDescription (customBaseClass)
- (NSString *)humanName;
- (NSString *)loginRequiredParameters;
- (BOOL)hasCustomSuperentity;
- (BOOL)hasSpecificCustomClass;
- (NSString*)customSuperentity;
- (void)_processPredicate:(NSPredicate*)predicate_ bindings:(NSMutableArray*)bindings_;
- (NSArray*)prettyFetchRequests;
- (NSArray *)allToManyRelationships;
@end

@interface NSAttributeDescription (scalarAttributeType)
- (BOOL)isTimeStamp;
- (BOOL)isUpdatedAt;
- (BOOL)isCreatedAt;
- (BOOL)isName;
- (BOOL)hasScalarAttributeType;
- (NSString*)scalarAttributeType;
- (NSString*)specifiedRailsAttributeType;
- (BOOL)railsAttributeIsString;
- (NSString*)railsAttributeType;
- (BOOL)isBinaryData;
- (BOOL)isDate;
- (NSString*)railsHTMLFormType;
- (BOOL)hasDefinedAttributeType;
- (NSString*)objectAttributeType;
@end

@interface NSPropertyDescription (MOGeneratorAdditions)
- (NSString *)within;
- (BOOL)hasOrder;
- (BOOL)hide;
- (NSString *)fieldName;
- (NSString *)humanName;
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
	NSString				*machineDirRB;
	NSString				*humanDir;
	NSString				*templateGroup;
	BOOL					_help;
	BOOL					_version;
	int						machineFilesGenerated;
}

- (NSString*)appSupportFileNamed:(NSString*)fileName_;
- (NSError*)outputError:(NSError*)error;
- (BOOL)processEntity:(id)entityModelOrRelationShip forMachine:(MiscMergeEngine*)machine withFileName:(NSString *)fileName;
- (BOOL)traverseRelationShipsForEntity:(NSEntityDescription *)entity migrate:(MiscMergeEngine *)machineMigrateRB children:(MiscMergeEngine *)machineChildrenRB existing:(MiscMergeEngine *)machineChildrenExistingRB;

@end