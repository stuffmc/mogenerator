/*******************************************************************************
	mogenerator.m
		Copyright (c) 2006-2008 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		This Fork (a.k.a. "morailsgenerator" has been highly modified by mc@stuffmc.com - @stuffmc
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import "mogenerator.h"
#import "ActiveSupportInflector.h"

NSString	*gCustomBaseClass;


@implementation NSManagedObjectModel (userInfo)
- (NSArray*)entitiesSorted {
	NSMutableArray *sorted = [[NSMutableArray alloc] init];
	NSUInteger count = [[self entitiesByName] count];
//	ddprintf(@"**** entity count: %d\n\n", count);
	for (NSUInteger index = 0 ; index < count ; index++) {
//		ddprintf(@"**** index: %d\n\n", index);
		NSEntityDescription *entitySorted = [self entityForMenuOrder:index];
		if (entitySorted) {
			[sorted addObject:entitySorted];
		}
	}
	
//	ddprintf(@"***allKeys: %@", [[self entitiesByName] allKeys]);
	for (NSUInteger index = 0 ; index < count ; index++) {
		//		ddprintf(@"**** index: %d\n\n", index);
		if (![self entityForMenuOrder:index]) {
			[sorted addObject:[[self entities] objectAtIndex:index]];
		}
	}
//	ddprintf(@"**** sorted: %@\n\n", sorted);
	return sorted;
}
- (NSEntityDescription *)entityForMenuOrder:(NSUInteger)menuOrder {
	for (NSEntityDescription *entity in [self entities]) {
//		ddprintf(@"**** order: %d\n\n", menuOrder);
//		ddprintf(@"**** allValues: %@\n\n", [[entity userInfo] allValues]);
//		ddprintf(@"**** VALUE: %@\n\n", [[[entity userInfo] allValues] objectAtIndex:0]);
		NSArray *allValues = [[entity userInfo] allValues];
		if (allValues && [allValues count] && [[allValues objectAtIndex:0] intValue] == menuOrder + 1) {
//			ddprintf(@"**** entity: %@\n\n", entity.name);
			return entity;
		}
	}
	return nil;
}

@end

@implementation NSEntityDescription (customBaseClass)

- (NSString *)humanName {
	NSString *humanNameInUserInfo = [self.userInfo valueForKey:@"humanName"];
	return (humanNameInUserInfo) ? humanNameInUserInfo : self.name;
}

- (NSString *)loginRequiredParameters {
//	for (id object in [self userInfo]) {
//		if ([object isEqualToString:@"loginRequiredParameters"]) {
//			return [[self userInfo] valueForKey:object];
//		}
//	}
//	return nil;
	return [self.userInfo valueForKey:@"loginRequiredParameters"];
}

- (BOOL)hasCustomSuperentity {
	NSEntityDescription *superentity = [self superentity];
	if (superentity) {
		return YES;
	} else {
		return gCustomBaseClass ? YES : NO;
	}
}
- (BOOL)hasSpecificCustomClass {
	return !([[self managedObjectClassName] isEqualToString:@"NSManagedObject"] ||	[[self managedObjectClassName] isEqualToString:gCustomBaseClass]);
}
- (NSString*)customSuperentity {
	NSEntityDescription *superentity = [self superentity];
	if (superentity) {
		return [superentity managedObjectClassName];
	} else {
		return gCustomBaseClass ? gCustomBaseClass : @"NSManagedObject";
	}
}
/** @TypeInfo NSAttributeDescription */
- (NSArray*)noninheritedAttributes {
	NSEntityDescription *superentity = [self superentity];
	if (superentity) {
		NSMutableArray *result = [[[[self attributesByName] allValues] mutableCopy] autorelease];
		[result removeObjectsInArray:[[superentity attributesByName] allValues]];
		return result;
	} else {
//		ddprintf(@"\n[[self attributesByName] allValues]: %@", [[self attributesByName] allValues]);
		return [[self attributesByName] allValues];
	}
}
/** @TypeInfo NSAttributeDescription */
- (NSArray*)noninheritedRelationships {
	NSEntityDescription *superentity = [self superentity];
	if (superentity) {
		NSMutableArray *result = [[[[self relationshipsByName] allValues] mutableCopy] autorelease];
		[result removeObjectsInArray:[[superentity relationshipsByName] allValues]];
		return result;
	} else {
		return [[self relationshipsByName] allValues];
	}
}

- (NSArray *)allToManyRelationships {
	NSMutableArray *array = [[[NSMutableArray alloc] init] autorelease];
	nsenumerate ([[self managedObjectModel] entities], NSEntityDescription, entity) {
		for (NSRelationshipDescription *relation in [self relationshipsWithDestinationEntity:entity]) {
//			ddprintf(@"REL: %@ (ToMany: %d)", relation, [relation isToMany]);
			if ([relation isToMany]) {
				[array addObject:relation];
			}
		}
	}
	return array;
}


#pragma mark Fetch Request support

