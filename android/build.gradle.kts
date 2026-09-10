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

    plugins.withId("com.android.library") {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val getNs = android.javaClass.getMethod("getNamespace")
                val currentNs = getNs.invoke(android) as? String
                if (currentNs.isNullOrEmpty()) {
                    val setNs = android.javaClass.getMethod("setNamespace", String::class.java)
                    val targetNs = if (project.name == "isar_flutter_libs") {
                        "dev.isar.isar_flutter_libs"
                    } else {
                        "dev.isar.${project.name.replace('-', '_')}"
                    }
                    setNs.invoke(android, targetNs)
                }
            } catch (_: Exception) {}
        }
    }

    afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android != null) {
            for (methodName in listOf("compileSdkVersion", "setCompileSdkVersion")) {
                try {
                    val m = android.javaClass.getMethod(methodName, Int::class.javaPrimitiveType)
                    m.invoke(android, 35)
                    break
                } catch (_: Exception) {}
            }
            try {
                val m = android.javaClass.getMethod("compileSdkVersion", String::class.java)
                m.invoke(android, "android-35")
            } catch (_: Exception) {}
            try {
                val m = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                m.invoke(android, 35)
            } catch (_: Exception) {}
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}



tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
