allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Toolchain fix (not a dependency change, uncommitted -- see E14-B07):
// `sentry_flutter` 8.14.2's own bundled Android module hardcodes
// `languageVersion = "1.6"` in its android/build.gradle (`kotlinOptions`),
// which this project's Kotlin Gradle Plugin (2.3.20, settings.gradle.kts)
// no longer supports compiling at all. Forces every Kotlin compile task
// project-wide (including third-party modules) onto a supported
// language/API version. This does NOT fix E14-B07's other half (the
// sentry_flutter-vs-package_info_plus AAR metadata compileSdk conflict),
// which has no known build-script-level fix and needs a human dependency-
// version decision.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
            apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