- (NSDictionary*)fetchRequestTemplates {
	// -[NSManagedObjectModel _fetchRequestTemplatesByName] is a private method, but it's the only way to get
	//	model fetch request templates without knowing their name ahead of time. rdar://problem/4901396 asks for
	//	a public method (-[NSManagedObjectModel fetchRequestTemplatesByName]) that does the same thing.
	//	If that request is fulfilled, this code won't need to be modified thanks to KVC lookup order magic.
    //  UPDATE: 10.5 now has a public -fetchRequestTemplatesByName method.
	NSDictionary *fetchRequests = [[self managedObjectModel] valueForKey:@"fetchRequestTemplatesByName"];
	
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[fetchRequests count]];
	nsenumerate ([fetchRequests allKeys], NSString, fetchRequestName) {
		NSFetchRequest *fetchRequest = [fetchRequests objectForKey:fetchRequestName];
		if ([fetchRequest entity] == self) {
			[result setObject:fetchRequest forKey:fetchRequestName];
		}
	}
	return result;
}
- (void)_processPredicate:(NSPredicate*)predicate_ bindings:(NSMutableArray*)bindings_ {
    if (!predicate_) return;
    
	if ([predicate_ isKindOfClass:[NSCompoundPredicate class]]) {
		nsenumerate([(NSCompoundPredicate*)predicate_ subpredicates], NSPredicate, subpredicate) {
			[self _processPredicate:subpredicate bindings:bindings_];
		}
	} else {
		assert([[(NSComparisonPredicate*)predicate_ leftExpression] expressionType] == NSKeyPathExpressionType);
		NSExpression *lhs = [(NSComparisonPredicate*)predicate_ leftExpression];
		NSExpression *rhs = [(NSComparisonPredicate*)predicate_ rightExpression];
		switch([rhs expressionType]) {
			case NSConstantValueExpressionType:
			case NSEvaluatedObjectExpressionType:
			case NSKeyPathExpressionType:
			case NSFunctionExpressionType:
				//	Don't do anything with these.
				break;
			case NSVariableExpressionType: {
				// TODO SHOULD Handle LHS keypaths.
                
                NSString *type = nil;
                
                NSAttributeDescription *attribute = [[self attributesByName] objectForKey:[lhs keyPath]];
                if (attribute) {
                    type = [attribute objectAttributeType];
                } else {
                    //  Probably a relationship
                    NSRelationshipDescription *relationship = [[self relationshipsByName] objectForKey:[lhs keyPath]];
                    assert(relationship);
                    type = [[relationship destinationEntity] managedObjectClassName];
                }
                type = [type stringByAppendingString:@"*"];
                
				[bindings_ addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                      [rhs variable], @"name",
                                      type, @"type",
                                      nil]];
			} break;
			default:
				assert(0 && "unknown NSExpression type");
		}
	}
}
- (NSArray*)prettyFetchRequests {
	NSDictionary *fetchRequests = [self fetchRequestTemplates];
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[fetchRequests count]];
	nsenumerate ([fetchRequests allKeys], NSString, fetchRequestName) {
		NSFetchRequest *fetchRequest = [fetchRequests objectForKey:fetchRequestName];
		NSMutableArray *bindings = [NSMutableArray array];
		[self _processPredicate:[fetchRequest predicate] bindings:bindings];
		[result addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                           fetchRequestName, @"name",
                           bindings, @"bindings",
                           [NSNumber numberWithBool:[fetchRequestName hasPrefix:@"one"]], @"singleResult",
                           nil]];
	}
	return result;
}



@end

@implementation NSAttributeDescription (scalarAttributeType)
- (BOOL)hasScalarAttributeType {
	switch ([self attributeType]) {
		case NSInteger16AttributeType:
		case NSInteger32AttributeType:
		case NSInteger64AttributeType:
		case NSDoubleAttributeType:
		case NSFloatAttributeType:
		case NSBooleanAttributeType:
			return YES;
			break;
		default:
			return NO;
	}
}
- (NSString*)scalarAttributeType {
	switch ([self attributeType]) {
		case NSInteger16AttributeType:
			return @"short";
			break;
		case NSInteger32AttributeType:
			return @"int";
			break;
		case NSInteger64AttributeType:
			return @"long long";
			break;
		case NSDoubleAttributeType:
			return @"double";
			break;
		case NSFloatAttributeType:
			return @"float";
			break;
		case NSBooleanAttributeType:
			return @"BOOL";
			break;
		default:
			return nil;
	}
}
- (BOOL)railsAttributeIsString {
	return [self attributeType] == NSStringAttributeType;
}

- (NSString*)specifiedRailsAttributeType {
//	NSString *type = nil;
//	if ([[[self userInfo] allKeys] count]) {
//		type = [[[self userInfo] allKeys] objectAtIndex:0];
//	}
//	return type;
	return [self.userInfo valueForKey:@"specifiedRailsAttributeType"];
}

