#!/usr/bin/env python3
"""
Generates LangSwitch.xcodeproj/project.pbxproj
"""

import os
import uuid

def gen_id():
    return uuid.uuid4().hex[:24].upper()

# Source files
SOURCE_FILES = [
    "main.swift",
    "AppDelegate.swift",
    "MenuBarController.swift",
    "HotkeyManager.swift",
    "TextBoundaryTracker.swift",
    "TextAccessibilityHelper.swift",
    "TextConverter.swift",
    "LanguageManager.swift",
    "ConversionHistory.swift",
    "OnboardingWindowController.swift",
    "SettingsWindowController.swift",
]

RESOURCE_FILES = [
    "Info.plist",
]

# Generate stable IDs (keyed by name for reproducibility)
def stable_id(seed):
    h = uuid.uuid5(uuid.NAMESPACE_DNS, seed).hex[:24].upper()
    return h

# IDs
PROJECT_ID         = stable_id("project")
TARGET_ID          = stable_id("target")
PRODUCTS_GROUP_ID  = stable_id("productsGroup")
MAIN_GROUP_ID      = stable_id("mainGroup")
SOURCES_GROUP_ID   = stable_id("sourcesGroup")
RESOURCES_GROUP_ID = stable_id("resourcesGroup")
FRAMEWORKS_GROUP_ID= stable_id("frameworksGroup")
PRODUCTS_REF_ID    = stable_id("productsRef")

BUILD_PHASES_SOURCES_ID   = stable_id("buildPhaseSources")
BUILD_PHASES_FRAMEWORKS_ID= stable_id("buildPhaseFrameworks")
BUILD_PHASES_RESOURCES_ID = stable_id("buildPhaseResources")

CONFIG_LIST_PROJECT_ID = stable_id("configListProject")
CONFIG_LIST_TARGET_ID  = stable_id("configListTarget")
CONFIG_DEBUG_PROJECT_ID  = stable_id("configDebugProject")
CONFIG_RELEASE_PROJECT_ID= stable_id("configReleaseProject")
CONFIG_DEBUG_TARGET_ID   = stable_id("configDebugTarget")
CONFIG_RELEASE_TARGET_ID = stable_id("configReleaseTarget")

APPKIT_FRAMEWORK_FILE_REF = stable_id("appKitFrameworkRef")
APPKIT_FRAMEWORK_BUILD_FILE = stable_id("appKitFrameworkBuildFile")

ENTITLEMENTS_FILE_REF  = stable_id("entitlementsFileRef")

# Per-file IDs
file_ref_ids = {}
build_file_ids = {}
for f in SOURCE_FILES + RESOURCE_FILES + ["LangSwitch.entitlements"]:
    file_ref_ids[f] = stable_id("fileRef_" + f)
    build_file_ids[f] = stable_id("buildFile_" + f)

PRODUCT_REF_ID = stable_id("productRef")

