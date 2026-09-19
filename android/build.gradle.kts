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

    // Inject namespace for older Flutter plugins like flutter_bluetooth_serial
    afterEvaluate {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            try {
                val namespaceMethod = androidExt.javaClass.getMethod("getNamespace")
                val namespaceVal = namespaceMethod.invoke(androidExt)
                if (namespaceVal == null) {
                    val fallback = project.group.toString()
                    androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, fallback)
                    println("Automatically injected namespace '$fallback' into plugin '${project.name}'")
                }
            } catch (e: Exception) {
                // Ignore if methods don't exist
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
