allprojects {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://jitpack.io")
    }
    extra["compileSdkVersion"] = 36
    extra["compileSdk"] = 36
    extra["targetSdkVersion"] = 36
    extra["minSdkVersion"] = 24
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
    val configureProject: Project.() -> Unit = {
        if (hasProperty("android")) {
            val androidExt = extensions.findByName("android")
            if (androidExt is com.android.build.gradle.BaseExtension) {
                androidExt.compileSdkVersion(36)
            }
        }
    }

    if (state.executed) {
        configureProject()
    } else {
        afterEvaluate {
            configureProject()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