- (NSString*)railsAttributeType {
	switch ([self attributeType]) {
		case NSInteger16AttributeType:
		case NSInteger32AttributeType:
		case NSInteger64AttributeType:
			return @"integer";
			break;
		case NSDoubleAttributeType:
		case NSDecimalAttributeType:
			return @"decimal";
			break;
		case NSBooleanAttributeType:
			return @"boolean";
			break;
		case NSStringAttributeType:
			return @"string"; // @"text"
			break;
		case NSDateAttributeType:
			return @"datetime"; // @"date", @"time"? @"timestamp"
			break;
		case NSBinaryDataAttributeType:
			return @"binary";
		default:
			return [self scalarAttributeType];	// NSFloatAttributeType is also "float" in rails. NSTransformableAttributeType will then return nil.
	}
}
- (BOOL)isBinaryData {
	return (self.attributeType == NSBinaryDataAttributeType);
}
- (BOOL)isDate {
//	ddprintf(@"\n\n***ATTRIBUTE USER INFO:%@\n\n", [self attributeKeys]);
	return (self.attributeType == NSDateAttributeType);
}
- (NSString*)railsHTMLFormType {
	if ([self attributeType] != NSTransformableAttributeType) {
		
	}
	switch ([self attributeType]) {
		case NSBooleanAttributeType:
			return @"check_box";
			break;
		case NSBinaryDataAttributeType:
			return @"file_field";
		default:
			return @"text_field"; // @"text_area" for @"text"
			break;
	}
}
- (BOOL)isTimeStamp {
	// This allows the templates to check for the "timestamp" fields used by Rails and thus, not display them.
	return ([self isCreatedAt] || [self isUpdatedAt]);
}
- (BOOL)isUpdatedAt {
	// This allows the templates to check for the "timestamp" fields used by Rails and thus, not display them.
	return [[self name] isEqualToString:@"updatedAt"];
}
- (BOOL)isCreatedAt {
	// This allows the templates to check for the "timestamp" fields used by Rails and thus, not display them.
	return [[self name] isEqualToString:@"createdAt"];
}
- (BOOL)isName {
	// This allows the templates to check for the "name" field to not display them, for example.
	return [[self name] isEqualToString:@"name"];
}

- (BOOL)hasDefinedAttributeType {
	return [self attributeType] != NSUndefinedAttributeType;
}
- (NSString*)objectAttributeType {
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
    #define NSTransformableAttributeType 1800
#endif
    if ([self attributeType] == NSTransformableAttributeType) {
        NSString *result = [[self userInfo] objectForKey:@"attributeValueClassName"];
        return result ? result : @"NSObject";
    } else {
        return [self attributeValueClassName];
    }
}
@end


@implementation NSPropertyDescription (MOGeneratorAdditions)

- (NSString *)within {
	NSString *from = nil, *to = nil, *withinString = nil;
	
	for (NSComparisonPredicate *predicate in self.validationPredicates) {
//		ddprintf(@"**withinString: %@\n", predicate);
		if ([[NSString stringWithFormat:@"%@", predicate.leftExpression] isEqualToString:@"length"]) {
			switch (predicate.predicateOperatorType) {
				case NSGreaterThanOrEqualToComparison:
					from = [NSString stringWithFormat:@"%@", [predicate rightExpression]];
					break;
				case NSLessThanOrEqualToComparison:
					to = [NSString stringWithFormat:@"%@", [predicate rightExpression]];
					break;
				default:
					break;
			}
		}
	}
	if (to) {
		if (!from) {
			from = @"1";
		}
		withinString = [NSString stringWithFormat:@"%@..%@", from, to];
	} 
//	ddprintf(@"withinString: %@\n", withinString);
	return withinString;
}

- (NSString *)humanName {
	NSString *humanNameInUserInfo = [self.userInfo valueForKey:@"humanName"];
	return (humanNameInUserInfo) ? humanNameInUserInfo : self.name;
}

- (NSString *)fieldName {
	NSString *fieldNameInUserInfo = [self.userInfo valueForKey:@"fieldName"];
	return (fieldNameInUserInfo) ? fieldNameInUserInfo : self.name;
}


- (BOOL)hide {
	return ([self.userInfo valueForKey:@"hide"] != nil);
}

- (BOOL)hasOrder {
//	
//	BOOL returnValue = true;
//	if (self.userInfo && self.userInfo.allKeys && self.userInfo.allKeys.count) {
////		ddprintf(@"property userInfo: %@", self.userInfo.allKeys);
//		returnValue = false;
//	}
//	return returnValue;
	return ([self.userInfo valueForKey:@"order"] == nil);
}

@end


@implementation NSString (camelCaseString)
- (NSString*)camelCaseString {
	NSArray *lowerCasedWordArray = [[self wordArray] arrayByMakingObjectsPerformSelector:@selector(lowercaseString)];
	unsigned wordIndex = 1, wordCount = [lowerCasedWordArray count];
	NSMutableArray *camelCasedWordArray = [NSMutableArray arrayWithCapacity:wordCount];
	if (wordCount)
		[camelCasedWordArray addObject:[lowerCasedWordArray objectAtIndex:0]];
	for (; wordIndex < wordCount; wordIndex++) {
		[camelCasedWordArray addObject:[[lowerCasedWordArray objectAtIndex:wordIndex] initialCapitalString]];
	}
	return [camelCasedWordArray componentsJoinedByString:@""];
}
@end

static MiscMergeEngine* engineWithTemplatePath(NSString *templatePath_) {
	MiscMergeTemplate *template = [[[MiscMergeTemplate alloc] init] autorelease];
	[template setStartDelimiter:@"<$" endDelimiter:@"$>"];
	[template parseContentsOfFile:templatePath_];
	
	return [[[MiscMergeEngine alloc] initWithTemplate:template] autorelease];
}

@implementation MOGeneratorApp

