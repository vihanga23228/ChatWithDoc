allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Plugins with native code (e.g. `jni`, used by path_provider_android) request NDK 28.2, whose automatic
// download fails on this machine. Build them with the installed NDK instead (newer NDKs are backward compatible).
// Registered before `evaluationDependsOn`, and applied after each plugin's own build script has run.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.withGroovyBuilder {
            "setNdkVersion"("30.0.16248370")
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
