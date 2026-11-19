"""Generate the checked-in Xcode project with no third-party project generator."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
objects = []

def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def q(value):
    return json.dumps(str(value), ensure_ascii=False)

def obj(name, body):
    key = ident(name)
    objects.append(f"\t\t{key} /* {name} */ = {{ {body} }};")
    return key

def ids(names):
    return "(" + ", ".join(ident(name) for name in names) + ",)" if names else "()"

def settings(values):
    return "{ " + " ".join(f"{key} = {q(value)};" for key, value in values.items()) + " }"

swift = sorted(p.name for p in (ROOT / 'Scrollshot').glob('*.swift'))
files = {name: ('sourcecode.swift', 'app') for name in swift}
files.update({
    'Info.plist': ('text.plist.xml', 'app'),
    'Scrollshot.entitlements': ('text.plist.entitlements', 'app'),
    'PrivacyInfo.xcprivacy': ('text.xml', 'app'),
    'Assets.xcassets': ('folder.assetcatalog', 'app'),
    'Scrollshot-Bridging-Header.h': ('sourcecode.c.h', 'app'),
    'SSMatcher.c': ('sourcecode.c.c', 'core'),
    'SSMatcher.h': ('sourcecode.c.h', 'core'),
    'ScrollshotTests.swift': ('sourcecode.swift', 'tests'),
})
for name, (kind, _) in files.items():
    obj('file:' + name, f'isa = PBXFileReference; lastKnownFileType = {q(kind)}; path = {q(name)}; sourceTree = "<group>";')
for name in swift + ['SSMatcher.c', 'PrivacyInfo.xcprivacy', 'Assets.xcassets', 'ScrollshotTests.swift']:
    obj('build:' + name, f'isa = PBXBuildFile; fileRef = {ident("file:" + name)};')

for label, path in [('app', 'Scrollshot'), ('core', 'Core'), ('tests', 'tests')]:
    children = ['file:' + name for name, (_, group) in files.items() if group == label]
    obj('group:' + label, f'isa = PBXGroup; children = {ids(children)}; path = {q(path)}; sourceTree = "<group>";')
obj('product:app', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Scrollshot.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('product:tests', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ScrollshotTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj('group:products', f'isa = PBXGroup; children = {ids(["product:app", "product:tests"])}; name = Products; sourceTree = "<group>";')
obj('group:root', f'isa = PBXGroup; children = {ids(["group:app", "group:core", "group:tests", "group:products"])}; sourceTree = "<group>";')

for target in ['app', 'tests']:
    source_names = swift + ['SSMatcher.c'] if target == 'app' else ['ScrollshotTests.swift']
    resources = ['PrivacyInfo.xcprivacy', 'Assets.xcassets'] if target == 'app' else []
    for phase, kind, names in [('sources', 'PBXSourcesBuildPhase', source_names), ('resources', 'PBXResourcesBuildPhase', resources), ('frameworks', 'PBXFrameworksBuildPhase', [])]:
        obj(f'{target}:{phase}', f'isa = {kind}; buildActionMask = 2147483647; files = {ids(["build:" + name for name in names])}; runOnlyForDeploymentPostprocessing = 0;')

obj('test:proxy', f'isa = PBXContainerItemProxy; containerPortal = {ident("project")}; proxyType = 1; remoteGlobalIDString = {ident("target:app")}; remoteInfo = Scrollshot;')
obj('test:dependency', f'isa = PBXTargetDependency; target = {ident("target:app")}; targetProxy = {ident("test:proxy")};')
for target, name, kind in [('app', 'Scrollshot', 'application'), ('tests', 'ScrollshotTests', 'bundle.unit-test')]:
    obj('target:' + target, f'''isa = PBXNativeTarget; buildConfigurationList = {ident(target + ':configlist')};
        buildPhases = {ids([target + ':sources', target + ':frameworks', target + ':resources'])}; buildRules = ();
        dependencies = {ids(['test:dependency'] if target == 'tests' else [])}; name = {name}; productName = {name};
        productReference = {ident('product:' + target)}; productType = "com.apple.product-type.{kind}";''')

base = {
    'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES',
    'GCC_C_LANGUAGE_STANDARD': 'gnu11', 'GCC_WARN_ABOUT_RETURN_TYPE': 'YES_ERROR',
    'CLANG_WARN_BOOL_CONVERSION': 'YES', 'CLANG_WARN_CONSTANT_CONVERSION': 'YES',
    'CLANG_WARN_INT_CONVERSION': 'YES', 'CLANG_WARN_UNREACHABLE_CODE': 'YES',
    'IPHONEOS_DEPLOYMENT_TARGET': '27.0', 'SDKROOT': 'iphoneos',
    'SWIFT_VERSION': '5.0', 'SWIFT_STRICT_CONCURRENCY': 'targeted',
}
app = {
    'PRODUCT_NAME': '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': 'local.scrollshot.iphone',
    'CODE_SIGN_STYLE': 'Automatic', 'DEVELOPMENT_TEAM': '',
    'CODE_SIGN_ENTITLEMENTS': 'Scrollshot/Scrollshot.entitlements',
    'INFOPLIST_FILE': 'Scrollshot/Info.plist', 'GENERATE_INFOPLIST_FILE': 'NO',
    'MARKETING_VERSION': '2.0.0', 'CURRENT_PROJECT_VERSION': '1',
    'TARGETED_DEVICE_FAMILY': '1', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator',
    'SUPPORTS_MACCATALYST': 'NO', 'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD': 'NO',
    'SWIFT_OBJC_BRIDGING_HEADER': '$(SRCROOT)/Scrollshot/Scrollshot-Bridging-Header.h',
    'HEADER_SEARCH_PATHS': '$(SRCROOT)/Core',
    'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
    'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks',
}
tests = {
    'PRODUCT_NAME': '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': 'local.scrollshot.iphone.tests',
    'CODE_SIGN_STYLE': 'Automatic', 'DEVELOPMENT_TEAM': '',
    'GENERATE_INFOPLIST_FILE': 'YES', 'TARGETED_DEVICE_FAMILY': '1',
    'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'SUPPORTS_MACCATALYST': 'NO',
    'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/Scrollshot.app/Scrollshot',
    'BUNDLE_LOADER': '$(TEST_HOST)',
    'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks @loader_path/Frameworks',
}
for target, values in [('project', base), ('app', app), ('tests', tests)]:
    for config in ['Debug', 'Release']:
        values = dict(values)
        if target == 'project':
            values.update({'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if config == 'Debug' else '-O',
                           'GCC_OPTIMIZATION_LEVEL': '0' if config == 'Debug' else 's',
                           'DEBUG_INFORMATION_FORMAT': 'dwarf' if config == 'Debug' else 'dwarf-with-dsym',
                           'ENABLE_TESTABILITY': 'YES' if config == 'Debug' else 'NO'})
        obj(target + ':' + config, f'isa = XCBuildConfiguration; buildSettings = {settings(values)}; name = {config};')
    obj(target + ':configlist', f'isa = XCConfigurationList; buildConfigurations = {ids([target + ":Debug", target + ":Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')

obj('project', f'''isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700;
    TargetAttributes = {{ {ident('target:app')} = {{ CreatedOnToolsVersion = 27.0; }};
    {ident('target:tests')} = {{ CreatedOnToolsVersion = 27.0; TestTargetID = {ident('target:app')}; }}; }}; }};
    buildConfigurationList = {ident('project:configlist')}; compatibilityVersion = "Xcode 14.0";
    developmentRegion = zh_CN; hasScannedForEncodings = 0; knownRegions = (zh_CN, en, Base,);
    mainGroup = {ident('group:root')}; productRefGroup = {ident('group:products')};
    projectDirPath = ""; projectRoot = ""; targets = {ids(['target:app', 'target:tests'])};''')

project = ROOT / 'Scrollshot.xcodeproj'
project.mkdir(exist_ok=True)
(project / 'project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n' + '\n'.join(objects) + '\n\t};\n\trootObject = ' + ident('project') + ';\n}\n', encoding='utf-8')

scheme = ET.Element('Scheme', LastUpgradeVersion='2700', version='1.3')
build_action = ET.SubElement(scheme, 'BuildAction', parallelizeBuildables='YES', buildImplicitDependencies='YES')
entries = ET.SubElement(build_action, 'BuildActionEntries')
entry = ET.SubElement(entries, 'BuildActionEntry', buildForTesting='YES', buildForRunning='YES', buildForProfiling='YES', buildForArchiving='YES', buildForAnalyzing='YES')

def reference(parent, target):
    return ET.SubElement(parent, 'BuildableReference', BuildableIdentifier='primary', BlueprintIdentifier=ident('target:' + target), BuildableName='Scrollshot.app' if target == 'app' else 'ScrollshotTests.xctest', BlueprintName='Scrollshot' if target == 'app' else 'ScrollshotTests', ReferencedContainer='container:Scrollshot.xcodeproj')

reference(entry, 'app')
test_action = ET.SubElement(scheme, 'TestAction', buildConfiguration='Debug', selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB', selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB', shouldUseLaunchSchemeArgsEnv='YES')
testable = ET.SubElement(ET.SubElement(test_action, 'Testables'), 'TestableReference', skipped='NO')
reference(testable, 'tests')
launch = ET.SubElement(scheme, 'LaunchAction', buildConfiguration='Debug', selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB', selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB', launchStyle='0', useCustomWorkingDirectory='NO', ignoresPersistentStateOnLaunch='NO', debugDocumentVersioning='YES', allowLocationSimulation='NO')
reference(ET.SubElement(launch, 'BuildableProductRunnable', runnableDebuggingMode='0'), 'app')
profile = ET.SubElement(scheme, 'ProfileAction', buildConfiguration='Release', shouldUseLaunchSchemeArgsEnv='YES', savedToolIdentifier='', useCustomWorkingDirectory='NO', debugDocumentVersioning='YES')
reference(ET.SubElement(profile, 'BuildableProductRunnable', runnableDebuggingMode='0'), 'app')
ET.SubElement(scheme, 'AnalyzeAction', buildConfiguration='Debug')
ET.SubElement(scheme, 'ArchiveAction', buildConfiguration='Release', revealArchiveInOrganizer='YES')
directory = project / 'xcshareddata' / 'xcschemes'
directory.mkdir(parents=True, exist_ok=True)
ET.indent(scheme)
(directory / 'Scrollshot.xcscheme').write_text(ET.tostring(scheme, encoding='unicode') + '\n', encoding='utf-8')
print('Generated Scrollshot.xcodeproj (iPhone app + native tests).')