NSString *ApplicationSupportSubdirectoryName = @"mogenerator";
- (NSString*)appSupportFileNamed:(NSString*)fileName_ {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDirectory;
	
	if (templatePath) {
		if ([fileManager fileExistsAtPath:templatePath isDirectory:&isDirectory] && isDirectory) {
			return [templatePath stringByAppendingPathComponent:fileName_];
		}
	} else {
		NSArray *appSupportDirectories = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask+NSLocalDomainMask, YES);
		assert(appSupportDirectories);
		
		nsenumerate (appSupportDirectories, NSString*, appSupportDirectory) {
			if ([fileManager fileExistsAtPath:appSupportDirectory isDirectory:&isDirectory]) {
				NSString *appSupportSubdirectory = [appSupportDirectory stringByAppendingPathComponent:ApplicationSupportSubdirectoryName];
				if (templateGroup) {
					appSupportSubdirectory = [appSupportSubdirectory stringByAppendingPathComponent:templateGroup];
				}
				if ([fileManager fileExistsAtPath:appSupportSubdirectory isDirectory:&isDirectory] && isDirectory) {
					NSString *appSupportFile = [appSupportSubdirectory stringByAppendingPathComponent:fileName_];
					if ([fileManager fileExistsAtPath:appSupportFile isDirectory:&isDirectory] && !isDirectory) {
						return appSupportFile;
					}
				}
			}
		}
	}
	
	NSLog(@"appSupportFileNamed:@\"%@\": file not found", fileName_);
	exit(EXIT_FAILURE);
	return nil;
}

- (void) application: (DDCliApplication *) app
    willParseOptions: (DDGetoptLongParser *) optionsParser;
{
    [optionsParser setGetoptLongOnly: YES];
    DDGetoptOption optionTable[] = 
    {
    // Long             Short   Argument options
    {@"model",          'm',    DDGetoptRequiredArgument},
    {@"base-class",      0,     DDGetoptRequiredArgument},
    // For compatibility:
    {@"baseClass",      0,      DDGetoptRequiredArgument},
    {@"includem",       0,      DDGetoptRequiredArgument},
    {@"template-path",  0,      DDGetoptRequiredArgument},
    // For compatibility:
    {@"templatePath",   0,      DDGetoptRequiredArgument},
    {@"output-dir",     'O',    DDGetoptRequiredArgument},
    {@"machine-dir",    'M',    DDGetoptRequiredArgument},
    {@"human-dir",      'H',    DDGetoptRequiredArgument},
	{@"rails-dir",		'R',    DDGetoptRequiredArgument},
    {@"template-group", 0,      DDGetoptRequiredArgument},

    {@"help",           'h',    DDGetoptNoArgument},
    {@"version",        0,      DDGetoptNoArgument},
    {nil,               0,      0},
    };
    [optionsParser addOptionsFromTable: optionTable];
}

- (void) printUsage;
{
    ddprintf(@"%@: Usage [OPTIONS] <argument> [...]\n", DDCliApp);
    printf("\n"
           "  -m, --model MODEL             Path to model\n"
           "      --base-class CLASS        Custom base class\n"
           "      --includem FILE           Generate aggregate include file\n"
           "      --template-path PATH      Path to templates\n"
           "      --template-group NAME     Name of template group\n"
           "  -O, --output-dir DIR          Output directory\n"
           "  -M, --machine-dir DIR         Output directory for machine files\n"
           "  -H, --human-dir DIR           Output director for human files\n"
		   // @stuffmc added support for Ruby On Rails generation on Augst 26, 2009.
           "  -R, --rails-dir DIR		Location of the already created Rails App's {RAILS_ROOT}\n"
           "      --version                 Display version and exit\n"
           "  -h, --help                    Display this help and exit\n"
           "\n"
           "Implements generation gap codegen pattern for Core Data.\n"
           "Inspired by eogenerator.\n");
}

- (void) setModel: (NSString *) path;
{
//	ddprintf(@"THE model: %@", path);
    assert(!model); // Currently we only can load one model.

    if( ![[NSFileManager defaultManager] fileExistsAtPath:path]){
        NSString * reason = [NSString stringWithFormat: @"error loading file at %@: no such file exists", path];
        DDCliParseException * e = [DDCliParseException parseExceptionWithReason: reason
                                                                       exitCode: EX_NOINPUT];
        @throw e;
    }

    if ([[path pathExtension] isEqualToString:@"xcdatamodel"]) {
        //	We've been handed a .xcdatamodel data model, transparently compile it into a .mom managed object model.
        
        //  Find where Xcode installed momc this week.
        NSString *momc = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Developer/usr/bin/momc"]) { // Xcode 3.1 installs it here.
            momc = @"/Developer/usr/bin/momc";
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/Application Support/Apple/Developer Tools/Plug-ins/XDCoreDataModel.xdplugin/Contents/Resources/momc"]) { // Xcode 3.0.
            momc = @"/Library/Application Support/Apple/Developer Tools/Plug-ins/XDCoreDataModel.xdplugin/Contents/Resources/momc";
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Developer/Library/Xcode/Plug-ins/XDCoreDataModel.xdplugin/Contents/Resources/momc"]) { // Xcode 2.4.
            momc = @"/Developer/Library/Xcode/Plug-ins/XDCoreDataModel.xdplugin/Contents/Resources/momc";
        }
        assert(momc && "momc not found");
        
        tempMOMPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:[(id)CFUUIDCreateString(kCFAllocatorDefault, CFUUIDCreate(kCFAllocatorDefault)) autorelease]] stringByAppendingPathExtension:@"mom"];
        system([[NSString stringWithFormat:@"\"%@\" \"%@\" \"%@\"", momc, path, tempMOMPath] UTF8String]); // Ignored system's result -- momc doesn't return any relevent error codes.
        path = tempMOMPath;
