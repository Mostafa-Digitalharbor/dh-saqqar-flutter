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
// Some third-party Flutter plugins (notably `receive_sharing_intent`)
// ship Kotlin sources targeting JVM 21 but leave Java compileOptions at
// 1.8, which fails Gradle's "Inconsistent JVM-target compatibility"
// check. Force every subproject's Android `compileOptions` + Kotlin
// `jvmTarget` to 17 (our app target) so the plugin's Kotlin step and
// Java step agree.
//
// MUST be registered BEFORE the `evaluationDependsOn(":app")` block
// below — that block forces every subproject to evaluate as part of
// configuring the root, which means by the time configuration reaches
// any later `afterEvaluate { ... }` they've already been evaluated and
// Gradle throws "Cannot run Project.afterEvaluate when the project is
// already evaluated". Order matters; don't swap these two blocks.
//
// `runCatching` so non-Android subprojects (the Flutter Gradle plugin
// itself, the root project) don't blow up when the BaseExtension /
// KotlinCompile types aren't present.
subprojects {
    afterEvaluate {
        runCatching {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