def pbxproj():
    lines = []

    def w(s=""):
        lines.append(s)

    w("// !$*UTF8*$!")
    w("{")
    w("\tarchiveVersion = 1;")
    w("\tclasses = {")
    w("\t};")
    w("\tobjectVersion = 56;")
    w("\tobjects = {")
    w()

    # ---- PBXBuildFile section ----
    w("/* Begin PBXBuildFile section */")
    # Swift source files
    for f in SOURCE_FILES:
        w(f"\t\t{build_file_ids[f]} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_ids[f]} /* {f} */; }};")
    # Resources
    for f in RESOURCE_FILES:
        w(f"\t\t{build_file_ids[f]} /* {f} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ref_ids[f]} /* {f} */; }};")
    # AppKit framework
    w(f"\t\t{APPKIT_FRAMEWORK_BUILD_FILE} /* AppKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {APPKIT_FRAMEWORK_FILE_REF} /* AppKit.framework */; }};")
    w("/* End PBXBuildFile section */")
    w()

    # ---- PBXFileReference section ----
    w("/* Begin PBXFileReference section */")
    for f in SOURCE_FILES:
        w(f"\t\t{file_ref_ids[f]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = \"{f}\"; path = \"LangSwitch/{f}\"; sourceTree = \"<group>\"; }};")
    for f in RESOURCE_FILES:
        w(f"\t\t{file_ref_ids[f]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = \"{f}\"; path = \"LangSwitch/{f}\"; sourceTree = \"<group>\"; }};")
    # Entitlements
    f = "LangSwitch.entitlements"
    w(f"\t\t{file_ref_ids[f]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; name = \"{f}\"; path = \"LangSwitch/{f}\"; sourceTree = \"<group>\"; }};")
    # AppKit framework
    w(f"\t\t{APPKIT_FRAMEWORK_FILE_REF} /* AppKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = AppKit.framework; path = System/Library/Frameworks/AppKit.framework; sourceTree = SDKROOT; }};")
    # Product
    w(f"\t\t{PRODUCT_REF_ID} /* LangSwitch.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = LangSwitch.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    w("/* End PBXFileReference section */")
    w()

    # ---- PBXFrameworksBuildPhase ----
    w("/* Begin PBXFrameworksBuildPhase section */")
    w(f"\t\t{BUILD_PHASES_FRAMEWORKS_ID} /* Frameworks */ = {{")
    w("\t\t\tisa = PBXFrameworksBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    w(f"\t\t\t\t{APPKIT_FRAMEWORK_BUILD_FILE} /* AppKit.framework in Frameworks */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXFrameworksBuildPhase section */")
    w()

    # ---- PBXGroup section ----
    w("/* Begin PBXGroup section */")

    # Main group
    w(f"\t\t{MAIN_GROUP_ID} = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{SOURCES_GROUP_ID} /* LangSwitch */,")
    w(f"\t\t\t\t{FRAMEWORKS_GROUP_ID} /* Frameworks */,")
    w(f"\t\t\t\t{PRODUCTS_GROUP_ID} /* Products */,")
    w("\t\t\t);")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Sources group
    w(f"\t\t{SOURCES_GROUP_ID} /* LangSwitch */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for f in SOURCE_FILES:
        w(f"\t\t\t\t{file_ref_ids[f]} /* {f} */,")
    for f in RESOURCE_FILES:
        w(f"\t\t\t\t{file_ref_ids[f]} /* {f} */,")
    f_ent = "LangSwitch.entitlements"
    w(f"\t\t\t\t{file_ref_ids[f_ent]} /* {f_ent} */,")
    w("\t\t\t);")
    w("\t\t\tname = LangSwitch;")
    w("\t\t\tpath = LangSwitch;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Products group
    w(f"\t\t{PRODUCTS_GROUP_ID} /* Products */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{PRODUCT_REF_ID} /* LangSwitch.app */,")
    w("\t\t\t);")
    w("\t\t\tname = Products;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Frameworks group
    w(f"\t\t{FRAMEWORKS_GROUP_ID} /* Frameworks */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{APPKIT_FRAMEWORK_FILE_REF} /* AppKit.framework */,")
    w("\t\t\t);")
    w("\t\t\tname = Frameworks;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    w("/* End PBXGroup section */")
    w()

    # ---- PBXNativeTarget ----
    w("/* Begin PBXNativeTarget section */")
    w(f"\t\t{TARGET_ID} /* LangSwitch */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {CONFIG_LIST_TARGET_ID} /* Build configuration list for PBXNativeTarget \"LangSwitch\" */;")
    w("\t\t\tbuildPhases = (")
    w(f"\t\t\t\t{BUILD_PHASES_SOURCES_ID} /* Sources */,")
    w(f"\t\t\t\t{BUILD_PHASES_FRAMEWORKS_ID} /* Frameworks */,")
    w(f"\t\t\t\t{BUILD_PHASES_RESOURCES_ID} /* Resources */,")
    w("\t\t\t);")
    w("\t\t\tbuildRules = (")
    w("\t\t\t);")
    w("\t\t\tdependencies = (")
    w("\t\t\t);")
    w("\t\t\tname = LangSwitch;")
    w(f"\t\t\tproductName = LangSwitch;")
    w(f"\t\t\tproductReference = {PRODUCT_REF_ID} /* LangSwitch.app */;")
    w("\t\t\tproductType = \"com.apple.product-type.application\";")
    w("\t\t};")
    w("/* End PBXNativeTarget section */")
    w()

    # ---- PBXProject ----
    w("/* Begin PBXProject section */")
    w(f"\t\t{PROJECT_ID} /* Project object */ = {{")
    w("\t\t\tisa = PBXProject;")
    w("\t\t\tattributes = {")
    w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    w("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    w("\t\t\t\tLastUpgradeCheck = 1500;")
    w("\t\t\t\tTargetAttributes = {")
    w(f"\t\t\t\t\t{TARGET_ID} = {{")
    w("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    w("\t\t\t\t\t};")
    w("\t\t\t\t};")
    w("\t\t\t};")
    w(f"\t\t\tbuildConfigurationList = {CONFIG_LIST_PROJECT_ID} /* Build configuration list for PBXProject \"LangSwitch\" */;")
    w("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    w("\t\t\tdevelopmentRegion = en;")
    w("\t\t\thasScannedForEncodings = 0;")
    w("\t\t\tknownRegions = (")
    w("\t\t\t\ten,")
    w("\t\t\t\tBase,")
    w("\t\t\t);")
    w(f"\t\t\tmainGroup = {MAIN_GROUP_ID};")
    w(f"\t\t\tproductRefGroup = {PRODUCTS_GROUP_ID} /* Products */;")
    w("\t\t\tprojectDirPath = \"\";")
    w("\t\t\tprojectRoot = \"\";")
    w("\t\t\ttargets = (")
    w(f"\t\t\t\t{TARGET_ID} /* LangSwitch */,")
    w("\t\t\t);")
    w("\t\t};")
    w("/* End PBXProject section */")
    w()

    # ---- PBXResourcesBuildPhase ----
    w("/* Begin PBXResourcesBuildPhase section */")
    w(f"\t\t{BUILD_PHASES_RESOURCES_ID} /* Resources */ = {{")
    w("\t\t\tisa = PBXResourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for f in RESOURCE_FILES:
        w(f"\t\t\t\t{build_file_ids[f]} /* {f} in Resources */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXResourcesBuildPhase section */")
    w()

    # ---- PBXSourcesBuildPhase ----
    w("/* Begin PBXSourcesBuildPhase section */")
    w(f"\t\t{BUILD_PHASES_SOURCES_ID} /* Sources */ = {{")
    w("\t\t\tisa = PBXSourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for f in SOURCE_FILES:
        w(f"\t\t\t\t{build_file_ids[f]} /* {f} in Sources */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXSourcesBuildPhase section */")
    w()

    # ---- XCBuildConfiguration section ----
    w("/* Begin XCBuildConfiguration section */")

    # Project Debug
    w(f"\t\t{CONFIG_DEBUG_PROJECT_ID} /* Debug */ = {{")
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    w("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    w("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    w("\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;")
    w("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
    w("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    w("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    w("\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;")
    w("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    w("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
    w("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
    w("\t\t\t\tENABLE_TESTABILITY = YES;")
    w("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
    w("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
    w("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
    w("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
    w("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (")
    w("\t\t\t\t\t\"DEBUG=1\",")
    w("\t\t\t\t\t\"$(inherited)\",")
    w("\t\t\t\t);")
    w("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;")
    w("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
    w("\t\t\t\tMTL_FAST_MATH = YES;")
    w("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
    w("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
    w("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
    w("\t\t\t};")
    w("\t\t\tname = Debug;")
    w("\t\t};")

    # Project Release
    w(f"\t\t{CONFIG_RELEASE_PROJECT_ID} /* Release */ = {{")
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    w("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    w("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    w("\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;")
    w("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
    w("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    w("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    w("\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;")
    w("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    w("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
    w("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
    w("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
    w("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
    w("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
    w("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;")
    w("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
    w("\t\t\t\tMTL_FAST_MATH = YES;")
    w("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
    w("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
    w("\t\t\t};")
    w("\t\t\tname = Release;")
    w("\t\t};")

    # Target Debug
    w(f"\t\t{CONFIG_DEBUG_TARGET_ID} /* Debug */ = {{")
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    w("\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"LangSwitch/LangSwitch.entitlements\";")
    w("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    w("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
    w("\t\t\t\tINFOPLIST_FILE = \"LangSwitch/Info.plist\";")
    w("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    w("\t\t\t\t\t\"$(inherited)\",")
    w("\t\t\t\t\t\"@executable_path/../Frameworks\",")
    w("\t\t\t\t);")
    w("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;")
    w("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"com.langswitch.app\";")
    w("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    w("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    w("\t\t\t\tSWIFT_VERSION = 5.0;")
    w("\t\t\t};")
    w("\t\t\tname = Debug;")
    w("\t\t};")

    # Target Release
    w(f"\t\t{CONFIG_RELEASE_TARGET_ID} /* Release */ = {{")
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    w("\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"LangSwitch/LangSwitch.entitlements\";")
    w("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    w("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
    w("\t\t\t\tINFOPLIST_FILE = \"LangSwitch/Info.plist\";")
    w("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    w("\t\t\t\t\t\"$(inherited)\",")
    w("\t\t\t\t\t\"@executable_path/../Frameworks\",")
    w("\t\t\t\t);")
    w("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;")
    w("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"com.langswitch.app\";")
    w("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    w("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    w("\t\t\t\tSWIFT_VERSION = 5.0;")
    w("\t\t\t};")
    w("\t\t\tname = Release;")
    w("\t\t};")

    w("/* End XCBuildConfiguration section */")
    w()

    # ---- XCConfigurationList section ----
    w("/* Begin XCConfigurationList section */")

    # Project config list
    w(f"\t\t{CONFIG_LIST_PROJECT_ID} /* Build configuration list for PBXProject \"LangSwitch\" */ = {{")
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f"\t\t\t\t{CONFIG_DEBUG_PROJECT_ID} /* Debug */,")
    w(f"\t\t\t\t{CONFIG_RELEASE_PROJECT_ID} /* Release */,")
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")

    # Target config list
    w(f"\t\t{CONFIG_LIST_TARGET_ID} /* Build configuration list for PBXNativeTarget \"LangSwitch\" */ = {{")
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f"\t\t\t\t{CONFIG_DEBUG_TARGET_ID} /* Debug */,")
    w(f"\t\t\t\t{CONFIG_RELEASE_TARGET_ID} /* Release */,")
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")

    w("/* End XCConfigurationList section */")
    w()

    w("\t};")
    w(f"\trootObject = {PROJECT_ID} /* Project object */;")
    w("}")

    return "\n".join(lines)


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    xcodeproj_dir = os.path.join(script_dir, "LangSwitch.xcodeproj")
    os.makedirs(xcodeproj_dir, exist_ok=True)

    pbxproj_path = os.path.join(xcodeproj_dir, "project.pbxproj")
    content = pbxproj()

    with open(pbxproj_path, "w") as f:
        f.write(content)

    print(f"Generated: {pbxproj_path}")
    print(f"Project IDs:")
    print(f"  Project:      {PROJECT_ID}")
    print(f"  Target:       {TARGET_ID}")
    print(f"  Source files: {len(SOURCE_FILES)}")