//		ddprintf(@"ASSERT momc:% @", momc);
    }
//	ddprintf(@"ASSERT model:% @", path);
    model = [[[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]] autorelease];
    assert(model);
}

- (int) application: (DDCliApplication *) app
   runWithArguments: (NSArray *) arguments;
{
    if (_help)
    {
        [self printUsage];
        return EXIT_SUCCESS;
    }
    
    if (_version)
    {
        printf("mogenerator 1.13.1. By Jonathan 'Wolf' Rentzsch + friends.\n");
        printf("morailsgenerator 1. By Manuel 'StuFF mc' Carrasco Molina.\n");
        return EXIT_SUCCESS;
    }
    
    gCustomBaseClass = [baseClass retain];
    NSString * mfilePath = includem;
	NSMutableString * mfileContent = [NSMutableString stringWithString:@""];
    if (outputDir == nil)
        outputDir = @"";
    if (machineDir == nil)
        machineDir = outputDir;
    if (humanDir == nil)
        humanDir = outputDir;

	NSFileManager *fm = [NSFileManager defaultManager];
    
	machineFilesGenerated = 0;        
	int humanFilesGenerated = 0;

	// !!!:@stuffmc:20090826 - Fixed the "deprecated" uses and checking (and reporting) for error.
	NSError *error = nil;
	
	if (model) {
		MiscMergeEngine *machineH = engineWithTemplatePath([self appSupportFileNamed:@"machine.h.motemplate"]);
		assert(machineH);
		MiscMergeEngine *machineM = engineWithTemplatePath([self appSupportFileNamed:@"machine.m.motemplate"]);
		assert(machineM);
		MiscMergeEngine *humanH = engineWithTemplatePath([self appSupportFileNamed:@"human.h.motemplate"]);
		assert(humanH);
		MiscMergeEngine *humanM = engineWithTemplatePath([self appSupportFileNamed:@"human.m.motemplate"]);
		assert(humanM);	
		
		// !!!:@stuffmc:20090826 - MiscMergeEngine *machineRB - Added support for generating Ruby On Rails template along side Core Data Template
		MiscMergeEngine *machineControllerRB;
		MiscMergeEngine *machineModelRB;
		MiscMergeEngine *machinePartialRB;
		MiscMergeEngine *machineChildrenRB;
		MiscMergeEngine *machineChildrenExistingRB;
		MiscMergeEngine *machineEditRB;
		MiscMergeEngine *machineIndexRB;
		MiscMergeEngine *machineNewRB;
		MiscMergeEngine *machineShowRB;
		MiscMergeEngine *machineMigrateRB;
		MiscMergeEngine *machineRoutesRB;
		MiscMergeEngine *machineAppLayoutRB;
		
		MiscMergeEngine *machineLocaleRB;
		
		MiscMergeEngine *humanModelRB;
		
		if (railsDir) {
//			NSString *path = [self appSupportFileNamed:@"ActiveSupportInflector/ActiveSupportInflector.plist"];
//			inflector = [[[ActiveSupportInflector alloc] initWithInflectionsFromFile:path] autorelease];

			// TODO: MiscMergeEngine, list of templates, ... in an NSArray and some kind of plist describing the template structure.
			machineControllerRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.controller.rb.motemplate"]);
			assert(machineControllerRB);
			machineModelRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.model.rb.motemplate"]);
			assert(machineModelRB);
			machinePartialRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.partial.rb.motemplate"]);
			assert(machinePartialRB);
			machineChildrenRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.children.rb.motemplate"]);
			assert(machineChildrenRB);
			machineChildrenExistingRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.existing.rb.motemplate"]);
			assert(machineChildrenExistingRB);
			machineEditRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.edit.rb.motemplate"]);
			assert(machineEditRB);
			machineIndexRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.index.rb.motemplate"]);
			assert(machineIndexRB);
			machineNewRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.new.rb.motemplate"]);
			assert(machineNewRB);
			machineShowRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.show.rb.motemplate"]);
			assert(machineShowRB);
			machineMigrateRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.migrate.rb.motemplate"]);
			assert(machineMigrateRB);
			
			machineRoutesRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.routes.rb.motemplate"]);
			assert(machineRoutesRB);
						
			machineAppLayoutRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.application.html.erb.motemplate"]);
			assert(machineAppLayoutRB);
			
			machineLocaleRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.locale.en.yml"]);
			assert(machineLocaleRB);
			
			// TODO: Add other human, not only the model.
			humanModelRB = engineWithTemplatePath([self appSupportFileNamed:@"human.model.rb.motemplate"]);
			assert(humanModelRB);
			
			machineDirRB = [railsDir stringByAppendingPathComponent:@"app"];
		}
		// --- end @stuffmc
        
		int entityCount = [[model entities] count];
        
		if(entityCount == 0){ 
			printf("No entities found in model. No files will be generated.\n");
			NSLog(@"the model description is %@.", model);
		}
		
		nsenumerate ([model entities], NSEntityDescription, entity) {
			NSString *entityClassName = [entity managedObjectClassName];
			
//			ddprintf(@"\n\n***ENTITY USER INFO:%@\n\n", [entity userInfo]);
            
			if (![entity hasSpecificCustomClass]){
				ddprintf(@"skipping entity %@ because it doesn't use a custom subclass.\n", 
                         entityClassName);
				continue;
			}
			
			NSString *generatedMachineH = [machineH executeWithObject:entity sender:nil];
			NSString *generatedMachineM = [machineM executeWithObject:entity sender:nil];
			NSString *generatedHumanH = [humanH executeWithObject:entity sender:nil];
			NSString *generatedHumanM = [humanM executeWithObject:entity sender:nil];
			
			BOOL machineDirtied = NO;

			NSString *machineHFileName = [machineDir stringByAppendingPathComponent:
                [NSString stringWithFormat:@"_%@.h", entityClassName]];
			if (![fm regularFileExistsAtPath:machineHFileName] || ![generatedMachineH isEqualToString:[NSString stringWithContentsOfFile:machineHFileName encoding:NSUTF8StringEncoding error:&error]]) {
				if (![self outputError:error]) {
					//	If the file doesn't exist or is different than what we just generated, write it out.
					[generatedMachineH writeToFile:machineHFileName atomically:NO encoding:NSUTF8StringEncoding error:&error];
					if (![self outputError:error]) {
						machineDirtied = YES;
						machineFilesGenerated++;
					}
				}
			}
			NSString *machineMFileName = [machineDir stringByAppendingPathComponent:
                [NSString stringWithFormat:@"_%@.m", entityClassName]];
			if (![fm regularFileExistsAtPath:machineMFileName] || ![generatedMachineM isEqualToString:[NSString stringWithContentsOfFile:machineMFileName encoding:NSUTF8StringEncoding error:&error]]) {
				if (![self outputError:error]) {
					//	If the file doesn't exist or is different than what we just generated, write it out.
					[generatedMachineM writeToFile:machineMFileName atomically:NO encoding:NSUTF8StringEncoding error:&error];
					if (![self outputError:error]) {
						machineDirtied = YES;
						machineFilesGenerated++;
					}
				}
			}
			NSString *humanHFileName = [humanDir stringByAppendingPathComponent:
                [NSString stringWithFormat:@"%@.h", entityClassName]];
			if ([fm regularFileExistsAtPath:humanHFileName]) {
				if (machineDirtied)
					[fm touchPath:humanHFileName];
			} else {
				[generatedHumanH writeToFile:humanHFileName atomically:NO encoding:NSUTF8StringEncoding error:&error];
				if (![self outputError:error]) {
					humanFilesGenerated++;
				}
			}

			NSString *humanMFileName = [humanDir stringByAppendingPathComponent:
                [NSString stringWithFormat:@"%@.m", entityClassName]];
			NSString *humanMMFileName = [humanDir stringByAppendingPathComponent:
                [NSString stringWithFormat:@"%@.mm", entityClassName]];
			if (![fm regularFileExistsAtPath:humanMFileName] && [fm regularFileExistsAtPath:humanMMFileName]) {
				//	Allow .mm human files as well as .m files.
				humanMFileName = humanMMFileName;
			}

			if ([fm regularFileExistsAtPath:humanMFileName]) {
				if (machineDirtied)
					[fm touchPath:humanMFileName];
			} else {
				[generatedHumanM writeToFile:humanMFileName atomically:NO encoding:NSUTF8StringEncoding error:&error];
				if (![self outputError:error]) {
					humanFilesGenerated++;
				}
			}
			
			[mfileContent appendFormat:@"#include \"%@\"\n#include \"%@\"\n",
                [humanMFileName lastPathComponent], [machineMFileName lastPathComponent]];
			
//			ddprintf(@"BEFORE railsDir");

			if (railsDir) {
//				ddprintf(@"\nrails machineControllerRB: %@", machineControllerRB);
				machineDirtied = [self processEntity:entity forMachine:machineControllerRB	withFileName:@"_controller.rb"];
				machineDirtied = [self processEntity:entity forMachine:machineModelRB		withFileName:@".rb"];
				machineDirtied = [self processEntity:entity forMachine:machinePartialRB		withFileName:@"/_.html.erb"];

//				ddprintf(@"BEFORE traverseRelationShipsForEntity");

				machineDirtied = [self traverseRelationShipsForEntity:entity migrate:machineMigrateRB children:machineChildrenRB existing:machineChildrenExistingRB];
				
				machineDirtied = [self processEntity:entity forMachine:machineEditRB		withFileName:@"/edit.html.erb"];
				machineDirtied = [self processEntity:entity forMachine:machineIndexRB		withFileName:@"/index.html.erb"];
				machineDirtied = [self processEntity:entity forMachine:machineNewRB			withFileName:@"/new.html.erb"];
				machineDirtied = [self processEntity:entity forMachine:machineShowRB		withFileName:@"/show.html.erb"];
				machineDirtied = [self processEntity:entity forMachine:machineMigrateRB		withFileName:@"migrate"];

				// TODO: Add other human files, not only the model...
				NSString *generatedHumanRB = [humanModelRB executeWithObject:entity sender:nil];
				NSString *humanRBFileName = [machineDirRB stringByAppendingPathComponent:
											 [NSString stringWithFormat:@"models/_%@.rb", [entityClassName underscorize]]];
				if ([fm regularFileExistsAtPath:humanRBFileName]) {
					if (machineDirtied)
						[fm touchPath:humanRBFileName];
				} else {
					[generatedHumanRB writeToFile:humanRBFileName atomically:NO encoding:NSUTF8StringEncoding error:&error];
					if (![self outputError:error]) {
						humanFilesGenerated++;
					}
				}
				
			}
		} 

		[self processEntity:nil forMachine:machineRoutesRB		withFileName:@"config/routes.rb"];
		[self processEntity:nil forMachine:machineAppLayoutRB	withFileName:@"app/views/layouts/application.html.erb"];
		[self processEntity:nil forMachine:machineLocaleRB		withFileName:@"config/locales/en.yml"];
		
		
	}
	
	if (tempMOMPath) {
		[fm removeItemAtPath:tempMOMPath error:&error];
		[self outputError:error];
	}
	bool mfileGenerated = NO;
	if (mfilePath && ![mfileContent isEqualToString:@""]) {
		[mfileContent writeToFile:mfilePath atomically:NO encoding:NSUTF8StringEncoding error:&error];
		mfileGenerated = YES;
	}
	
	printf("%d machine files%s %d human files%s generated.\n", machineFilesGenerated,
		   (mfileGenerated ? "," : " and"), humanFilesGenerated, (mfileGenerated ? " and one include.m file" : ""));
    
    return EXIT_SUCCESS;
}

