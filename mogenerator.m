/*******************************************************************************
	mogenerator.m
		Copyright (c) 2006-2008 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import "mogenerator.h"
#import "ActiveSupportInflector.h"

NSString	*gCustomBaseClass;

@implementation NSEntityDescription (customBaseClass)
- (BOOL)hasCustomSuperentity {
	NSEntityDescription *superentity = [self superentity];
	if (superentity) {
		return YES;
	} else {
		return gCustomBaseClass ? YES : NO;
	}
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
//- (NSString*)pluralize {
////	ddprintf(@"\nplural of person is %@ and singular of people is %@", [inflector pluralize:@"person"], [inflector singularize:@"people"]);
//	// TODO: Use the same for NSAttributeDescription & NSEntityDescription  Get the appSuportFileName AND Pass the inflector, *DO NOT* initialize it everytime. Time pressure right now :(
////	NSString *path = [self appSupportFileNamed:@"ActiveSupportInflector/ActiveSupportInflector.plist"];
//	NSString *path = @"/Volumes/Macintosh HD/Code/Open Source/mogenerator/contributed templates/StuFF mc/ActiveSupportInflector/ActiveSupportInflector.plist";
//	ActiveSupportInflector *inflector = [[[ActiveSupportInflector alloc] initWithInflectionsFromFile:path] autorelease];
//	return [inflector pluralize:[self name]];
//}

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
- (BOOL)isTimeStamp {
	// This allows the templates to check for the "timestamp" fields used by Rails and thus, not display them.
	return ([[self name] isEqualToString:@"createdAt"] || [[self name] isEqualToString:@"updatedAt"]);
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
           "  -R, --rails-dir DIR		Location of the already created Rails App's {RAILS_ROOT}\n"
           "      --version                 Display version and exit\n"
           "  -h, --help                    Display this help and exit\n"
           "\n"
           "Implements generation gap codegen pattern for Core Data.\n"
           "Inspired by eogenerator.\n");
}

- (void) setModel: (NSString *) path;
{
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
    }
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
		MiscMergeEngine *machineEditRB;
		MiscMergeEngine *machineIndexRB;
		MiscMergeEngine *machineNewRB;
		MiscMergeEngine *machineShowRB;
		MiscMergeEngine *machineMigrateRB;
		MiscMergeEngine *humanRB;
		
		if (railsDir) {
//			NSString *path = [self appSupportFileNamed:@"ActiveSupportInflector/ActiveSupportInflector.plist"];
//			inflector = [[[ActiveSupportInflector alloc] initWithInflectionsFromFile:path] autorelease];

			machineControllerRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.controller.rb.motemplate"]);
			assert(machineControllerRB);
			machineModelRB = engineWithTemplatePath([self appSupportFileNamed:@"machine.model.rb.motemplate"]);
			assert(machineModelRB);
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
			
			// TODO: Add human RB's, not crucial for the moment since I'll have them empty during the dev.
			humanRB = engineWithTemplatePath([self appSupportFileNamed:@"human.rb.motemplate"]);
			assert(humanRB);
		}
		// --- end @stuffmc
        
		int entityCount = [[model entities] count];
        
		if(entityCount == 0){ 
			printf("No entities found in model. No files will be generated.\n");
			NSLog(@"the model description is %@.", model);
		}
		
		nsenumerate ([model entities], NSEntityDescription, entity) {
			NSString *entityClassName = [entity managedObjectClassName];
            
			if ([entityClassName isEqualToString:@"NSManagedObject"] ||
				[entityClassName isEqualToString:gCustomBaseClass]){
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
			
			if (railsDir) {
//				ddprintf(@"\nrails machineControllerRB: %@", machineControllerRB);
				machineDirtied = [self processEntity:entity forMachine:machineControllerRB	withFileName:@"_controller.rb"];
				machineDirtied = [self processEntity:entity forMachine:machineModelRB		withFileName:@".rb"];
				machineDirtied = [self processEntity:entity forMachine:machineEditRB		withFileName:@"/edit.html.erb"];
				machineDirtied = [self processEntity:entity forMachine:machineIndexRB		withFileName:@"/index.html.erb"];
				machineDirtied = [self processEntity:entity forMachine:machineNewRB			withFileName:@"/new.html.erb"];
				machineDirtied = [self processEntity:entity forMachine:machineShowRB		withFileName:@"/show.html.erb"];
				machineDirtied = [self processEntity:entity forMachine:machineMigrateRB		withFileName:@"migrate"];

				//	- (void) setUp {
				//		[self setInflector:[[[ActiveSupportInflector alloc] init] autorelease]];
				//	}
				//	
				//	- (void) testPluralizationAndSingularization {
				
				
				// TODO: Add human RB's, not crucial for the moment since I'll have them empty during the dev.
//				NSString *generatedHumanRB = [humanRB executeWithObject:entity sender:nil];
//				NSString *humanRBFileName = [humanDir stringByAppendingPathComponent:
//											 [NSString stringWithFormat:@"%@.rb", entityClassName]];
//				if ([fm regularFileExistsAtPath:humanRBFileName]) {
//					if (machineDirtied)
//						[fm touchPath:humanRBFileName];
//				} else {
//					[generatedHumanRB writeToFile:humanRBFileName atomically:NO encoding:NSUTF8StringEncoding error:&error];
//					if (![self outputError:error]) {
//						humanFilesGenerated++;
//					}
//				}
				
			}
		}
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

// !!!:@stuffmc:20090826 - Checking (and reporting) for error..
- (NSError*)outputError:(NSError*)error {
	if (error) {
		ddprintf(@"\nError occured: %@", error);
	}
	return error;
}

- (BOOL)processEntity:(NSEntityDescription *)entity forMachine:(MiscMergeEngine*)machine withFileName:(NSString *)fileName {

	NSString *entityClassName = [[entity managedObjectClassName] lowercaseString];
	NSString *generatedMachine = [machine executeWithObject:entity sender:nil];

//	ddprintf(@"\nrails entityClassName: %@ - generatedMachine: %@", entityClassName, generatedMachine);

	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *machineRBFileName;
	NSString *machineDirRB = [railsDir stringByAppendingPathComponent:@"app"];
	NSString *machineDirToCreate = nil;
	
	if ([fileName hasPrefix:@"/"]) {
//		machineDirToCreate = [[machineDirRB stringByAppendingPathComponent:@"views"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@s", [entityClassName lowercaseString]]];
		machineDirToCreate = [[machineDirRB stringByAppendingPathComponent:@"views"] stringByAppendingPathComponent:[entityClassName pluralize]];
	}
	if ([fileName isEqualToString:@"migrate"]) {
		machineDirToCreate = [[railsDir stringByAppendingPathComponent:@"db"] stringByAppendingPathComponent:@"migrate"];
		NSDateComponents *dc = [[NSCalendar currentCalendar] components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit  fromDate:[NSDate date]];
		rand(); rand(); rand();
//		NSLog(@"DATE: %d%02d%02d%.0f", [dc year], [dc month], [dc day], round(rand()/(double)(RAND_MAX)*1000000));
		fileName = [NSString stringWithFormat:@"%d%02d%02d%.0f_create_%@.rb", [dc year], [dc month], [dc day], round(rand()/(double)(RAND_MAX)*1000000), [entityClassName pluralize]];
	}

	if (machineDirToCreate) {
		if (![fm directoryExistsAtPath:machineDirToCreate]) {
			// Create the directory if it doesn't exist already
	//		ddprintf(@"[machineDir stringByAppendingPathComponent:entityClassName]: %@", [machineDir stringByAppendingPathComponent:entityClassName]);
			if ([fm createDirectoryAtPath:machineDirToCreate attributes:nil]) {
				machineDirRB = machineDirToCreate;
			} else {
				ddprintf(@"\nError while creating %@", machineDirToCreate);
			}
		}
		machineRBFileName = [machineDirToCreate stringByAppendingPathComponent:fileName];
	} else {
		if ([fileName containsString:@"controller"]) {
			machineDirRB = [machineDirRB stringByAppendingPathComponent:@"controllers"];
//			ddprintf(@"\n entityClassName: %@ = %@", entityClassName, [entityClassName pluralize]);
			entityClassName = [entityClassName pluralize];
		} else {
			machineDirRB = [machineDirRB stringByAppendingPathComponent:@"models"];
		}
		//TODO: Might not work with Rails having a "_" at the beginning...
//		machineRBFileName = [machineDirRB stringByAppendingPathComponent:[NSString stringWithFormat:@"_%@%@", entityClassName, fileName]];
		machineRBFileName = [machineDirRB stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", entityClassName, fileName]];
//		ddprintf(@"\n***machineRBFileName: %@", machineRBFileName);
	}

	
//	ddprintf(@"\n%s -- entityClassName = %@ -- machineRBFileName = %@", _cmd, entityClassName, machineRBFileName);
	NSError *error = nil;
	BOOL machineDirtied = NO;
	
	if (![fm regularFileExistsAtPath:machineRBFileName] || ![generatedMachine isEqualToString:[NSString stringWithContentsOfFile:machineRBFileName encoding:NSUTF8StringEncoding error:&error]]) {
		if (![self outputError:error]) {
//			ddprintf(@"\nAFTER 1st error");
			//	If the file doesn't exist or is different than what we just generated, write it out.
			[generatedMachine writeToFile:machineRBFileName atomically:NO encoding:NSUTF8StringEncoding error:&error];
			if (![self outputError:error]) {
//			if (true) {
//				ddprintf(@"\nAFTER 2nd error");
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
