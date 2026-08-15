allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // Force flutter_bluetooth_serial to use a compatible appcompat version
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.appcompat" && requested.name == "appcompat") {
                useVersion("1.2.0")
                because("flutter_bluetooth_serial 0.4.0 is incompatible with appcompat 1.3+ on compileSdk 36")
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