- (BOOL)traverseRelationShipsForEntity:(NSEntityDescription *)entity migrate:(MiscMergeEngine *)machineMigrateRB children:(MiscMergeEngine *)machineChildrenRB existing:(MiscMergeEngine *)machineChildrenExistingRB {
	// TODO: Extract this whole loop in a method!
	BOOL machineDirtied = false;
	for (NSEntityDescription *oneEntityFromTheModel in [model entities]) {
		for (NSRelationshipDescription *child in [entity relationshipsWithDestinationEntity:oneEntityFromTheModel]) {
			if ([child isToMany]) {
//				ddprintf(@"\nPARENT is %@, CHILD is %@\n", [[child inverseRelationship] name], [child name]);

				machineDirtied = [self processEntity:child forMachine:machineChildrenRB	
										withFileName:[NSString stringWithFormat:@"/_children_%@", [[[entity managedObjectClassName] pluralize] underscorize]]];
				machineDirtied = [self processEntity:child forMachine:machineChildrenExistingRB	
										withFileName:[NSString stringWithFormat:@"/_children_%@_existing", [[[entity managedObjectClassName] pluralize] underscorize]]];
				if ([[child inverseRelationship] isToMany] && ![[child inverseRelationship] isTransient]) {
					// We need to create a migration "HABTM" join table in Rails for this "many-to-many" CoreData representation.
					// The "isTranscient" check is just a way to "mark it as done" since we only need to do the Join Table once.
					// We might want to use something in the UserInfo of the inverseRelationship instead.
					// BTW: We are not using this model to save any data anyways, so we can "misuse" transient, no big deal :-)
					NSEntityDescription *entityJoin = [[[NSEntityDescription alloc] init] autorelease];
					NSString *firstEntityName, *secondEntityName;
					if ([[child name] isGreaterThan:[[child inverseRelationship] name]]) {
						firstEntityName = [[child inverseRelationship] name];
						secondEntityName = [child name];
					} else {
						firstEntityName = [child name];
						secondEntityName = [[child inverseRelationship] name];
					}
					
					[entityJoin setName:[NSString stringWithFormat:@"%@%@", firstEntityName, [[secondEntityName singularize] initialCapitalString]]];
					[entityJoin setAbstract:YES]; // This "abstract" flag is just a way to mark it as a join table. We might want to use something in the UserInfo later.
					
					
					NSAttributeDescription *child_id = [[NSAttributeDescription alloc] init];
					[child_id setName:[NSString stringWithFormat:@"%@_id", [[child name] singularize]]];
					[child_id setAttributeType:NSInteger64AttributeType];
					
					NSAttributeDescription *parent_id = [[NSAttributeDescription alloc] init];
					[parent_id setAttributeType:NSInteger64AttributeType];
					NSRelationshipDescription *inverse = [child inverseRelationship];
					[parent_id setName:[NSString stringWithFormat:@"%@_id", ([[inverse destinationEntity] isKindOfEntity:oneEntityFromTheModel]) ? [[oneEntityFromTheModel name] underscorize] : [[[inverse name] singularize] underscorize] ] ];
					
					[entityJoin setProperties:[NSArray arrayWithObjects:child_id, parent_id, nil]];
					machineDirtied = [self processEntity:entityJoin forMachine:machineMigrateRB		withFileName:@"migrate"];
					[child setTransient:YES]; // "Marked as done", this way the Join table will only be done once. See comment up.
				}
			}
		}
	}
	return machineDirtied;
}

