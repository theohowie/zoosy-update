import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取签名配置（key.properties 已被 .gitignore 忽略，不会提交到仓库）
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// key.properties 里沿用 AGP 习惯：相对路径先按 app 模块解析
// （storeFile=upload-keystore.jks -> android/app/upload-keystore.jks），
// 找不到再按 android/ 解析（../keystores/legacy-debug.jks -> android/keystores/...）。
fun keystorePath(value: String?): File {
    if (value.isNullOrBlank()) throw GradleException("key.properties 中缺少路径配置")
    val f = File(value)
    if (f.isAbsolute) return f
    val fromApp = file(value)                       // android/app/<value>
    if (fromApp.exists()) return fromApp
    val fromRoot = rootProject.file(value)          // android/<value>
    if (fromRoot.exists()) return fromRoot
    return fromApp
}

android {
    namespace = "com.theohowie.zoosy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.theohowie.zoosy"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // 仅当 key.properties 存在时配置正式签名，否则回退 debug 签名（便于 CI/他人克隆构建）
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystorePath(keystoreProperties["storeFile"] as String?)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            // R8 代码混淆 + 资源压缩（release 默认关闭，这里显式开启）
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // MMKV 高性能 KV 存储
    implementation("com.tencent:mmkv:1.3.1")
}

flutter {
    source = "../.."
}

// ============================================================================
//  签名配置自检
//
//  历史包袱：<= v1.15.0 的正式包用 debug 密钥签名，v1.16.0 起改用 upload 密钥，
//  Android 只允许同签名的包覆盖安装，老用户升级会报「签名冲突」。
//  修复方式是 v3 签名密钥轮换（lineage: debug -> upload），由
//  tool/build-release.ps1 在 flutter build 之后追加签名。
//
//  这里只做配置自检，避免发出无法让老用户升级的包。
// ============================================================================
tasks.register("verifyReleaseSigningConfig") {
    group = "verification"
    description = "检查 release 签名与密钥轮换（lineage）配置是否完整"

    val propsFile = rootProject.file("key.properties")
    val legacyPath = keystoreProperties["legacyStoreFile"] as String?
    val lineagePath = keystoreProperties["lineageFile"] as String?
    val hasProps = propsFile.exists()
    val legacyFile = if (legacyPath != null) keystorePath(legacyPath) else null
    val lineageFileResolved = if (lineagePath != null) keystorePath(lineagePath) else null

    doLast {
        if (!hasProps) {
            logger.warn("[签名] 缺少 android/key.properties，release 将使用 debug 签名（仅限本地调试）")
            return@doLast
        }
        logger.lifecycle("[签名] upload 密钥: ${keystorePath(keystoreProperties["storeFile"] as String?)}")
        val rotationOk = legacyFile != null && legacyFile.exists() &&
            lineageFileResolved != null && lineageFileResolved.exists()
        if (rotationOk) {
            logger.lifecycle("[签名] 密钥轮换 lineage 已就绪: ${lineageFileResolved!!.name}")
            logger.lifecycle("[签名] 构建正式发布包请使用: powershell -File tool/build-release.ps1")
        } else {
            logger.warn("[签名] 未配置 legacyStoreFile / lineageFile，将无法生成密钥轮换签名。")
            logger.warn("[签名] 后果：<= v1.15.0（debug 签名）的老用户覆盖安装会报「签名冲突」。")
            logger.warn("[签名] 修复：把旧的 debug.keystore 放到 android/keystores/legacy-debug.jks，")
            logger.warn("[签名]       并按 README「签名与版本发布」一节生成 lineage 文件。")
        }
    }
}
