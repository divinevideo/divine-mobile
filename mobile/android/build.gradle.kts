allprojects {
    repositories {
        google()
        mavenCentral()
        // Guardian Project Maven repo for ProofMode library
        maven {
            url = uri("https://raw.githubusercontent.com/guardianproject/gpmaven/master")
        }
        // Zendesk Maven repo for Support SDK
        maven {
            url = uri("https://zendesk.jfrog.io/zendesk/repo")
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.media3") {
                useVersion("1.11.1")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