// !!!:@stuffmc:20090826 - Checking (and reporting) for error..
- (NSError*)outputError:(NSError*)error {
	if (error) {
		ddprintf(@"\nError occured: %@", error);
	}
	return error;
}

- (BOOL)processEntity:(id)entityModelOrRelationShip forMachine:(MiscMergeEngine*)machine withFileName:(NSString *)fileName {

	NSString *entityClassName = nil;
	NSEntityDescription *entity = nil;
	if ([entityModelOrRelationShip isKindOfClass:[NSEntityDescription class]] || [entityModelOrRelationShip isKindOfClass:[NSRelationshipDescription class]]) {
		if ([entityModelOrRelationShip isKindOfClass:[NSRelationshipDescription class]]) {
			entity = [entityModelOrRelationShip destinationEntity];
		} else {
			entity = entityModelOrRelationShip;
		}
		entityClassName = [[entity managedObjectClassName] underscorize];
	}
	NSString *generatedMachine = [machine executeWithObject:(entityModelOrRelationShip)?(id)entityModelOrRelationShip:(id)model sender:nil];

	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *machineRBFileName;
	NSString *machineDirToCreate = nil;
	NSString *currentMachineDir;
	
	NSString *directoryEntity;
	NSMutableString *fileNameDirectoryEntity;
	if ([fileName hasPrefix:@"/"]) {
		NSString *childrenString = @"/_children_";
		if ([fileName hasPrefix:childrenString]) {
			directoryEntity = [[fileName substringFromEndOfString:childrenString] pluralize];
			fileNameDirectoryEntity = [[directoryEntity singularize] mutableCopy];
//			NSLog(@"fileNameDirectoryEntity 1: %@ \n",  fileNameDirectoryEntity);
			NSString *existingString = @"_existing";
			if ([directoryEntity containsString:existingString]) {
				directoryEntity = [[directoryEntity substringToString:existingString] pluralize];
			}
		} else {
			directoryEntity = [entityClassName pluralize];
		}
		machineDirToCreate = [[machineDirRB stringByAppendingPathComponent:@"views"] stringByAppendingPathComponent:directoryEntity];

	}
	if ([fileName isEqualToString:@"migrate"]) {
		machineDirToCreate = [[railsDir stringByAppendingPathComponent:@"db"] stringByAppendingPathComponent:@"migrate"];
		NSDateComponents *dc = [[NSCalendar currentCalendar] components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit  fromDate:[NSDate date]];
		rand(); rand(); rand();
		fileName = [NSString stringWithFormat:@"%d%02d%02d%.0f_create_%@%@.rb", [dc year], [dc month], [dc day], round(rand()/(double)(RAND_MAX)*1000000), 
					[[[entity name] underscorize] pluralize], ([entity isAbstract]) ? @"_join" : @""];
//		if ([entityClassName hasPrefix:@"user_stat"]) {
//			ddprintf(@"[entity name]: %@ \n",  [entity name]);
//			ddprintf(@"=== directoryEntity: %@ \n",  directoryEntity);
//			ddprintf(@"=== fileName: %@\n", fileName);
//		}
	}

	if (machineDirToCreate) {
		if (![fm directoryExistsAtPath:machineDirToCreate]) {
			// Create the directory if it doesn't exist already
			if ([fm createDirectoryAtPath:machineDirToCreate attributes:nil]) {
				currentMachineDir = machineDirToCreate;
			} else {
				ddprintf(@"\nError while creating %@", machineDirToCreate);
			}
		}
		if ([fileName hasPrefix:@"/_"])	{
			if ([fileName hasPrefix:@"/_children"]) {
				fileName = [NSString stringWithFormat:@"/_%@_%@.html.erb", fileNameDirectoryEntity, entityClassName];
//				machineDirToCreate = machineDirToCreate.pluralize;
			} else {
				fileName = [NSString stringWithFormat:@"/_%@%@", entityClassName, [fileName substringFromIndex:2]];
			}
		}
		machineRBFileName = [machineDirToCreate stringByAppendingPathComponent:fileName];
//		ddprintf(@"fileName: %@\n", machineRBFileName);
	} else {
		if (entityClassName) {
			if ([fileName containsString:@"controller"]) {
				currentMachineDir = [machineDirRB stringByAppendingPathComponent:@"controllers"];
				entityClassName = [entityClassName pluralize];
			} else {
				currentMachineDir = [machineDirRB stringByAppendingPathComponent:@"models"];
			}
			//TODO: Might not work with Rails having a "_" at the beginning...
			//		machineRBFileName = [currentMachineDir stringByAppendingPathComponent:[NSString stringWithFormat:@"_%@%@", entityClassName, fileName]];
			machineRBFileName = [currentMachineDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", entityClassName, fileName]];
		} else {
			machineRBFileName = [railsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", fileName]];
		}
	}

	
	NSError *error = nil;
	BOOL machineDirtied = NO;
	
	if (![fm regularFileExistsAtPath:machineRBFileName] || ![generatedMachine isEqualToString:[NSString stringWithContentsOfFile:machineRBFileName encoding:NSUTF8StringEncoding error:&error]]) {
		if (![self outputError:error]) {
			//	If the file doesn't exist or is different than what we just generated, write it out.
			[generatedMachine writeToFile:machineRBFileName atomically:NO encoding:NSUTF8StringEncoding error:&error];
			if (![self outputError:error]) {
				machineDirtied = YES;
				machineFilesGenerated++;
			}

		}
	}
	return machineDirtied;
}

@end

int main (int argc, char * const * argv)
{
    return DDCliAppRunWithClass([MOGeneratorApp class]);
}
