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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// otp_autofill تضبط compileSdk=33 داخل بلوك android{} الخاص بها، بينما اعتمادياتها
// AndroidX الحديثة تتطلب 34+. بلوك plugins.withId وحده يشتغل وقت تطبيق البِلَجِن —
// أي قبل بلوك android{} — فترجع القيمة 33. لذا نفرض الحدّ الأدنى بعد اكتمال تقييم
// المشروع، و**نرفع فقط ما هو دون 34** حتى لا نخفض مكتبات أخرى تحتاج أعلى (مثل
// permission_handler الذي يُصرَّف ضد 36/37). ومع AGP 9 + evaluationDependsOn(":app")
// بعض المشاريع تكون اتقيّمت قبل وصول هذا البلوك، فنتفادى خطأ "already evaluated".
subprojects {
    val raiseCompileSdk = {
        plugins.withId("com.android.library") {
            val android =
                extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null) {
                // getter يُرجع نصًّا مثل "android-33"؛ نستخرج الرقم فقط للمقارنة.
                val current =
                    android.compileSdkVersion
                        ?.filter { it.isDigit() }
                        ?.toIntOrNull() ?: 0
                if (current < 34) {
                    android.compileSdkVersion(34)
                }
            }
        }
    }
    if (state.executed) {
        raiseCompileSdk()
    } else {
        afterEvaluate { raiseCompileSdk() }
    }
}
